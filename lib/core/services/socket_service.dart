import 'dart:developer' as dev;

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/app_constants.dart';

/// Socket.io event name constants.
abstract class SocketEvents {
  static const newMessage = 'new_message';
  static const typing = 'typing';
  static const stopTyping = 'stop_typing';
  static const online = 'online';
  static const offline = 'offline';
  static const userStatus = 'user_status';
  static const refresh = 'refresh';
  static const markRead = 'mark_read';
  static const call = 'call';
  static const joinChat = 'join_chat';
  static const leaveChat = 'leave_chat';
  static const messageEdit = 'message_edit';
  static const messageDelete = 'message_delete';
  static const reaction = 'reaction';
}

class SocketService {
  SocketService._();

  static final SocketService instance = SocketService._();

  io.Socket? _socket;

  /// Handlers registered even before [connect], then attached to the socket.
  final Map<String, List<void Function(dynamic)>> _handlers = {};

  bool get isConnected => _socket?.connected ?? false;

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  void connect(String authToken) {
    // Don't create another socket if already connected.
    if (isConnected) {
      _log('Socket already connected');
      return;
    }

    // Dispose an old socket before creating a new one.
    _socket?.dispose();

    final socketUrl = '${AppConstants.socketUrl}?token=$authToken';

    _log('Connecting to: ${AppConstants.socketUrl}?token=***');

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );

    _socket!
      ..onConnect((_) {
        _log('✅ Connected to server');
        _log('Socket connected: ${_socket?.connected}');
      })
      ..onDisconnect((reason) {
        _log('🔌 Disconnected from server');
        _log('Disconnect reason: $reason');
      })
      ..onError((error) {
        _log('❌ Error while connection');
        _log('Socket connected: ${_socket?.connected}');
        _log('Error: $error');
      })
      ..onConnectError((error) {
        _log('❌ Connect error: $error');
        _log('Socket connected: ${_socket?.connected}');
      });

    _attachStoredHandlers();
  }

  void _attachStoredHandlers() {
    final socket = _socket;
    if (socket == null) return;
    for (final entry in _handlers.entries) {
      for (final handler in entry.value) {
        socket.on(entry.key, handler);
      }
    }
  }

  void disconnect() {
    _log('Disconnecting socket');

    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  // ---------------------------------------------------------------------------
  // Emit
  // ---------------------------------------------------------------------------

  void emit(String event, [dynamic data]) {
    if (_socket == null) {
      _log('⚠️ Cannot emit "$event": socket is null');
      return;
    }

    if (!isConnected) {
      _log('⚠️ Cannot emit "$event": socket is not connected');
      return;
    }

    _log('➡️ Emit: $event');

    if (data != null) {
      _log('Data: $data');
      _socket!.emit(event, data);
    } else {
      _socket!.emit(event);
    }
  }

  void emitWithAck(
      String event,
      dynamic data, {
        required void Function(dynamic response) ack,
      }) {
    if (_socket == null || !isConnected) {
      _log('⚠️ Cannot emitWithAck "$event": socket not connected');
      return;
    }

    _socket!.emitWithAck(
      event,
      data,
      ack: ack,
    );
  }

  // ---------------------------------------------------------------------------
  // Subscribe
  // ---------------------------------------------------------------------------

  void on(
      String event,
      void Function(dynamic data) handler,
      ) {
    final list = _handlers.putIfAbsent(event, () => []);
    if (!list.contains(handler)) {
      list.add(handler);
    }
    _socket?.on(event, handler);
    _log('👂 Listening: $event');
  }

  // ---------------------------------------------------------------------------
  // Unsubscribe
  // ---------------------------------------------------------------------------

  void off(
      String event, [
        void Function(dynamic data)? handler,
      ]) {
    if (handler != null) {
      _handlers[event]?.remove(handler);
      _socket?.off(event, handler);
    } else {
      _handlers.remove(event);
      _socket?.off(event);
    }
    _log('🚫 Removed listener: $event');
  }

  // ---------------------------------------------------------------------------
  // Chat
  // ---------------------------------------------------------------------------

  void joinChat(String chatId) {
    emit(
      SocketEvents.joinChat,
      {
        'chatId': chatId,
      },
    );
  }

  void leaveChat(String chatId) {
    emit(
      SocketEvents.leaveChat,
      {
        'chatId': chatId,
      },
    );
  }

  void sendTyping(String chatId) {
    emit(
      SocketEvents.typing,
      {
        'chatId': chatId,
      },
    );
  }

  void sendStopTyping(String chatId) {
    emit(
      SocketEvents.stopTyping,
      {
        'chatId': chatId,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Logging
  // ---------------------------------------------------------------------------

  void _log(String message) {
    dev.log(
      message,
      name: 'SocketService',
    );
  }
}