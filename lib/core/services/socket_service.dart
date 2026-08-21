import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/app_constants.dart';

/// socket.io-client wrapper (replaces socket.io-client from RN).
/// Manages the connection lifecycle and exposes typed event callbacks.
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
          .setAuth({'token': authToken})
          .build(),
    );

    _socket!
      ..onConnect((_) => _log('Connected'))
      ..onDisconnect((_) => _log('Disconnected'))
      ..onError((err) => _log('Error: $err'))
      ..onConnectError((err) => _log('Connect error: $err'));
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  // ── Emit ──────────────────────────────────────────────────────────────────

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void emitWithAck(
    String event,
    dynamic data, {
    required void Function(dynamic) ack,
  }) {
    _socket?.emitWithAck(event, data, ack: ack);
  }

  // ── Listen ────────────────────────────────────────────────────────────────

  void on(String event, void Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event, [void Function(dynamic)? handler]) {
    _socket?.off(event, handler);
  }

  // ── Common Chat Events ────────────────────────────────────────────────────

  /// Join a specific chat room.
  void joinChat(String chatId) => emit('join_chat', {'chatId': chatId});

  /// Leave a specific chat room.
  void leaveChat(String chatId) => emit('leave_chat', {'chatId': chatId});

  /// Notify others the user is typing.
  void sendTyping(String chatId) => emit('typing', {'chatId': chatId});

  /// Notify others the user stopped typing.
  void sendStopTyping(String chatId) =>
      emit('stop_typing', {'chatId': chatId});

  void _log(String msg) {
    // ignore: avoid_print
    print('[SocketService] $msg');
  }
}
