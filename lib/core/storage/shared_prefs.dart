import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Wrapper around [SharedPreferences] (replaces @react-native-async-storage/async-storage).
class AppSharedPrefs {
  AppSharedPrefs(this._prefs);

  final SharedPreferences _prefs;

  // ── Onboarding ────────────────────────────────────────────────────────────
  bool get isOnboardingDone =>
      _prefs.getBool(AppConstants.keyOnboardingDone) ?? false;

  Future<void> setOnboardingDone(bool value) =>
      _prefs.setBool(AppConstants.keyOnboardingDone, value);

  // ── Generic helpers ───────────────────────────────────────────────────────
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  String? getString(String key) => _prefs.getString(key);

  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  bool? getBool(String key) => _prefs.getBool(key);

  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  int? getInt(String key) => _prefs.getInt(key);

  Future<void> remove(String key) => _prefs.remove(key);

  Future<void> clearAll() => _prefs.clear();
}
