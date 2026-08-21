import 'auth_repository.dart';
import '../models/user_model.dart';

/// Abstract interface for user-profile & miscellaneous user operations.
abstract interface class UserRepository {
  // ── Profile ────────────────────────────────────────────────────────────────

  /// Fetch a user by [userId].
  Future<UserModel> getUserById(String userId);

  /// Edit the current user's profile.
  /// Supports `multipart/form-data` for file uploads (photo / cover).
  Future<ApiResult<UserModel>> editProfile(Map<String, dynamic> data);

  /// Permanently delete the current user's account.
  Future<ApiResult<void>> deleteAccount(Map<String, dynamic> data);

  /// Update the current user's profile fields (lightweight JSON patch variant).
  Future<UserModel> updateProfile({
    String? displayName,
    String? bio,
    String? phone,
  });

  /// Upload a new avatar image from [localPath], returns the remote URL.
  Future<String> uploadAvatar(String localPath);

  // ── About (user bio / intro section) ───────────────────────────────────────

  /// Fetch the user's "About" information.
  Future<ApiResult<Map<String, dynamic>>> about();

  /// Update / create the user's "About" information.
  Future<ApiResult<Map<String, dynamic>>> updateAbout(Map<String, dynamic> data);

  /// Delete a specific field from the user's "About" section.
  Future<ApiResult<Map<String, dynamic>>> deleteAbout(Map<String, dynamic> data);

  // ── Misc ───────────────────────────────────────────────────────────────────

  /// Submit a report (user / content / message…) to moderators.
  Future<ApiResult<void>> report(Map<String, dynamic> data);

  /// Fetch the current user's permission flags from the backend.
  Future<ApiResult<Map<String, dynamic>>> getPermission();

  /// Fetch a single general-setting value by its [key].
  Future<ApiResult<Map<String, dynamic>>> getGeneralSetting(String key);

  /// Fetch the server-side translation / phrase map.
  Future<ApiResult<Map<String, dynamic>>> getTranslations();

  /// Fetch the list of available languages on the site.
  Future<ApiResult<List<dynamic>>> getLanguages();

  /// Switch the currently-logged in user's language.
  Future<ApiResult<void>> changeLanguage(Map<String, dynamic> data);

  /// Fetch the contents of a CMS / static page (privacy, terms, about-us…).
  Future<ApiResult<Map<String, dynamic>>> pageInformation(String page);

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Search users by username or phone.
  Future<List<UserModel>> searchUsers(String query);

  /// Block a user.
  Future<void> blockUser(String userId);

  /// Unblock a user.
  Future<void> unblockUser(String userId);
}
