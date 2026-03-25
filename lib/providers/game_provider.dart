import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/hex.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../models/game_mode.dart';
import '../logic/game_logic.dart';
import '../logic/ai_player.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../services/game_save_service.dart';
import '../providers/settings_provider.dart';

typedef SendMoveCallback = Future<void> Function();

final gameProvider = NotifierProvider<GameNotifier, GameState>(
  GameNotifier.new,
);

final currentTurnProvider = Provider<Player>(
  (ref) => ref.watch(gameProvider.select((s) => s.currentTurn)),
);

final selectionProvider = Provider<List<Hex>>(
  (ref) => ref.watch(gameProvider.select((s) => s.selection)),
);

final blackScoreProvider = Provider<int>(
  (ref) => ref.watch(gameProvider.select((s) => s.blackScore)),
);

final whiteScoreProvider = Provider<int>(
  (ref) => ref.watch(gameProvider.select((s) => s.whiteScore)),
);

final moveCountProvider = Provider<int>(
  (ref) => ref.watch(gameProvider.select((s) => s.moveCount)),
);

final statusProvider = Provider<String>(
  (ref) => ref.watch(gameProvider.select((s) => s.statusMessage)),
);

final isGameOverProvider = Provider<bool>(
  (ref) => ref.watch(gameProvider.select((s) => s.isGameOver)),
);

final winnerProvider = Provider<Player?>(
  (ref) => ref.watch(gameProvider.select((s) => s.winner)),
);

final isAiThinkingProvider = Provider<bool>(
  (ref) => ref.watch(gameProvider.select((s) => s.isAnimating)),
);

final extraTurnProvider = Provider<bool>(
  (ref) => ref.watch(gameProvider.select((s) => s.extraTurn)),
);
class GameNotifier extends Notifier<GameState> {
  final List<GameState> _history = [];
  GameMode _mode = GameMode.localMultiplayer;
  AiPlayer? _ai;
  AiDifficulty _aiDifficulty = AiDifficulty.medium;
  bool _aiThinking = false;
  bool _disposed = false;
  bool _tipActive = false;
  bool _aiPaused = false;
  bool _aiPendingMove = false;

  Player _myColor = Player.black;
  Player? _onlineMyColor;

  SendMoveCallback? onMoveMade;

