import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';
import '../../repositories/chat_repository.dart';

/// Remote data source — calls the real SocialEngine REST API.
/// All endpoint paths mirror the RN app's services/chat.js & services/message.js.
class ChatRemoteDataSource implements ChatRepository {
  const ChatRemoteDataSource(this._api);
  final ApiClient _api;

  // ── Chat list ─────────────────────────────────────────────────────────────

  @override
  Future<PaginatedResult<ChatModel>> fetchChats(
      FetchChatsParams params) async {
    final raw = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.chats,
      queryParameters: {
        'archive': params.archive,
        'unread': params.unread,
        'group': params.group,
        'limit': params.limit,
        if (params.lastMessage != null) 'lastMessage': params.lastMessage,
      },
    );
    final chats = (raw['chats'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((e) => ChatModel.fromJson(e))
        .toList();
    return PaginatedResult(
      items: chats,
      hasMore: raw['more'] == true,
    );
  }

  @override
  Future<ChatModel> getChatById(String chatId) async {
    final raw = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.chatById(chatId),
    );
    return ChatModel.fromJson(raw);
  }

  @override
  Future<PaginatedResult<ChatModel>> searchChats(String query) async {
    final raw = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.chatSearch,
      queryParameters: {'search': query, 'limit': 5},
    );
    final chats = (raw['chats'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((e) => ChatModel.fromJson(e))
        .toList();
    return PaginatedResult(items: chats, hasMore: false);
  }

  @override
  Future<List<ChatModel>> getNewChatUsers(String query) async {
    final raw = await _api.get<dynamic>(
      ApiEndpoints.chatNewChat,
      queryParameters: query.isNotEmpty ? {'search': query} : null,
    );
    // SE /chat/new-chat returns the array directly (mirrors RN: response.data IS array)
    List<dynamic> rawList;
    if (raw is List) {
      rawList = raw;
    } else if (raw is Map<String, dynamic>) {
      rawList = (raw['chats'] as List?) ??
          (raw['users'] as List?) ??
          (raw['data']  as List?) ??
          [];
    } else {
      rawList = [];
    }
    return rawList
        .whereType<Map<String, dynamic>>()
        .map((e) => ChatModel.fromJson(e))
        .toList();
  }

  @override
  Future<int> getArchiveCount() async {
    final raw = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.chatArchiveCount,
    );
    return (raw['count'] as num?)?.toInt() ?? 0;
  }

  // ── Chat actions ──────────────────────────────────────────────────────────

  @override
  Future<void> pinChat(String chatId) =>
      _api.post<void>(ApiEndpoints.chatPin, data: {'chat': chatId});

  @override
  Future<void> unpinChat(String chatId) =>
      _api.post<void>(ApiEndpoints.chatUnpin, data: {'chat': chatId});

  @override
  Future<void> archiveChat(String chatId) =>
      _api.post<void>(ApiEndpoints.chatArchive, data: {'chat': chatId});

  @override
  Future<void> unarchiveChat(String chatId) =>
      _api.post<void>(ApiEndpoints.chatUnarchive, data: {'chat': chatId});

  @override
  Future<void> markRead(String chatId, String chatType) =>
      _api.post<void>(ApiEndpoints.chatMarkRead,
          data: [{'chat': chatId, 'chatType': chatType}]);

  @override
  Future<void> markUnread(String chatId, String chatType) =>
      _api.post<void>(ApiEndpoints.chatMarkUnread,
          data: [{'chat': chatId, 'chatType': chatType}]);

  @override
  Future<void> muteChat(String chatId, {int? muteUntil}) => _api.post<void>(
        ApiEndpoints.chatMute,
        data: {
          'chat': chatId,
          if (muteUntil != null) 'muteUntil': muteUntil,
        },
      );

  @override
  Future<void> unmuteChat(String chatId) =>
      _api.post<void>(ApiEndpoints.chatUnmute, data: {'chat': chatId});

  @override
  Future<void> deleteChat(String chatId, String chatType) =>
      _api.post<void>(ApiEndpoints.chatDelete, data: [
        {'chat': chatId, 'chatType': chatType},
      ]);

  // ── Messages ──────────────────────────────────────────────────────────────

