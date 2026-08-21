import 'message_model.dart';
import 'user_model.dart';

enum ChatType { direct, group }

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
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final ChatType type;
  final String? name;
  final String? avatar;
  final List<UserModel> members;
  final MessageModel? lastMessage;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final String? createdAt;
  final String? updatedAt;

  static ChatType _typeFromJson(dynamic v) {
    final s = v?.toString() ?? 'direct';
    if (s == '1' || s == 'group') return ChatType.group;
    return ChatType.direct;
  }

  static String _typeToJson(ChatType t) => t.name;

  static List<UserModel> _membersFromJson(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map<String, dynamic>>()
          .map((e) => UserModel.fromJson(e))
          .toList();
    }
    return const [];
  }

  static MessageModel? _lastMessageFromJson(dynamic v) {
    if (v is Map<String, dynamic>) return MessageModel.fromJson(v);
    return null;
  }

  static int? _toInt(dynamic v) =>
      v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));

  factory ChatModel.fromJson(Map<String, dynamic> json) => ChatModel(
        id: (json['id'] ?? json['_id'] ?? json['chat_id'] ?? '').toString(),
        type: _typeFromJson(json['type']),
        name: (json['name'] ?? json['title'])?.toString(),
        avatar: (json['avatar_url'] ?? json['avatar'] ?? json['photo'])?.toString(),
        members: _membersFromJson(json['members']),
        lastMessage: _lastMessageFromJson(json['last_message'] ?? json['lastMessage']),
        unreadCount: _toInt(json['unread_count'] ?? json['unreadCount']) ?? 0,
        isPinned: json['is_pinned'] == true || json['isPinned'] == true,
        isMuted: json['is_muted'] == true || json['isMuted'] == true,
        createdAt: (json['created_at'] ?? json['createdAt'])?.toString(),
        updatedAt: (json['updated_at'] ?? json['updatedAt'])?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': _typeToJson(type),
        if (name != null) 'name': name,
        if (avatar != null) 'avatar_url': avatar,
        'members': members.map((e) => e.toJson()).toList(),
        if (lastMessage != null) 'last_message': lastMessage!.toJson(),
        'unread_count': unreadCount,
        'is_pinned': isPinned,
        'is_muted': isMuted,
        if (createdAt != null) 'created_at': createdAt,
        if (updatedAt != null) 'updated_at': updatedAt,
      };
}
