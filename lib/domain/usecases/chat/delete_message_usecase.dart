import '../../../data/repositories/chat_repository.dart';

class DeleteMessageUseCase {
  const DeleteMessageUseCase(this._repo);
  final ChatRepository _repo;

  Future<void> call(List<String> messageIds,
      {bool forEveryone = false, String? chatId}) {
    if (forEveryone && chatId != null) {
      return _repo.deleteMessageForEveryone(messageIds, chatId: chatId);
    }
    return _repo.deleteMessage(messageIds);
  }
}