  @override
  Future<PaginatedResult<MessageModel>> fetchMessages(
      FetchMessagesParams params) async {
    // SE backend URL uses 'user'/'group' — convert from '0'/'1'
    final receiverType = (params.chatType == '1' || params.chatType == 'group') ? 'group' : 'user';

    final queryParts = <String>[
      'limit=${params.limit}',
      if (params.lastMessage != null) 'lastMessage=${Uri.encodeComponent(params.lastMessage!)}',
      if (params.beforeMessage != null) 'beforeMessage=${Uri.encodeComponent(params.beforeMessage!)}',
      if (params.search != null) 'search=${Uri.encodeComponent(params.search!)}',
    ];
    final qs  = queryParts.isEmpty ? '' : '?${queryParts.join('&')}';
    final url = '${ApiEndpoints.messages(params.chatId, receiverType)}$qs';

    final raw = await _api.post<Map<String, dynamic>>(
      url,
      data: (params.password != null && params.password!.isNotEmpty)
          ? {'password': params.password}
          : <String, dynamic>{},
    );
    final messages = (raw['messages'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((e) => MessageModel.fromJson(e))
        .toList();
    return PaginatedResult(items: messages, hasMore: raw['more'] == true);
  }

  @override
  Future<MessageModel> sendMessage({
    required String chatId,
    required String chatType,   // '0' = direct → 'user', '1' = group → 'group'
    required String contentType,
    String? text,
    String? mediaId,
    String? replyToId,
    List<String>? mentions,
  }) async {
    // SE backend expects 'receiver'+'receiverType' with values 'user'/'group'
    final receiverType = (chatType == '1' || chatType == 'group') ? 'group' : 'user';

    final raw = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.sendMessage,
      data: {
        'receiver':     chatId,
        'receiverType': receiverType,
        'contentType':  contentType,
        if (text != null) 'text': text,
        if (mediaId != null) 'media': mediaId,
        if (replyToId != null) 'reply': replyToId,
        if (mentions != null && mentions.isNotEmpty) 'mentions': mentions,
      },
    );
    return MessageModel.fromJson(raw);
  }

  @override
  Future<MessageModel> sendMediaMessage({
    required String chatId,
    required String chatType,
    required String localPath,
    required MessageType type,
    String? text,
  }) async {
    final filename = localPath.split(RegExp(r'[/\\]')).last;
    // RN uses /message/media for upload then /message with receiver+receiverType
    final receiverType = (chatType == '1' || chatType == 'group') ? 'group' : 'user';


    // Step 1: upload the file to /message/media
    // final filename = localPath.split(RegExp(r'[/\\]')).last;
    final uploadForm = FormData.fromMap({
      'file': await MultipartFile.fromFile(localPath, filename: filename),
    });
    final uploadRaw = await _api.uploadFile<Map<String, dynamic>>(
      ApiEndpoints.messageMediaUpload,
      uploadForm,
    );
    final mediaId = (uploadRaw['_id'] ?? uploadRaw['id'] ?? '').toString();

    // Step 2: send the message with the uploaded media ID
    final raw = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.sendMessage,
      data: {
        'receiver':     chatId,
        'receiverType': receiverType,
        'contentType':  type.name,
        'media':        mediaId,
        if (text != null) 'text': text,
      },
    );
    return MessageModel.fromJson(raw);
  }

  @override
  Future<MessageModel> editMessage(String messageId, String text) async {
    final raw = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.messageEdit,
      data: {'message': messageId, 'text': text},
    );
    return MessageModel.fromJson(raw);
  }

  @override
  Future<void> deleteMessage(List<String> messageIds) =>
      _api.post<void>(ApiEndpoints.messageDelete,
          data: messageIds.map((id) => {'message': id}).toList());

  @override
  Future<void> deleteMessageForEveryone(List<String> messageIds,
      {required String chatId}) =>
      _api.post<void>(ApiEndpoints.messageDeleteEveryone,
          data: messageIds
              .map((id) => {'message': id, 'chat': chatId})
              .toList());

  @override
  Future<void> starMessage(
          String messageId, String chatId, String chatType) =>
      _api.post<void>(ApiEndpoints.messageStarred,
          data: {'message': messageId, 'chat': chatId, 'chatType': chatType});

  @override
  Future<void> unstarMessage(
          String messageId, String chatId, String chatType) =>
      _api.post<void>(ApiEndpoints.messageUnstarred,
          data: {'message': messageId, 'chat': chatId, 'chatType': chatType});

  @override
  Future<void> forwardMessage(
      List<String> messageIds, List<String> targetChatIds) =>
      _api.post<void>(ApiEndpoints.messageForward,
          data: {'messages': messageIds, 'chats': targetChatIds});

  @override
  Future<void> addReaction(
      String messageId, String chatId, String reaction) =>
      _api.post<void>(ApiEndpoints.messageReaction,
          data: {'message': messageId, 'chat': chatId, 'reaction': reaction});

  @override
  Future<void> removeReaction(String messageId, String chatId) =>
      _api.post<void>(ApiEndpoints.messageRemoveReaction,
          data: {'message': messageId, 'chat': chatId});

  @override
  Future<void> pinMessage(String messageId, String chatId) =>
      _api.post<void>(ApiEndpoints.messagePin,
          data: {'message': messageId, 'chat': chatId});

  @override
  Future<void> unpinMessage(String messageId) =>
      _api.delete<void>(ApiEndpoints.messageUnpin(messageId));

  @override
  Future<MessageModel?> getPinnedMessage(String chatId) async {
    try {
      final raw = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.chatPinMessage(chatId),
      );
      final list = raw['data'] as List?;
      if (list == null || list.isEmpty) return null;
      return MessageModel.fromJson(list.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
