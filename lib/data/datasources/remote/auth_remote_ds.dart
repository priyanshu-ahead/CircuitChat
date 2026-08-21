import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/network_exceptions.dart';
import '../../../core/storage/secure_storage.dart';
import '../../models/user_model.dart';
import '../../repositories/auth_repository.dart';

/// Remote data source — calls the SocialEngine REST API for auth operations.
///
/// Every public method mirrors the React-Native functions in `auth.js`:
///   try { await axios.…; return {success: true, data: …}; }
///   catch (e) { return {success: false, message: e.response?.data?.message}; }
///
/// The [ApiClient] already maps [DioException] → [NetworkException]; this
/// class catches those and wraps them into the typed [ApiResult] envelope so
/// the presentation layer only ever deals with `result.success` / `.message`.
class AuthRemoteDataSource implements AuthRepository {
  const AuthRemoteDataSource(this._api, this._storage);

  final ApiClient _api;
  final SecureStorage _storage;

  // ── Helper: extract server message from any exception ────────────────────

  static String? _messageFromError(Object e) {
    if (e is NetworkException) return e.message;
    return e.toString().replaceFirst('Exception: ', '');
  }

  /// Pull the access+refresh tokens out of a login-style API response and
  /// persist them to secure storage. Returns the nested user object map.
  Map<String, dynamic> _extractUserAndSaveTokens(Map<String, dynamic> data) {
    final token = data['access_token'] as String? ?? data['token'] as String?;
    if (token != null) _storage.saveAuthToken(token);

    final refresh = data['refresh_token'] as String?;
    if (refresh != null) _storage.saveRefreshToken(refresh);

    final userMap = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : null;
    final userId = data['user_id']?.toString() ??
        data['userId']?.toString() ??
        (userMap != null
            ? (userMap['_id']?.toString() ??
                userMap['id']?.toString() ??
                userMap['user_id']?.toString())
            : null) ??
        data['_id']?.toString();
    if (userId != null && userId.isNotEmpty) _storage.saveUserId(userId);

    if (userMap != null) {
      return userMap;
    }
    // Some SE endpoints return the user flat at the root level alongside the
    // token. Fall back to returning the whole body so UserModel.fromJson can
    // still extract its id/username/email fields.
    return data;
  }

  // ── Core auth ─────────────────────────────────────────────────────────────

  @override
  Future<ApiResult<UserModel>> login(Map<String, dynamic> data) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.login,
        data: data,
      );
      final userJson = _extractUserAndSaveTokens(response);
      return ApiResult.success(UserModel.fromJson(userJson));
    } catch (e) {
      return ApiResult.failure(_messageFromError(e) ?? 'Login failed.');
    }
  }

  @override
  Future<ApiResult<UserModel>> signup(Map<String, dynamic> data) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.register,
        data: data,
      );
      final userJson = _extractUserAndSaveTokens(response);
      return ApiResult.success(UserModel.fromJson(userJson));
    } catch (e) {
      return ApiResult.failure(_messageFromError(e) ?? 'Signup failed.');
    }
  }

  @override
  Future<ApiResult<UserModel>> loginWithUid(String uid) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.loginUid,
        data: {'uid': uid},
      );
      final userJson = _extractUserAndSaveTokens(response);
      return ApiResult.success(UserModel.fromJson(userJson));
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Login with UID failed.',
      );
    }
  }

  @override
  Future<ApiResult<UserModel>> me() async {
    try {
      final response = await _api.get<Map<String, dynamic>>(ApiEndpoints.me);
      // SE `/user/me` typically returns the user object directly.
      final userJson =
          response['user'] is Map<String, dynamic>
              ? response['user'] as Map<String, dynamic>
              : response;
      return ApiResult.success(UserModel.fromJson(userJson));
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Failed to load profile.',
      );
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _api.post<void>(ApiEndpoints.logout);
    } catch (_) {
      // Swallow server-side logout failures — still clear local tokens below
      // so the user is not stuck.
    }
    await _storage.clearAll();
  }

  @override
  Future<bool> refreshToken() async {
    final token = await _storage.getRefreshToken();
    if (token == null) return false;
    try {
      final data = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.refreshToken,
        data: {'refresh_token': token},
      );
      final newToken = data['access_token'] as String?;
      if (newToken != null) {
        await _storage.saveAuthToken(newToken);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Password flow ─────────────────────────────────────────────────────────

  @override
  Future<ApiResult<void>> forgetPassword(Map<String, dynamic> data) async {
    try {
      await _api.post<void>(ApiEndpoints.forgetPassword, data: data);
      return ApiResult.success();
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Failed to send reset link.',
      );
    }
  }

  @override
  Future<ApiResult<void>> resetPassword(Map<String, dynamic> data) async {
    try {
      await _api.post<void>(ApiEndpoints.resetPassword, data: data);
      return ApiResult.success();
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Failed to reset password.',
      );
    }
  }

  @override
  Future<ApiResult<void>> changePassword(Map<String, dynamic> data) async {
    try {
      await _api.put<void>(ApiEndpoints.changePassword, data: data);
      return ApiResult.success();
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Failed to change password.',
      );
    }
  }

  // ── Email verification ────────────────────────────────────────────────────

  @override
  Future<ApiResult<void>> verifyEmail(Map<String, dynamic> data) async {
    try {
      await _api.post<void>(ApiEndpoints.verifyEmail, data: data);
      return ApiResult.success();
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Failed to verify email.',
      );
    }
  }

  // ── Push notification tokens ──────────────────────────────────────────────

  @override
  Future<ApiResult<void>> addPushNotificationToken(
    Map<String, dynamic> data,
  ) async {
    try {
      await _api.post<void>(ApiEndpoints.pushNotification, data: data);
      return ApiResult.success();
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Failed to register push token.',
      );
    }
  }

  @override
  Future<ApiResult<void>> removePushNotificationToken(
    Map<String, dynamic> data,
  ) async {
    try {
      await _api.delete<void>(ApiEndpoints.pushNotification, data: data);
      return ApiResult.success();
    } catch (e) {
      return ApiResult.failure(
        _messageFromError(e) ?? 'Failed to remove push token.',
      );
    }
  }
}
