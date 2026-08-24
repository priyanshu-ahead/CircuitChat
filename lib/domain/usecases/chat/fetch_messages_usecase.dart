import '../../../data/models/message_model.dart';
import '../../../data/repositories/chat_repository.dart';

class FetchMessagesUseCase {
  const FetchMessagesUseCase(this._repo);
  final ChatRepository _repo;

  Future<PaginatedResult<MessageModel>> call(FetchMessagesParams params) =>
      _repo.fetchMessages(params);
}
