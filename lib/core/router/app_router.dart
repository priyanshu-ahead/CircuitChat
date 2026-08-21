import 'package:go_router/go_router.dart';

import '../../presentation/auth/view/login_screen.dart';
import '../../presentation/auth/view/register_screen.dart';
import '../../presentation/auth/view/forgot_password_screen.dart';
import '../../presentation/auth/view/reset_password_screen.dart';
import '../../presentation/auth/view/verify_email_screen.dart';
import '../../presentation/home/view/home_screen.dart';
import '../../presentation/chat/view/chat_list_screen.dart';
import '../../presentation/chat/view/chat_detail_screen.dart';
import '../../presentation/splash/view/splash_screen.dart';

/// Route name constants — use these instead of raw strings.
abstract class Routes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const verifyEmail = '/verify-email';
  static const home = '/home';
  static const chatList = '/chats';
  static const chatDetail = '/chats/:chatId';
}

/// GoRouter instance — splash is the initial route so auth session can be restored.
final appRouter = GoRouter(
  initialLocation: Routes.splash,
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: Routes.splash,
      builder: (_, __) => const SplashScreen(),
    ),
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
    GoRoute(
      path: Routes.home,
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: Routes.chatList,
      builder: (_, __) => const ChatListScreen(),
      routes: [
        GoRoute(
          path: ':chatId',
          builder: (_, state) => ChatDetailScreen(
            chatId: state.pathParameters['chatId']!,
          ),
        ),
      ],
    ),
  ],
);
