import '../../../data/repositories/user_repository.dart';
import '../../entities/user_entity.dart';

/// Fetch a user profile by ID, mapped to a domain [UserEntity].
class GetUserProfileUseCase {
  const GetUserProfileUseCase(this._repository);

  final UserRepository _repository;

  Future<UserEntity> call(String userId) async {
    final model = await _repository.getUserById(userId);
    return UserEntity(
      id: model.id,
      username: model.username,
      email: model.email,
      displayName: model.displayName,
      avatar: model.avatar,
      phone: model.phone,
      bio: model.bio,
      isOnline: model.isOnline,
    );
  }
}
