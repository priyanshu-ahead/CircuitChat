import '../../../data/models/chat_model.dart';
import '../../../data/repositories/chat_repository.dart';

class FetchChatsUseCase {
  const FetchChatsUseCase(this._repo);
  final ChatRepository _repo;

  Future<PaginatedResult<ChatModel>> call(FetchChatsParams params) =>
      _repo.fetchChats(params);
}
