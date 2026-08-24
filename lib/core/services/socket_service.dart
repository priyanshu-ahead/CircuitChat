import 'dart:developer' as dev;

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/app_constants.dart';

/// Socket.io event name constants — mirrors RN's SOCKET_EVENTS constant.
abstract class SocketEvents {
  static const newMessage   = 'new_message';
  static const typing       = 'typing';
  static const stopTyping   = 'stop_typing';
  static const online       = 'online';
  static const offline      = 'offline';
  static const markRead     = 'mark_read';
  static const call         = 'call';
  static const joinChat     = 'join_chat';
  static const leaveChat    = 'leave_chat';
  static const messageEdit  = 'message_edit';
  static const messageDelete = 'message_delete';
  static const reaction     = 'reaction';
}

/// socket.io-client wrapper (replaces socket.io-client from RN).
/// Singleton — call [connect] once after auth, [disconnect] on logout.
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  bool get isConnected => _socket?.connected ?? false;

  // ── Connection ────────────────────────────────────────────────────────────

  void connect(String authToken) {
    if (isConnected) return;

    _socket = io.io(
      AppConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(10)
          .setAuth({'token': authToken})
          .build(),
    );

    _socket!
      ..onConnect((_)      => _log('✅ Connected'))
      ..onDisconnect((_)   => _log('🔌 Disconnected'))
      ..onError((err)      => _log('❌ Error: $err'))
      ..onConnectError((e) => _log('❌ Connect error: $e'));
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  // ── Emit ──────────────────────────────────────────────────────────────────

  void emit(String event, dynamic data) => _socket?.emit(event, data);

  void emitWithAck(String event, dynamic data,
      {required void Function(dynamic) ack}) =>
      _socket?.emitWithAck(event, data, ack: ack);

  // ── Subscribe / Unsubscribe ────────────────────────────────────────────────

  void on(String event, void Function(dynamic) handler) =>
      _socket?.on(event, handler);

  void off(String event, [void Function(dynamic)? handler]) =>
      _socket?.off(event, handler);

  // ── Chat room helpers ─────────────────────────────────────────────────────

  void joinChat(String chatId) =>
      emit(SocketEvents.joinChat, {'chatId': chatId});

  void leaveChat(String chatId) =>
      emit(SocketEvents.leaveChat, {'chatId': chatId});

  void sendTyping(String chatId) =>
      emit(SocketEvents.typing, {'chatId': chatId});

  void sendStopTyping(String chatId) =>
      emit(SocketEvents.stopTyping, {'chatId': chatId});

  // ── Internal ──────────────────────────────────────────────────────────────

  void _log(String msg) =>
      dev.log(msg, name: 'SocketService');
}
