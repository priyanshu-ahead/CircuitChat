import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/chat_model.dart';
import '../../presentation/auth/view/login_screen.dart';
import '../../presentation/auth/view/register_screen.dart';
import '../../presentation/auth/view/forgot_password_screen.dart';
import '../../presentation/auth/view/reset_password_screen.dart';
import '../../presentation/auth/view/verify_email_screen.dart';
import '../../presentation/calls/view/call_log_screen.dart';
import '../../presentation/calls/view/call_screen.dart';
import '../../presentation/chat/view/archived_chats_screen.dart';
import '../../presentation/chat/view/chat_detail_screen.dart';
import '../../presentation/chat/view/chat_list_screen.dart';
import '../../presentation/chat/view/chat_media_screen.dart';
import '../../presentation/chat/view/chat_profile_screen.dart';
import '../../presentation/chat/view/chat_starred_screen.dart';
import '../../presentation/chat/view/message_info_screen.dart';
import '../../presentation/chat/view/new_chat_screen.dart';
import '../../presentation/group/view/create_group_screen.dart';
import '../../presentation/group/view/group_invite_screen.dart';
import '../../presentation/group/view/group_join_screen.dart';
import '../../presentation/group/view/group_members_screen.dart';
import '../../presentation/group/view/group_pending_screen.dart';
import '../../presentation/group/view/group_qr_screen.dart';
import '../../presentation/group/view/group_settings_screen.dart';
import '../../presentation/home/view/home_screen.dart';
import '../../presentation/settings/view/about_screen.dart';
import '../../presentation/settings/view/account_settings_screen.dart';
import '../../presentation/settings/view/blocked_users_screen.dart';
import '../../presentation/settings/view/edit_profile_screen.dart';
import '../../presentation/settings/view/notification_settings_screen.dart';
import '../../presentation/settings/view/privacy_settings_screen.dart';
import '../../presentation/splash/view/splash_screen.dart';

// ── Route path constants ───────────────────────────────────────────────────────
abstract class Routes {
  // Auth
  static const splash            = '/';
  static const login             = '/login';
  static const register          = '/register';
  static const forgotPassword    = '/forgot-password';
  static const resetPassword     = '/reset-password';
  static const verifyEmail       = '/verify-email';

  // Home shell
  static const home              = '/home';

  // Chats
  static const chatList          = '/chats';
  static const chatDetail        = '/chats/:chatId';
  static const chatProfile       = '/chats/:chatId/profile';
  static const chatMedia         = '/chats/:chatId/media';
  static const chatStarred       = '/chats/:chatId/starred';
  static const newChat           = '/new-chat';
  static const archivedChats     = '/archived';
  static const messageInfo       = '/message/:messageId/info';

  // Groups
  static const groupSettings     = '/groups/:groupId/settings';
  static const groupMembers      = '/groups/:groupId/members';
  static const groupPending      = '/groups/:groupId/pending';
  static const groupInvite       = '/groups/:groupId/invite';
  static const groupQR           = '/groups/:groupId/qr';
  static const createGroup       = '/groups/create';
  static const groupJoin         = '/groups/join/:token';

  // Calls
  static const callLog           = '/calls';
  static const callScreen        = '/calls/:callId';

  // Settings
  static const editProfile       = '/settings/edit-profile';
  static const accountSettings   = '/settings/account';
  static const privacySettings   = '/settings/privacy';
  static const notificationSettings = '/settings/notifications';
  static const blockedUsers      = '/settings/blocked';
  static const starredMessages   = '/settings/starred';
  static const aboutApp          = '/settings/about';
}

