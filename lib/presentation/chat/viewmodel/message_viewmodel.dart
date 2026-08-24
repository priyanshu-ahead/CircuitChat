import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/providers.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/message_model.dart';
import '../../../data/repositories/chat_repository.dart';
import 'chat_list_viewmodel.dart';

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
    this.errorMessage,
  });

  final List<MessageModel> messages;
  final MessageStatus2 status;
  final bool hasMore;
  final bool isSending;

  /// The message being replied to (shown in input bar).
  final MessageModel? replyTo;

  /// Remote typing indicator.
  final bool isTyping;
  final String? typingUserId;

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
    String? errorMessage,
  }) =>
      MessageState(
        messages: messages ?? this.messages,
        status: status ?? this.status,
        hasMore: hasMore ?? this.hasMore,
        isSending: isSending ?? this.isSending,
        replyTo: clearReplyTo ? null : (replyTo ?? this.replyTo),
        isTyping: isTyping ?? this.isTyping,
        typingUserId: typingUserId ?? this.typingUserId,
        errorMessage: errorMessage,
      );
}

enum MessageStatus2 { initial, loading, success, loadingMore, error }

// ── ViewModel ─────────────────────────────────────────────────────────────────
class MessageViewModel extends FamilyNotifier<MessageState, String> {
  /// [arg] is the chatId.
  @override
  MessageState build(String arg) {
    _chatId = arg;
    _loadInitial();
    return const MessageState(status: MessageStatus2.loading);
  }

  late final String _chatId;
  String? _lastMessage; // oldest message ID loaded so far (for pagination)
  final _uuid = const Uuid();

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  String get _chatType {
    // Derive chatType from ChatListViewModel state if available, else default to '0'.
    try {
      final chatList = ref.read(chatListViewModelProvider);
      final chat = chatList.chats.firstWhere((c) => c.id == _chatId,
          orElse: () => const ChatModel(
                id: '', type: ChatType.direct, unreadCount: 0));
      return chat.type == ChatType.group ? '1' : '0';
    } catch (_) {
      return '0';
    }
  }

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> _loadInitial() async {
    state = const MessageState(status: MessageStatus2.loading);
    try {
      final result = await _repo.fetchMessages(FetchMessagesParams(
        chatId: _chatId,
        chatType: _chatType,
        limit: 30,
      ));
      if (result.items.isNotEmpty) {
        _lastMessage = result.items.last.id;
      }
      // Messages from API come newest-first; reverse to display oldest at top.
      final msgs = result.items.reversed.toList();
      state = state.copyWith(
        messages: msgs,
        status: MessageStatus2.success,
        hasMore: result.hasMore,
      );
      // Mark read
      await _repo.markRead(_chatId);
    } catch (e) {
      state = state.copyWith(
        status: MessageStatus2.error,
        errorMessage: e.toString(),
      );
    }
  }

  // ── Load older messages (pagination: scroll to top) ───────────────────────
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
      if (result.items.isNotEmpty) {
        _lastMessage = result.items.last.id;
      }
      // Prepend older messages (reversed so oldest appears at top).
      final older = result.items.reversed.toList();
      state = state.copyWith(
        messages: [...older, ...state.messages],
        status: MessageStatus2.success,
        hasMore: result.hasMore,
      );
    } catch (_) {
      state = state.copyWith(status: MessageStatus2.success);
    }
  }

  // ── Send text ─────────────────────────────────────────────────────────────
  Future<void> sendText(String text, {String? currentUserId}) async {
    if (text.trim().isEmpty) return;
    final tempId = _uuid.v4();
    final replyTo = state.replyTo;
    final optimistic = MessageModel(
      id: tempId,
      chatId: _chatId,
      senderId: currentUserId ?? '',
      contentType: ContentType.text,
      text: text.trim(),
      status: MessageStatus.sending,
      fromMe: true,
      createdAt: DateTime.now().toIso8601String(),
      replyToId: replyTo?.id,
      replyToMessage: replyTo,
    );

    // Append optimistic message instantly.
    state = state.copyWith(
      messages: [...state.messages, optimistic],
      isSending: true,
      clearReplyTo: true,
    );

    try {
      final sent = await _repo.sendMessage(
        chatId: _chatId,
        chatType: _chatType,
        contentType: 'text',
        text: text.trim(),
        replyToId: replyTo?.id,
      );
      // Replace temp message with the real one.
      state = state.copyWith(
        messages: state.messages
            .map((m) => m.id == tempId
                ? sent.copyWith(fromMe: true, status: MessageStatus.sent)
                : m)
            .toList(),
        isSending: false,
      );
    } catch (_) {
      // Mark as failed.
      state = state.copyWith(
        messages: state.messages
            .map((m) =>
                m.id == tempId ? m.copyWith(status: MessageStatus.failed) : m)
            .toList(),
        isSending: false,
      );
    }
  }

  // ── Reply ─────────────────────────────────────────────────────────────────
  void setReplyTo(MessageModel? message) {
    state = message == null
        ? state.copyWith(clearReplyTo: true)
        : state.copyWith(replyTo: message);
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> deleteMessage(String messageId,
      {bool forEveryone = false}) async {
    // Optimistic soft-delete.
    state = state.copyWith(
      messages: state.messages
          .map((m) => m.id == messageId
              ? m.copyWith(
                  isDeleted: true,
                  status: forEveryone
                      ? MessageStatus.deletedEveryone
                      : m.status)
              : m)
          .toList(),
    );
    try {
      if (forEveryone) {
        await _repo.deleteMessageForEveryone([messageId], chatId: _chatId);
      } else {
        await _repo.deleteMessage([messageId]);
      }
    } catch (_) {
      await _loadInitial(); // revert on failure
    }
  }

  // ── Typing indicator (Socket.io hook — called externally later) ───────────
  void setTyping({required bool typing, String? userId}) {
    state = state.copyWith(isTyping: typing, typingUserId: userId);
  }
}

/// Family provider — one per chatId so each chat screen has its own state.
final messageViewModelProvider =
    NotifierProviderFamily<MessageViewModel, MessageState, String>(
        MessageViewModel.new);
