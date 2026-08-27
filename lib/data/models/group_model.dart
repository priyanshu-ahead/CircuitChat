import 'user_model.dart';

/// Group type constants — mirrors RN's GROUP_TYPE constant.
enum GroupType {
  open,           // anyone can join
  private,        // requires admin approval
  passwordProtected, // requires a password
}

/// A single group member entry as returned by /group/members/:id.
class GroupMember {
  const GroupMember({
    required this.id,
    required this.user,
    required this.role,
    required this.status,
    this.joinedAt,
  });

  final String id;
  final UserModel user;
  final String role;   // 'admin' | 'member'
  final String status; // 'active' | 'inactive' | 'pending'
  final String? joinedAt;

  bool get isAdmin => role == 'admin';

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    final userRaw = json['user'];
    final user = userRaw is Map<String, dynamic>
        ? UserModel.fromJson(userRaw)
        : UserModel(
            id: userRaw?.toString() ?? '',
            username: '',
            email: '',
          );
    return GroupMember(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      user: user,
      role: (json['role'] ?? 'member').toString(),
      status: (json['status'] ?? 'active').toString(),
      joinedAt: json['createdAt']?.toString() ?? json['joinedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'user': user.toJson(),
        'role': role,
        'status': status,
        if (joinedAt != null) 'createdAt': joinedAt,
      };
}

/// Nested permissions object inside group settings.
class GroupPermissions {
  const GroupPermissions({
    this.editDetails = true,
    this.sendMessage = true,
    this.call = true,
    this.addMember = true,
    this.approveMember = false,
  });

  final bool editDetails;
  final bool sendMessage;
  final bool call;
  final bool addMember;
  final bool approveMember; // admin-level: require approval for new members

  factory GroupPermissions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const GroupPermissions();
    final member = json['member'] is Map<String, dynamic>
        ? json['member'] as Map<String, dynamic>
        : <String, dynamic>{};
    final admin = json['admin'] is Map<String, dynamic>
        ? json['admin'] as Map<String, dynamic>
        : <String, dynamic>{};
    return GroupPermissions(
      editDetails: _b(member['editDetails']) ?? true,
      sendMessage: _b(member['sendMessage']) ?? true,
      call: _b(member['call']) ?? true,
      addMember: _b(member['addMember']) ?? true,
      approveMember: _b(admin['approveMember']) ?? false,
    );
  }

  static bool? _b(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    return null;
  }

  /// Returns the raw nested shape the SE API expects: {member:{...}, admin:{...}}
  Map<String, dynamic> toApiJson() => {
        'member': {
          'editDetails': editDetails,
          'sendMessage': sendMessage,
          'call': call,
          'addMember': addMember,
        },
        'admin': {
          'approveMember': approveMember,
        },
      };
}