// ── Router instance ───────────────────────────────────────────────────────────
//
// Deep-link native config (do this once):
//
// Android — android/app/src/main/AndroidManifest.xml inside <activity>:
//   <intent-filter android:autoVerify="true">
//     <action android:name="android.intent.action.VIEW"/>
//     <category android:name="android.intent.category.DEFAULT"/>
//     <category android:name="android.intent.category.BROWSABLE"/>
//     <data android:scheme="circuitchat" android:host="open"/>
//     <data android:scheme="https" android:host="chat.aheadsofttech.com"/>
//   </intent-filter>
//
// iOS — ios/Runner/Info.plist:
//   CFBundleURLTypes → add scheme "circuitchat"
//   com.apple.developer.associated-domains → applinks:chat.aheadsofttech.com
//
// GoRouter automatically matches incoming URLs against the declared routes.
// The redirect below maps the legacy universal-link path /group-join/:token
// to the internal /groups/join/:token route.
final appRouter = GoRouter(
  initialLocation: Routes.splash,
  debugLogDiagnostics: true,

  redirect: (context, state) {
    final path = state.uri.path;
    // Map https://domain/group-join/<token> → /groups/join/<token>
    final match = RegExp(r'^/group-join/(.+)$').firstMatch(path);
    if (match != null) {
      return Routes.groupJoin.replaceFirst(':token', match.group(1)!);
    }
    return null;
  },

  routes: [
    // ── Splash ──────────────────────────────────────────────────────────────
    GoRoute(
      path: Routes.splash,
      builder: (_, __) => const SplashScreen(),
    ),

    // ── Auth ─────────────────────────────────────────────────────────────────
    GoRoute(path: Routes.login,    builder: (_, __) => const LoginScreen()),
    GoRoute(path: Routes.register, builder: (_, __) => const RegisterScreen()),
    GoRoute(path: Routes.forgotPassword, builder: (_, __) => const ForgotPasswordScreen()),
    GoRoute(
      path: Routes.resetPassword,
      builder: (_, state) {
        final token = state.uri.queryParameters['ref'] ??
            state.uri.queryParameters['token'] ?? '';
        return ResetPasswordScreen(token: token);
      },
    ),
    GoRoute(
      path: Routes.verifyEmail,
      builder: (_, state) {
        final token = state.uri.queryParameters['ref'] ??
            state.uri.queryParameters['token'] ?? '';
        final email = state.uri.queryParameters['email'];
        return VerifyEmailScreen(token: token, email: email);
      },
    ),

    // ── Home shell ────────────────────────────────────────────────────────────
    GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),

    // ── Chats ─────────────────────────────────────────────────────────────────
    GoRoute(path: Routes.chatList,      builder: (_, __) => const ChatListScreen()),
    GoRoute(path: Routes.newChat,       builder: (_, __) => const NewChatScreen()),
    GoRoute(path: Routes.archivedChats, builder: (_, __) => const ArchivedChatsScreen()),

    GoRoute(
      path: Routes.chatDetail,
      builder: (_, state) {
        final chat = state.extra is ChatModel
            ? state.extra as ChatModel
            : ChatModel(id: state.pathParameters['chatId']!, type: ChatType.direct);
        return ChatDetailScreen(chat: chat);
      },
    ),
    GoRoute(
      path: Routes.chatProfile,
      builder: (_, state) {
        final chat = state.extra is ChatModel
            ? state.extra as ChatModel
            : ChatModel(id: state.pathParameters['chatId']!, type: ChatType.direct);
        return ChatProfileScreen(chat: chat);
      },
    ),
    GoRoute(
      path: Routes.chatMedia,
      builder: (_, state) {
        final chat = state.extra is ChatModel
            ? state.extra as ChatModel
            : ChatModel(id: state.pathParameters['chatId']!, type: ChatType.direct);
        return ChatMediaScreen(chat: chat);
      },
    ),
    GoRoute(
      path: Routes.chatStarred,
      builder: (_, state) {
        final chat = state.extra is ChatModel
            ? state.extra as ChatModel
            : ChatModel(id: state.pathParameters['chatId']!, type: ChatType.direct);
        return ChatStarredScreen(chat: chat);
      },
    ),
    GoRoute(
      path: Routes.messageInfo,
      builder: (_, state) => MessageInfoScreen(
        messageId: state.pathParameters['messageId']!,
      ),
    ),

    // ── Groups ─────────────────────────────────────────────────────────────────
    GoRoute(path: Routes.createGroup, builder: (_, __) => const CreateGroupScreen()),
    GoRoute(
      path: Routes.groupJoin,
      builder: (_, state) => GroupJoinScreen(
        token: state.pathParameters['token']!,
      ),
    ),
    GoRoute(
      path: Routes.groupSettings,
      builder: (_, state) => GroupSettingsScreen(groupId: state.pathParameters['groupId']!),
    ),
    GoRoute(
      path: Routes.groupMembers,
      builder: (_, state) => GroupMembersScreen(groupId: state.pathParameters['groupId']!),
    ),
    GoRoute(
      path: Routes.groupPending,
      builder: (_, state) => GroupPendingScreen(groupId: state.pathParameters['groupId']!),
    ),
    GoRoute(
      path: Routes.groupInvite,
      builder: (_, state) => GroupInviteScreen(groupId: state.pathParameters['groupId']!),
    ),
    GoRoute(
      path: Routes.groupQR,
      builder: (_, state) => GroupQRScreen(groupId: state.pathParameters['groupId']!),
    ),

    // ── Calls ──────────────────────────────────────────────────────────────────
    GoRoute(path: Routes.callLog, builder: (_, __) => const CallLogScreen()),
    GoRoute(
      path: Routes.callScreen,
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return CallScreen(
          callId:   state.pathParameters['callId']!,
          callType: extra['callType'] as String? ?? 'audio',
          chatName: extra['chatName'] as String? ?? '',
          isIncoming: extra['isIncoming'] as bool? ?? false,
        );
      },
    ),

    // ── Settings ───────────────────────────────────────────────────────────────
    GoRoute(path: Routes.editProfile,          builder: (_, __) => const EditProfileScreen()),
    GoRoute(path: Routes.accountSettings,      builder: (_, __) => const AccountSettingsScreen()),
    GoRoute(path: Routes.privacySettings,      builder: (_, __) => const PrivacySettingsScreen()),
    GoRoute(path: Routes.notificationSettings, builder: (_, __) => const NotificationSettingsScreen()),
    GoRoute(path: Routes.blockedUsers,         builder: (_, __) => const BlockedUsersScreen()),
    GoRoute(path: Routes.aboutApp,             builder: (_, __) => const AboutScreen()),
    GoRoute(
      path: Routes.starredMessages,
      builder: (_, state) {
        final chat = state.extra is ChatModel
            ? state.extra as ChatModel
            : const ChatModel(id: 'all', type: ChatType.direct);
        return ChatStarredScreen(chat: chat);
      },
    ),
  ],
);
