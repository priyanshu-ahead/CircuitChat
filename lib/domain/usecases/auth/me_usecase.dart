import '../../../data/repositories/auth_repository.dart';
import '../../entities/user_entity.dart';

class MeUseCase {
  const MeUseCase(this._repository);

  final AuthRepository _repository;

  Future<ApiResult<UserEntity>> call() async {
    final result = await _repository.me();
    if (!result.success || result.data == null) {
      return ApiResult.failure(result.message ?? 'Not logged in.');
    }
    final m = result.data!;
    return ApiResult.success(
      UserEntity(
        id: m.id,
        username: m.username,
        email: m.email,
        displayName: m.displayName,
        avatar: m.avatar,
        phone: m.phone,
        bio: m.bio,
        isOnline: m.isOnline,
        lastSeen: m.lastSeen != null ? DateTime.tryParse(m.lastSeen!) : null,
      ),
    );
  }
}
