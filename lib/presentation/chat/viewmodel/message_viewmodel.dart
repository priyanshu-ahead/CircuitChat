import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/providers.dart';
import '../../../core/services/socket_service.dart';
import '../../../data/models/message_model.dart';
import '../../../data/repositories/chat_repository.dart';


// ── State ─────────────────────────────────────────────────────────────────────
class MessageState {
  const MessageState({
    this.messages = const [],
    this.status = MessageStatus2.initial,
    this.hasMore = true,
    this.isSending = false,
    this.replyTo,
    this.isTyping = false,
    this.typingUserId,
    this.pinnedMessage,
    this.errorMessage,
  });

  final List<MessageModel> messages;
  final MessageStatus2 status;
  final bool hasMore;
  final bool isSending;
  final MessageModel? replyTo;
  final bool isTyping;
  final String? typingUserId;
  final MessageModel? pinnedMessage;
  final String? errorMessage;

  bool get isLoading => status == MessageStatus2.loading;

  MessageState copyWith({
    List<MessageModel>? messages,
    MessageStatus2? status,
    bool? hasMore,
    bool? isSending,
    MessageModel? replyTo,
    bool clearReplyTo = false,
    bool? isTyping,
    String? typingUserId,
    MessageModel? pinnedMessage,
    bool clearPinned = false,
    String? errorMessage,
  }) =>
      MessageState(
        messages:      messages      ?? this.messages,
        status:        status        ?? this.status,
        hasMore:       hasMore       ?? this.hasMore,
        isSending:     isSending     ?? this.isSending,
        replyTo:       clearReplyTo  ? null : (replyTo ?? this.replyTo),
        isTyping:      isTyping      ?? this.isTyping,
        typingUserId:  typingUserId  ?? this.typingUserId,
        pinnedMessage: clearPinned   ? null : (pinnedMessage ?? this.pinnedMessage),
        errorMessage:  errorMessage,
      );
}

enum MessageStatus2 { initial, loading, success, loadingMore, error }

// ── ViewModel params: (chatId, chatType) ──────────────────────────────────────
/// Arg passed to [MessageViewModel]: a record of (chatId, chatType).
/// chatType: 'user' = direct, 'group' = group (mirrors RN CHAT_TYPE constant).
typedef MessageVmArg = ({String chatId, String chatType});

// ── ViewModel ─────────────────────────────────────────────────────────────────
class MessageViewModel extends FamilyNotifier<MessageState, MessageVmArg> {
  @override
  MessageState build(MessageVmArg arg) {
    _chatId   = arg.chatId;
    _chatType = arg.chatType;
    _loadInitial();
    _subscribeSocket();
    // Cleanup socket listeners when provider is disposed
    ref.onDispose(_unsubscribeSocket);
    return const MessageState(status: MessageStatus2.loading);
  }

  late final String _chatId;
  late final String _chatType;
  String? _lastMessage;
  final _uuid = const Uuid();

  ChatRepository get _repo   => ref.read(chatRepositoryProvider);
  SocketService  get _socket => SocketService.instance;

  // ── Socket ────────────────────────────────────────────────────────────────

  void _subscribeSocket() {
    _socket.joinChat(_chatId);

    _socket.on(SocketEvents.newMessage,    _onNewMessage);
    _socket.on(SocketEvents.typing,        _onTyping);
    _socket.on(SocketEvents.stopTyping,    _onStopTyping);
    _socket.on(SocketEvents.markRead,      _onMarkRead);
    _socket.on(SocketEvents.messageEdit,   _onMessageEdit);
    _socket.on(SocketEvents.messageDelete, _onMessageDelete);
    _socket.on(SocketEvents.reaction,      _onReaction);
  }

  void _unsubscribeSocket() {
    _socket.leaveChat(_chatId);
    _socket.off(SocketEvents.newMessage);
    _socket.off(SocketEvents.typing);
    _socket.off(SocketEvents.stopTyping);
    _socket.off(SocketEvents.markRead);
    _socket.off(SocketEvents.messageEdit);
    _socket.off(SocketEvents.messageDelete);
    _socket.off(SocketEvents.reaction);
  }

  void _onNewMessage(dynamic data) {
    if (data is! Map) return;
    final msg = MessageModel.fromJson(Map<String, dynamic>.from(data));
    if (msg.chatId != _chatId && data['chat'] != _chatId) return;
    if (state.messages.any((m) => m.id == msg.id)) return;
    // Prepend at index 0 — with reverse:true this appears at the visual bottom
    state = state.copyWith(messages: [msg, ...state.messages]);
    _repo.markRead(_chatId, _chatType);
  }

  void _onTyping(dynamic data) {
    if (data is! Map) return;
    if (data['chatId'] != _chatId) return;
    state = state.copyWith(
        isTyping: true, typingUserId: data['userId']?.toString());
  }

  void _onStopTyping(dynamic data) {
    if (data is! Map) return;
    if (data['chatId'] != _chatId) return;
    state = state.copyWith(isTyping: false, typingUserId: null);
  }

