class UserProfile {
  final String userId;
  final String displayName;
  final int avatarIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.userId,
    required this.displayName,
    this.avatarIndex = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  String get shortId {
    if (userId.length >= 8) {
      return 'HEX-${userId.substring(0, 8).toUpperCase()}';
    }
    return 'HEX-${userId.toUpperCase()}';
  }

  UserProfile copyWith({
    String? userId,
    String? displayName,
    int? avatarIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'avatarIndex': avatarIndex,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      userId: map['userId'] ?? '',
      displayName: map['displayName'] ?? '',
      avatarIndex: map['avatarIndex'] ?? 0,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  factory UserProfile.defaultProfile(String userId) {
    return UserProfile(
      userId: userId,
      displayName: '',
      avatarIndex: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}