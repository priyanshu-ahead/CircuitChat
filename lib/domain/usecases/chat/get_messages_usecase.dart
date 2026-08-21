import '../../../data/models/message_model.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../entities/message_entity.dart';

/// Fetch paginated messages for a chat, mapped to domain entities.
class GetMessagesUseCase {
  const GetMessagesUseCase(this._repository);

  final ChatRepository _repository;

  Future<List<MessageEntity>> call(
    String chatId, {
    int page = 1,
    int limit = 30,
  }) async {
    final models = await _repository.getMessages(
      chatId,
      page: page,
      limit: limit,
    );

    return models.map(_toEntity).toList();
  }

  MessageEntity _toEntity(MessageModel m) => MessageEntity(
        id: m.id,
        chatId: m.chatId,
        senderId: m.senderId,
        kind: _mapKind(m.type),
        text: m.text,
        mediaUrl: m.mediaUrl,
        mediaDuration: m.mediaDuration,
        latitude: m.latitude,
        longitude: m.longitude,
        status: _mapStatus(m.status),
        isDeleted: m.isDeleted,
        replyToId: m.replyToId,
        createdAt: DateTime.tryParse(m.createdAt) ?? DateTime.now(),
      );

  MessageKind _mapKind(MessageType type) => switch (type) {
        MessageType.text => MessageKind.text,
        MessageType.image => MessageKind.image,
        MessageType.video => MessageKind.video,
        MessageType.audio => MessageKind.audio,
        MessageType.file => MessageKind.file,
        MessageType.location => MessageKind.location,
        MessageType.call => MessageKind.call,
      };

  DeliveryStatus _mapStatus(MessageStatus status) => switch (status) {
        MessageStatus.sending => DeliveryStatus.sending,
        MessageStatus.sent => DeliveryStatus.sent,
        MessageStatus.delivered => DeliveryStatus.delivered,
        MessageStatus.seen => DeliveryStatus.seen,
        MessageStatus.failed => DeliveryStatus.failed,
      };
}
