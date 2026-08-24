import '../../../data/repositories/chat_repository.dart';

class MarkReadUseCase {
  const MarkReadUseCase(this._repo);
  final ChatRepository _repo;

  Future<void> call(String chatId) => _repo.markRead(chatId);
}
