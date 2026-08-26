import 'dart:developer' as dev;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/di/providers.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/storage/shared_prefs.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'presentation/common/widgets/connectivity_banner.dart';

// ── FCM background handler (top-level, required by Firebase) ─────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  dev.log('FCM background: ${message.messageId}', name: 'FCM');
}

// ── App entry point ───────────────────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase ──────────────────────────────────────────────────────────────
  // Requires google-services.json (Android) / GoogleService-Info.plist (iOS).
  // The try/catch lets the app run in dev without those files present.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await NotificationService.instance.initialise();
    dev.log('Firebase initialised', name: 'main');
  } catch (e) {
    dev.log('Firebase init skipped (no config): $e', name: 'main');
  }

  // ── SharedPreferences ─────────────────────────────────────────────────────
  final prefs    = await SharedPreferences.getInstance();
  final appPrefs = AppSharedPrefs(prefs);

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(appPrefs)],
      child: const CircuitChatApp(),
    ),
  );
}

// ── Root widget ───────────────────────────────────────────────────────────────
class CircuitChatApp extends ConsumerWidget {
  const CircuitChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the persisted theme mode — rebuilds app when toggled
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'CircuitChat',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme:     AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,
      builder: (context, child) {
        return ConnectivityBanner(
          child: _NavKeyCapture(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

/// Single-frame widget that registers the navigator context with
/// [NotificationService] so deep-link navigation works from notification taps.
class _NavKeyCapture extends StatefulWidget {
  const _NavKeyCapture({required this.child});
  final Widget child;

  @override
  State<_NavKeyCapture> createState() => _NavKeyCaptureState();
}

class _NavKeyCaptureState extends State<_NavKeyCapture> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store context reference used by NotificationService._navigate()
    navigatorKey.currentState; // access to ensure it's initialised
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
