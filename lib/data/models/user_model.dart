class UserModel {
  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.displayName,
    this.avatar,
    this.phone,
    this.bio,
    this.isOnline = false,
    this.lastSeen,
    this.createdAt,
  });

  final String id;
  final String username;
  final String email;
  final String? displayName;
  final String? avatar;
  final String? phone;
  final String? bio;
  final bool isOnline;
  final String? lastSeen;
  final String? createdAt;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final id = (json['_id'] ?? json['id'] ?? json['user_id'] ?? '').toString();
    final name = (json['name'] ?? json['display_name'] ?? json['displayName'] ?? json['username'] ?? '').toString();
    final uname = (json['username'] ?? name).toString();
    final mail = (json['email'] ?? '').toString();
    return UserModel(
      id: id,
      username: uname,
      email: mail,
      displayName: json['display_name']?.toString() ?? json['displayName']?.toString() ?? (name != uname ? name : null),
      avatar: json['avatar_url']?.toString() ?? json['avatar']?.toString() ?? json['photo']?.toString(),
      phone: json['phone']?.toString(),
      bio: json['bio']?.toString() ?? json['about']?.toString(),
      isOnline: json['is_online'] == true || json['isOnline'] == true || json['online'] == true,
      lastSeen: json['last_seen']?.toString() ?? json['lastSeen']?.toString(),
      createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        if (displayName != null) 'display_name': displayName,
        if (avatar != null) 'avatar_url': avatar,
        if (phone != null) 'phone': phone,
        if (bio != null) 'bio': bio,
        'is_online': isOnline,
        if (lastSeen != null) 'last_seen': lastSeen,
        if (createdAt != null) 'created_at': createdAt,
      };

  String get name => displayName ?? username;
}
