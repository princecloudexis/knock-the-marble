import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hex.dart';
import '../models/player.dart';
import '../models/user_profile.dart';

class RoomData {
  final String roomId;
  final String hostId;
  final String hostName;
  final int hostAvatar;
  final String hostColorStr;
  final String? guestId;
  final String? guestName;
  final int? guestAvatar;
  final Map<Hex, Player> board;
  final Player currentTurn;
  final int blackScore;
  final int whiteScore;
  final int moveCount;
  final String status;
  final DateTime createdAt;

  final DateTime? hostLastSeen;
  final DateTime? guestLastSeen;
  final DateTime? lastMoveAt;
  final String? disconnectedBy;
  final DateTime? disconnectedAt;
  final String? closedReason;

  const RoomData({
    required this.roomId,
    required this.hostId,
    required this.hostName,
    required this.hostAvatar,
    this.hostColorStr = 'black',
    this.guestId,
    this.guestName,
    this.guestAvatar,
    required this.board,
    required this.currentTurn,
    required this.blackScore,
    required this.whiteScore,
    required this.moveCount,
    required this.status,
    required this.createdAt,
    this.hostLastSeen,
    this.guestLastSeen,
    this.lastMoveAt,
    this.disconnectedBy,
    this.disconnectedAt,
    this.closedReason,
  });

  bool get isFull => guestId != null;
  bool get isWaiting => status == 'waiting';
  bool get isPlaying => status == 'playing';
  bool get isFinished => status == 'finished';
  bool get isAbandoned => status == 'abandoned';
  bool get isClosed => status == 'abandoned' || status == 'finished';

  Player get hostColor =>
      hostColorStr == 'white' ? Player.white : Player.black;

  bool get hasDisconnect =>
      disconnectedBy != null && disconnectedAt != null;

  int get disconnectSecondsLeft {
    if (disconnectedAt == null) return 60;
    final elapsed = DateTime.now().difference(disconnectedAt!).inSeconds;
    return (60 - elapsed).clamp(0, 60);
  }

  bool get isDisconnectExpired => hasDisconnect && disconnectSecondsLeft <= 0;

  bool isPlayerOffline(String userId) {
    final lastSeen = userId == hostId ? hostLastSeen : guestLastSeen;
    if (lastSeen == null) return false;
    return DateTime.now().difference(lastSeen).inSeconds > 45;
  }

  int get secondsSinceLastMove {
    if (lastMoveAt == null) return 0;
    return DateTime.now().difference(lastMoveAt!).inSeconds;
  }

  String? get currentTurnUserId {
    if (currentTurn == hostColor) return hostId;
    return guestId;
  }

  String? get waitingUserId {
    if (currentTurn == hostColor) return guestId;
    return hostId;
  }

  Map<String, dynamic> toMap() {
    final boardMap = <String, String>{};
    board.forEach((hex, player) {
      boardMap['${hex.q},${hex.r}'] = player.name;
    });

    return {
      'roomId': roomId,
      'hostId': hostId,
      'hostName': hostName,
      'hostAvatar': hostAvatar,
      'hostColor': hostColorStr,
      'guestId': guestId,
      'guestName': guestName,
      'guestAvatar': guestAvatar,
      'board': boardMap,
      'currentTurn': currentTurn.name,
      'blackScore': blackScore,
      'whiteScore': whiteScore,
      'moveCount': moveCount,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'hostLastSeen': hostLastSeen?.toIso8601String(),
      'guestLastSeen': guestLastSeen?.toIso8601String(),
      'lastMoveAt': lastMoveAt?.toIso8601String(),
      'disconnectedBy': disconnectedBy,
      'disconnectedAt': disconnectedAt?.toIso8601String(),
      'closedReason': closedReason,
    };
  }

