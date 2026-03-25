import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knock_the_marble/models/avatar_data.dart';
import 'package:knock_the_marble/models/game_state.dart';
import 'package:knock_the_marble/providers/user_provider.dart';
import '../models/player.dart';
import '../models/game_mode.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/room_provider.dart';
import '../providers/tips_provider.dart';
import '../providers/ad_provider.dart';
import '../widgets/board_widget.dart';
import '../widgets/game_over_dialog.dart';
import '../widgets/tutorial_overlay.dart';
import '../widgets/banner_ad_widget.dart';
import '../theme/board_themes.dart';
import 'menu_screen.dart';
import 'profile_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _boardEntry;
  late AnimationController _turnGlow;
  bool _gameOverShown = false;
  bool _showTutorial = false;
  bool _earnedBonusFromAd = false;
  bool _onlineErrorShown = false;

  int _freeUndosUsed = 0;
  static const int _maxFreeUndos = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _boardEntry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _turnGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTutorial());
  }

  void _checkTutorial() {
    if (!mounted) return;
    final mode = ref.read(gameProvider.notifier).mode;
    final hasSeen = ref.read(hasSeenTutorialProvider);
    if (mode == GameMode.vsComputer && !hasSeen) {
      setState(() => _showTutorial = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _boardEntry.dispose();
    _turnGlow.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    final notifier = ref.read(gameProvider.notifier);
    final mode = notifier.mode;
    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.inactive) {
      if (mode == GameMode.vsComputer) notifier.pauseAi();
      if (mode == GameMode.online) {
        ref.read(roomProvider.notifier).onAppPaused();
      }
    } else if (lifecycleState == AppLifecycleState.resumed) {
      if (mode == GameMode.vsComputer) notifier.resumeAi();
      if (mode == GameMode.online) {
        ref.read(roomProvider.notifier).onAppResumed();
      }
    }
  }

  String _getMyName(GameMode mode) {
    final userProfile = ref.watch(currentUserProvider);
    if (userProfile != null && userProfile.displayName.isNotEmpty) {
      return userProfile.displayName;
    }
    if (mode == GameMode.localMultiplayer) return 'Player 1';
    return 'You';
  }

  String _getOpponentName(GameMode mode) {
    if (mode == GameMode.vsComputer) {
      final diff = ref.read(gameProvider.notifier).aiDifficulty;
      switch (diff) {
        case AiDifficulty.easy:
          return 'Easy Bot';
        case AiDifficulty.medium:
          return 'Smart Bot';
        case AiDifficulty.hard:
          return 'Master Bot';
      }
    }
    if (mode == GameMode.online) {
      return 'Opponent';
    }
    return 'Player 2';
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    final notifier = ref.read(gameProvider.notifier);
    final t = ref.watch(boardThemeProvider);
    final screen = MediaQuery.of(context).size;
    final compact = screen.height < 700;
    final mode = notifier.mode;

    Player myPlayer;
    Player opponentPlayer;

    if (mode == GameMode.vsComputer) {
      myPlayer = notifier.myColor;
      opponentPlayer = notifier.aiColor;
    } else if (mode == GameMode.online) {
      final room = ref.watch(roomProvider);
      myPlayer = room.myColor ?? Player.black;
      opponentPlayer = myPlayer.opponent;
    } else {
      myPlayer = Player.white;
      opponentPlayer = Player.black;
    }

    bool shouldFlip = false;
    if (mode == GameMode.vsComputer || mode == GameMode.online) {
      shouldFlip = myPlayer == Player.black;
    }

    final myScore = myPlayer == Player.black
        ? game.blackScore
        : game.whiteScore;
    final oppScore = opponentPlayer == Player.black
        ? game.blackScore
        : game.whiteScore;

    ref.listen<bool>(isGameOverProvider, (prev, isOver) {
      if (isOver && !_gameOverShown) {
        _gameOverShown = true;
        _earnedBonusFromAd = false;
        notifier.pauseAi();
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _showGameOver();
        });
      }
    });

    if (mode == GameMode.online) _setupOnlineListener();

    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: BoxDecoration(gradient: t.backgroundGradient)),
          SafeArea(
            child: Column(
              children: [
                _topBar(t, mode, compact),
                _playersRow(
                  t: t,
                  mode: mode,
                  myPlayer: myPlayer,
                  opponentPlayer: opponentPlayer,
                  myScore: myScore,
                  oppScore: oppScore,
                  currentTurn: game.currentTurn,
                  compact: compact,
                ),
                _turnBanner(t, game, myPlayer, compact),
                Expanded(
                  child: FadeTransition(
                    opacity: _boardEntry,
                    child: _boardArea(t, game, notifier, shouldFlip, compact),
                  ),
                ),
                _controls(t, mode, game, compact),
                const BannerAdWidget(),
              ],
            ),
          ),
          if (_showTutorial)
            TutorialOverlay(
              markAsSeen: true,
              onDismiss: () {
                if (mounted) setState(() => _showTutorial = false);
              },
            ),
          if (mode == GameMode.online) _disconnectBanner(t),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // TOP BAR
  // ══════════════════════════════════════

  Widget _topBar(BoardTheme t, GameMode mode, bool compact) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 4 : 6),
      child: Row(
        children: [
          _circleBtn(
            icon: Icons.close_rounded,
            t: t,
            onTap: () {
              if (mode == GameMode.online) {
                _confirmLeaveOnline();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'KNOCK THE MARBLE',
                style: TextStyle(
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w900,
                  color: t.accent,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 3),
              _modePill(t, mode),
            ],
          ),
          const Spacer(),
          _circleBtn(icon: Icons.settings_rounded, t: t, onTap: _showMenu),
        ],
      ),
    );
  }

  Widget _modePill(BoardTheme t, GameMode mode) {
    String label;
    Color c;
    if (mode == GameMode.vsComputer) {
      final diff = ref.read(gameProvider.notifier).aiDifficulty;
      switch (diff) {
        case AiDifficulty.easy:
          label = 'Easy';
          c = const Color(0xFF4CAF50);
        case AiDifficulty.medium:
          label = 'Medium';
          c = const Color(0xFFFF9800);
        case AiDifficulty.hard:
          label = 'Hard';
          c = const Color(0xFFFF5252);
      }
    } else if (mode == GameMode.online) {
      label = 'Online';
      c = const Color(0xFF00E5FF);
    } else {
      label = 'Local 1v1';
      c = const Color(0xFF8BC34A);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: c.withOpacity(0.1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: c,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required BoardTheme t,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: t.cardColor.withOpacity(0.6),
          border: Border.all(color: t.surfaceBorder.withOpacity(0.4)),
        ),
        child: Icon(icon, size: 18, color: t.textPrimary.withOpacity(0.7)),
      ),
    );
  }

  // ══════════════════════════════════════
  // PLAYERS ROW
  // ══════════════════════════════════════

  Widget _playersRow({
    required BoardTheme t,
    required GameMode mode,
    required Player myPlayer,
    required Player opponentPlayer,
    required int myScore,
    required int oppScore,
    required Player currentTurn,
    required bool compact,
  }) {
    final myName = _getMyName(mode);
    final oppName = _getOpponentName(mode);
    final userProfile = ref.watch(currentUserProvider);
    final myAvatar = userProfile?.avatarIndex ?? 0;
    final myActive = currentTurn == myPlayer;
    final oppActive = currentTurn == opponentPlayer;
    final avatarSize = compact ? 34.0 : 40.0;

    final myMarbleColors = myPlayer == Player.black
        ? t.blackMarbleColors
        : t.whiteMarbleColors;
    final oppMarbleColors = opponentPlayer == Player.black
        ? t.blackMarbleColors
        : t.whiteMarbleColors;

    return AnimatedBuilder(
      animation: _turnGlow,
      builder: (_, __) {
        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: compact ? 3 : 5,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: t.cardColor.withOpacity(0.6),
            border: Border.all(color: t.surfaceBorder.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _playerSide(
                      t: t,
                      name: myName,
                      player: myPlayer,
                      isActive: myActive,
                      isMe: true,
                      avatarIndex: myAvatar,
                      mode: mode,
                      avatarSize: avatarSize,
                      compact: compact,
                      alignRight: false,
                    ),
                  ),
                  _scoreNumbers(t, myScore, oppScore, compact),
                  Expanded(
                    flex: 3,
                    child: _playerSide(
                      t: t,
                      name: oppName,
                      player: opponentPlayer,
                      isActive: oppActive,
                      isMe: false,
                      avatarIndex: null,
                      mode: mode,
                      avatarSize: avatarSize,
                      compact: compact,
                      alignRight: true,
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 5 : 7),
              _knockedOutDots(
                t: t,
                myScore: myScore,
                oppScore: oppScore,
                myMarbleColors: myMarbleColors,
                oppMarbleColors: oppMarbleColors,
                compact: compact,
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════
  // PLAYER SIDE
  // ══════════════════════════════════════

  Widget _playerSide({
    required BoardTheme t,
    required String name,
    required Player player,
    required bool isActive,
    required bool isMe,
    required int? avatarIndex,
    required GameMode mode,
    required double avatarSize,
    required bool compact,
    required bool alignRight,
  }) {
    final glowVal = isActive ? _turnGlow.value : 0.0;
    final marbleColors = player == Player.black
        ? t.blackMarbleColors
        : t.whiteMarbleColors;

    final avatar = _buildAvatar(
      t: t,
      avatarIndex: isMe ? avatarIndex : null,
      player: player,
      isActive: isActive,
      isMe: isMe,
      mode: mode,
      size: avatarSize,
      glowVal: glowVal,
    );

    final double nameSize = compact ? 11.0 : 12.5;
    final double marbleSize = compact ? 7.0 : 8.0;

    final info = Expanded(
      child: Column(
        crossAxisAlignment: alignRight
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: nameSize,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive
                  ? t.textPrimary
                  : t.textSecondary.withOpacity(0.6),
              height: 1.2,
            ),
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: alignRight
                ? [
                    Flexible(
                      child: Text(
                        isActive ? (isMe ? 'Turn' : 'Playing') : 'Ready',
                        style: TextStyle(
                          fontSize: compact ? 7 : 8,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? t.accent.withOpacity(0.8)
                              : t.textSecondary.withOpacity(0.3),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 3),
                    _marbleDot(marbleColors, isActive, marbleSize),
                  ]
                : [
                    _marbleDot(marbleColors, isActive, marbleSize),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        isActive ? (isMe ? 'Turn' : 'Playing') : 'Ready',
                        style: TextStyle(
                          fontSize: compact ? 7 : 8,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? t.accent.withOpacity(0.8)
                              : t.textSecondary.withOpacity(0.3),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );

    return Row(
      children: alignRight
          ? [info, const SizedBox(width: 5), avatar]
          : [avatar, const SizedBox(width: 5), info],
    );
  }

  // ══════════════════════════════════════
  // MARBLE DOT
  // ══════════════════════════════════════

  Widget _marbleDot(List<Color> marbleColors, bool isActive, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 0.8,
            colors: isActive
                ? marbleColors
                : marbleColors.map((c) => c.withOpacity(0.35)).toList(),
          ),
          border: Border.all(
            color: isActive
                ? Colors.white.withOpacity(0.25)
                : Colors.white.withOpacity(0.08),
            width: 0.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: marbleColors.first.withOpacity(0.25),
                    blurRadius: 3,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // SCORE NUMBERS
  // ══════════════════════════════════════

  Widget _scoreNumbers(BoardTheme t, int myScore, int oppScore, bool compact) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$myScore',
            style: TextStyle(
              fontSize: compact ? 18 : 22,
              fontWeight: FontWeight.w900,
              color: t.textPrimary,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              ':',
              style: TextStyle(
                fontSize: compact ? 14 : 18,
                fontWeight: FontWeight.w900,
                color: t.textSecondary.withOpacity(0.3),
              ),
            ),
          ),
          Text(
            '$oppScore',
            style: TextStyle(
              fontSize: compact ? 18 : 22,
              fontWeight: FontWeight.w900,
              color: t.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // KNOCKED OUT DOTS
  // ══════════════════════════════════════

  Widget _knockedOutDots({
    required BoardTheme t,
    required int myScore,
    required int oppScore,
    required List<Color> myMarbleColors,
    required List<Color> oppMarbleColors,
    required bool compact,
  }) {
    final dotSize = compact ? 12.0 : 13.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 4 : 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: t.surfaceColor.withOpacity(0.3),
        border: Border.all(color: t.surfaceBorder.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(
            6,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: _scoreDot(t, i < myScore, oppMarbleColors, dotSize),
            ),
          ),
          Container(
            width: 1.5,
            height: dotSize + 4,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              color: t.surfaceBorder.withOpacity(0.25),
            ),
          ),
          ...List.generate(
            6,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: _scoreDot(t, i < oppScore, myMarbleColors, dotSize),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreDot(
    BoardTheme t,
    bool filled,
    List<Color> marbleColors,
    double size,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: filled
            ? RadialGradient(
                center: const Alignment(-0.3, -0.35),
                radius: 0.85,
                colors: marbleColors,
              )
            : null,
        color: filled ? null : t.scoreEmpty,
        border: Border.all(
          color: filled
              ? Colors.white.withOpacity(0.2)
              : t.surfaceBorder.withOpacity(0.12),
          width: 0.5,
        ),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 2,
                  offset: const Offset(0.5, 1),
                ),
              ]
            : null,
      ),
    );
  }

  // ══════════════════════════════════════
  // TURN BANNER
  // ══════════════════════════════════════

  Widget _turnBanner(
    BoardTheme t,
    GameState game,
    Player myPlayer,
    bool compact,
  ) {
    final isMyTurn = game.currentTurn == myPlayer;
    final mode = ref.read(gameProvider.notifier).mode;

    String turnText;
    if (mode == GameMode.localMultiplayer) {
      turnText =
          '${game.currentTurn == Player.black ? "OPPONENT" : "YOUR"}\'S TURN';
    } else {
      turnText = isMyTurn ? 'YOUR TURN!' : 'WAITING...';
    }

    final isExtra = game.extraTurn;
    final displayText = isExtra ? 'GO AGAIN!' : turnText;

    return AnimatedBuilder(
      animation: _turnGlow,
      builder: (_, __) {
        final glow = (isMyTurn || isExtra) ? _turnGlow.value : 0.0;
        final extraColor = const Color.fromARGB(255, 97, 255, 53);

        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: 50,
            vertical: compact ? 2 : 4,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isExtra
                ? extraColor.withOpacity(0.12 + glow * 0.06)
                : isMyTurn
                ? t.accent.withOpacity(0.10 + glow * 0.05)
                : t.cardColor.withOpacity(0.35),
            border: Border.all(
              color: isExtra
                  ? extraColor.withOpacity(0.35 + glow * 0.2)
                  : isMyTurn
                  ? t.accent.withOpacity(0.25 + glow * 0.15)
                  : t.surfaceBorder.withOpacity(0.15),
              width: isExtra ? 1.5 : 1.0,
            ),
            boxShadow: (isMyTurn || isExtra)
                ? [
                    BoxShadow(
                      color: (isExtra ? extraColor : t.accent).withOpacity(
                        0.06 + glow * 0.04,
                      ),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.w900,
                color: isExtra
                    ? extraColor
                    : isMyTurn
                    ? t.accent
                    : t.textSecondary.withOpacity(0.4),
                letterSpacing: 1.2,
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════
  // AVATAR
  // ══════════════════════════════════════

  Widget _buildAvatar({
    required BoardTheme t,
    required int? avatarIndex,
    required Player player,
    required bool isActive,
    required bool isMe,
    required GameMode mode,
    required double size,
    required double glowVal,
  }) {
    Widget content;

    if (avatarIndex != null && isMe) {
      final avatar = AvatarData.getAvatar(avatarIndex);
      content = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isActive
                ? avatar.gradientColors
                : avatar.gradientColors.map((c) => c.withOpacity(0.3)).toList(),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(avatar.emoji, style: TextStyle(fontSize: size * 0.48)),
        ),
      );
    } else {
      final mc = player == Player.black
          ? t.blackMarbleColors
          : t.whiteMarbleColors;
      content = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.2, -0.3),
            radius: 0.9,
            colors: isActive ? mc : mc.map((c) => c.withOpacity(0.25)).toList(),
          ),
        ),
        child: Icon(
          _opponentIcon(mode),
          size: size * 0.42,
          color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive
              ? t.accent.withOpacity(0.5 + glowVal * 0.3)
              : t.surfaceBorder.withOpacity(0.2),
          width: isActive ? 2.5 : 1.5,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: t.accent.withOpacity(0.15 + glowVal * 0.1),
                  blurRadius: 10,
                ),
              ]
            : [],
      ),
      child: content,
    );
  }

  IconData _opponentIcon(GameMode mode) {
    switch (mode) {
      case GameMode.vsComputer:
        return Icons.smart_toy_rounded;
      case GameMode.online:
        return Icons.person_outline_rounded;
      case GameMode.localMultiplayer:
        return Icons.person_rounded;
    }
  }

  // ══════════════════════════════════════
  // BOARD AREA
  // ══════════════════════════════════════

  Widget _boardArea(
    BoardTheme t,
    GameState game,
    GameNotifier notifier,
    bool shouldFlip,
    bool compact,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
      child: Center(
        child: BoardWidget(
          board: game.board,
          selection: game.selection,
          hintHexes: game.hintHexes,
          pushTargets: game.pushTargets,
          currentTurn: game.currentTurn,
          onHexTap: notifier.tapHex,
          flipBoard: shouldFlip,
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // CONTROLS
  // ══════════════════════════════════════

  Widget _controls(BoardTheme t, GameMode mode, GameState game, bool compact) {
    final notifier = ref.read(gameProvider.notifier);
    final sel = ref.watch(selectionProvider);
    final isAiThinking = ref.watch(isAiThinkingProvider);
    final isGameOver = ref.watch(isGameOverProvider);
    final tipsRemaining = ref.watch(tipsRemainingProvider);
    final canUseTip = ref.watch(canUseTipProvider);
    final sz = compact ? 34.0 : 38.0;

    final canUndo = notifier.canUndo && !isAiThinking && !isGameOver;
    final showTips = mode != GameMode.online && !isAiThinking && !isGameOver;
    final showClear = sel.isNotEmpty && !isGameOver;

    if (mode == GameMode.online) {
      if (!showClear) return const SizedBox(height: 4);
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 3 : 5,
        ),
        child: _ctrlBtn(
          icon: Icons.close_rounded,
          label: 'Clear',
          onTap: () {
            HapticFeedback.lightImpact();
            notifier.clearSelection();
          },
          sz: sz,
          t: t,
          highlight: true,
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 3 : 5),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 5 : 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: t.cardColor.withOpacity(0.5),
        border: Border.all(color: t.surfaceBorder.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ctrlBtn(
            icon: Icons.undo_rounded,
            label: 'Undo',
            onTap: canUndo
                ? () {
                    if (_freeUndosUsed < _maxFreeUndos) {
                      _freeUndosUsed++;
                      notifier.undoPlayerMove();
                    } else {
                      _showUndoAdDialog(t);
                    }
                  }
                : null,
            sz: sz,
            t: t,
            badge: canUndo
                ? (_freeUndosUsed < _maxFreeUndos
                      ? '${_maxFreeUndos - _freeUndosUsed}'
                      : '▶')
                : null,
            badgeColor: _freeUndosUsed < _maxFreeUndos
                ? const Color(0xFF4CAF50)
                : Colors.orange,
          ),
          if (showClear)
            _ctrlBtn(
              icon: Icons.close_rounded,
              label: 'Clear',
              onTap: () {
                HapticFeedback.lightImpact();
                notifier.clearSelection();
              },
              sz: sz,
              t: t,
              highlight: true,
            ),
          if (showTips)
            _ctrlBtn(
              icon: Icons.lightbulb_rounded,
              label: 'Tip',
              onTap: () async {
                if (canUseTip) {
                  final used = await ref.read(tipsProvider.notifier).useTip();
                  if (used) await notifier.showTipMove();
                } else {
                  _showNoTipsDialog(t);
                }
              },
              sz: sz,
              t: t,
              badge: '$tipsRemaining',
              badgeColor: tipsRemaining > 0
                  ? const Color(0xFFFFD700)
                  : Colors.grey,
              iconColor: const Color(0xFFFFD700),
            ),
          _ctrlBtn(
            icon: Icons.refresh_rounded,
            label: 'Restart',
            onTap: () {
              _freeUndosUsed = 0;
              _earnedBonusFromAd = false;
              _gameOverShown = false;
              ref.read(gameProvider.notifier).resetGame();
            },
            sz: sz,
            t: t,
          ),
        ],
      ),
    );
  }

  Widget _ctrlBtn({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required double sz,
    required BoardTheme t,
    bool highlight = false,
    String? badge,
    Color? badgeColor,
    Color? iconColor,
  }) {
    final enabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.25,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: sz,
                  height: sz,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: highlight
                        ? t.accent.withOpacity(0.15)
                        : t.surfaceColor.withOpacity(0.5),
                    border: Border.all(
                      color: highlight
                          ? t.accent.withOpacity(0.4)
                          : t.surfaceBorder.withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color:
                        iconColor ??
                        (highlight
                            ? t.accent
                            : t.textSecondary.withOpacity(0.7)),
                    size: sz * 0.42,
                  ),
                ),
                if (badge != null && enabled)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 15,
                        minHeight: 15,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: badgeColor ?? const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: t.cardColor, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                color: highlight
                    ? t.accent.withOpacity(0.7)
                    : t.textSecondary.withOpacity(0.4),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // ONLINE LISTENER
  // ══════════════════════════════════════

  void _setupOnlineListener() {
    ref.listen<RoomState>(roomProvider, (prev, next) {
      if (next.error != null && prev?.error == null && !_onlineErrorShown) {
        _onlineErrorShown = true;
        final navigator = Navigator.of(context);
        final roomNotifier = ref.read(roomProvider.notifier);
        final t = ref.read(boardThemeProvider);

        final reason = next.closedReason;
        IconData icn;
        String title;

        switch (reason) {
          case 'disconnect_timeout':
            icn = Icons.wifi_off_rounded;
            title = 'Opponent Disconnected';
          case 'player_left':
            icn = Icons.exit_to_app_rounded;
            title = 'Opponent Left';
          default:
            icn = Icons.info_outline_rounded;
            title = 'Game Ended';
        }

        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dc) => _dialog(
              t: t,
              icon: icn,
              iconColor: Colors.red,
              title: title,
              content: next.error ?? 'The game has ended.',
              actions: [
                _dialogBtn(
                  t: t,
                  label: 'Back to Menu',
                  primary: true,
                  onTap: () {
                    Navigator.pop(dc);
                    roomNotifier.clearError();
                    _onlineErrorShown = false;
                    navigator.popUntil((r) => r.isFirst);
                  },
                ),
              ],
            ),
          );
        });
      }
    });
  }

  Widget _disconnectBanner(BoardTheme t) {
    final room = ref.watch(roomProvider);
    if (!room.opponentDisconnected) return const SizedBox.shrink();
    if (room.roomData == null || !room.roomData!.isPlaying) {
      return const SizedBox.shrink();
    }

    final secs = room.disconnectSecondsLeft;
    final urgent = secs <= 15;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: urgent
                  ? [Colors.red.withOpacity(0.95), const Color(0xFFB71C1C)]
                  : [Colors.orange.withOpacity(0.95), const Color(0xFFE65100)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                urgent ? Icons.warning_rounded : Icons.wifi_off_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Opponent disconnected',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      urgent
                          ? 'Game ends in ${secs}s...'
                          : 'Waiting ${secs}s for reconnect...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: secs / 60,
                      strokeWidth: 2.5,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(
                        urgent ? Colors.yellow : Colors.white.withOpacity(0.8),
                      ),
                    ),
                    Center(
                      child: Text(
                        '$secs',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // DIALOGS
  // ══════════════════════════════════════

  Widget _dialog({
    required BoardTheme t,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required List<Widget> actions,
  }) {
    return AlertDialog(
      backgroundColor: t.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: t.surfaceBorder),
      ),
      title: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        content,
        style: TextStyle(color: t.textSecondary, fontSize: 13),
      ),
      actions: actions,
    );
  }

  Widget _dialogBtn({
    required BoardTheme t,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
    Color? color,
  }) {
    if (primary) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? t.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
    }
    return TextButton(
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(color: t.textSecondary, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ══════════════════════════════════════
  // CONFIRM LEAVE ONLINE
  // ══════════════════════════════════════

  void _confirmLeaveOnline() {
    final t = ref.read(boardThemeProvider);
    final roomNotifier = ref.read(roomProvider.notifier);
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      builder: (dc) => _dialog(
        t: t,
        icon: Icons.exit_to_app_rounded,
        iconColor: Colors.orange,
        title: 'Leave Game?',
        content: 'If you leave, the game will end for both players.',
        actions: [
          _dialogBtn(t: t, label: 'Stay', onTap: () => Navigator.pop(dc)),
          _dialogBtn(
            t: t,
            label: 'Leave',
            primary: true,
            color: Colors.red,
            onTap: () async {
              Navigator.pop(dc);
              await roomNotifier.leaveRoom();
              navigator.popUntil((r) => r.isFirst);
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // GAME OVER
  // ══════════════════════════════════════

  void _showGameOver() {
    final winner = ref.read(winnerProvider);
    if (winner == null) return;
    _earnedBonusFromAd = false;
    try {
      ref
          .read(adProvider.notifier)
          .showGameOverAd(
            onDone: () => _showGameOverDialog(winner),
            onReward: () => _earnedBonusFromAd = true,
          );
    } catch (_) {
      _showGameOverDialog(winner);
    }
  }

  void _showGameOverDialog(Player winner) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => GameOverDialog(
        winner: winner,
        earnedBonus: _earnedBonusFromAd,
        onPlayAgain: () {
          Navigator.pop(context);
          _gameOverShown = false;
          _freeUndosUsed = 0;
          _earnedBonusFromAd = false;
          ref.read(gameProvider.notifier).resetGame();
        },
        onMainMenu: () {
          Navigator.pop(context);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MenuScreen()),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════
  // UNDO AD DIALOG
  // ══════════════════════════════════════

  void _showUndoAdDialog(BoardTheme t) {
    ref.read(gameProvider.notifier).pauseAi();
    showDialog(
      context: context,
      builder: (ctx) => _dialog(
        t: t,
        icon: Icons.undo,
        iconColor: t.accent,
        title: 'Extra Undo',
        content:
            'You\'ve used your 2 free undos.\nWatch a short video to get 3 more!',
        actions: [
          _dialogBtn(
            t: t,
            label: 'NO THANKS',
            onTap: () {
              Navigator.pop(ctx);
              ref.read(gameProvider.notifier).resumeAi();
            },
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final shown = await ref
                  .read(adProvider.notifier)
                  .showRewardedAd(
                    onReward: () {
                      if (mounted) {
                        setState(() => _freeUndosUsed = 0);
                        ref.read(gameProvider.notifier).undoPlayerMove();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🎉 +3 Undos unlocked!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    onDone: () => ref.read(gameProvider.notifier).resumeAi(),
                  );
              if (!shown && mounted) {
                ref.read(gameProvider.notifier).resumeAi();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No video available. Try later.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('Watch Video (+3)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // NO TIPS DIALOG
  // ══════════════════════════════════════

  void _showNoTipsDialog(BoardTheme t) {
    ref.read(gameProvider.notifier).pauseAi();
    showDialog(
      context: context,
      builder: (ctx) => _dialog(
        t: t,
        icon: Icons.lightbulb_outline,
        iconColor: const Color(0xFFFFD700),
        title: 'No Tips Left',
        content:
            'You\'ve used all tips for today.\nWatch a short video to get 2 extra tips!',
        actions: [
          _dialogBtn(
            t: t,
            label: 'NO THANKS',
            onTap: () {
              Navigator.pop(ctx);
              ref.read(gameProvider.notifier).resumeAi();
            },
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final shown = await ref
                  .read(adProvider.notifier)
                  .showRewardedAd(
                    onReward: () {
                      ref.read(tipsProvider.notifier).addExtraTips(2);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🎉 +2 Tips added!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    onDone: () => ref.read(gameProvider.notifier).resumeAi(),
                  );
              if (!shown && mounted) {
                ref.read(gameProvider.notifier).resumeAi();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No video available. Try later.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('Watch Video (+2)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // MENU
  // ══════════════════════════════════════

  void _showMenu() {
    final t = ref.read(boardThemeProvider);
    final notifier = ref.read(gameProvider.notifier);
    final mode = notifier.mode;
    notifier.pauseAi();

    showModalBottomSheet(
      context: context,
      backgroundColor: t.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: t.textSecondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _menuTile(Icons.person, 'My Profile', () {
              Navigator.pop(ctx);
              notifier.resumeAi();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            }, t),
            _menuTile(Icons.refresh, 'New Game', () {
              Navigator.pop(ctx);
              _gameOverShown = false;
              _freeUndosUsed = 0;
              _earnedBonusFromAd = false;
              notifier.resetGame();
            }, t),
            _menuTile(Icons.school_rounded, 'How to Play', () {
              Navigator.pop(ctx);
              notifier.pauseAi();
              // Open as a full screen instead of overlay
              Navigator.of(context)
                  .push(
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) =>
                          const TutorialScreen(markAsSeen: false),
                      transitionsBuilder: (_, a, __, child) => FadeTransition(
                        opacity: CurvedAnimation(
                          parent: a,
                          curve: Curves.easeOut,
                        ),
                        child: child,
                      ),
                      transitionDuration: const Duration(milliseconds: 400),
                    ),
                  )
                  .then((_) {
                    if (mounted) notifier.resumeAi();
                  });
            }, t),
            _menuTile(Icons.home_rounded, 'Main Menu', () {
              Navigator.pop(ctx);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MenuScreen()),
              );
            }, t),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ).whenComplete(() {
      if (mounted) notifier.resumeAi();
    });
  }

  Widget _menuTile(
    IconData icon,
    String title,
    VoidCallback onTap,
    BoardTheme t,
  ) {
    return ListTile(
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: t.accent.withOpacity(0.1),
        ),
        child: Icon(icon, color: t.accent, size: 17),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: t.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: t.textSecondary.withOpacity(0.3),
        size: 18,
      ),
      onTap: onTap,
    );
  }
}
