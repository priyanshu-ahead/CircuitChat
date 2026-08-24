import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/socket_service.dart';
import '../../core/storage/secure_storage.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class AppInitState {
  const AppInitState({
    this.permissions  = const {},
    this.translations = const {},
    this.reactions    = const [],
    this.unreadCount  = 0,
    this.generalSettings = const {},
    this.isInitialized = false,
  });

  final Map<String, dynamic> permissions;
  final Map<String, dynamic> translations;
  final List<dynamic>        reactions;
  final int                  unreadCount;
  final Map<String, dynamic> generalSettings;
  final bool                 isInitialized;

  /// Whether Agora calling is enabled on this server.
  bool get agoraEnabled =>
      (generalSettings['agora_app_id'] as String? ?? '').isNotEmpty;

  /// Whether group feature is enabled.
  bool get groupEnabled =>
      generalSettings['enable_group'] != false;

  /// Get a translated string by key, falls back to the key itself.
  String t(String key) =>
      (translations[key] as String?) ?? key;

  AppInitState copyWith({
    Map<String, dynamic>? permissions,
    Map<String, dynamic>? translations,
    List<dynamic>?        reactions,
    int?                  unreadCount,
    Map<String, dynamic>? generalSettings,
    bool?                 isInitialized,
  }) =>
      AppInitState(
        permissions:     permissions     ?? this.permissions,
        translations:    translations    ?? this.translations,
        reactions:       reactions       ?? this.reactions,
        unreadCount:     unreadCount     ?? this.unreadCount,
        generalSettings: generalSettings ?? this.generalSettings,
        isInitialized:   isInitialized   ?? this.isInitialized,
      );
}

// ── ViewModel ─────────────────────────────────────────────────────────────────

/// Replicates the boot sequence from RN's AppContext (context/app.js).
///
/// Call [init] once after a successful auth session restore (from
/// SplashViewModel) or after login/signup. It fetches permissions,
/// translations, reactions, unread count, and general settings in parallel,
/// then connects the socket and registers the FCM token.
class AppInitViewModel extends Notifier<AppInitState> {
  @override
  AppInitState build() => const AppInitState();

  Future<void> init() async {
    dev.log('AppInit: starting boot sequence', name: 'AppInit');
    final api = ref.read(apiClientProvider);

    // Run all boot fetches in parallel — mirrors RN app.js
    final results = await Future.wait([
      api.get<Map<String, dynamic>>(ApiEndpoints.permissions)
          .catchError((_) => <String, dynamic>{}),
      api.get<Map<String, dynamic>>(ApiEndpoints.translation)
          .catchError((_) => <String, dynamic>{}),
      api.get<Map<String, dynamic>>(ApiEndpoints.chatReactions)
          .catchError((_) => <String, dynamic>{}),
      api.get<Map<String, dynamic>>(ApiEndpoints.chatUnread)
          .catchError((_) => <String, dynamic>{}),
      _fetchGeneralSettings(api),
    ]);

    final perms      = results[0] as Map<String, dynamic>;
    final trans      = results[1] as Map<String, dynamic>;
    final reactRaw   = results[2] as Map<String, dynamic>;
    final unreadRaw  = results[3] as Map<String, dynamic>;
    final genSettings = results[4] as Map<String, dynamic>;

    final reactions  = reactRaw['reactions'] as List? ?? [];
    final unread     = (unreadRaw['count'] as num?)?.toInt() ?? 0;

    state = state.copyWith(
      permissions:     perms,
      translations:    trans,
      reactions:       reactions,
      unreadCount:     unread,
      generalSettings: genSettings,
      isInitialized:   true,
    );

    // Connect socket
    final token = await ref.read(secureStorageProvider).getAuthToken();
    if (token != null && token.isNotEmpty) {
      SocketService.instance.connect(token);
      dev.log('AppInit: socket connected', name: 'AppInit');
    }

    // Background contact sync (fire-and-forget)
    ref.read(contactSyncServiceProvider).sync().catchError((_) {});

    // FCM token → POST /user/push-notification (RN firebase/index.js)
    await _registerFcmToken();
    NotificationService.instance.listenTokenRefresh((token) {
      _pushFcmToken(token);
    });

    dev.log('AppInit: boot complete — unread=$unread, '
        'reactions=${reactions.length}', name: 'AppInit');
  }

  /// Fetch the device FCM token and register it with the backend.
  Future<void> _registerFcmToken() async {
    try {
      final token = await NotificationService.instance.getFcmToken();
      if (token == null || token.isEmpty) {
        dev.log('AppInit: no FCM token available', name: 'AppInit');
        return;
      }
      await _pushFcmToken(token);
    } catch (e) {
      dev.log('AppInit: FCM register skipped: $e', name: 'AppInit');
    }
  }

  /// Same payload as RN: `{ token, type: 'fcm' }`.
  Future<void> _pushFcmToken(String token) async {
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .addPushNotificationToken({'token': token, 'type': 'fcm'});
      dev.log(
        result.success
            ? 'AppInit: FCM token registered'
            : 'AppInit: FCM token push failed — ${result.message}',
        name: 'AppInit',
      );
    } catch (e) {
      dev.log('AppInit: FCM token push error: $e', name: 'AppInit');
    }
  }

  Future<Map<String, dynamic>> _fetchGeneralSettings(ApiClient api) async {
    final keys = [
      'agora_app_id',
      'enable_group',
      'domain',
      'firebase_config',
      'messaging_setting',
    ];
    final merged = <String, dynamic>{};
    try {
      final List<Future<Map<String, dynamic>>> futures = [
        for (final k in keys)
          api
              .get<Map<String, dynamic>>(ApiEndpoints.generalSettingsByKey(k))
              .catchError((_) => <String, dynamic>{}),
      ];
      final results = await Future.wait(futures);
      for (final r in results) {
        merged.addAll(r);
      }
    } catch (_) {
      // return whatever was merged so far
    }
    return merged;
  }

  void decrementUnread() {
    if (state.unreadCount > 0) {
      state = state.copyWith(unreadCount: state.unreadCount - 1);
    }
  }

  void setUnreadCount(int count) {
    state = state.copyWith(unreadCount: count);
  }
}

final appInitProvider =
    NotifierProvider<AppInitViewModel, AppInitState>(AppInitViewModel.new);

/// Convenience provider: just the unread count for the badge.
final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(appInitProvider).unreadCount;
});

/// Server i18n map from `/user/translation` — mirrors RN AppContext.translation.
final translationsProvider = Provider<Map<String, dynamic>>((ref) {
  return ref.watch(appInitProvider.select((s) => s.translations));
});

/// Lookup a translated string: `ref.watch(i18nProvider)('signup_title')`.
/// Falls back to the key itself when the map has no entry.
final i18nProvider = Provider<String Function(String)>((ref) {
  final translations = ref.watch(translationsProvider);
  return (key) => (translations[key] as String?) ?? key;
});