  factory RoomData.fromMap(Map<String, dynamic> map) {
    final boardMap = <Hex, Player>{};
    final rawBoard = map['board'] as Map<String, dynamic>? ?? {};
    rawBoard.forEach((key, value) {
      final parts = key.split(',');
      if (parts.length == 2) {
        final q = int.tryParse(parts[0]) ?? 0;
        final r = int.tryParse(parts[1]) ?? 0;
        final player = Player.values.firstWhere(
          (p) => p.name == value,
          orElse: () => Player.none,
        );
        boardMap[Hex(q, r)] = player;
      }
    });

    return RoomData(
      roomId: map['roomId'] ?? '',
      hostId: map['hostId'] ?? '',
      hostName: map['hostName'] ?? 'Host',
      hostAvatar: map['hostAvatar'] ?? 0,
      hostColorStr: map['hostColor'] ?? 'black',
      guestId: map['guestId'],
      guestName: map['guestName'],
      guestAvatar: map['guestAvatar'],
      board: boardMap,
      currentTurn: Player.values.firstWhere(
        (p) => p.name == (map['currentTurn'] ?? 'black'),
        orElse: () => Player.black,
      ),
      blackScore: map['blackScore'] ?? 0,
      whiteScore: map['whiteScore'] ?? 0,
      moveCount: map['moveCount'] ?? 0,
      status: map['status'] ?? 'waiting',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      hostLastSeen: _parseDate(map['hostLastSeen']),
      guestLastSeen: _parseDate(map['guestLastSeen']),
      lastMoveAt: _parseDate(map['lastMoveAt']),
      disconnectedBy: map['disconnectedBy'],
      disconnectedAt: _parseDate(map['disconnectedAt']),
      closedReason: map['closedReason'],
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class RoomService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'rooms';

  static String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  static Future<String> createRoom({
    required UserProfile host,
    required Map<Hex, Player> initialBoard,
    Player hostColor = Player.black,
  }) async {
    await _cleanupOldRooms(host.userId);

    final roomId = _generateRoomCode();
    final now = DateTime.now();

    final room = RoomData(
      roomId: roomId,
      hostId: host.userId,
      hostName: host.displayName.isEmpty ? host.shortId : host.displayName,
      hostAvatar: host.avatarIndex,
      hostColorStr: hostColor.name,
      board: initialBoard,
      currentTurn: Player.black,
      blackScore: 0,
      whiteScore: 0,
      moveCount: 0,
      status: 'waiting',
      createdAt: now,
      hostLastSeen: now,
      lastMoveAt: now,
    );

    await _firestore.collection(_collection).doc(roomId).set(room.toMap());
    return roomId;
  }

  static Future<bool> joinRoom({
    required String roomId,
    required UserProfile guest,
  }) async {
    final doc = await _firestore.collection(_collection).doc(roomId).get();
    if (!doc.exists) return false;

    final data = doc.data()!;
    if (data['guestId'] != null) return false;
    if (data['status'] != 'waiting') return false;
    if (data['hostId'] == guest.userId) return false;

    final now = DateTime.now().toIso8601String();

    await _firestore.collection(_collection).doc(roomId).update({
      'guestId': guest.userId,
      'guestName':
          guest.displayName.isEmpty ? guest.shortId : guest.displayName,
      'guestAvatar': guest.avatarIndex,
      'guestLastSeen': now,
      'lastMoveAt': now,
      'status': 'playing',
      'hostLastSeen': now,
    });

    return true;
  }

  // In RoomService class, replace the sendHeartbeat method:

static Future<void> sendHeartbeat(String roomId, String userId) async {
  try {
    final doc = await _firestore.collection(_collection).doc(roomId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final isHost = data['hostId'] == userId;
    final field = isHost ? 'hostLastSeen' : 'guestLastSeen';
    final now = DateTime.now().toIso8601String();

    await _firestore.collection(_collection).doc(roomId).update({
      field: now,
    });
  } catch (_) {}
}

static Future<void> markDisconnected(String roomId, String userId) async {
  try {
    final doc = await _firestore.collection(_collection).doc(roomId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    if (data['status'] != 'playing') return;
    if (data['disconnectedBy'] != null) return;

    final isHost = data['hostId'] == userId;
    final lastSeenStr = isHost ? data['hostLastSeen'] : data['guestLastSeen'];

    if (lastSeenStr != null) {
      final lastSeen = DateTime.tryParse(lastSeenStr);
      if (lastSeen != null) {
        final elapsed = DateTime.now().difference(lastSeen).inSeconds;
        if (elapsed < 30) return;
      }
    }

    final lastMoveStr = data['lastMoveAt'];
    if (lastMoveStr != null) {
      final lastMove = DateTime.tryParse(lastMoveStr);
      if (lastMove != null) {
        final sinceMoveSeconds = DateTime.now().difference(lastMove).inSeconds;
        if (sinceMoveSeconds < 20) {
          return;
        }
      }
    }

    await _firestore.collection(_collection).doc(roomId).update({
      'disconnectedBy': userId,
      'disconnectedAt': DateTime.now().toIso8601String(),
    });
  } catch (_) {}
}

  static Stream<RoomData?> listenToRoom(String roomId) {
    return _firestore
        .collection(_collection)
        .doc(roomId)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return RoomData.fromMap(snap.data()!);
    });
  }

  static Future<void> updateBoard({
    required String roomId,
    required Map<Hex, Player> board,
    required Player nextTurn,
    required int blackScore,
    required int whiteScore,
    required int moveCount,
  }) async {
    final boardMap = <String, String>{};
    board.forEach((hex, player) {
      boardMap['${hex.q},${hex.r}'] = player.name;
    });

    final now = DateTime.now().toIso8601String();

    await _firestore.collection(_collection).doc(roomId).update({
      'board': boardMap,
      'currentTurn': nextTurn.name,
      'blackScore': blackScore,
      'whiteScore': whiteScore,
      'moveCount': moveCount,
      'lastMoveAt': now,
      'disconnectedBy': null,
      'disconnectedAt': null,
      'hostLastSeen': now,
      'guestLastSeen': now,
    });
  }

  static Future<void> clearDisconnect(String roomId, String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(roomId).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      if (data['disconnectedBy'] != userId) return;

      final isHost = data['hostId'] == userId;
      final seenField = isHost ? 'hostLastSeen' : 'guestLastSeen';

      await _firestore.collection(_collection).doc(roomId).update({
        'disconnectedBy': null,
        'disconnectedAt': null,
        seenField: DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<void> closeGame(String roomId, String reason) async {
    try {
      final doc = await _firestore.collection(_collection).doc(roomId).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      if (data['status'] == 'abandoned' || data['status'] == 'finished') {
        return;
      }

      await _firestore.collection(_collection).doc(roomId).update({
        'status': 'abandoned',
        'closedReason': reason,
        'disconnectedBy': null,
        'disconnectedAt': null,
      });

      _scheduleDelete(roomId);
    } catch (_) {}
  }

  static Future<void> endGame(String roomId) async {
    try {
      await _firestore.collection(_collection).doc(roomId).update({
        'status': 'finished',
        'closedReason': 'finished',
      });
      _scheduleDelete(roomId);
    } catch (_) {}
  }

  static Future<void> leaveRoom(String roomId, String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(roomId).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final status = data['status'] ?? 'waiting';

      if (status == 'playing') {
        await closeGame(roomId, 'player_left');
      } else if (status == 'waiting') {
        if (data['hostId'] == userId) {
          await _firestore.collection(_collection).doc(roomId).delete();
        } else {
          await _firestore.collection(_collection).doc(roomId).update({
            'guestId': null,
            'guestName': null,
            'guestAvatar': null,
            'guestLastSeen': null,
            'status': 'waiting',
          });
        }
      }
    } catch (_) {}
  }

  static Future<bool> roomExists(String roomId) async {
    final doc = await _firestore.collection(_collection).doc(roomId).get();
    return doc.exists;
  }

  static Future<void> _cleanupOldRooms(String userId) async {
    try {
      final hostRooms = await _firestore
          .collection(_collection)
          .where('hostId', isEqualTo: userId)
          .where('status', whereIn: ['waiting', 'playing'])
          .get();

      for (final doc in hostRooms.docs) {
        final status = doc.data()['status'];
        if (status == 'playing') {
          await closeGame(doc.id, 'host_created_new_room');
        } else {
          await doc.reference.delete();
        }
      }

      final guestRooms = await _firestore
          .collection(_collection)
          .where('guestId', isEqualTo: userId)
          .where('status', isEqualTo: 'playing')
          .get();

      for (final doc in guestRooms.docs) {
        await closeGame(doc.id, 'guest_created_new_room');
      }
    } catch (_) {}
  }

  static void _scheduleDelete(String roomId) {
    Future.delayed(const Duration(seconds: 10), () async {
      try {
        final doc =
            await _firestore.collection(_collection).doc(roomId).get();
        if (doc.exists) {
          final status = doc.data()?['status'];
          if (status == 'abandoned' || status == 'finished') {
            await doc.reference.delete();
          }
        }
      } catch (_) {}
    });
  }
}