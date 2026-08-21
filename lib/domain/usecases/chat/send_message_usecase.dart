import '../../../data/repositories/chat_repository.dart';
import '../../entities/message_entity.dart';

/// Send a text message and return the saved [MessageEntity].
class SendMessageUseCase {
  const SendMessageUseCase(this._repository);

  final ChatRepository _repository;

  Future<MessageEntity> call({
    required String chatId,
    required String text,
    String? replyToId,
  }) async {
    if (text.trim().isEmpty) throw ArgumentError('Message cannot be empty.');

    final model = await _repository.sendTextMessage(
      chatId: chatId,
      text: text.trim(),
      replyToId: replyToId,
    );

    return _toEntity(model);
  }

  MessageEntity _toEntity(dynamic model) {
    // Simple mapping — expand as models evolve
    return MessageEntity(
      id: model.id as String,
      chatId: model.chatId as String,
      senderId: model.senderId as String,
      kind: MessageKind.text,
      text: model.text as String?,
      createdAt: DateTime.tryParse(model.createdAt as String? ?? '') ?? DateTime.now(),
    );
  }
}