/// Full group model matching the SE /group/:id response.
class GroupModel {
  const GroupModel({
    required this.id,
    required this.name,
    this.avatar,
    this.about,
    this.type = GroupType.open,
    this.members = const [],
    this.memberCount = 0,
    this.settings,
    this.chatId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? avatar;
  final String? about;
  final GroupType type;
  final List<GroupMember> members;
  final int memberCount;
  final GroupPermissions? settings;

  /// The associated chat _id (SE links groups to a chat document).
  final String? chatId;
  final String? createdAt;
  final String? updatedAt;

  static GroupType _typeFromJson(dynamic v) {
    switch (v?.toString()) {
      case 'private':
        return GroupType.private;
      case 'password_protected':
      case 'passwordProtected':
        return GroupType.passwordProtected;
      default:
        return GroupType.open;
    }
  }

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    // SE may wrap the group under a 'group' key
    final g = json['group'] is Map<String, dynamic>
        ? json['group'] as Map<String, dynamic>
        : json;

    final membersRaw = g['members'] as List? ?? [];
    final members = membersRaw
        .whereType<Map<String, dynamic>>()
        .map((e) => GroupMember.fromJson(e))
        .toList();

    return GroupModel(
      id: (g['_id'] ?? g['id'] ?? '').toString(),
      name: (g['name'] ?? g['title'] ?? '').toString(),
      avatar: g['avatar']?.toString() ?? g['photo']?.toString(),
      about: g['about']?.toString() ?? g['description']?.toString(),
      type: _typeFromJson(g['type'] ?? g['groupType']),
      members: members,
      // Priority: explicit count fields → embedded members length
      // SE /group/:id embeds the full members array so members.length is accurate.
      memberCount: members.isNotEmpty
          ? members.length
          : ((g['memberCount'] as num?)?.toInt() ??
              (g['totalMembers'] as num?)?.toInt() ??
              (g['member_count'] as num?)?.toInt() ??
              0),
      settings: GroupPermissions.fromJson(
        g['settings'] is Map<String, dynamic>
            ? g['settings'] as Map<String, dynamic>
            : null,
      ),
      chatId: (g['chat'] ?? g['chatId'])?.toString(),
      createdAt: (g['createdAt'] ?? g['created_at'])?.toString(),
      updatedAt: (g['updatedAt'] ?? g['updated_at'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        if (avatar != null) 'avatar': avatar,
        if (about != null) 'about': about,
        'type': type.name,
        'members': members.map((e) => e.toJson()).toList(),
        'memberCount': memberCount,
        if (settings != null) 'settings': settings!.toApiJson(),
        if (chatId != null) 'chat': chatId,
        if (createdAt != null) 'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };

  GroupModel copyWith({
    String? name,
    String? avatar,
    String? about,
    GroupType? type,
    List<GroupMember>? members,
    int? memberCount,
    GroupPermissions? settings,
  }) =>
      GroupModel(
        id: id,
        name: name ?? this.name,
        avatar: avatar ?? this.avatar,
        about: about ?? this.about,
        type: type ?? this.type,
        members: members ?? this.members,
        memberCount: memberCount ?? this.memberCount,
        settings: settings ?? this.settings,
        chatId: chatId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/// A pending join request entry from /group/pending/:id.
class GroupPendingMember {
  const GroupPendingMember({
    required this.id,
    required this.user,
    this.requestedAt,
  });

  final String id;
  final UserModel user;
  final String? requestedAt;

  factory GroupPendingMember.fromJson(Map<String, dynamic> json) {
    final userRaw = json['user'];
    final user = userRaw is Map<String, dynamic>
        ? UserModel.fromJson(userRaw)
        : UserModel(id: userRaw?.toString() ?? '', username: '', email: '');
    return GroupPendingMember(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      user: user,
      requestedAt: json['createdAt']?.toString(),
    );
  }
}

/// Call model for call log entries.
class CallModel {
  const CallModel({
    required this.id,
    this.chatId,
    this.chatName,
    this.chatAvatar,
    this.chatType,
    this.callType,
    this.status,
    this.duration,
    this.channelId,
    this.uuid,
    this.createdAt,
    this.fromMe = false,
  });

  final String id;
  final String? chatId;
  final String? chatName;
  final String? chatAvatar;
  final String? chatType;   // 'user' direct, 'group' group
  final String? callType;   // 'audio' | 'video'
  final String? status;     // 'ongoing' | 'ended' | 'rejected' | 'missed'
  final int? duration;      // seconds
  final String? channelId;
  final String? uuid;
  final String? createdAt;
  final bool fromMe;

  bool get isVideo => callType == 'video';
  bool get isOngoing => status == 'ongoing' || status == 'accepted';
  bool get isMissed => status == 'missed' || status == 'rejected';

  factory CallModel.fromJson(Map<String, dynamic> json) {
    final chat = json['chat'] is Map<String, dynamic>
        ? json['chat'] as Map<String, dynamic>
        : <String, dynamic>{};
    return CallModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      chatId: (chat['_id'] ?? chat['id'] ?? json['chat'])?.toString(),
      chatName: (chat['name'] ?? json['chatName'])?.toString(),
      chatAvatar: (chat['avatar'] ?? json['chatAvatar'])?.toString(),
      chatType: (json['chatType'] ?? json['receiverType'])?.toString(),
      callType: (json['callType'] ?? json['type'])?.toString(),
      status: json['status']?.toString(),
      duration: (json['duration'] as num?)?.toInt(),
      channelId: json['channelId']?.toString(),
      uuid: json['uuid']?.toString(),
      createdAt: (json['createdAt'] ?? json['created_at'])?.toString(),
      fromMe: json['fromMe'] == true || json['isInitiator'] == true,
    );
  }
}
