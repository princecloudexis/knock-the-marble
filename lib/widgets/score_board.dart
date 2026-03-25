import 'package:knock_the_marble/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player.dart';
import '../models/game_mode.dart';
import '../providers/settings_provider.dart';
import '../providers/user_provider.dart';
import '../providers/game_provider.dart';
import '../providers/room_provider.dart';
import '../theme/board_themes.dart';
import 'avatar_widget.dart';

class ScoreBoard extends ConsumerWidget {
  final Player currentTurn;
  final int blackScore;
  final int whiteScore;
  final int moveCount;

  const ScoreBoard({
    super.key,
    required this.currentTurn,
    required this.blackScore,
    required this.whiteScore,
    required this.moveCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(boardThemeProvider);
    final user = ref.watch(currentUserProvider);
    final mode = ref.read(gameProvider.notifier).mode;
    final room = ref.watch(roomProvider);

    final blackName = _getPlayerName(Player.black, user, mode, room);
    final whiteName = _getPlayerName(Player.white, user, mode, room);
    final blackAvatar = _getAvatarIndex(Player.black, user, mode, room);
    final whiteAvatar = _getAvatarIndex(Player.white, user, mode, room);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.cardColor.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _side(blackName, Player.black, blackScore,
              currentTurn == Player.black, t, blackAvatar),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MOVE ${moveCount + 1}',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.accent.withOpacity(0.2)),
                  ),
                  child: Text(
                    currentTurn == Player.black
                        ? '● $blackName'
                        : '○ $whiteName',
                    style: TextStyle(
                      color: t.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          _side(whiteName, Player.white, whiteScore,
              currentTurn == Player.white, t, whiteAvatar),
        ],
      ),
    );
  }

  String _getPlayerName(
      Player player, UserProfile? user, GameMode mode, RoomState room) {
    final isBlack = player == Player.black;

    if (mode == GameMode.vsComputer) {
      if (isBlack) {
        return (user != null && user.displayName.isNotEmpty)
            ? user.displayName
            : user?.shortId ?? 'YOU';
      }
      return 'CPU';
    }

    if (mode == GameMode.online) {
      final roomData = room.roomData;
      if (roomData != null) {
        if (isBlack) return roomData.hostName;
        return roomData.guestName ?? 'Waiting...';
      }
    }

    if (mode == GameMode.localMultiplayer) {
      if (isBlack) {
        return (user != null && user.displayName.isNotEmpty)
            ? user.displayName
            : 'P1';
      }
      return 'P2';
    }

    return isBlack ? 'BLACK' : 'WHITE';
  }

  int? _getAvatarIndex(
      Player player, UserProfile? user, GameMode mode, RoomState room) {
    final isBlack = player == Player.black;

    if (mode == GameMode.vsComputer) {
      if (isBlack) return user?.avatarIndex;
      return null;
    }

    if (mode == GameMode.online) {
      final roomData = room.roomData;
      if (roomData != null) {
        if (isBlack) return roomData.hostAvatar;
        return roomData.guestAvatar;
      }
    }

    if (mode == GameMode.localMultiplayer && isBlack) {
      return user?.avatarIndex;
    }

    return null;
  }

  Widget _side(String label, Player player, int score, bool active,
      BoardTheme t, int? avatarIndex) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? t.accent.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? t.accent.withOpacity(0.25) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (avatarIndex != null)
                AvatarWidget(avatarIndex: avatarIndex, size: 16)
              else
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.3, -0.3),
                      colors: player == Player.black
                          ? [const Color(0xFF555555), const Color(0xFF111111)]
                          : [const Color(0xFFFFFFF8), const Color(0xFFCCCCBB)],
                    ),
                    border: Border.all(
                      color: Colors.black.withOpacity(0.2),
                      width: 0.5,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 60),
                child: Text(
                  label,
                  style: TextStyle(
                    color: active ? t.accent : t.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(6, (i) {
              final filled = i < score;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? t.scoreFilled : t.scoreEmpty,
                    boxShadow: filled
                        ? [
                            BoxShadow(
                              color: t.scoreFilled.withOpacity(0.4),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                    border: filled
                        ? null
                        : Border.all(
                            color: t.textSecondary.withOpacity(0.15),
                            width: 0.5,
                          ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}