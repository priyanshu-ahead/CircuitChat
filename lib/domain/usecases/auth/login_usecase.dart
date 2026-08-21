import '../../../data/repositories/auth_repository.dart';
import '../../entities/user_entity.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  Future<ApiResult<UserEntity>> call({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      return ApiResult.failure('Email is required');
    }
    if (!_emailRegex.hasMatch(trimmedEmail)) {
      return ApiResult.failure('Please enter a valid email address');
    }
    if (password.isEmpty) {
      return ApiResult.failure('Password is required');
    }

    final result = await _repository.login({
      'email': trimmedEmail.toLowerCase(),
      'password': password,
    });

    if (!result.success || result.data == null) {
      return ApiResult.failure(result.message ?? 'Login failed. Please try again.');
    }
    final model = result.data!;
    return ApiResult.success(
      UserEntity(
        id: model.id,
        username: model.username,
        email: model.email,
        displayName: model.displayName,
        avatar: model.avatar,
        phone: model.phone,
        bio: model.bio,
        isOnline: model.isOnline,
        lastSeen: model.lastSeen != null
            ? DateTime.tryParse(model.lastSeen!)
            : null,
      ),
    );
  }
}
