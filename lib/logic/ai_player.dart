import 'dart:math';
import '../models/hex.dart';
import '../models/player.dart';
import '../models/game_mode.dart';
import '../logic/game_logic.dart';

class AiPlayer {
  final AiDifficulty difficulty;
  final _random = Random();

  AiPlayer({required this.difficulty});

  Future<(List<Hex>, Hex)?> findMove(
      Map<Hex, Player> board, Player aiPlayer) async {
    // Run in isolate-like delay to not block UI
    await Future.delayed(const Duration(milliseconds: 300));

    switch (difficulty) {
      case AiDifficulty.easy:
        return _findRandomMove(board, aiPlayer);
      case AiDifficulty.medium:
        return _findMediumMove(board, aiPlayer);
      case AiDifficulty.hard:
        return _findHardMove(board, aiPlayer);
    }
  }

  // ── EASY: Random valid move ──
  (List<Hex>, Hex)? _findRandomMove(
      Map<Hex, Player> board, Player player) {
    final allMoves = _getAllValidMoves(board, player);
    if (allMoves.isEmpty) return null;
    return allMoves[_random.nextInt(allMoves.length)];
  }

  // ── MEDIUM: Prefer pushes, then center moves ──
  (List<Hex>, Hex)? _findMediumMove(
      Map<Hex, Player> board, Player player) {
    final allMoves = _getAllValidMoves(board, player);
    if (allMoves.isEmpty) return null;

    // Priority 1: Moves that push opponent off
    final pushOffMoves = <(List<Hex>, Hex)>[];
    // Priority 2: Moves that push opponent
    final pushMoves = <(List<Hex>, Hex)>[];
    // Priority 3: Moves toward center
    final centerMoves = <(List<Hex>, Hex)>[];

    for (final (sel, dir) in allMoves) {
      final result = GameLogic.tryMove(sel, dir, board, player);
      if (!result.valid || result.newBoard == null) continue;

      if (result.pushedOff > 0) {
        pushOffMoves.add((sel, dir));
      } else {
        // Check if any opponent marble is being pushed
        final sorted = GameLogic.sortSelection(sel);
        final front = sorted.last;
        final target = front + dir;
        if (board.containsKey(target) &&
            board[target] == player.opponent) {
          pushMoves.add((sel, dir));
        } else {
          // Prefer moves toward center
          final avgDist = sel
              .map((h) => (h + dir).distanceTo(const Hex(0, 0)))
              .reduce((a, b) => a + b) / sel.length;
          final currentDist = sel
              .map((h) => h.distanceTo(const Hex(0, 0)))
              .reduce((a, b) => a + b) / sel.length;
          if (avgDist <= currentDist) {
            centerMoves.add((sel, dir));
          }
        }
      }
    }

    if (pushOffMoves.isNotEmpty) {
      return pushOffMoves[_random.nextInt(pushOffMoves.length)];
    }
    if (pushMoves.isNotEmpty && _random.nextDouble() > 0.3) {
      return pushMoves[_random.nextInt(pushMoves.length)];
    }
    if (centerMoves.isNotEmpty && _random.nextDouble() > 0.2) {
      return centerMoves[_random.nextInt(centerMoves.length)];
    }
    return allMoves[_random.nextInt(allMoves.length)];
  }

  // ── HARD: Score-based evaluation ──
  (List<Hex>, Hex)? _findHardMove(
      Map<Hex, Player> board, Player player) {
    final allMoves = _getAllValidMoves(board, player);
    if (allMoves.isEmpty) return null;

    double bestScore = double.negativeInfinity;
    final bestMoves = <(List<Hex>, Hex)>[];

    for (final (sel, dir) in allMoves) {
      final result = GameLogic.tryMove(sel, dir, board, player);
      if (!result.valid || result.newBoard == null) continue;

      double score = 0;

      // Huge bonus for pushing off
      score += result.pushedOff * 100;

      // Evaluate board position
      score += _evaluateBoard(result.newBoard!, player);
      score -= _evaluateBoard(board, player);

      // Group cohesion bonus
      score += _cohesionScore(result.newBoard!, player) * 2;

      // Center control
      score += _centerControl(result.newBoard!, player) * 3;

      // Penalize spreading out
      score -= _spreadPenalty(result.newBoard!, player);

      // Small randomness to avoid repetition
      score += _random.nextDouble() * 2;

      if (score > bestScore) {
        bestScore = score;
        bestMoves.clear();
        bestMoves.add((sel, dir));
      } else if (score == bestScore) {
        bestMoves.add((sel, dir));
      }
    }

    if (bestMoves.isEmpty) {
      return allMoves[_random.nextInt(allMoves.length)];
    }
    return bestMoves[_random.nextInt(bestMoves.length)];
  }

