import '../models/user_model.dart';

/// Result wrapper used across all SE backend calls.
/// Matches the `{success: bool, data/message?}` shape returned from the RN API
/// functions so the presentation layer can reason about outcomes uniformly.
class ApiResult<T> {
  const ApiResult({
    required this.success,
    this.data,
    this.message,
  });

  factory ApiResult.success([T? data]) =>
      ApiResult(success: true, data: data);

  factory ApiResult.failure(String message) =>
      ApiResult(success: false, message: message);

  final bool success;
  final T? data;
  final String? message;

  bool get hasData => data != null;
}

/// Abstract interface for auth data operations.
/// Implementations: [AuthRemoteDataSource], [AuthLocalDataSource].
abstract interface class AuthRepository {
  // ── Core auth ──────────────────────────────────────────────────────────────

  /// Login with email + password.
  /// Returns the authenticated [UserModel] wrapped in an [ApiResult] carrying
  /// any server-side error `message` on failure.
  Future<ApiResult<UserModel>> login(Map<String, dynamic> data);

  /// Register a new account.
  Future<ApiResult<UserModel>> signup(Map<String, dynamic> data);

  /// Login directly via a SocialEngine `uid` (silent SSO / deep-link flow).
  Future<ApiResult<UserModel>> loginWithUid(String uid);

  /// Fetch the currently-authenticated user's profile (`/user/me`).
  Future<ApiResult<UserModel>> me();

  /// Logout — invalidate token on server + clear local storage.
  Future<void> logout();

  /// Refresh auth token, returns true on success.
  Future<bool> refreshToken();

  // ── Password flow ──────────────────────────────────────────────────────────

  /// Request a password-reset OTP / email.
  Future<ApiResult<void>> forgetPassword(Map<String, dynamic> data);

  /// Verify OTP and reset password.
  Future<ApiResult<void>> resetPassword(Map<String, dynamic> data);

  /// Change the logged-in user's password (requires old password).
  Future<ApiResult<void>> changePassword(Map<String, dynamic> data);

  // ── Email verification ─────────────────────────────────────────────────────

  /// Verify the user's email address with a token / code.
  Future<ApiResult<void>> verifyEmail(Map<String, dynamic> data);

  // ── Push notifications ─────────────────────────────────────────────────────

  /// Register an FCM / APNs push token for the current user.
  Future<ApiResult<void>> addPushNotificationToken(Map<String, dynamic> data);

  /// Remove a previously-registered push token (on logout, device change…).
  Future<ApiResult<void>> removePushNotificationToken(Map<String, dynamic> data);
}
