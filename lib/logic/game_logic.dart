import 'dart:math' as math;
import '../models/hex.dart';
import '../models/player.dart';
import '../models/game_state.dart';

class GameLogic {
  static Map<Hex, Player> createInitialBoard() {
    final board = <Hex, Player>{};

    for (int q = -4; q <= 4; q++) {
      for (int r = math.max(-4, -q - 4); r <= math.min(4, -q + 4); r++) {
        board[Hex(q, r)] = Player.none;
      }
    }

    for (int q = 0; q <= 4; q++) {
      board[Hex(q, -4)] = Player.black;
    }
    for (int q = -1; q <= 4; q++) {
      if (board.containsKey(Hex(q, -3))) {
        board[Hex(q, -3)] = Player.black;
      }
    }
    for (int q = 0; q <= 2; q++) {
      if (board.containsKey(Hex(q, -2))) {
        board[Hex(q, -2)] = Player.black;
      }
    }

    for (int q = -4; q <= 0; q++) {
      board[Hex(q, 4)] = Player.white;
    }
    for (int q = -4; q <= 1; q++) {
      if (board.containsKey(Hex(q, 3))) {
        board[Hex(q, 3)] = Player.white;
      }
    }
    for (int q = -2; q <= 0; q++) {
      if (board.containsKey(Hex(q, 2))) {
        board[Hex(q, 2)] = Player.white;
      }
    }

    return board;
  }

  static GameState initialState() {
    return GameState(
      board: createInitialBoard(),
      currentTurn: Player.black,
      statusMessage: 'Black\'s turn — tap your marbles',
    );
  }

