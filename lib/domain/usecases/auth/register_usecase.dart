import '../../../data/repositories/auth_repository.dart';
import '../../entities/user_entity.dart';

class RegisterUseCase {
  const RegisterUseCase(this._repository);

  final AuthRepository _repository;

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _passwordRegex =
      RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\w\s])[A-Za-z\d\W]{8,}$');

  Future<ApiResult<UserEntity>> call(Map<String, dynamic> data) async {
    final name = (data['name'] ?? data['username'] ?? '') as String;
    final email = (data['email'] ?? '') as String;
    final password = (data['password'] ?? '') as String;
    final confirmPassword = data['confirm_password']?.toString() ??
        data['confirmPassword']?.toString() ??
        '';
    final language = (data['language'] ?? data['language_id'] ?? '') as String;
    final agreeToTerms = data['agreeToTerms'] == true || data['agree_to_terms'] == true;

    if (name.trim().isEmpty) {
      return ApiResult.failure('Name is required');
    }
    if (email.trim().isEmpty) {
      return ApiResult.failure('Email is required');
    }
    if (!_emailRegex.hasMatch(email.trim())) {
      return ApiResult.failure('Please enter a valid email address');
    }
    if (password.isEmpty) {
      return ApiResult.failure('Password is required');
    }
    if (!_passwordRegex.hasMatch(password)) {
      return ApiResult.failure(
        'Password must be at least 8 characters and include uppercase, lowercase, number and special character',
      );
    }
    if (confirmPassword.isNotEmpty && confirmPassword != password) {
      return ApiResult.failure('Password and confirm password must match');
    }
    if (language.isEmpty) {
      return ApiResult.failure('Language is required');
    }
    if (!agreeToTerms) {
      return ApiResult.failure('You must agree to the terms and conditions');
    }

    final payload = Map<String, dynamic>.from(data);
    payload['name'] = name.trim();
    payload['email'] = email.trim().toLowerCase();
    payload['password'] = password;
    if (!payload.containsKey('language')) {
      payload['language'] = language;
    }
    payload.remove('confirm_password');
    payload.remove('confirmPassword');
    payload.remove('agreeToTerms');
    payload.remove('agree_to_terms');
    payload.remove('language_id');

    final result = await _repository.signup(payload);
    if (!result.success || result.data == null) {
      return ApiResult.failure(result.message ?? 'Signup failed.');
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
