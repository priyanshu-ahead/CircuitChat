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
    this.active = false,
    this.state = 0,
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

  /// Presence flag from RN Redux (`user.active`) / `GET /friend/active`.
  final bool active;

  /// RN USER_STATE: 0 offline, 1 active/online, 2 away, 3 dnd.
  final int state;
  final String? lastSeen;
  final String? createdAt;

  static bool _toBool(dynamic v) {
    if (v == true || v == 1 || v == '1') return true;
    return false;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final nested = json['user'];
    if (nested is Map<String, dynamic> &&
        json['_id'] == null &&
        json['id'] == null) {
      return UserModel.fromJson(nested);
    }
    final id = (json['_id'] ?? json['id'] ?? json['user_id'] ?? '').toString();
    final name = (json['name'] ?? json['display_name'] ?? json['displayName'] ?? json['username'] ?? '').toString();
    final uname = (json['username'] ?? name).toString();
    final mail = (json['email'] ?? '').toString();
    final active = _toBool(json['active']);
    final online = _toBool(json['is_online']) ||
        _toBool(json['isOnline']) ||
        _toBool(json['online']) ||
        active;
    final stateRaw = json['state'];
    final state = stateRaw is num
        ? stateRaw.toInt()
        : int.tryParse(stateRaw?.toString() ?? '') ?? (active || online ? 1 : 0);
    return UserModel(
      id: id,
      username: uname,
      email: mail,
      displayName: json['display_name']?.toString() ?? json['displayName']?.toString() ?? (name != uname ? name : null),
      avatar: json['avatar_url']?.toString() ?? json['avatar']?.toString() ?? json['photo']?.toString(),
      phone: json['phone']?.toString(),
      bio: json['bio']?.toString() ?? json['about']?.toString(),
      isOnline: online,
      active: active || online,
      state: state,
      lastSeen: json['last_seen']?.toString() ?? json['lastSeen']?.toString() ?? json['lastActive']?.toString(),
      createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString(),
    );
  }

  UserModel copyWith({
    String? username,
    String? email,
    String? displayName,
    String? avatar,
    String? phone,
    String? bio,
    bool? isOnline,
    bool? active,
    int? state,
    String? lastSeen,
  }) =>
      UserModel(
        id: id,
        username: username ?? this.username,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        avatar: avatar ?? this.avatar,
        phone: phone ?? this.phone,
        bio: bio ?? this.bio,
        isOnline: isOnline ?? this.isOnline,
        active: active ?? this.active,
        state: state ?? this.state,
        lastSeen: lastSeen ?? this.lastSeen,
        createdAt: createdAt,
      );

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
