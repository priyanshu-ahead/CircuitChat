import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Wrapper around [FlutterSecureStorage] (replaces react-native-keychain).
class SecureStorage {
  const SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  // ── Auth Token ────────────────────────────────────────────────────────────
  Future<void> saveAuthToken(String token) =>
      _storage.write(key: AppConstants.keyAuthToken, value: token);

  Future<String?> getAuthToken() =>
      _storage.read(key: AppConstants.keyAuthToken);

  Future<void> deleteAuthToken() =>
      _storage.delete(key: AppConstants.keyAuthToken);

  // ── Refresh Token ─────────────────────────────────────────────────────────
  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: AppConstants.keyRefreshToken, value: token);

  Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.keyRefreshToken);

  Future<void> deleteRefreshToken() =>
      _storage.delete(key: AppConstants.keyRefreshToken);

  // ── User ID ───────────────────────────────────────────────────────────────
  Future<void> saveUserId(String id) =>
      _storage.write(key: AppConstants.keyUserId, value: id);

  Future<String?> getUserId() =>
      _storage.read(key: AppConstants.keyUserId);

  // ── Clear All ─────────────────────────────────────────────────────────────
  Future<void> clearAll() => _storage.deleteAll();
}