  void _onMarkRead(dynamic data) {
    if (data is! Map) return;
    if (data['chatId'] != _chatId) return;
    // Update status of all my sent messages to seen
    state = state.copyWith(
      messages: state.messages.map((m) {
        if (m.fromMe && m.status == MessageStatus.delivered) {
          return m.copyWith(status: MessageStatus.seen);
        }
        return m;
      }).toList(),
    );
  }

  void _onMessageEdit(dynamic data) {
    if (data is! Map) return;
    final id   = data['_id']?.toString() ?? data['id']?.toString();
    final text = data['text']?.toString();
    if (id == null || text == null) return;
    state = state.copyWith(
      messages: state.messages
          .map((m) => m.id == id ? m.copyWith(text: text) : m)
          .toList(),
    );
  }

  void _onMessageDelete(dynamic data) {
    if (data is! Map) return;
    final id = data['_id']?.toString() ?? data['id']?.toString();
    if (id == null) return;
    state = state.copyWith(
      messages: state.messages
          .map((m) => m.id == id ? m.copyWith(isDeleted: true) : m)
          .toList(),
    );
  }

  void _onReaction(dynamic data) {
    if (data is! Map) return;
    final msgId   = data['message']?.toString();
    final emoji   = data['reaction']?.toString();
    final userId  = data['user']?.toString();
    if (msgId == null || emoji == null || userId == null) return;

    state = state.copyWith(
      messages: state.messages.map((m) {
        if (m.id != msgId) return m;
        final existing = List<MessageReaction>.from(m.reactions);
        existing.removeWhere((r) => r.userId == userId);
        if (emoji.isNotEmpty) {
          existing.add(MessageReaction(
            id: '${userId}_$msgId',
            messageId: msgId,
            userId: userId,
            reaction: emoji,
          ));
        }
        return m.copyWith(reactions: existing);
      }).toList(),
    );
  }

  // ── Typing emit ───────────────────────────────────────────────────────────

  void emitTyping()     => _socket.sendTyping(_chatId);
  void emitStopTyping() => _socket.sendStopTyping(_chatId);

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _loadInitial() async {
    state = const MessageState(status: MessageStatus2.loading);
    try {
      final result = await _repo.fetchMessages(FetchMessagesParams(
        chatId: _chatId,
        chatType: _chatType,
        limit: 30,
      ));
      if (result.items.isNotEmpty) _lastMessage = result.items.last.id;
      // Keep API order (newest-first). ListView uses reverse:true so
      // index-0 = newest appears at the visual bottom automatically.
      state = state.copyWith(
        messages: result.items,
        status: MessageStatus2.success,
        hasMore: result.hasMore,
      );
      await _repo.markRead(_chatId, _chatType);
      final pinned = await _repo.getPinnedMessage(_chatId);
      if (pinned != null) {
        state = state.copyWith(pinnedMessage: pinned);
      }
    } catch (e) {
      state = state.copyWith(
          status: MessageStatus2.error, errorMessage: e.toString());
    }
  }

  /// Public reload used by the Retry button on error state.
  Future<void> reload() => _loadInitial();

  Future<void> loadMore() async {
    if (!state.hasMore || state.status == MessageStatus2.loadingMore) return;
    state = state.copyWith(status: MessageStatus2.loadingMore);
    try {
      final result = await _repo.fetchMessages(FetchMessagesParams(
        chatId: _chatId,
        chatType: _chatType,
        lastMessage: _lastMessage,
        limit: 30,
      ));
      if (result.items.isNotEmpty) _lastMessage = result.items.last.id;
      // Older messages go at the END of the list (high index = visual top
      // in a reversed ListView — these are the oldest messages).
      state = state.copyWith(
        messages: [...state.messages, ...result.items],
        status: MessageStatus2.success,
        hasMore: result.hasMore,
      );
    } catch (_) {
      state = state.copyWith(status: MessageStatus2.success);
    }
  }

  // ── Send ──────────────────────────────────────────────────────────────────

  Future<void> sendText(String text, {String? currentUserId}) async {
    if (text.trim().isEmpty) return;
    final tempId  = _uuid.v4();
    final replyTo = state.replyTo;
    final optimistic = MessageModel(
      id:          tempId,
      chatId:      _chatId,
      senderId:    currentUserId ?? '',
      contentType: ContentType.text,
      text:        text.trim(),
      status:      MessageStatus.sending,
      fromMe:      true,
      createdAt:   DateTime.now().toIso8601String(),
      replyToId:   replyTo?.id,
      replyToMessage: replyTo,
    );
    state = state.copyWith(
        // Prepend at index 0 so it appears at visual bottom (reverse:true)
        messages: [optimistic, ...state.messages],
        isSending: true, clearReplyTo: true);
    try {
      final sent = await _repo.sendMessage(
        chatId: _chatId, chatType: _chatType,
        contentType: 'text', text: text.trim(),
        replyToId: replyTo?.id,
      );
      state = state.copyWith(
        messages: state.messages.map((m) => m.id == tempId
            ? sent.copyWith(fromMe: true, status: MessageStatus.sent) : m)
            .toList(),
        isSending: false,
      );
    } catch (_) {
      state = state.copyWith(
        messages: state.messages.map((m) => m.id == tempId
            ? m.copyWith(status: MessageStatus.failed) : m).toList(),
        isSending: false,
      );
    }
  }

