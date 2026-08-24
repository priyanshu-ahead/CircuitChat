import 'dart:async';
import 'dart:developer' as dev;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

// ── Global navigator key ──────────────────────────────────────────────────────
// Set this in main.dart: navigatorKey = NotificationService.navigatorKey
final navigatorKey = GlobalKey<NavigatorState>();

/// Handles FCM token registration, foreground / background message routing,
/// and local notification display — mirrors RN's context/app.js FCM setup.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _local   = FlutterLocalNotificationsPlugin();
  final _fcm     = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenRefreshSub;

  // ── Android channel ───────────────────────────────────────────────────────

  static const _msgChannel = AndroidNotificationChannel(
    'circuit_chat_messages',
    'Messages',
    description: 'New chat messages',
    importance: Importance.high,
    playSound: true,
  );

  static const _callChannel = AndroidNotificationChannel(
    'circuit_chat_calls',
    'Calls',
    description: 'Incoming voice and video calls',
    importance: Importance.max,
    playSound: true,
  );

  // ── Initialise ────────────────────────────────────────────────────────────

  Future<void> initialise() async {
    // 1. Request permission
    final settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );
    dev.log('FCM permission: ${settings.authorizationStatus}',
        name: 'NotificationService');

    // 2. Create Android channels
    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_msgChannel);
    await androidPlugin?.createNotificationChannel(_callChannel);

    // 3. Init flutter_local_notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false, // already requested above
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalTap,
    );

    // 4. Foreground presentation (iOS shows banner even when app is open)
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    // 5. Listen to foreground FCM messages
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // 6. Notification-tap when app was in background (but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // 7. Check if app was launched from a terminated-state notification tap
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleTap(initial);

    dev.log('NotificationService initialised', name: 'NotificationService');
  }

  // ── FCM token ─────────────────────────────────────────────────────────────

  Future<String?> getFcmToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      dev.log('FCM getToken error: $e', name: 'NotificationService');
      return null;
    }
  }

  /// Mirrors RN `messaging().onTokenRefresh` — subscribe once.
  void listenTokenRefresh(void Function(String token) onRefresh) {
    _tokenRefreshSub ??= _fcm.onTokenRefresh.listen(onRefresh);
  }

  // ── Foreground handler ────────────────────────────────────────────────────

  void _handleForeground(RemoteMessage message) {
    dev.log('FCM foreground: ${message.messageId}  '
        'type=${message.data['notificationType']}',
        name: 'NotificationService');

    final data = message.data;
    final type = data['notificationType'] as String? ?? 'message';

    if (type == 'call') {
      _showCallNotification(message);
      return;
    }

    // Regular message notification
    final notification = message.notification;
    final title = notification?.title ?? data['title'] ?? 'CircuitChat';
    final body  = notification?.body  ?? data['body']  ?? '';

    _local.show(
      message.hashCode,
      title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _msgChannel.id, _msgChannel.name,
          channelDescription: _msgChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: _buildPayload(data),
    );
  }

  void _showCallNotification(RemoteMessage message) {
    final data     = message.data;
    final name     = data['name']     as String? ?? 'Unknown';
    final callType = data['callType'] as String? ?? 'audio';

    _local.show(
      message.hashCode,
      name,
      '${callType == 'video' ? 'Video' : 'Voice'} call incoming',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _callChannel.id, _callChannel.name,
          channelDescription: _callChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          actions: [
            const AndroidNotificationAction('accept', 'Answer',
                showsUserInterface: true),
            const AndroidNotificationAction('reject', 'Decline'),
          ],
          fullScreenIntent: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _buildPayload(data),
    );
  }

  // ── Tap handler (background / terminated) ────────────────────────────────

  void _handleTap(RemoteMessage message) {
    final data = message.data;
    dev.log('FCM tapped: ${message.messageId}  data=$data',
        name: 'NotificationService');
    _navigate(data);
  }

  void _onLocalTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    // payload format: "type:id"  e.g. "chat:abc123"  or  "call:xyz"
    final parts = payload.split(':');
    if (parts.length < 2) return;

    _navigate({'notificationType': parts[0], 'chatId': parts[1]});
  }

  // ── Navigation helper ─────────────────────────────────────────────────────

  void _navigate(Map<String, dynamic> data) {
    final router  = _router;
    if (router == null) return;

    final type   = data['notificationType'] as String? ?? 'message';
    final chatId = data['chatId'] as String? ?? data['chat'] as String? ?? '';
    final callId = data['callId'] as String? ?? data['_id'] as String? ?? '';

    switch (type) {
      case 'call':
        if (callId.isNotEmpty) {
          router.push(
            Routes.callScreen.replaceFirst(':callId', callId),
            extra: {
              'callType':   data['callType'] ?? 'audio',
              'chatName':   data['name']     ?? '',
              'isIncoming': true,
            },
          );
        }
        break;

      case 'group_join':
        final token = data['token'] as String? ?? '';
        if (token.isNotEmpty) {
          router.push(Routes.groupJoin.replaceFirst(':token', token));
        }
        break;

      default:
        // Regular message — navigate to chat
        if (chatId.isNotEmpty) {
          router.push(
            Routes.chatDetail.replaceFirst(':chatId', chatId),
          );
        }
        break;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _buildPayload(Map<String, dynamic> data) {
    final type   = data['notificationType'] ?? 'message';
    final chatId = data['chatId'] ?? data['chat'] ?? data['callId'] ?? '';
    return '$type:$chatId';
  }

  /// Access the GoRouter via the navigator key.
  GoRouter? get _router {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return null;
    try {
      return GoRouter.of(ctx);
    } catch (_) {
      return null;
    }
  }
}
