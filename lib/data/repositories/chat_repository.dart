import '../models/chat_model.dart';
import '../models/message_model.dart';

/// Abstract interface for chat data operations.
abstract interface class ChatRepository {
  /// Fetch paginated list of chats for the logged-in user.
  Future<List<ChatModel>> getChats({int page = 1, int limit = 20});

  /// Fetch a single chat by [chatId].
  Future<ChatModel> getChatById(String chatId);

  /// Fetch paginated messages for [chatId].
  Future<List<MessageModel>> getMessages(
    String chatId, {
    int page = 1,
    int limit = 30,
  });

  /// Send a text message.
  Future<MessageModel> sendTextMessage({
    required String chatId,
    required String text,
    String? replyToId,
  });

  /// Send a media message (image/video/audio/file).
  Future<MessageModel> sendMediaMessage({
    required String chatId,
    required String localPath,
    required MessageType type,
    String? text,
  });

  /// Mark all messages in [chatId] as read.
  Future<void> markAsRead(String chatId);

  /// Delete a message (soft delete).
  Future<void> deleteMessage(String chatId, String messageId);

  /// Create a new direct chat with [userId].
  Future<ChatModel> createDirectChat(String userId);

  /// Create a group chat.
  Future<ChatModel> createGroup({
    required String name,
    required List<String> memberIds,
    String? avatar,
  });

  /// Clear unread count for [chatId].
  Future<void> clearUnread(String chatId);
}
