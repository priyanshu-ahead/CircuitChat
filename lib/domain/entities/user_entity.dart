/// Pure domain entity — no JSON serialization, no Flutter dependencies.
class UserEntity {
  const UserEntity({
    required this.id,
    required this.username,
    required this.email,
    this.displayName,
    this.avatar,
    this.phone,
    this.bio,
    this.isOnline = false,
    this.lastSeen,
  });

  final String id;
  final String username;
  final String email;
  final String? displayName;
  final String? avatar;
  final String? phone;
  final String? bio;
  final bool isOnline;
  final DateTime? lastSeen;

  String get name => displayName ?? username;

  UserEntity copyWith({
    String? displayName,
    String? avatar,
    String? bio,
    String? phone,
    bool? isOnline,
    DateTime? lastSeen,
  }) =>
      UserEntity(
        id: id,
        username: username,
        email: email,
        displayName: displayName ?? this.displayName,
        avatar: avatar ?? this.avatar,
        phone: phone ?? this.phone,
        bio: bio ?? this.bio,
        isOnline: isOnline ?? this.isOnline,
        lastSeen: lastSeen ?? this.lastSeen,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
