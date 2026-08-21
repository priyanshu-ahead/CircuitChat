import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../entities/user_entity.dart';

/// Edit the logged-in user's profile. Accepts any fields the SE backend
/// supports on `/user/edit` (display_name, photo, cover, description, etc.),
/// auto-converts file paths to multipart uploads in the data layer.
class EditProfileUseCase {
  const EditProfileUseCase(this._repository);

  final UserRepository _repository;

  Future<ApiResult<UserEntity>> call(Map<String, dynamic> data) async {
    final result = await _repository.editProfile(data);
    if (!result.success || result.data == null) {
      return ApiResult.failure(result.message ?? 'Failed to update profile.');
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
      ),
    );
  }
}
