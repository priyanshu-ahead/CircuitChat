import 'dart:convert';

import '../../../core/storage/secure_storage.dart';
import '../../../core/storage/shared_prefs.dart';
import '../../models/user_model.dart';

/// Local cache for auth state — stores/retrieves user from SharedPrefs.
class AuthLocalDataSource {
  const AuthLocalDataSource(this._prefs, this._secure);

  final AppSharedPrefs _prefs;
  final SecureStorage _secure;

  static const _keyUser = 'cached_user';

  Future<void> cacheUser(UserModel user) =>
      _prefs.setString(_keyUser, userModelToJsonString(user));

  UserModel? getCachedUser() {
    final json = _prefs.getString(_keyUser);
    if (json == null) return null;
    return userModelFromJsonString(json);
  }

  Future<void> clearCache() async {
    await _prefs.remove(_keyUser);
    await _secure.clearAll();
  }

  static String userModelToJsonString(UserModel user) {
    return jsonEncode(user.toJson());
  }

  static UserModel? userModelFromJsonString(String json) {
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return UserModel.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
