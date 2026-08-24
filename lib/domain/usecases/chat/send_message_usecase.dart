import '../../../data/models/message_model.dart';
import '../../../data/repositories/chat_repository.dart';

class SendMessageUseCase {
  const SendMessageUseCase(this._repo);
  final ChatRepository _repo;

  Future<MessageModel> call({
    required String chatId,
    required String chatType,
    required String contentType,
    String? text,
    String? mediaId,
    String? replyToId,
    List<String>? mentions,
  }) =>
      _repo.sendMessage(
        chatId: chatId,
        chatType: chatType,
        contentType: contentType,
        text: text,
        mediaId: mediaId,
        replyToId: replyToId,
        mentions: mentions,
      );
}
