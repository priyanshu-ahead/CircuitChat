import 'message_model.dart';
import 'user_model.dart';

/// Chat types matching SocialEngine's chatType field.
enum ChatType { direct, group }

/// Holds a typing / action indicator state for a chat.
class ChatAction {
  const ChatAction({required this.typing, required this.userId});
  final bool typing;
  final String userId;
}

/// Full chat model matching the SE API response shape used in the RN app's
/// Redux store (see `store/reducer/chats.js` for the complete field inventory).
class ChatModel {
  const ChatModel({
    required this.id,
    required this.type,
    this.name,
    this.avatar,
    this.members = const [],
    this.lastMessage,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.isArchived = false,
    this.isBlocked = false,
    this.isBlockedByMe = false,
    this.isOnline = false,
    this.action,
    this.lastActive,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final ChatType type;
  final String? name;
  final String? avatar;
  final List<UserModel> members;
  final MessageModel? lastMessage;

  /// Unread message count; -1 means muted / not-tracked.
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final bool isArchived;
  final bool isBlocked;      // current user blocked the other
  final bool isBlockedByMe;  // current user IS the one who blocked
  final bool isOnline;       // other user is online (direct chats)
  final ChatAction? action;  // typing indicator
  /// Last activity timestamp of the other user (direct chat) — mirrors RN
  /// `chat.lastActive`. Used for the "Active X ago" subtitle when offline.
  final String? lastActive;
  final String? createdAt;
  final String? updatedAt;

  // ── fromJson ──────────────────────────────────────────────────────────────

  static ChatType _typeFromJson(dynamic v) {
    final s = v?.toString() ?? '';
    if (s == '1' || s.toLowerCase() == 'group') return ChatType.group;
    return ChatType.direct;
  }

  static List<UserModel> _membersFromJson(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map<String, dynamic>>()
          .map((e) => UserModel.fromJson(e))
          .toList();
    }
    return const [];
  }

  static MessageModel? _msgFromJson(dynamic v) {
    if (v is Map<String, dynamic>) return MessageModel.fromJson(v);
    return null;
  }

  static int _toInt(dynamic v, {int fallback = 0}) =>
      v == null ? fallback : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? fallback);

  static bool _toBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    return fallback;
  }

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    // SE wraps each chat entry as { chat: {...}, lastMessage: {...}, unread: n, ... }
    final chatInfo = json['chat'] is Map<String, dynamic>
        ? json['chat'] as Map<String, dynamic>
        : json;

    final lastMsg = _msgFromJson(json['lastMessage'] ?? json['last_message']);

    // Online status can live on the chat object or a nested "user" object.
    final dynamic onlineRaw =
        chatInfo['isOnline'] ?? chatInfo['is_online'] ?? chatInfo['online'];

    return ChatModel(
      id: (chatInfo['_id'] ?? chatInfo['id'] ?? chatInfo['chat_id'] ?? '').toString(),
      type: _typeFromJson(chatInfo['chatType'] ?? chatInfo['type']),
      name: (chatInfo['name'] ?? chatInfo['title'])?.toString(),
      avatar: (chatInfo['avatar'] ?? chatInfo['avatar_url'] ?? chatInfo['photo'])?.toString(),
      members: _membersFromJson(chatInfo['members']),
      lastMessage: lastMsg,
      unreadCount: _toInt(json['unread'] ?? json['unread_count'] ?? json['unreadCount']),
      isPinned: json['pin'] != null || _toBool(json['isPinned'] ?? json['is_pinned']),
      isMuted: _toBool(json['mute'] ?? json['isMuted'] ?? json['is_muted']),
      isArchived: _toBool(json['archive'] ?? json['isArchived'] ?? json['is_archived']),
      isBlocked: _toBool(json['blocked'] ?? json['isBlocked']),
      isBlockedByMe: _toBool(json['blockedMe'] ?? json['is_blocked_by_me']),
      isOnline: _toBool(onlineRaw),
      lastActive: (chatInfo['lastActive'] ?? chatInfo['last_active']
          ?? chatInfo['lastSeen'] ?? chatInfo['last_seen'])?.toString(),
      createdAt: (chatInfo['createdAt'] ?? chatInfo['created_at'])?.toString(),
      updatedAt: (chatInfo['updatedAt'] ?? chatInfo['updated_at'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        if (name != null) 'name': name,
        if (avatar != null) 'avatar': avatar,
        'members': members.map((e) => e.toJson()).toList(),
        if (lastMessage != null) 'lastMessage': lastMessage!.toJson(),
        'unread': unreadCount,
        'isPinned': isPinned,
        'isMuted': isMuted,
        'isArchived': isArchived,
        'isBlocked': isBlocked,
        'isBlockedByMe': isBlockedByMe,
        'isOnline': isOnline,
        if (lastActive != null) 'lastActive': lastActive,
        if (createdAt != null) 'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };

  ChatModel copyWith({
    String? name,
    String? avatar,
    MessageModel? lastMessage,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    bool? isArchived,
    bool? isBlocked,
    bool? isBlockedByMe,
    bool? isOnline,
    ChatAction? action,
    String? lastActive,
  }) =>
      ChatModel(
        id: id,
        type: type,
        name: name ?? this.name,
        avatar: avatar ?? this.avatar,
        members: members,
        lastMessage: lastMessage ?? this.lastMessage,
        unreadCount: unreadCount ?? this.unreadCount,
        isPinned: isPinned ?? this.isPinned,
        isMuted: isMuted ?? this.isMuted,
        isArchived: isArchived ?? this.isArchived,
        isBlocked: isBlocked ?? this.isBlocked,
        isBlockedByMe: isBlockedByMe ?? this.isBlockedByMe,
        isOnline: isOnline ?? this.isOnline,
        action: action ?? this.action,
        lastActive: lastActive ?? this.lastActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