  @override
  GameState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _aiThinking = false;
    });

    final settings = ref.watch(settingsProvider);
    HapticService.setEnabled(settings.hapticEnabled);
    SoundService.setEnabled(settings.soundEnabled);

    return GameLogic.initialState();
  }

  bool get canUndo => _history.isNotEmpty && !_aiThinking;
  GameMode get mode => _mode;
  bool get isAiThinking => _aiThinking;
  bool get isTipActive => _tipActive;
  AiDifficulty get aiDifficulty => _aiDifficulty;

  Player get myColor {
    if (_mode == GameMode.online) return _onlineMyColor ?? Player.black;
    if (_mode == GameMode.vsComputer) return _myColor;
    return Player.black;
  }

  Player get aiColor => _myColor.opponent;

  SettingsState get _settings => ref.read(settingsProvider);

  Duration _adjustedDuration(int baseMs) {
    return Duration(
        milliseconds: (baseMs / _settings.animationSpeed).round());
  }

  void _safeUpdate(GameState newState) {
    if (!_disposed) state = newState;
  }

  // ══════════════════════════════════════
  // AUTO SAVE
  // ══════════════════════════════════════

  void _autoSave() {
    if (_mode == GameMode.online) return;

    if (state.isGameOver) {
      GameSaveService.deleteSave(_mode);
      return;
    }
    if (state.moveCount == 0) return;

    GameSaveService.saveGame(
      gameState: state,
      mode: _mode,
      aiDifficulty: _mode == GameMode.vsComputer ? _aiDifficulty : null,
      myColor: _mode == GameMode.vsComputer ? _myColor : null,
    );
  }

  // ══════════════════════════════════════
  // AI PAUSE / RESUME
  // ══════════════════════════════════════

  void pauseAi() {
    _aiPaused = true;
  }

  void resumeAi() {
    _aiPaused = false;
    if (_aiPendingMove && !_disposed && !state.isGameOver) {
      _aiPendingMove = false;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!_disposed && !_aiPaused) _doAiMove();
      });
    }
  }

  // ══════════════════════════════════════
  // CONTINUE SAVED GAME
  // ══════════════════════════════════════

  Future<bool> continueGame(GameMode targetMode) async {
    final saveData = await GameSaveService.loadGame(targetMode);
    if (saveData == null) return false;

    _history.clear();
    _aiThinking = false;
    _tipActive = false;
    _aiPaused = false;
    _aiPendingMove = false;
    onMoveMade = null;
    _mode = saveData.mode;

    if (saveData.mode == GameMode.vsComputer) {
      _aiDifficulty = saveData.aiDifficulty ?? AiDifficulty.medium;
      _myColor = saveData.myColor ?? Player.black;
      _ai = AiPlayer(difficulty: _aiDifficulty);

      final isMyTurn = saveData.currentTurn == _myColor;
      _safeUpdate(GameState(
        board: saveData.board,
        currentTurn: saveData.currentTurn,
        blackScore: saveData.blackScore,
        whiteScore: saveData.whiteScore,
        moveCount: saveData.moveCount,
        statusMessage: isMyTurn ? 'Your turn' : 'Computer thinking...',
        selection: [],
        hintHexes: {},
        pushTargets: {},
      ));

      if (!isMyTurn) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!_disposed) _doAiMove();
        });
      }
    } else if (saveData.mode == GameMode.localMultiplayer) {
      _ai = null;
      _myColor = Player.black;

      _safeUpdate(GameState(
        board: saveData.board,
        currentTurn: saveData.currentTurn,
        blackScore: saveData.blackScore,
        whiteScore: saveData.whiteScore,
        moveCount: saveData.moveCount,
        statusMessage: '${saveData.currentTurn.displayName}\'s turn',
        selection: [],
        hintHexes: {},
        pushTargets: {},
      ));
    }

    return true;
  }

  // ══════════════════════════════════════
  // GAME SETUP
  // ══════════════════════════════════════

  void startVsComputer(AiDifficulty difficulty,
    {Player myColor = Player.black}) {
  _mode = GameMode.vsComputer;
  _aiDifficulty = difficulty;
  _myColor = myColor;
  _ai = AiPlayer(difficulty: difficulty);
  _history.clear();
  _aiThinking = false;
  _tipActive = false;
  _aiPaused = false;
  _aiPendingMove = false;
  onMoveMade = null;

  final fresh = GameLogic.initialState();
  _safeUpdate(GameState(
    board: fresh.board,
    currentTurn: fresh.currentTurn,
    blackScore: 0,
    whiteScore: 0,
    selection: const [],
    moveCount: 0,
    statusMessage: myColor == Player.black
        ? 'Your turn — tap your marbles'
        : 'Computer thinking...',
    hintHexes: const {},
    pushTargets: const {},
    isAnimating: false,
    lastMoveAnimation: null,
    extraTurn: false,
  ));

  if (myColor == Player.white) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_disposed) _doAiMove();
    });
  }
}

void startLocalMultiplayer() {
  _mode = GameMode.localMultiplayer;
  _ai = null;
  _myColor = Player.black;
  _history.clear();
  _aiThinking = false;
  _tipActive = false;
  _aiPaused = false;
  _aiPendingMove = false;
  onMoveMade = null;

  final fresh = GameLogic.initialState();
  _safeUpdate(GameState(
    board: fresh.board,
    currentTurn: fresh.currentTurn,
    blackScore: 0,
    whiteScore: 0,
    selection: const [],
    moveCount: 0,
    statusMessage: '${fresh.currentTurn.displayName}\'s turn',
    hintHexes: const {},
    pushTargets: const {},
    isAnimating: false,
    lastMoveAnimation: null,
    extraTurn: false,
  ));
}

