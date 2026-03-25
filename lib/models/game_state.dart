import 'player.dart';
import 'hex.dart';

class MoveResult {
  final bool valid;
  final Map<Hex, Player>? newBoard;
  final int pushedOff;
  final String? reason;

  const MoveResult({
    required this.valid,
    this.newBoard,
    this.pushedOff = 0,
    this.reason,
  });

  static const MoveResult invalid =
      MoveResult(valid: false, reason: 'Invalid move');

  /// Returns true if this move pushed an opponent marble off the board
  bool get hasPushOff => pushedOff > 0; // ← NEW
}

/// Describes one marble moving from A to B
class MarbleAnimation {
  final Hex from;
  final Hex to;
  final Player player;
  final bool isPushedOff;

  const MarbleAnimation({
    required this.from,
    required this.to,
    required this.player,
    this.isPushedOff = false,
  });
}

/// All animation data for a single move
class MoveAnimationData {
  final List<MarbleAnimation> animations;
  final Hex direction;
  final Player movingPlayer;
  final int pushedOffCount;

  const MoveAnimationData({
    required this.animations,
    required this.direction,
    required this.movingPlayer,
    this.pushedOffCount = 0,
  });

  List<MarbleAnimation> get sliding =>
      animations.where((a) => !a.isPushedOff).toList();

  List<MarbleAnimation> get pushedOff =>
      animations.where((a) => a.isPushedOff).toList();
}

class GameState {
  final Map<Hex, Player> board;
  final Player currentTurn;
  final int blackScore;
  final int whiteScore;
  final List<Hex> selection;
  final int moveCount;
  final String statusMessage;
  final Set<Hex> hintHexes;
  final Set<Hex> pushTargets;
  final bool isAnimating;
  final MoveAnimationData? lastMoveAnimation;
  final bool extraTurn;

  static const int winScore = 6;

  const GameState({
    required this.board,
    required this.currentTurn,
    this.blackScore = 0,
    this.whiteScore = 0,
    this.selection = const [],
    this.moveCount = 0,
    this.statusMessage = '',
    this.hintHexes = const {},
    this.pushTargets = const {},
    this.isAnimating = false,
    this.lastMoveAnimation,
    this.extraTurn = false,
  });

  bool get isGameOver => blackScore >= winScore || whiteScore >= winScore;

  Player? get winner {
    if (blackScore >= winScore) return Player.black;
    if (whiteScore >= winScore) return Player.white;
    return null;
  }

  bool get hasSelection => selection.isNotEmpty;

  GameState copyWith({
    Map<Hex, Player>? board,
    Player? currentTurn,
    int? blackScore,
    int? whiteScore,
    List<Hex>? selection,
    int? moveCount,
    String? statusMessage,
    Set<Hex>? hintHexes,
    Set<Hex>? pushTargets,
    bool? isAnimating,
    MoveAnimationData? lastMoveAnimation,
    bool clearAnimation = false,
    bool? extraTurn,
  }) {
    return GameState(
      board: board ?? Map.from(this.board),
      currentTurn: currentTurn ?? this.currentTurn,
      blackScore: blackScore ?? this.blackScore,
      whiteScore: whiteScore ?? this.whiteScore,
      selection: selection ?? List.from(this.selection),
      moveCount: moveCount ?? this.moveCount,
      statusMessage: statusMessage ?? this.statusMessage,
      hintHexes: hintHexes ?? Set.from(this.hintHexes),
      pushTargets: pushTargets ?? Set.from(this.pushTargets),
      isAnimating: isAnimating ?? this.isAnimating,
      // ═══════════════════════════════════════════
      // FIX: clearAnimation OR explicit null clears it
      // ═══════════════════════════════════════════
      lastMoveAnimation: clearAnimation
          ? null
          : (lastMoveAnimation ?? this.lastMoveAnimation),
      extraTurn: extraTurn ?? this.extraTurn,
    );
  }

  /// Creates a completely clean state from this one (for resets)
  GameState cleared() {
    return GameState(
      board: Map.from(board),
      currentTurn: currentTurn,
      blackScore: blackScore,
      whiteScore: whiteScore,
      selection: const [],
      moveCount: moveCount,
      statusMessage: statusMessage,
      hintHexes: const {},
      pushTargets: const {},
      isAnimating: false,
      lastMoveAnimation: null,
      extraTurn: false,
    );
  }
}