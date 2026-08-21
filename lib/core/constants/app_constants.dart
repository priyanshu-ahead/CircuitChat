// App-wide constants: base URLs, timeouts, keys, etc.
class AppConstants {
  AppConstants._();

  // ── API ───────────────────────────────────────────────────────────────────
  static const int connectTimeoutMs = 30000;
  static const int receiveTimeoutMs = 30000;

  // ── Socket ────────────────────────────────────────────────────────────────
  static const String socketUrl = 'https://socket.yourcircuitchat.com';

  // ── Pagination ────────────────────────────────────────────────────────────
  static const int defaultPageSize = 20;

  // ── Storage Keys ──────────────────────────────────────────────────────────
  static const String keyAuthToken = 'auth_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId = 'user_id';
  static const String keyOnboardingDone = 'onboarding_done';

  // ── Agora ─────────────────────────────────────────────────────────────────
  static const String agoraAppId = 'YOUR_AGORA_APP_ID';

  // ── Firebase ─────────────────────────────────────────────────────────────
  static const String fcmTopicGlobal = 'circuit_chat_global';


  // ── API ──────────────────────────────────────────────────────────────────
  static const String baseUrl = 'https://chatadmin.aheadsofttech.com';
  static const String clientId = '6765426309e27220072435da';
  static const String clientSecret =
      '1d91e8fe-604b-49c6-8bc5-16a23c2f8220';

  static const String seServerUrl = 'https://chat.aheadsofttech.com/';

  // Alternate / local dev config — swap in when testing against ngrok.
  // static const String baseUrl = 'https://ded9-10jkdjfkdjjfkdjk.ngrok-free.app';
  // static const String clientId = '66ea7fjdkjfkdjkfjkdjkf23861202';
  // static const String clientSecret = '653f1slklfkldkflkdlkflklskl932e-e1030c5dcb1c';

  static const String apiUrl = '$baseUrl/api';

  // ── Run mode ─────────────────────────────────────────────────────────────
  static const String runModeIntegrated = 'INTEGRATED';
  static const String runModeScript = 'SCRIPT';
  static const String runModeIndependent = 'INDEPENDENT';

  static const String runMode = runModeIndependent;

  // ── Keychain configuration ───────────────────────────────────────────────
  static const String keychainService = 'circuitchat';
  static const String keychainAccessGroup =
      '8UQ6BJBNZU.circuitchat.com.sharedkeychain';

  // ── Pagination / limits ──────────────────────────────────────────────────
  static const int limit = 25; // should not be less than 10

  static const int truncateLength = 250;

  // ── Default assets ───────────────────────────────────────────────────────
  static const String defaultPeopleImg =
      '$baseUrl/assets/defaultPeopleAvatar.png';
  static const String defaultGroupImg =
      '$baseUrl/assets/defaultGroupAvatar.png';

  // ── File upload ──────────────────────────────────────────────────────────
  static const int maxFileSize = 50 * 1024 * 1024;
}

/// Enum form of run modes, if you'd rather use type-safe values
/// instead of the raw string constants above.
enum RunMode {
  integrated,
  script,
  independent;

  String get value {
    switch (this) {
      case RunMode.integrated:
        return AppConstants.runModeIntegrated;
      case RunMode.script:
        return AppConstants.runModeScript;
      case RunMode.independent:
        return AppConstants.runModeIndependent;
    }
  }
}