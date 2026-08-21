import 'message_entity.dart';
import 'user_entity.dart';

/// Chat type.
enum ChatKind { direct, group }

/// Pure domain entity for a chat conversation.
class ChatEntity {
  const ChatEntity({
    required this.id,
    required this.kind,
    this.name,
    this.avatar,
    this.members = const [],
    this.lastMessage,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.updatedAt,
  });

  final String id;
  final ChatKind kind;
  final String? name;
  final String? avatar;
  final List<UserEntity> members;
  final MessageEntity? lastMessage;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final DateTime? updatedAt;

  bool get isDirect => kind == ChatKind.direct;
  bool get isGroup => kind == ChatKind.group;

  /// Returns the other member in a direct chat (not the current user).
  UserEntity? otherMember(String currentUserId) => isDirect
      ? members.where((m) => m.id != currentUserId).firstOrNull
      : null;

  UserEntity? get firstOrNull =>
      members.isEmpty ? null : members.first;

  ChatEntity copyWith({
    MessageEntity? lastMessage,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
  }) =>
      ChatEntity(
        id: id,
        kind: kind,
        name: name,
        avatar: avatar,
        members: members,
        lastMessage: lastMessage ?? this.lastMessage,
        unreadCount: unreadCount ?? this.unreadCount,
        isPinned: isPinned ?? this.isPinned,
        isMuted: isMuted ?? this.isMuted,
        updatedAt: updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatEntity && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