void startOnline(Player myColor) {
  _mode = GameMode.online;
  _onlineMyColor = myColor;
  _ai = null;
  _history.clear();
  _aiThinking = false;
  _tipActive = false;
  _aiPaused = false;
  _aiPendingMove = false;

  final fresh = GameLogic.initialState();
  _safeUpdate(GameState(
    board: fresh.board,
    currentTurn: fresh.currentTurn,
    blackScore: 0,
    whiteScore: 0,
    selection: const [],
    moveCount: 0,
    statusMessage: myColor == Player.black
        ? 'Your turn'
        : 'Opponent\'s turn...',
    hintHexes: const {},
    pushTargets: const {},
    isAnimating: false,
    lastMoveAnimation: null,
    extraTurn: false,
  ));
}

  void updateFromOnline(
    Map<Hex, Player> board,
    Player turn,
    int bScore,
    int wScore,
    int moves,
  ) {
    // Detect if this was a push-off (score increased)
    final bool wasPushOff = (bScore > state.blackScore) ||
        (wScore > state.whiteScore);
    final bool isExtraTurn = wasPushOff && (turn == state.currentTurn);

    // Build animation from board diff
    MoveAnimationData? animData;
    if (state.board.isNotEmpty && moves > state.moveCount) {
      animData = _buildAnimFromDiff(state.board, board);
    }

    String statusMsg;
    if (isExtraTurn) {
      if (turn == _onlineMyColor) {
        statusMsg = '🔥 You pushed off! BONUS TURN!';
      } else {
        statusMsg = '🔥 Opponent pushed off! Opponent goes again...';
      }
    } else {
      statusMsg = turn == _onlineMyColor
          ? 'Your turn'
          : 'Opponent\'s turn...';
    }

    _safeUpdate(GameState(
      board: board,
      currentTurn: turn,
      blackScore: bScore,
      whiteScore: wScore,
      moveCount: moves,
      statusMessage: statusMsg,
      selection: [],
      hintHexes: {},
      pushTargets: {},
      lastMoveAnimation: animData,
      extraTurn: isExtraTurn, // ← NEW
    ));
  }

  /// Build animation data by diffing old and new boards
  MoveAnimationData? _buildAnimFromDiff(
    Map<Hex, Player> oldBoard,
    Map<Hex, Player> newBoard,
  ) {
    final anims = <MarbleAnimation>[];
    final appeared = <Hex, Player>{};
    final disappeared = <Hex, Player>{};

    final allHexes = {...oldBoard.keys, ...newBoard.keys};
    for (final hex in allHexes) {
      final oldP = oldBoard[hex] ?? Player.none;
      final newP = newBoard[hex] ?? Player.none;
      if (oldP == newP) continue;
      if (oldP != Player.none && newP == Player.none) {
        disappeared[hex] = oldP;
      }
      if (oldP == Player.none && newP != Player.none) {
        appeared[hex] = newP;
      }
      if (oldP != Player.none && newP != Player.none && oldP != newP) {
        disappeared[hex] = oldP;
        appeared[hex] = newP;
      }
    }

    // Try to match disappeared → appeared of same color
    final usedAppeared = <Hex>{};
    for (final entry in disappeared.entries) {
      Hex? bestMatch;
      int bestDist = 999;
      for (final aEntry in appeared.entries) {
        if (usedAppeared.contains(aEntry.key)) continue;
        if (aEntry.value == entry.value) {
          final dist = entry.key.distanceTo(aEntry.key);
          if (dist < bestDist) {
            bestDist = dist;
            bestMatch = aEntry.key;
          }
        }
      }
      if (bestMatch != null && bestDist <= 3) {
        usedAppeared.add(bestMatch);
        anims.add(MarbleAnimation(
          from: entry.key,
          to: bestMatch,
          player: entry.value,
        ));
      } else {
        // Pushed off
        anims.add(MarbleAnimation(
          from: entry.key,
          to: entry.key, // stays in place visually then fades
          player: entry.value,
          isPushedOff: true,
        ));
      }
    }

    if (anims.isEmpty) return null;

    // Guess direction
    Hex dir = const Hex(0, 0);
    final sliding = anims.where((a) => !a.isPushedOff).toList();
    if (sliding.isNotEmpty) {
      dir = sliding.first.to - sliding.first.from;
    }

    return MoveAnimationData(
      animations: anims,
      direction: dir,
      movingPlayer: sliding.isNotEmpty ? sliding.first.player : Player.none,
      pushedOffCount: anims.where((a) => a.isPushedOff).length,
    );
  }

  // ══════════════════════════════════════
  // TAP
  // ══════════════════════════════════════

  void tapHex(Hex hex) {
    if (state.isGameOver || _aiThinking) return;
    if (_mode == GameMode.online && state.currentTurn != _onlineMyColor) {
      return;
    }
    if (_mode == GameMode.vsComputer && state.currentTurn != _myColor) {
      return;
    }

    _tipActive = false;
    final player = state.currentTurn;
    final board = state.board;

    if (board[hex] == player) {
      _handleSelection(hex, player);
      return;
    }

    if (state.hasSelection &&
        GameLogic.isValidSelection(state.selection, board)) {
      _handleMove(hex, player);
      return;
    }

    _clearSelection();
  }

  void _handleSelection(Hex hex, Player player) {
    HapticService.selectionClick();
    SoundService.playSelect();

    final sel = List<Hex>.from(state.selection);

    if (sel.contains(hex)) {
      sel.remove(hex);
    } else if (sel.length < 3) {
      sel.add(hex);
      if (!GameLogic.isValidSelection(sel, state.board)) {
        sel.removeLast();
        _safeUpdate(
            state.copyWith(statusMessage: 'Must be in a straight line'));
        return;
      }
    } else {
      sel
        ..clear()
        ..add(hex);
    }

    _safeUpdate(state.copyWith(
      selection: sel,
      clearAnimation: true,
    ));
    _updateHints();

    String statusMsg;
     if (sel.isEmpty) {
      if (state.extraTurn) {
        if (_mode == GameMode.vsComputer || _mode == GameMode.online) {
          statusMsg = 'Bonus turn! Select marbles';
        } else {
          statusMsg = '${player.displayName}\'s bonus turn!';
        }
      } else {
        if (_mode == GameMode.vsComputer) {
          statusMsg = 'Your turn';
        } else if (_mode == GameMode.online) {
          statusMsg = 'Your turn';
        } else {
          statusMsg = '${player.displayName}\'s turn';
        }
      }
    } else {
      statusMsg = '${sel.length} selected — tap to move';
    }
    _safeUpdate(state.copyWith(statusMessage: statusMsg));
  }

  void _handleMove(Hex target, Player player) {
    final dir =
        _findDirection(state.selection, target, state.board, player);

    if (dir != null) {
      final result =
          GameLogic.tryMove(state.selection, dir, state.board, player);
      if (result.valid && result.newBoard != null) {
        _executeMove(result, dir, List.from(state.selection));
        return;
      }
      _safeUpdate(state.copyWith(
          statusMessage: result.reason ?? 'Invalid move'));
      HapticService.heavyImpact();
      SoundService.playError();
      return;
    }

    _safeUpdate(state.copyWith(statusMessage: 'Can\'t move there'));
    HapticService.lightImpact();
  }

  // ══════════════════════════════════════
  // BUILD MOVE ANIMATION
  // ══════════════════════════════════════

  MoveAnimationData _buildMoveAnimation(
    List<Hex> selection,
    Hex direction,
    Map<Hex, Player> oldBoard,
    Player movingPlayer,
    MoveResult result,
  ) {
    final anims = <MarbleAnimation>[];
    final sorted = GameLogic.sortSelection(selection);

    // Determine inline vs broadside
    Hex? lineDir;
    if (sorted.length >= 2) {
      lineDir = sorted[1] - sorted[0];
    }

    final isInline = lineDir != null &&
        (direction == lineDir || direction == Hex(-lineDir.q, -lineDir.r));

    // Add player marble slide animations
    for (final hex in sorted) {
      anims.add(MarbleAnimation(
        from: hex,
        to: hex + direction,
        player: movingPlayer,
      ));
    }

    // Add pushed opponent marbles
    if (isInline && result.pushedOff > 0) {
      final bool movingForward = lineDir == direction;
      final front = movingForward ? sorted.last : sorted.first;

      Hex check = front + direction;
      while (oldBoard.containsKey(check) &&
          oldBoard[check] == movingPlayer.opponent) {
        final dest = check + direction;
        final isPushedOff = !oldBoard.containsKey(dest);
        anims.add(MarbleAnimation(
          from: check,
          to: dest,
          player: movingPlayer.opponent,
          isPushedOff: isPushedOff,
        ));
        check = check + direction;
      }
    }

    return MoveAnimationData(
      animations: anims,
      direction: direction,
      movingPlayer: movingPlayer,
      pushedOffCount: result.pushedOff,
    );
  }

  // ══════════════════════════════════════
  // EXECUTE MOVE
  // ══════════════════════════════════════

   void _executeMove(MoveResult result, Hex direction, List<Hex> sel) {
    HapticService.mediumImpact();
    SoundService.playMove();
    _history.add(state);

    // Build animation BEFORE updating board
    final animData = _buildMoveAnimation(
      sel,
      direction,
      state.board,
      state.currentTurn,
      result,
    );

    // ── Calculate scores ──
    int bScore = state.blackScore;
    int wScore = state.whiteScore;

    if (result.pushedOff > 0) {
      if (state.currentTurn == Player.black) {
        bScore += result.pushedOff;
      } else {
        wScore += result.pushedOff;
      }
      HapticService.heavyImpact();
      SoundService.playPush();
    }

    // ══════════════════════════════════════════
    // KEY CHANGE: Determine next turn
    // ══════════════════════════════════════════
    final bool isPushOff = result.pushedOff > 0;
    final Player currentPlayer = state.currentTurn;

    // If push-off → SAME player gets extra turn
    // If no push-off → OPPONENT's turn
    final Player nextTurn = isPushOff
        ? currentPlayer        // BONUS: same player again!
        : currentPlayer.opponent;  // Normal: switch turns

    final bool isExtraTurn = isPushOff;

    // ── Build status message ──
    String statusMsg;
    if (isPushOff) {
      if (_mode == GameMode.vsComputer) {
        statusMsg = nextTurn == _myColor
            ? 'Pushed off! Play again'
            : 'Computer plays again...';
      } else if (_mode == GameMode.online) {
        statusMsg = nextTurn == _onlineMyColor
            ? 'Pushed off! Play again'
            : 'Opponent plays again...';
      } else {
        statusMsg = '${currentPlayer.displayName} plays again!';
      }
    } else {
      if (_mode == GameMode.vsComputer) {
        statusMsg = nextTurn == _myColor
            ? 'Your turn'
            : 'Computer thinking...';
      } else if (_mode == GameMode.online) {
        statusMsg = nextTurn == _onlineMyColor
            ? 'Your turn'
            : 'Opponent\'s turn...';
      } else {
        statusMsg = '${nextTurn.displayName}\'s turn';
      }
    }

    // ── Update state ──
    _safeUpdate(GameState(
      board: result.newBoard!,
      currentTurn: nextTurn,           // ← Same player if push-off!
      blackScore: bScore,
      whiteScore: wScore,
      selection: [],
      moveCount: state.moveCount + 1,
      statusMessage: statusMsg,
      hintHexes: {},
      pushTargets: {},
      lastMoveAnimation: animData,
      extraTurn: isExtraTurn,          // ← Track bonus turn for UI
    ));

    _autoSave();

    // ── Check game over ──
    if (state.isGameOver) {
      SoundService.playWin();
      HapticService.heavyImpact();
      return;
    }

    // ── Handle AI turn ──
    // AI plays if it's now the AI's turn (including bonus turns FOR the AI)
    if (_mode == GameMode.vsComputer && nextTurn == aiColor) {
      if (_aiPaused) {
        _aiPendingMove = true;
      } else {
        _doAiMove();
      }
    }

    // ── Handle online sync ──
    if (_mode == GameMode.online && onMoveMade != null) {
      Future.microtask(() => onMoveMade!());
    }
    Future.delayed(const Duration(milliseconds: 800), () {
    if (!_disposed && state.lastMoveAnimation != null) {
      _safeUpdate(state.copyWith(clearAnimation: true));
    }
  });
  }

  // ══════════════════════════════════════
  // TIP MOVE
  // ══════════════════════════════════════

  Future<bool> showTipMove() async {
    if (state.isGameOver || _aiThinking) return false;

    final player = state.currentTurn;
    if (_mode == GameMode.vsComputer && player != _myColor) return false;
    if (_mode == GameMode.online && player != _onlineMyColor) return false;

    final tipAi = AiPlayer(difficulty: AiDifficulty.hard);
    final move = await tipAi.findMove(state.board, player);
    if (move == null || _disposed) return false;

    final (sel, dir) = move;
    final result = GameLogic.tryMove(sel, dir, state.board, player);
    if (!result.valid || result.newBoard == null) return false;

    _tipActive = true;
    _aiThinking = true;
    _safeUpdate(state.copyWith(isAnimating: true));

    _safeUpdate(state.copyWith(
        selection: sel, statusMessage: '💡 Selecting marbles...'));
    SoundService.playSelect();
    HapticService.mediumImpact();

    await Future.delayed(_adjustedDuration(800));
    if (_disposed) return false;

    final sorted = GameLogic.sortSelection(sel);
    final targetHexes = <Hex>{};
    final pushHexes = <Hex>{};

    for (final h in sorted) {
      final t = h + dir;
      if (state.board.containsKey(t)) {
        if (state.board[t] == Player.none) {
          targetHexes.add(t);
        } else if (state.board[t] == player.opponent) {
          pushHexes.add(t);
        }
      }
    }

    if (pushHexes.isNotEmpty) {
      Hex check = sorted.last + dir;
      while (state.board.containsKey(check) &&
          state.board[check] != Player.none) {
        pushHexes.add(check);
        check = check + dir;
      }
    }

    _safeUpdate(state.copyWith(
      hintHexes: targetHexes,
      pushTargets: pushHexes,
      statusMessage:
          pushHexes.isNotEmpty ? '💡 Pushing!' : '💡 Moving here...',
    ));
    HapticService.lightImpact();

    await Future.delayed(_adjustedDuration(600));
    if (_disposed) return false;

    _tipActive = false;
    _aiThinking = false;

    _executeMove(result, dir, List.from(sel));

    await Future.delayed(_adjustedDuration(300));
    if (_disposed) return false;

    _safeUpdate(state.copyWith(
      isAnimating: false,
      statusMessage: '💡 Tip used! ${state.statusMessage}',
    ));

    // If _executeMove didn't trigger AI (e.g. bonus turn for player),
    // check again now
    if (_mode == GameMode.vsComputer &&
        !state.isGameOver &&
        state.currentTurn == aiColor &&
        !_aiThinking) {
      if (_aiPaused) {
        _aiPendingMove = true;
      } else {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_disposed && !_aiThinking) _doAiMove();
        });
      }
    }

    return true;
  }

  // ══════════════════════════════════════
  // AI MOVE
  // ══════════════════════════════════════

  Future<void> _doAiMove() async {
    if (_disposed || _aiThinking || _aiPaused) {
      if (_aiPaused) _aiPendingMove = true;
      return;
    }

    _aiThinking = true;
    _safeUpdate(state.copyWith(
        statusMessage: 'Computer thinking...', isAnimating: true));

    final move = await _ai!.findMove(state.board, aiColor);

    if (move == null || _disposed) {
      _aiThinking = false;
      if (!_disposed) _safeUpdate(state.copyWith(isAnimating: false));
      return;
    }

    if (_aiPaused) {
      _aiPendingMove = true;
      _aiThinking = false;
      if (!_disposed) _safeUpdate(state.copyWith(isAnimating: false));
      return;
    }

    final (sel, dir) = move;
    final result = GameLogic.tryMove(sel, dir, state.board, aiColor);

    if (result.valid && result.newBoard != null) {
      // Show AI selection
      _safeUpdate(state.copyWith(
          selection: sel, statusMessage: 'Computer selecting...'));
      SoundService.playSelect();
      HapticService.lightImpact();

      await Future.delayed(_adjustedDuration(700));
      if (_disposed) return;

      if (_aiPaused) {
        _aiPendingMove = true;
        _aiThinking = false;
        _safeUpdate(state.copyWith(selection: [], isAnimating: false));
        return;
      }

      // Show AI target hints
      final sorted = GameLogic.sortSelection(sel);
      final targetHexes = <Hex>{};
      final pushHexes = <Hex>{};

      for (final h in sorted) {
        final t = h + dir;
        if (state.board.containsKey(t)) {
          if (state.board[t] == Player.none) {
            targetHexes.add(t);
          } else if (state.board[t] == aiColor.opponent) {
            pushHexes.add(t);
          }
        }
      }

      if (pushHexes.isNotEmpty) {
        Hex check = sorted.last + dir;
        while (state.board.containsKey(check) &&
            state.board[check] != Player.none) {
          pushHexes.add(check);
          check = check + dir;
        }
      }

      _safeUpdate(state.copyWith(
        hintHexes: targetHexes,
        pushTargets: pushHexes,
        statusMessage: pushHexes.isNotEmpty
            ? 'Computer pushing!'
            : 'Computer moving...',
      ));
      HapticService.mediumImpact();

      await Future.delayed(_adjustedDuration(500));
      if (_disposed) return;

      // Execute the move — this handles bonus turn logic internally
      _executeMove(result, dir, List.from(sel));

      await Future.delayed(_adjustedDuration(300));
      if (_disposed) return;

      // ══════════════════════════════════════
      // KEY: Check if AI got a bonus turn
      // ══════════════════════════════════════
      if (!state.isGameOver && state.extraTurn && state.currentTurn == aiColor) {
        // AI pushed off a marble and gets another turn!
        _aiThinking = false; // Reset so _doAiMove can run again

        await Future.delayed(_adjustedDuration(800)); // Pause to show banner
        if (_disposed) return;

        if (_aiPaused) {
          _aiPendingMove = true;
          _safeUpdate(state.copyWith(isAnimating: false));
          return;
        }

        // AI takes its bonus turn
        await _doAiMove();
        return;
      }

      if (state.isGameOver) {
        SoundService.playWin();
        HapticService.heavyImpact();
      }
    }

    _aiThinking = false;
    if (!_disposed) _safeUpdate(state.copyWith(isAnimating: false));
  }
