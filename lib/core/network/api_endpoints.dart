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
  static String page(String p) => '/user/page/$p';

  // ── Refresh token ──────────────────────────────────────────────────────────
  static const String refreshToken = '/auth/refresh';

  // ── Chats (matches RN services/chat.js) ───────────────────────────────────
  /// GET /chat  — fetchChats list
  static const String chats = '/chat';

  /// GET /chat/:id — single chat
  static String chatById(String id) => '/chat/$id';

  /// POST /chat/pin  /  POST /chat/unpin
  static const String chatPin = '/chat/pin';
  static const String chatUnpin = '/chat/unpin';

  /// POST /chat/archive  /  POST /chat/unarchive
  static const String chatArchive = '/chat/archive';
  static const String chatUnarchive = '/chat/unarchive';

  /// POST /chat/mark-read  /  POST /chat/mark-unread
  static const String chatMarkRead = '/chat/mark-read';
  static const String chatMarkUnread = '/chat/mark-unread';

  /// POST /chat/mute  /  POST /chat/unmute
  static const String chatMute = '/chat/mute';
  static const String chatUnmute = '/chat/unmute';

  /// POST /chat/delete
  static const String chatDelete = '/chat/delete';

  /// GET /chat/search?search=…&limit=5
  static const String chatSearch = '/chat/search';

  /// GET /chat/archive/count
  static const String chatArchiveCount = '/chat/archive/count';

  /// GET /chat/unread
  static const String chatUnread = '/chat/unread';

  /// GET /chat/new-chat?search=…
  static const String chatNewChat = '/chat/new-chat';

  /// GET /chat/reactions
  static const String chatReactions = '/chat/reactions';

  /// GET /chat/:chatId/pin/message
  static String chatPinMessage(String chatId) => '/chat/$chatId/pin/message';

  // ── Messages (matches RN services/message.js) ─────────────────────────────
  /// POST /message/:chatId/:chatType  — fetchMessages (body = {password?})
  static String messages(String chatId, String chatType) =>
      '/message/$chatId/$chatType';

  /// POST /message  — send a new message
  static const String sendMessage = '/message';

  /// POST /message/media  — upload media attachment
  static const String messageMediaUpload = '/message/media';

  /// DELETE /message/media/:id
  static String messageMediaDelete(String id) => '/message/media/$id';

  /// POST /message/draft
  static const String messageDraft = '/message/draft';

  /// POST /message/edit
  static const String messageEdit = '/message/edit';

  /// POST /message/delete
  static const String messageDelete = '/message/delete';

  /// POST /message/delete-everyone
  static const String messageDeleteEveryone = '/message/delete-everyone';

  /// POST /message/reaction  /  POST /message/remove-reaction
  static const String messageReaction = '/message/reaction';
  static const String messageRemoveReaction = '/message/remove-reaction';

  /// POST /message/starred  /  POST /message/unstarred
  static const String messageStarred = '/message/starred';
  static const String messageUnstarred = '/message/unstarred';

  /// GET /message/starred/:chatId/:chatType
  static String messageStarredList(String chatId, String chatType) =>
      '/message/starred/$chatId/$chatType';

  /// POST /message/forward
  static const String messageForward = '/message/forward';

  /// POST /message/pin  /  DELETE /message/pin/:id
  static const String messagePin = '/message/pin';
  static String messageUnpin(String id) => '/message/pin/$id';

  /// GET /message/info/:id
  static String messageInfo(String id) => '/message/info/$id';

  /// GET /message/media/:chatId/:chatType/:mediaType
  static String messageMediaList(
          String chatId, String chatType, String mediaType) =>
      '/message/media/$chatId/$chatType/$mediaType';

  // ── Contacts ──────────────────────────────────────────────────────────────
  static const String contacts = '/contacts';
  static const String syncContacts = '/contacts/sync';

  // ── Groups ────────────────────────────────────────────────────────────────
  /// GET /group/:id
  static String groupById(String id) => '/group/$id';

  /// POST /group/create  (multipart/form-data)
  static const String groupCreate = '/group/create';

  /// POST /group/edit  (multipart/form-data)
  static const String groupEdit = '/group/edit';

  /// PUT /group/setting
  static const String groupSetting = '/group/setting';

  /// POST /group/leave
  static const String groupLeave = '/group/leave';

  /// POST /group/add-user
  static const String groupAddUser = '/group/add-user';

  /// POST /group/remove
  static const String groupRemoveMember = '/group/remove';

  /// POST /group/change-member-role
  static const String groupChangeMemberRole = '/group/change-member-role';

  /// GET /group/members/:id  (paginated)
  static String groupMembers(String id) => '/group/members/$id';

  /// GET /group/pending/:id
  static String groupPending(String id) => '/group/pending/$id';

  /// POST /group/pending  (approve/reject)
  static const String groupPendingStatus = '/group/pending';

  /// GET /group/link/:id
  static String groupLink(String id) => '/group/link/$id';

  /// GET /group/reset-link/:id
  static String groupResetLink(String id) => '/group/reset-link/$id';

  /// GET /group/join/:id
  static String groupJoin(String id) => '/group/join/$id';

  /// POST /group/join-req
  static const String groupJoinRequest = '/group/join-req';

  /// POST /group/join-req-cancel
  static const String groupJoinRequestCancel = '/group/join-req-cancel';

  /// GET /group/qr/:id
  static String groupQR(String id) => '/group/qr/$id';

  /// POST /group/validate-password
  static const String groupValidatePassword = '/group/validate-password';

  /// POST /group/forgot-password
  static const String groupForgotPassword = '/group/forgot-password';

  /// POST /group/resend-otp
  static const String groupResendOtp = '/group/resend-otp';

  /// POST /group/verify-otp
  static const String groupVerifyOtp = '/group/verify-otp';

  /// POST /group/change-password
  static const String groupChangePassword = '/group/change-password';

  /// GET /group/create?search=  (search users to create a group)
  static const String groupCreateSearch = '/group/create';

  /// GET /group/add-user/:id?search=  (search users to add to group)
  static String groupAddUserSearch(String id) => '/group/add-user/$id';

  // ── Calls ─────────────────────────────────────────────────────────────────
  /// POST /call  — initiate a call
  static const String callInitiate = '/call';

  /// GET /call  — paginated call log
  static const String callLog = '/call';

  /// GET /call/:id  — call detail
  static String callById(String id) => '/call/$id';

  /// GET /call/channel/:id  — Agora channel info
  static String callChannel(String id) => '/call/channel/$id';

  /// POST /call/reject/:id
  static String callReject(String id) => '/call/reject/$id';

  /// POST /call/accept/:id
  static String callAccept(String id) => '/call/accept/$id';

  // ── Friend / Contacts ─────────────────────────────────────────────────────
  /// GET /friend/active  — online friends
  static const String friendActive = '/friend/active';

  /// POST /friend/block
  static const String friendBlock = '/friend/block';

  /// POST /friend/unblock
  static const String friendUnblock = '/friend/unblock';

  /// POST /friend/accept
  static const String friendAccept = '/friend/accept';

  /// POST /friend/reject
  static const String friendReject = '/friend/reject';

  /// GET /friend/block  — list blocked users
  static const String friendBlockedList = '/friend/block';

  // ── Media ─────────────────────────────────────────────────────────────────
  static const String uploadMedia = '/media/upload';

  // ── Notifications ─────────────────────────────────────────────────────────
  static const String registerPushToken = '/notifications/token';
}
