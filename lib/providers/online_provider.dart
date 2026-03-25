import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player.dart';
import '../providers/room_provider.dart';

/// Quick check if currently in online game
final isOnlineGameProvider = Provider<bool>((ref) {
  final room = ref.watch(roomProvider);
  return room.inRoom && room.roomData?.status == 'playing';
});

/// My color in online game
final myOnlineColorProvider = Provider<Player?>((ref) {
  final room = ref.watch(roomProvider);
  return room.myColor;
});

/// Is it my turn in online game
final isMyTurnProvider = Provider<bool>((ref) {
  final room = ref.watch(roomProvider);
  if (!room.inRoom) return true;
  if (room.roomData == null) return false;
  return room.roomData!.currentTurn == room.myColor;
});

/// Online game status text
final onlineStatusProvider = Provider<String>((ref) {
  final room = ref.watch(roomProvider);

  if (!room.inRoom) return '';

  final roomData = room.roomData;
  if (roomData == null) return 'Loading...';

  switch (roomData.status) {
    case 'waiting':
      return 'Waiting for opponent...';
    case 'playing':
      if (roomData.currentTurn == room.myColor) {
        return 'Your turn';
      } else {
        return 'Opponent\'s turn...';
      }
    case 'finished':
      return 'Game finished';
    default:
      return '';
  }
});