void handleSwipeMove(Hex fromHex, Hex direction) {
  if (state.isGameOver || _aiThinking) return;
  if (_mode == GameMode.online && state.currentTurn != _onlineMyColor) {
    return;
  }
  if (_mode == GameMode.vsComputer && state.currentTurn != _myColor) {
    return;
  }

  _tipActive = false;
  final player = state.currentTurn;

  if (state.selection.isEmpty || !state.selection.contains(fromHex)) {
    if (state.board[fromHex] == player) {
      _handleSelection(fromHex, player);
    } else {
      return;
    }
  }

  if (state.hasSelection &&
      GameLogic.isValidSelection(state.selection, state.board)) {
    final sel = List<Hex>.from(state.selection);
    final result = GameLogic.tryMove(sel, direction, state.board, player);
    if (result.valid && result.newBoard != null) {
      _executeMove(result, direction, sel);
      return;
    }

    for (final s in state.selection) {
      final target = s + direction;
      if (state.board.containsKey(target)) {
        final dir = _findDirection(
            state.selection, target, state.board, player);
        if (dir != null) {
          final moveResult = GameLogic.tryMove(
              state.selection, dir, state.board, player);
          if (moveResult.valid && moveResult.newBoard != null) {
            _executeMove(moveResult, dir, List.from(state.selection));
            return;
          }
        }
      }
    }

    HapticService.lightImpact();
    _safeUpdate(
        state.copyWith(statusMessage: 'Can\'t move that direction'));
  }
}
  // ══════════════════════════════════════
  // UNDO
  // ══════════════════════════════════════

  void undoPlayerMove() {
    if (!canUndo || _mode == GameMode.online) return;

    HapticService.lightImpact();
    SoundService.playTap();

    if (_mode == GameMode.vsComputer) {
      // If it's currently the player's bonus turn, just undo 1 move
      // (undo the push-off move, turn goes back to opponent or stays)
      if (state.extraTurn && state.currentTurn == _myColor) {
        if (_history.isNotEmpty) {
          final restored = _history.removeLast();
          _safeUpdate(restored.copyWith(
            hintHexes: {},
            pushTargets: {},
            statusMessage: 'Bonus turn undone — opponent\'s turn',
            clearAnimation: true,
            extraTurn: false,
          ));
          _autoSave();

          // After undo, if it's now AI's turn, trigger AI
          if (restored.currentTurn == aiColor) {
            if (_aiPaused) {
              _aiPendingMove = true;
            } else {
              _doAiMove();
            }
          }
          return;
        }
      }

      // Normal undo: skip AI's move too (undo 2 states)
      if (state.currentTurn == _myColor && _history.length >= 2) {
        _history.removeLast();
        final restored = _history.removeLast();
        _safeUpdate(restored.copyWith(
          hintHexes: {},
          pushTargets: {},
          statusMessage: 'Your turn — undone',
          clearAnimation: true,
          extraTurn: false,
        ));
        _autoSave();
        return;
      }

      if (_history.isNotEmpty) {
        final restored = _history.removeLast();
        _safeUpdate(restored.copyWith(
          hintHexes: {},
          pushTargets: {},
          statusMessage: 'Your turn — undone',
          clearAnimation: true,
          extraTurn: false,
        ));
        _autoSave();
        return;
      }
    } else {
      // Local multiplayer
      final restored = _history.removeLast();
      _safeUpdate(restored.copyWith(
        hintHexes: {},
        pushTargets: {},
        statusMessage:
            '${restored.currentTurn.displayName}\'s turn — undone',
        clearAnimation: true,
        extraTurn: false,
      ));
      _autoSave();
    }
  }

  void undo() => undoPlayerMove();

  void clearSelection() => _clearSelection();

    void _clearSelection() {
    String msg;
    final isBonus = state.extraTurn;

    if (_mode == GameMode.vsComputer) {
      msg = state.currentTurn == _myColor
          ? (isBonus ? 'Bonus turn! Select marbles' : 'Your turn')
          : 'Computer thinking...';
    } else if (_mode == GameMode.online) {
      msg = state.currentTurn == _onlineMyColor
          ? (isBonus ? 'Bonus turn! Select marbles' : 'Your turn')
          : 'Opponent\'s turn...';
    } else {
      final name = state.currentTurn.displayName;
      msg = isBonus ? '$name\'s bonus turn!' : '$name\'s turn';
    }
    _safeUpdate(state.copyWith(
      selection: [],
      hintHexes: {},
      pushTargets: {},
      statusMessage: msg,
    ));
  }

  void clearTip() {
    _tipActive = false;
    _clearSelection();
  }

  void _updateHints() {
    if (!_settings.showMoveHints) {
      _safeUpdate(state.copyWith(hintHexes: {}, pushTargets: {}));
      return;
    }

    final sel = state.selection;
    if (sel.isEmpty ||
        !GameLogic.isValidSelection(sel, state.board)) {
      _safeUpdate(state.copyWith(hintHexes: {}, pushTargets: {}));
      return;
    }

    final dirs = GameLogic.getValidMoveDirections(
        sel, state.board, state.currentTurn);
    final hints = <Hex>{};
    final pushes = <Hex>{};

    for (final dir in dirs) {
      for (final h in GameLogic.sortSelection(sel)) {
        final t = h + dir;
        if (!state.board.containsKey(t)) continue;
        if (state.board[t] == Player.none) {
          hints.add(t);
        } else if (state.board[t] == state.currentTurn.opponent) {
          pushes.add(t);
        }
      }
    }

    _safeUpdate(state.copyWith(hintHexes: hints, pushTargets: pushes));
  }

  void resetGame() {
  HapticService.mediumImpact();
  SoundService.playTap();
  _history.clear();
  _aiThinking = false;
  _tipActive = false;
  _aiPaused = false;
  _aiPendingMove = false;

  GameSaveService.deleteSave(_mode);

  if (_mode == GameMode.vsComputer) {
    startVsComputer(_aiDifficulty, myColor: _myColor);
  } else if (_mode == GameMode.online) {
    final myColor = _onlineMyColor ?? Player.black;
    final fresh = GameLogic.initialState();
    _safeUpdate(GameState(
      board: fresh.board,
      currentTurn: fresh.currentTurn,
      blackScore: 0,
      whiteScore: 0,
      selection: const [],
      moveCount: 0,
      statusMessage: myColor == Player.black
          ? 'Your turn'
          : 'Opponent\'s turn...',
      hintHexes: const {},
      pushTargets: const {},
      isAnimating: false,
      lastMoveAnimation: null,
      extraTurn: false,
    ));
  } else {
    final fresh = GameLogic.initialState();
    _safeUpdate(GameState(
      board: fresh.board,
      currentTurn: fresh.currentTurn,
      blackScore: 0,
      whiteScore: 0,
      selection: const [],
      moveCount: 0,
      statusMessage: '${fresh.currentTurn.displayName}\'s turn',
      hintHexes: const {},
      pushTargets: const {},
      isAnimating: false,
      lastMoveAnimation: null,
      extraTurn: false,
    ));
  }
}

  Hex? _findDirection(
      List<Hex> sel, Hex target, Map<Hex, Player> board, Player player) {
    if (sel.length == 1) {
      final diff = target - sel.first;
      return Hex.directions.contains(diff) ? diff : null;
    }

    final validDirs =
        GameLogic.getValidMoveDirections(sel, board, player);

    for (final dir in validDirs) {
      for (final h in GameLogic.sortSelection(sel)) {
        if (h + dir == target) return dir;
      }
    }

    for (final dir in validDirs) {
      final sorted = GameLogic.sortSelection(sel);
      final lineDir =
          sorted.length >= 2 ? sorted[1] - sorted[0] : null;
      if (lineDir == null) continue;
      final isInline =
          dir == lineDir || dir == Hex(-lineDir.q, -lineDir.r);
      if (!isInline) continue;

      Hex front = dir == lineDir ? sorted.last : sorted.first;
      Hex check = front + dir;
      for (int d = 0; d < 4; d++) {
        if (!board.containsKey(check)) break;
        if (check == target) return dir;
        if (board[check] == Player.none) break;
        check = check + dir;
      }
    }

    Hex? best;
    double bestScore = double.infinity;
    for (final dir in validDirs) {
      final sorted = GameLogic.sortSelection(sel);
      double aq = 0, ar = 0;
      for (final h in sorted) {
        aq += h.q;
        ar += h.r;
      }
      aq /= sorted.length;
      ar /= sorted.length;
      final tq = target.q - aq;
      final tr = target.r - ar;
      final dot = dir.q * tq + dir.r * tr;
      if (dot > 0) {
        final sc = (tq * tq + tr * tr) - dot * dot;
        if (sc < bestScore) {
          bestScore = sc;
          best = dir;
        }
      }
    }
    return best;
  }
}