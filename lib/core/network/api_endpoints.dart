// All REST endpoint paths — centralised here so route changes are one-liner fixes.
// Mirrors the SocialEngine backend routes used in the React Native codebase.
class ApiEndpoints {
  ApiEndpoints._();

  // ── Auth / User core ──────────────────────────────────────────────────────
  static const String logout = '/auth/logout';
  static const String report = '/user/report';
  static const String translation = '/user/translation';
  static const String permissions = '/user/permissions';
  static const String about = '/user/about';
  static const String generalSettings = '/user/general-settings';
  static String generalSettingsByKey(String key) =>
      '/user/general-settings?key=$key';
  static const String loginUid = '/user/login-uid';
  static const String login = '/user/login';
  static const String me = '/user/me';
  static const String register = '/user/register';
  static const String pushNotification = '/user/push-notification';
  static const String changePassword = '/user/change-password';
  static const String forgetPassword = '/user/forget-password';
  static const String resetPassword = '/user/reset-password';
  static const String verifyEmail = '/user/verify-email';
  static const String editProfile = '/user/edit';
  static const String deleteAccount = '/user/';
  static const String languages = '/user/languages';
  static const String changeLanguage = '/user/change-language';
  static String page(String page) => '/user/page/$page';

  // ── Refresh token (kept separate, used inside ApiClient interceptor) ──────
  static const String refreshToken = '/auth/refresh';

  // ── Chats ─────────────────────────────────────────────────────────────────
  static const String chats = '/chats';
  static String chatById(String id) => '/chats/$id';
  static String chatMessages(String chatId) => '/chats/$chatId/messages';
  static String sendMessage(String chatId) => '/chats/$chatId/messages';

  // ── Contacts ──────────────────────────────────────────────────────────────
  static const String contacts = '/contacts';
  static const String syncContacts = '/contacts/sync';

  // ── Groups ────────────────────────────────────────────────────────────────
  static const String groups = '/groups';
  static String groupById(String id) => '/groups/$id';
  static String groupMembers(String id) => '/groups/$id/members';

  // ── Calls ─────────────────────────────────────────────────────────────────
  static const String callToken = '/calls/token';
  static String endCall(String callId) => '/calls/$callId/end';

  // ── Media ─────────────────────────────────────────────────────────────────
  static const String uploadMedia = '/media/upload';

  // ── Notifications ─────────────────────────────────────────────────────────
  static const String registerPushToken = '/notifications/token';
}
