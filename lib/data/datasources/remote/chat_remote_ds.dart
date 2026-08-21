import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';
import '../../repositories/chat_repository.dart';

/// Remote data source — calls the REST API for chat operations.
class ChatRemoteDataSource implements ChatRepository {
  const ChatRemoteDataSource(this._api);

  final ApiClient _api;

  @override
  Future<List<ChatModel>> getChats({int page = 1, int limit = 20}) async {
    final data = await _api.get<List<dynamic>>(
      ApiEndpoints.chats,
      queryParameters: {'page': page, 'limit': limit},
    );
    return data.map((e) => ChatModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<ChatModel> getChatById(String chatId) async {
    final data = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.chatById(chatId),
    );
    return ChatModel.fromJson(data);
  }

  @override
  Future<List<MessageModel>> getMessages(
    String chatId, {
    int page = 1,
    int limit = 30,
  }) async {
    final data = await _api.get<List<dynamic>>(
      ApiEndpoints.chatMessages(chatId),
      queryParameters: {'page': page, 'limit': limit},
    );
    return data
        .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<MessageModel> sendTextMessage({
    required String chatId,
    required String text,
    String? replyToId,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.sendMessage(chatId),
      data: {
        'type': 'text',
        'text': text,
        if (replyToId != null) 'reply_to_id': replyToId,
      },
    );
    return MessageModel.fromJson(data);
  }

  @override
  Future<MessageModel> sendMediaMessage({
    required String chatId,
    required String localPath,
    required MessageType type,
    String? text,
  }) async {
    final formData = FormData.fromMap({
      'type': type.name,
      'file': await MultipartFile.fromFile(localPath),
      if (text != null) 'text': text,
    });
    final data = await _api.uploadFile<Map<String, dynamic>>(
      ApiEndpoints.sendMessage(chatId),
      formData,
    );
    return MessageModel.fromJson(data);
  }

  @override
  Future<void> markAsRead(String chatId) =>
      _api.post<void>('${ApiEndpoints.chatById(chatId)}/read');

  @override
  Future<void> deleteMessage(String chatId, String messageId) =>
      _api.delete<void>('${ApiEndpoints.chatMessages(chatId)}/$messageId');

  @override
  Future<ChatModel> createDirectChat(String userId) async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.chats,
      data: {'type': 'direct', 'user_id': userId},
    );
    return ChatModel.fromJson(data);
  }

  @override
  Future<ChatModel> createGroup({
    required String name,
    required List<String> memberIds,
    String? avatar,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.chats,
      data: {
        'type': 'group',
        'name': name,
        'member_ids': memberIds,
      },
    );
    return ChatModel.fromJson(data);
  }

  @override
  Future<void> clearUnread(String chatId) =>
      _api.post<void>('${ApiEndpoints.chatById(chatId)}/clear-unread');
}
