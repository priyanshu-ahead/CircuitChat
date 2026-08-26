import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/providers.dart';

// ── Storage key ───────────────────────────────────────────────────────────────
const _kThemeKey = 'app_theme_mode';

// ── Provider ──────────────────────────────────────────────────────────────────

/// Exposes the current [ThemeMode] and persists it to SharedPreferences.
/// Mirrors RN's `mode`/`setMode` pattern from AppContext (context/app.js).
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Load persisted value synchronously from SharedPreferences
    _loadSaved();
    return ThemeMode.light; // default until async load completes
  }

  Future<void> _loadSaved() async {
    try {
      final prefs = ref.read(sharedPrefsProvider);
      final saved = prefs.getString(_kThemeKey);
      if (saved == 'dark') {
        state = ThemeMode.dark;
      } else {
        state = ThemeMode.light;
      }
    } catch (_) {
      state = ThemeMode.light;
    }
  }

  /// Toggle between light and dark.
  Future<void> toggle() async {
    final next =
        state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    _persist(next);
  }

  /// Explicitly set the theme.
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    _persist(mode);
  }

  bool get isDark => state == ThemeMode.dark;

  void _persist(ThemeMode mode) {
    try {
      final prefs = ref.read(sharedPrefsProvider);
      prefs.setString(_kThemeKey, mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }
}
