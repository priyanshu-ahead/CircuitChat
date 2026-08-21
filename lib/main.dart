import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_router.dart';
import 'core/di/providers.dart';
import 'core/storage/shared_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase (uncomment once google-services.json / GoogleService-Info.plist added)
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ── SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final appPrefs = AppSharedPrefs(prefs);

  runApp(
    ProviderScope(
      overrides: [
        // Inject the initialised SharedPreferences instance
        sharedPrefsProvider.overrideWithValue(appPrefs),
      ],
      child: const CircuitChatApp(),
    ),
  );
}

class CircuitChatApp extends StatelessWidget {
  const CircuitChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CircuitChat',
      debugShowCheckedModeBanner: false,

      // ── Theme ────────────────────────────────────────────────────────────
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
        ),
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A1A2E),
          elevation: 0,
          centerTitle: false,
        ),
      ),

      // ── Router ───────────────────────────────────────────────────────────
      routerConfig: appRouter,
    );
  }
}