  // ── Helper: Get all valid moves ──
  List<(List<Hex>, Hex)> _getAllValidMoves(
      Map<Hex, Player> board, Player player) {
    final moves = <(List<Hex>, Hex)>[];
    final myHexes = board.entries
        .where((e) => e.value == player)
        .map((e) => e.key)
        .toList();

    // Single marble moves
    for (final h in myHexes) {
      final sel = [h];
      for (final dir in Hex.directions) {
        final result = GameLogic.tryMove(sel, dir, board, player);
        if (result.valid) moves.add((sel, dir));
      }
    }

    // Two marble moves
    for (int i = 0; i < myHexes.length; i++) {
      for (int j = i + 1; j < myHexes.length; j++) {
        if (myHexes[i].distanceTo(myHexes[j]) != 1) continue;
        final sel = [myHexes[i], myHexes[j]];
        if (!GameLogic.isValidSelection(sel, board)) continue;
        for (final dir in Hex.directions) {
          final result = GameLogic.tryMove(sel, dir, board, player);
          if (result.valid) moves.add((sel, dir));
        }
      }
    }

    // Three marble moves
    for (int i = 0; i < myHexes.length; i++) {
      for (int j = i + 1; j < myHexes.length; j++) {
        if (myHexes[i].distanceTo(myHexes[j]) != 1) continue;
        for (int k = j + 1; k < myHexes.length; k++) {
          final sel = [myHexes[i], myHexes[j], myHexes[k]];
          if (!GameLogic.isValidSelection(sel, board)) continue;
          for (final dir in Hex.directions) {
            final result = GameLogic.tryMove(sel, dir, board, player);
            if (result.valid) moves.add((sel, dir));
          }
        }
      }
    }

    return moves;
  }

  // ── Evaluation helpers ──
  double _evaluateBoard(Map<Hex, Player> board, Player player) {
    double score = 0;
    for (final entry in board.entries) {
      if (entry.value == player) {
        score += 10;
        // Bonus for being near center
        score += (4 - entry.key.distanceTo(const Hex(0, 0))) * 1.5;
      } else if (entry.value == player.opponent) {
        score -= 10;
        // Opponent near edge is good for us
        final dist = entry.key.distanceTo(const Hex(0, 0));
        if (dist >= 3) score += dist * 2;
      }
    }
    return score;
  }

  double _cohesionScore(Map<Hex, Player> board, Player player) {
    double score = 0;
    final myHexes = board.entries
        .where((e) => e.value == player)
        .map((e) => e.key)
        .toList();

    for (final h in myHexes) {
      for (final n in h.neighbors) {
        if (board[n] == player) score += 1;
      }
    }
    return score / 2; // Each pair counted twice
  }

  double _centerControl(Map<Hex, Player> board, Player player) {
    double score = 0;
    for (final entry in board.entries) {
      if (entry.value == player) {
        final dist = entry.key.distanceTo(const Hex(0, 0));
        if (dist <= 1) score += 3;
        else if (dist <= 2) score += 1.5;
      }
    }
    return score;
  }

  double _spreadPenalty(Map<Hex, Player> board, Player player) {
    final myHexes = board.entries
        .where((e) => e.value == player)
        .map((e) => e.key)
        .toList();

    if (myHexes.length <= 1) return 0;

    double totalDist = 0;
    int pairs = 0;
    for (int i = 0; i < myHexes.length; i++) {
      for (int j = i + 1; j < myHexes.length; j++) {
        totalDist += myHexes[i].distanceTo(myHexes[j]);
        pairs++;
      }
    }
    return pairs > 0 ? (totalDist / pairs) : 0;
  }
}