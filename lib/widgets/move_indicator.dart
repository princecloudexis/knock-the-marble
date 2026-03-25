import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player.dart';
import '../models/game_mode.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/room_provider.dart';
import '../theme/board_themes.dart';

class MoveIndicator extends ConsumerWidget {
  final bool compact;

  const MoveIndicator({super.key, required this.compact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(statusProvider);
    final sel = ref.watch(selectionProvider);
    final moveCount = ref.watch(moveCountProvider);
    final t = ref.watch(boardThemeProvider);
    final game = ref.watch(gameProvider);
    final notifier = ref.read(gameProvider.notifier);
    final mode = notifier.mode;
    final currentTurn = game.currentTurn;
    final bool isMyTurn = _isMyTurn(ref, mode, notifier, currentTurn);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: compact ? 1 : 3,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Move counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: t.surfaceColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '#${moveCount + 1}',
              style: TextStyle(
                color: t.textSecondary.withOpacity(0.5),
                fontSize: compact ? 9 : 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Turn indicator with marble color ──
          _turnMarbleIndicator(t, currentTurn, isMyTurn, mode),

          const SizedBox(width: 8),

          // Status message
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: compact ? 2 : 4,
              ),
              decoration: BoxDecoration(
                color: isMyTurn
                    ? t.accent.withOpacity(0.08)
                    : t.cardColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isMyTurn
                      ? t.accent.withOpacity(0.25)
                      : t.surfaceBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    sel.isNotEmpty
                        ? Icons.open_with_rounded
                        : Icons.touch_app_rounded,
                    size: 11,
                    color: isMyTurn
                        ? t.accent.withOpacity(0.7)
                        : t.accent.withOpacity(0.5),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _getStatusText(status, isMyTurn, mode),
                      style: TextStyle(
                        color: isMyTurn ? t.accent : t.textSecondary,
                        fontSize: compact ? 9 : 10,
                        fontWeight:
                            isMyTurn ? FontWeight.w700 : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Selection pills
          if (sel.isNotEmpty) ...[
            const SizedBox(width: 8),
            _selectionDots(sel.length, t),
          ],
        ],
      ),
    );
  }

  bool _isMyTurn(
    WidgetRef ref,
    GameMode mode,
    GameNotifier notifier,
    Player currentTurn,
  ) {
    if (mode == GameMode.vsComputer) {
      return currentTurn == notifier.myColor;
    }
    if (mode == GameMode.online) {
      final room = ref.watch(roomProvider);
      return room.myColor != null && currentTurn == room.myColor;
    }
    // Local multiplayer — always "your turn"
    return true;
  }

  String _getStatusText(String status, bool isMyTurn, GameMode mode) {
    if (mode == GameMode.localMultiplayer) return status;

    // For vs computer and online, make it personal
    if (status.toLowerCase().contains('select') ||
        status.toLowerCase().contains('tap') ||
        status.toLowerCase().contains('choose')) {
      return isMyTurn ? 'Your turn — $status' : 'Opponent\'s turn...';
    }
    return status;
  }

  /// Shows a small marble in the current turn's theme color
  Widget _turnMarbleIndicator(
    BoardTheme t,
    Player currentTurn,
    bool isMyTurn,
    GameMode mode,
  ) {
    final isBlack = currentTurn == Player.black;
    final List<Color> marbleColors =
        isBlack ? t.blackMarbleColors : t.whiteMarbleColors;

    final turnLabel = _getTurnLabel(isMyTurn, mode);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isMyTurn
            ? t.accent.withOpacity(0.12)
            : t.surfaceColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMyTurn
              ? t.accent.withOpacity(0.3)
              : t.surfaceBorder,
          width: isMyTurn ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini marble
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.35),
                radius: 0.85,
                colors: marbleColors,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 2,
                  offset: const Offset(0.5, 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            turnLabel,
            style: TextStyle(
              color: isMyTurn ? t.accent : t.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  String _getTurnLabel(bool isMyTurn, GameMode mode) {
    if (mode == GameMode.localMultiplayer) return 'TURN';
    return isMyTurn ? 'YOU' : 'OPP';
  }

  Widget _selectionDots(int count, dynamic t) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final on = i < count;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: on ? 14 : 5,
            height: 5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: on ? t.accent : t.scoreEmpty,
            ),
          ),
        );
      }),
    );
  }
}