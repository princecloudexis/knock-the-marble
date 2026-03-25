enum GameMode {
  vsComputer,
  localMultiplayer,
  online,
}

enum AiDifficulty {
  easy,
  medium,
  hard,
}

class RoomData {
  final String roomId;
  final String hostId;
  final String? guestId;
  final Map<String, dynamic> boardData;
  final String currentTurn;
  final int blackScore;
  final int whiteScore;
  final int moveCount;
  final bool isActive;
  final DateTime createdAt;

  const RoomData({
    required this.roomId,
    required this.hostId,
    this.guestId,
    required this.boardData,
    required this.currentTurn,
    this.blackScore = 0,
    this.whiteScore = 0,
    this.moveCount = 0,
    this.isActive = true,
    required this.createdAt,
  });

  bool get isFull => guestId != null;
  bool get isWaiting => guestId == null;

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'hostId': hostId,
      'guestId': guestId,
      'boardData': boardData,
      'currentTurn': currentTurn,
      'blackScore': blackScore,
      'whiteScore': whiteScore,
      'moveCount': moveCount,
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory RoomData.fromMap(Map<String, dynamic> map) {
    return RoomData(
      roomId: map['roomId'] ?? '',
      hostId: map['hostId'] ?? '',
      guestId: map['guestId'],
      boardData: Map<String, dynamic>.from(map['boardData'] ?? {}),
      currentTurn: map['currentTurn'] ?? 'black',
      blackScore: map['blackScore'] ?? 0,
      whiteScore: map['whiteScore'] ?? 0,
      moveCount: map['moveCount'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch),
    );
  }
}