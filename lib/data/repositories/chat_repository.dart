import '../models/chat_model.dart';
import '../models/message_model.dart';

/// Fetch params for the chat list — mirrors RN's fetchChats() params.
class FetchChatsParams {
  const FetchChatsParams({
    this.archive = false,
    this.unread = false,
    this.group = false,
    this.lastMessage,
    this.limit = 20,
  });

  final bool archive;
  final bool unread;
  final bool group;
  final String? lastMessage; // cursor for pagination
  final int limit;
}

/// Fetch params for a message list — mirrors RN's fetchMessages() params.
class FetchMessagesParams {
  const FetchMessagesParams({
    required this.chatId,
    required this.chatType,
    this.lastMessage,
    this.beforeMessage,
    this.limit = 30,
    this.password,
    this.search,
  });

  final String chatId;
  final String chatType; // '0' = direct, '1' = group (matches RN CHAT_TYPE constant)
  final String? lastMessage;    // cursor: fetch older than this
  final String? beforeMessage;  // cursor: fetch newer than this
  final int limit;
  final String? password;       // password-locked groups
  final String? search;
}

/// Result wrapper returned by list calls.
class PaginatedResult<T> {
  const PaginatedResult({required this.items, required this.hasMore});
  final List<T> items;
  final bool hasMore;
}

/// Abstract interface for all chat & message data operations.
/// Matches the full surface of RN's services/chat.js + services/message.js.
abstract interface class ChatRepository {
  // ── Chat list ─────────────────────────────────────────────────────────────

  Future<PaginatedResult<ChatModel>> fetchChats(FetchChatsParams params);

  Future<ChatModel> getChatById(String chatId);

  Future<PaginatedResult<ChatModel>> searchChats(String query);

  Future<List<ChatModel>> getNewChatUsers(String query);

  Future<int> getArchiveCount();

  // ── Chat actions ──────────────────────────────────────────────────────────

  Future<void> pinChat(String chatId);
  Future<void> unpinChat(String chatId);

  Future<void> archiveChat(String chatId);
  Future<void> unarchiveChat(String chatId);

  Future<void> markRead(String chatId, String chatType);
  Future<void> markUnread(String chatId, String chatType);

  Future<void> muteChat(String chatId, {int? muteUntil});
  Future<void> unmuteChat(String chatId);

  Future<void> deleteChat(String chatId, String chatType);

  // ── Messages ──────────────────────────────────────────────────────────────

  Future<PaginatedResult<MessageModel>> fetchMessages(
      FetchMessagesParams params);

  Future<MessageModel> sendMessage({
    required String chatId,
    required String chatType,
    required String contentType,
    String? text,
    String? mediaId,
    String? replyToId,
    List<String>? mentions,
  });

  Future<MessageModel> sendMediaMessage({
    required String chatId,
    required String chatType,
    required String localPath,
    required MessageType type,
    String? text,
  });

  Future<MessageModel> editMessage(String messageId, String text);

  Future<void> deleteMessage(List<String> messageIds);
  Future<void> deleteMessageForEveryone(List<String> messageIds,
      {required String chatId});

  Future<void> starMessage(String messageId, String chatId, String chatType);
  Future<void> unstarMessage(String messageId, String chatId, String chatType);

  Future<void> forwardMessage(
      List<String> messageIds, List<String> targetChatIds);

  Future<void> addReaction(
      String messageId, String chatId, String reaction);
  Future<void> removeReaction(String messageId, String chatId);

  Future<void> pinMessage(String messageId, String chatId);
  Future<void> unpinMessage(String messageId);

  Future<MessageModel?> getPinnedMessage(String chatId);
}