  Future<void> sendMedia({
    required String localPath,
    required MessageType type,
    String? currentUserId,
    String? text,
  }) async {
    final tempId = _uuid.v4();
    final replyTo = state.replyTo;
    final optimistic = MessageModel(
      id: tempId,
      chatId: _chatId,
      senderId: currentUserId ?? '',
      contentType: _contentTypeFor(type),
      text: text,
      mediaUrl: localPath,
      status: MessageStatus.sending,
      fromMe: true,
      createdAt: DateTime.now().toIso8601String(),
      replyToId: replyTo?.id,
      replyToMessage: replyTo,
    );
    state = state.copyWith(
      messages: [optimistic, ...state.messages],
      isSending: true,
      clearReplyTo: true,
    );
    try {
      final sent = await _repo.sendMediaMessage(
        chatId: _chatId,
        chatType: _chatType,
        localPath: localPath,
        type: type,
        text: text,
      );
      state = state.copyWith(
        messages: state.messages
            .map((m) => m.id == tempId
                ? sent.copyWith(fromMe: true, status: MessageStatus.sent)
                : m)
            .toList(),
        isSending: false,
      );
    } catch (_) {
      state = state.copyWith(
        messages: state.messages
            .map((m) => m.id == tempId
                ? m.copyWith(status: MessageStatus.failed)
                : m)
            .toList(),
        isSending: false,
      );
    }
  }

  ContentType _contentTypeFor(MessageType type) {
    switch (type) {
      case MessageType.image:
        return ContentType.image;
      case MessageType.video:
        return ContentType.video;
      case MessageType.audio:
        return ContentType.audio;
      case MessageType.file:
        return ContentType.file;
      case MessageType.location:
        return ContentType.location;
      case MessageType.call:
        return ContentType.call;
      case MessageType.text:
        return ContentType.text;
    }
  }

  // ── Reply ─────────────────────────────────────────────────────────────────

  void setReplyTo(MessageModel? message) {
    state = message == null
        ? state.copyWith(clearReplyTo: true)
        : state.copyWith(replyTo: message);
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteMessage(String messageId, {bool forEveryone = false}) async {
    state = state.copyWith(
      messages: state.messages.map((m) => m.id == messageId
          ? m.copyWith(isDeleted: true,
              status: forEveryone ? MessageStatus.deletedEveryone : m.status)
          : m).toList(),
    );
    try {
      if (forEveryone) {
        await _repo.deleteMessageForEveryone([messageId], chatId: _chatId);
      } else {
        await _repo.deleteMessage([messageId]);
      }
    } catch (_) {
      await _loadInitial();
    }
  }

  // ── Star ──────────────────────────────────────────────────────────────────

  Future<void> starMessage(String messageId) async {
    state = state.copyWith(
      messages: state.messages.map((m) => m.id == messageId
          ? m.copyWith(isStarred: true) : m).toList(),
    );
    await _repo.starMessage(messageId, _chatId, _chatType);
  }

  Future<void> unstarMessage(String messageId) async {
    state = state.copyWith(
      messages: state.messages.map((m) => m.id == messageId
          ? m.copyWith(isStarred: false) : m).toList(),
    );
    await _repo.unstarMessage(messageId, _chatId, _chatType);
  }

  // ── Reaction ──────────────────────────────────────────────────────────────

  Future<void> addReaction(String messageId, String emoji) async {
    await _repo.addReaction(messageId, _chatId, emoji);
  }

  Future<void> removeReaction(String messageId) async {
    await _repo.removeReaction(messageId, _chatId);
  }

  // ── Pin ───────────────────────────────────────────────────────────────────

  Future<void> pinMessage(String messageId) async {
    await _repo.pinMessage(messageId, _chatId);
    final pinned = await _repo.getPinnedMessage(_chatId);
    if (pinned != null) state = state.copyWith(pinnedMessage: pinned);
  }

  Future<void> unpinMessage(String messageId) async {
    await _repo.unpinMessage(messageId);
    state = state.copyWith(clearPinned: true);
  }

  // ── External typing state (for UI without socket, e.g. testing) ──────────
  void setTyping({required bool typing, String? userId}) {
    state = state.copyWith(isTyping: typing, typingUserId: userId);
  }
  // ── In-chat search ────────────────────────────────────────────────────────

  Future<void> searchMessages(String query) async {
    state = state.copyWith(status: MessageStatus2.loading);
    try {
      final result = await _repo.fetchMessages(FetchMessagesParams(
        chatId:   _chatId,
        chatType: _chatType,
        limit:    50,
        search:   query,
      ));
      state = state.copyWith(
        messages: result.items,
        status:   MessageStatus2.success,
        hasMore:  false, // search results are not paginated
      );
    } catch (_) {
      state = state.copyWith(status: MessageStatus2.success);
    }
  }

  void clearSearch() => _loadInitial();
}

final messageViewModelProvider =
    NotifierProviderFamily<MessageViewModel, MessageState, MessageVmArg>(
        MessageViewModel.new);
