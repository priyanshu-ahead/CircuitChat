import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/chat_model.dart';
import '../../presentation/auth/view/login_screen.dart';
import '../../presentation/auth/view/register_screen.dart';
import '../../presentation/auth/view/forgot_password_screen.dart';
import '../../presentation/auth/view/reset_password_screen.dart';
import '../../presentation/auth/view/verify_email_screen.dart';
import '../../presentation/home/view/home_screen.dart';
import '../../presentation/chat/view/chat_list_screen.dart';
import '../../presentation/chat/view/chat_detail_screen.dart';
import '../../presentation/chat/view/chat_profile_screen.dart';
import '../../presentation/chat/view/chat_media_screen.dart';
import '../../presentation/chat/view/chat_starred_screen.dart';
import '../../presentation/chat/view/new_chat_screen.dart';
import '../../presentation/chat/view/archived_chats_screen.dart';
import '../../presentation/group/view/group_settings_screen.dart';
import '../../presentation/group/view/group_members_screen.dart';
import '../../presentation/group/view/group_pending_screen.dart';
import '../../presentation/group/view/group_invite_screen.dart';
import '../../presentation/group/view/group_qr_screen.dart';
import '../../presentation/settings/view/account_settings_screen.dart';
import '../../presentation/settings/view/privacy_settings_screen.dart';
import '../../presentation/settings/view/notification_settings_screen.dart';
import '../../presentation/settings/view/blocked_users_screen.dart';
import '../../presentation/splash/view/splash_screen.dart';

/// Route name constants — use these instead of raw strings everywhere.
abstract class Routes {
  // ── Auth ──────────────────────────────────────────────────────────────────
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const verifyEmail = '/verify-email';

  // ── Home shell ────────────────────────────────────────────────────────────
  static const home = '/home';

  // ── Chats ─────────────────────────────────────────────────────────────────
  static const chatList = '/chats';
  static const chatDetail = '/chats/:chatId';
  static const chatProfile = '/chats/:chatId/profile';
  static const chatMedia = '/chats/:chatId/media';
  static const chatStarred = '/chats/:chatId/starred';
  static const newChat = '/new-chat';
  static const archivedChats = '/archived';

  // ── Groups ────────────────────────────────────────────────────────────────
  static const groupSettings = '/groups/:groupId/settings';
  static const groupMembers = '/groups/:groupId/members';
  static const groupPending = '/groups/:groupId/pending';
  static const groupInvite = '/groups/:groupId/invite';
  static const groupQR = '/groups/:groupId/qr';

  // ── Settings sub-screens ──────────────────────────────────────────────────
  static const accountSettings = '/settings/account';
  static const privacySettings = '/settings/privacy';
  static const notificationSettings = '/settings/notifications';
  static const blockedUsers = '/settings/blocked';
  static const editProfile = '/settings/edit-profile';
  static const starredMessages = '/settings/starred';
}