  static bool isValidSelection(List<Hex> sel, Map<Hex, Player> board) {
    if (sel.isEmpty || sel.length > 3) return false;

    final player = board[sel.first];
    if (player == null || player == Player.none) return false;
    if (!sel.every((h) => board[h] == player)) return false;

    if (sel.length == 1) return true;

    if (sel.length == 2) {
      return sel[0].distanceTo(sel[1]) == 1;
    }

    if (sel.length == 3) {
      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          if (j == i) continue;
          int k = 3 - i - j;
          if (sel[i].distanceTo(sel[j]) == 1 &&
              sel[j].distanceTo(sel[k]) == 1 &&
              sel[i].distanceTo(sel[k]) == 2) {
            final d1 = sel[j] - sel[i];
            final d2 = sel[k] - sel[j];
            if (d1 == d2) return true;
          }
        }
      }
      return false;
    }
    return false;
  }

  static List<Hex> sortSelection(List<Hex> sel) {
    if (sel.length <= 1) return List.from(sel);
    if (sel.length == 2) return List.from(sel);

    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (j == i) continue;
        int k = 3 - i - j;
        final d1 = sel[j] - sel[i];
        final d2 = sel[k] - sel[j];
        if (d1 == d2 &&
            sel[i].distanceTo(sel[j]) == 1 &&
            sel[j].distanceTo(sel[k]) == 1) {
          return [sel[i], sel[j], sel[k]];
        }
      }
    }
    return List.from(sel);
  }

  static List<Hex> getValidMoveDirections(
      List<Hex> sel, Map<Hex, Player> board, Player player) {
    if (!isValidSelection(sel, board)) return [];

    final validDirs = <Hex>[];
    for (final dir in Hex.directions) {
      final result = tryMove(sel, dir, board, player);
      if (result.valid) validDirs.add(dir);
    }
    return validDirs;
  }

  static MoveResult tryMove(
      List<Hex> sel, Hex direction, Map<Hex, Player> board, Player player) {
    if (sel.isEmpty) return MoveResult.invalid;

    final sorted = sortSelection(sel);
    final lineDir = sorted.length >= 2 ? sorted[1] - sorted[0] : null;

    final isInline = lineDir != null &&
        (direction == lineDir || direction == Hex(-lineDir.q, -lineDir.r));

    if (sel.length == 1 || isInline) {
      return _tryInlineMove(sorted, direction, board, player);
    } else {
      return _tryBroadsideMove(sorted, direction, board, player);
    }
  }

  static MoveResult _tryInlineMove(List<Hex> sorted, Hex direction,
      Map<Hex, Player> board, Player player) {
    Hex front;
    if (sorted.length == 1) {
      front = sorted[0];
    } else {
      final lineDir = sorted[1] - sorted[0];
      if (direction == lineDir) {
        front = sorted.last;
      } else if (direction == Hex(-lineDir.q, -lineDir.r)) {
        front = sorted.first;
      } else {
        return MoveResult.invalid;
      }
    }

    final target = front + direction;

    if (!board.containsKey(target)) return MoveResult.invalid;

    if (board[target] == Player.none) {
      final newBoard = Map<Hex, Player>.from(board);
      if (sorted.length == 1) {
        newBoard[target] = player;
        newBoard[sorted[0]] = Player.none;
      } else {
        final lineDir = sorted[1] - sorted[0];
        if (direction == lineDir) {
          newBoard[target] = player;
          newBoard[sorted.first] = Player.none;
        } else {
          final backTarget = sorted.first + direction;
          newBoard[backTarget] = player;
          newBoard[sorted.last] = Player.none;
        }
      }
      return MoveResult(valid: true, newBoard: newBoard);
    }

    if (board[target] == player.opponent) {
      return _tryPush(sorted, direction, board, player);
    }

    return MoveResult.invalid;
  }

  static MoveResult _tryPush(List<Hex> sorted, Hex direction,
      Map<Hex, Player> board, Player player) {
    final ownCount = sorted.length;

    Hex check;
    if (sorted.length == 1) {
      check = sorted[0] + direction;
    } else {
      final lineDir = sorted[1] - sorted[0];
      if (direction == lineDir) {
        check = sorted.last + direction;
      } else {
        check = sorted.first + direction;
      }
    }

    int opponentCount = 0;
    final opponentMarbles = <Hex>[];

    while (board.containsKey(check) && board[check] == player.opponent) {
      opponentCount++;
      opponentMarbles.add(check);
      check = check + direction;
    }

    if (opponentCount >= ownCount) {
      return const MoveResult(
          valid: false, reason: 'Need numerical superiority');
    }

    int pushedOff = 0;
    if (!board.containsKey(check)) {
      pushedOff = 1;
    } else if (board[check] != Player.none) {
      return const MoveResult(valid: false, reason: 'Push blocked');
    }

    final newBoard = Map<Hex, Player>.from(board);

    for (int i = opponentMarbles.length - 1; i >= 0; i--) {
      final dest = opponentMarbles[i] + direction;
      if (board.containsKey(dest)) {
        newBoard[dest] = player.opponent;
      }
    }

    final lineDir =
        sorted.length >= 2 ? sorted[1] - sorted[0] : direction;
    if (direction == lineDir || sorted.length == 1) {
      newBoard[sorted.last + direction] = player;
      newBoard[sorted.first] = Player.none;
    } else {
      newBoard[sorted.first + direction] = player;
      newBoard[sorted.last] = Player.none;
    }

    return MoveResult(valid: true, newBoard: newBoard, pushedOff: pushedOff);
  }

  static MoveResult _tryBroadsideMove(List<Hex> sorted, Hex direction,
      Map<Hex, Player> board, Player player) {
    final targets = sorted.map((h) => h + direction).toList();

    for (final t in targets) {
      if (!board.containsKey(t)) {
        return const MoveResult(valid: false, reason: 'Off board');
      }
      if (board[t] != Player.none && !sorted.contains(t)) {
        return const MoveResult(valid: false, reason: 'Occupied');
      }
    }

    final newBoard = Map<Hex, Player>.from(board);
    for (final h in sorted) {
      newBoard[h] = Player.none;
    }
    for (final t in targets) {
      newBoard[t] = player;
    }

    return MoveResult(valid: true, newBoard: newBoard);
  }

  static Set<Hex> getValidTargetHexes(
      List<Hex> sel, Map<Hex, Player> board, Player player) {
    final targets = <Hex>{};
    final validDirs = getValidMoveDirections(sel, board, player);

    for (final dir in validDirs) {
      for (final h in sel) {
        final target = h + dir;
        if (board.containsKey(target) && board[target] != player) {
          targets.add(target);
        }
      }
    }
    return targets;
  }
  static Player getNextTurn(Player currentTurn, MoveResult result) {
    if (result.hasPushOff) {
      return currentTurn; // BONUS TURN! Same player goes again
    }
    return currentTurn.opponent;
  }

  /// Generate status message based on turn state
  static String getExtraTurnMessage(Player player) {
    final colorName = player == Player.black ? 'Black' : 'White';
    return '🔥 $colorName pushed one off! BONUS TURN!';
  }
}