/// GoRouter instance. Splash is the initial route so auth session can be
/// restored before deciding where to land.
final appRouter = GoRouter(
  initialLocation: Routes.splash,
  debugLogDiagnostics: true,
  routes: [
    // ── Splash ──────────────────────────────────────────────────────────────
    GoRoute(
      path: Routes.splash,
      builder: (_, __) => const SplashScreen(),
    ),

    // ── Auth ─────────────────────────────────────────────────────────────────
    GoRoute(
      path: Routes.login,
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: Routes.register,
      builder: (_, __) => const RegisterScreen(),
    ),
    GoRoute(
      path: Routes.forgotPassword,
      builder: (_, __) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: Routes.resetPassword,
      builder: (_, state) {
        final token = state.uri.queryParameters['ref'] ??
            state.uri.queryParameters['token'] ??
            '';
        return ResetPasswordScreen(token: token);
      },
    ),
    GoRoute(
      path: Routes.verifyEmail,
      builder: (_, state) {
        final token = state.uri.queryParameters['ref'] ??
            state.uri.queryParameters['token'] ??
            '';
        final email = state.uri.queryParameters['email'];
        return VerifyEmailScreen(token: token, email: email);
      },
    ),

    // ── Home shell ────────────────────────────────────────────────────────────
    GoRoute(
      path: Routes.home,
      builder: (_, __) => const HomeScreen(),
    ),

    // ── New chat ──────────────────────────────────────────────────────────────
    GoRoute(
      path: Routes.newChat,
      builder: (_, __) => const NewChatScreen(),
    ),

    // ── Archived chats ────────────────────────────────────────────────────────
    GoRoute(
      path: Routes.archivedChats,
      builder: (_, __) => const ArchivedChatsScreen(),
    ),

    // ── Chat list + nested chat routes ────────────────────────────────────────
    GoRoute(
      path: Routes.chatList,
      builder: (_, __) => const ChatListScreen(),
    ),

    // /chats/:chatId — detail screen
    GoRoute(
      path: Routes.chatDetail,
      builder: (_, state) {
        final chat = state.extra is ChatModel
            ? state.extra as ChatModel
            : ChatModel(
                id: state.pathParameters['chatId']!,
                type: ChatType.direct,
              );
        return ChatDetailScreen(chat: chat);
      },
    ),

    // /chats/:chatId/profile
    GoRoute(
      path: Routes.chatProfile,
      builder: (_, state) {
        final chat = state.extra is ChatModel
            ? state.extra as ChatModel
            : ChatModel(
                id: state.pathParameters['chatId']!,
                type: ChatType.direct,
              );
        return ChatProfileScreen(chat: chat);
      },
    ),

    // /chats/:chatId/media
    GoRoute(
      path: Routes.chatMedia,
      builder: (_, state) {
        final chat = state.extra is ChatModel
            ? state.extra as ChatModel
            : ChatModel(
                id: state.pathParameters['chatId']!,
                type: ChatType.direct,
              );
        return ChatMediaScreen(chat: chat);
      },
    ),

    // /chats/:chatId/starred
    GoRoute(
      path: Routes.chatStarred,
      builder: (_, state) {
        final chat = state.extra is ChatModel
            ? state.extra as ChatModel
            : ChatModel(
                id: state.pathParameters['chatId']!,
                type: ChatType.direct,
              );
        return ChatStarredScreen(chat: chat);
      },
    ),

    // ── Group screens ─────────────────────────────────────────────────────────

    // /groups/:groupId/settings
    GoRoute(
      path: Routes.groupSettings,
      builder: (_, state) => GroupSettingsScreen(
        groupId: state.pathParameters['groupId']!,
      ),
    ),

    // /groups/:groupId/members
    GoRoute(
      path: Routes.groupMembers,
      builder: (_, state) => GroupMembersScreen(
        groupId: state.pathParameters['groupId']!,
      ),
    ),

    // /groups/:groupId/pending
    GoRoute(
      path: Routes.groupPending,
      builder: (_, state) => GroupPendingScreen(
        groupId: state.pathParameters['groupId']!,
      ),
    ),

    // /groups/:groupId/invite
    GoRoute(
      path: Routes.groupInvite,
      builder: (_, state) => GroupInviteScreen(
        groupId: state.pathParameters['groupId']!,
      ),
    ),

    // /groups/:groupId/qr
    GoRoute(
      path: Routes.groupQR,
      builder: (_, state) => GroupQRScreen(
        groupId: state.pathParameters['groupId']!,
      ),
    ),

    // ── Settings sub-screens ──────────────────────────────────────────────────

    GoRoute(
      path: Routes.accountSettings,
      builder: (_, __) => const AccountSettingsScreen(),
    ),
    GoRoute(
      path: Routes.privacySettings,
      builder: (_, __) => const PrivacySettingsScreen(),
    ),
    GoRoute(
      path: Routes.notificationSettings,
      builder: (_, __) => const NotificationSettingsScreen(),
    ),
    GoRoute(
      path: Routes.blockedUsers,
      builder: (_, __) => const BlockedUsersScreen(),
    ),

    // Starred messages from settings — reuses ChatStarredScreen with a
    // stub "all chats" ChatModel; the screen fetches across all chats when
    // no specific chatId is provided. Route kept separate so it can be
    // reached from both settings and individual chat profile.
    GoRoute(
      path: Routes.starredMessages,
      builder: (_, state) {
        final chat = state.extra is ChatModel
            ? state.extra as ChatModel
            : const ChatModel(id: 'all', type: ChatType.direct);
        return ChatStarredScreen(chat: chat);
      },
    ),

    // Edit profile — re-uses whatever EditProfileScreen exists in auth/settings
    GoRoute(
      path: Routes.editProfile,
      builder: (_, __) => const _EditProfilePlaceholder(),
    ),
  ],
);

/// Thin placeholder until EditProfileScreen is built.
/// Replace this class body once the screen is available.
class _EditProfilePlaceholder extends StatelessWidget {
  const _EditProfilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: const Center(child: Text('Edit Profile — coming soon')),
    );
  }
}


