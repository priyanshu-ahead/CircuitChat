import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/services/socket_service.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/message_model.dart';
import '../../../data/repositories/chat_repository.dart';

// ── Filter enum ────────────────────────────────────────────────────────────────
enum ChatFilter { all, unread, group }

// ── State ─────────────────────────────────────────────────────────────────────
class ChatListState {
  const ChatListState({
    this.chats = const [],
    this.status = ChatListStatus.initial,
    this.filter = ChatFilter.all,
    this.searchQuery = '',
    this.hasMore = true,
    this.archiveCount = 0,
    this.errorMessage,
  });

  final List<ChatModel> chats;
  final ChatListStatus status;
  final ChatFilter filter;
  final String searchQuery;
  final bool hasMore;
  final int archiveCount;
  final String? errorMessage;

  bool get isLoading => status == ChatListStatus.loading;
  bool get isLoadingMore => status == ChatListStatus.loadingMore;

  /// Filtered view used by the UI (search is applied server-side on first page
  /// but also client-side for instant feedback on already-loaded items).
  List<ChatModel> get filtered {
    var list = chats;
    switch (filter) {
      case ChatFilter.unread:
        list = list.where((c) => c.unreadCount > 0).toList();
        break;
      case ChatFilter.group:
        list = list.where((c) => c.type == ChatType.group).toList();
        break;
      case ChatFilter.all:
        break;
    }
    final q = searchQuery.toLowerCase().trim();
    if (q.isNotEmpty) {
      list = list
          .where((c) => (c.name ?? '').toLowerCase().contains(q))
          .toList();
    }
    // Pinned chats always float to top.
    list.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return 0;
    });
    return list;
  }

  ChatListState copyWith({
    List<ChatModel>? chats,
    ChatListStatus? status,
    ChatFilter? filter,
    String? searchQuery,
    bool? hasMore,
    int? archiveCount,
    String? errorMessage,
  }) =>
      ChatListState(
        chats: chats ?? this.chats,
        status: status ?? this.status,
        filter: filter ?? this.filter,
        searchQuery: searchQuery ?? this.searchQuery,
        hasMore: hasMore ?? this.hasMore,
        archiveCount: archiveCount ?? this.archiveCount,
        errorMessage: errorMessage,
      );
}

enum ChatListStatus { initial, loading, success, loadingMore, error }

// ── ViewModel ─────────────────────────────────────────────────────────────────
class ChatListViewModel extends Notifier<ChatListState> {
  late final void Function(dynamic) _newMessageListener;
  late final void Function(dynamic) _onlineListener;
  late final void Function(dynamic) _offlineListener;
  late final void Function(dynamic) _userStatusListener;
  late final void Function(dynamic) _markReadListener;

  @override
  ChatListState build() {
    // Do NOT auto-load here. The screen calls loadOnce() from initState()
    // so that IndexedStack doesn't trigger all 4 tabs simultaneously.
    _newMessageListener = _onNewMessage;
    _onlineListener = _onOnline;
    _offlineListener = _onOffline;
    _userStatusListener = _onUserStatus;
    _markReadListener = _onMarkRead;
    _subscribeSocket();
    ref.onDispose(_unsubscribeSocket);
    return const ChatListState(status: ChatListStatus.initial);
  }

  bool _loaded = false;

  /// Called by the screen on first mount. Safe to call multiple times —
  /// only fetches on the first call; subsequent calls are no-ops unless
  /// [refresh] is true.
  Future<void> loadOnce() async {
    if (_loaded) return;
    _loaded = true;
    await _load();
  }

  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  SocketService  get _socket => SocketService.instance;

  // ── Socket ────────────────────────────────────────────────────────────────

  void _subscribeSocket() {
    _socket.on(SocketEvents.newMessage, _newMessageListener);
    _socket.on(SocketEvents.online, _onlineListener);
    _socket.on(SocketEvents.offline, _offlineListener);
    _socket.on(SocketEvents.userStatus, _userStatusListener);
    _socket.on(SocketEvents.markRead, _markReadListener);
  }

  void _unsubscribeSocket() {
    _socket.off(SocketEvents.newMessage, _newMessageListener);
    _socket.off(SocketEvents.online, _onlineListener);
    _socket.off(SocketEvents.offline, _offlineListener);
    _socket.off(SocketEvents.userStatus, _userStatusListener);
    _socket.off(SocketEvents.markRead, _markReadListener);
  }

  void _onNewMessage(dynamic data) {
    if (data is! Map) return;
    final chatId = data['chat']?.toString() ?? data['chatId']?.toString();
    if (chatId == null) return;
    // Update last message & increment unread for the relevant chat
    final msgRaw = data is Map<String, dynamic>
        ? data : Map<String, dynamic>.from(data as Map);
    final msg = MessageModel.fromJson(msgRaw);
    _updateChat(chatId, (c) => c.copyWith(
      lastMessage: msg,
      unreadCount: c.unreadCount + 1,
    ));
    // Bubble to top (re-sort happens via pinned sort in filtered getter)
    state = state.copyWith(
      chats: [
        ...state.chats.where((c) => c.id == chatId),
        ...state.chats.where((c) => c.id != chatId),
      ],
    );
  }

  bool _isDirectPeer(ChatModel c, String userId) {
    if (c.type != ChatType.direct) return false;
    return c.id == userId || c.members.any((m) => m.id == userId);
  }

  void _setPeerOnline(String userId, bool online) {
    state = state.copyWith(
      chats: state.chats
          .map((c) => _isDirectPeer(c, userId) ? c.copyWith(isOnline: online) : c)
          .toList(),
    );
  }

  void _onOnline(dynamic data) {
    if (data is! Map) return;
    final userId = data['userId']?.toString() ??
        data['user']?.toString() ??
        data['_id']?.toString();
    if (userId == null) return;
    _setPeerOnline(userId, true);
  }

  void _onOffline(dynamic data) {
    if (data is! Map) return;
    final userId = data['userId']?.toString() ??
        data['user']?.toString() ??
        data['_id']?.toString();
    if (userId == null) return;
    _setPeerOnline(userId, false);
  }

  void _onUserStatus(dynamic data) {
    if (data is! Map) return;
    final userId = (data['_id'] ?? data['id'] ?? data['userId'])?.toString();
    if (userId == null || userId.isEmpty) return;
    final active = data['active'] == true ||
        data['active'] == 1 ||
        data['active'] == '1';
    _setPeerOnline(userId, active);
  }

  void _onMarkRead(dynamic data) {
    if (data is! Map) return;
    final chatId = data['chatId']?.toString() ?? data['chat']?.toString();
    if (chatId == null) return;
    _updateChat(chatId, (c) => c.copyWith(unreadCount: 0));
  }

  // Cursor for pagination (the _id of the last fetched chat's last message).
  String? _lastMessage;

  // ── Initial load / refresh ─────────────────────────────────────────────────
  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      _lastMessage = null;
      state = state.copyWith(
          status: ChatListStatus.loading, chats: [], hasMore: true);
    }
    try {
      final result = await _repo.fetchChats(FetchChatsParams(
        archive: false,
        unread: state.filter == ChatFilter.unread,
        group: state.filter == ChatFilter.group,
        lastMessage: _lastMessage,
      ));
      if (result.items.isNotEmpty) {
        final last = result.items.last.lastMessage;
        _lastMessage = last?.id;
      }
      final archiveCount = await _repo.getArchiveCount();
      state = state.copyWith(
        chats: refresh ? result.items : [...state.chats, ...result.items],
        status: ChatListStatus.success,
        hasMore: result.hasMore,
        archiveCount: archiveCount,
      );
    } catch (e) {
      state = state.copyWith(
        status: ChatListStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refresh() => _load(refresh: true);

  // ── Load more (pagination) ─────────────────────────────────────────────────
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(status: ChatListStatus.loadingMore);
    try {
      final result = await _repo.fetchChats(FetchChatsParams(
        archive: false,
        lastMessage: _lastMessage,
      ));
      if (result.items.isNotEmpty) {
        _lastMessage = result.items.last.lastMessage?.id;
      }
      state = state.copyWith(
        chats: [...state.chats, ...result.items],
        status: ChatListStatus.success,
        hasMore: result.hasMore,
      );
    } catch (_) {
      state = state.copyWith(status: ChatListStatus.success);
    }
  }

  // ── Filter & search ────────────────────────────────────────────────────────
  void setFilter(ChatFilter filter) {
    if (state.filter == filter) return;
    state = state.copyWith(filter: filter);
    _load(refresh: true);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  // ── Chat mutations ─────────────────────────────────────────────────────────
  Future<void> pinChat(String chatId) async {
    _updateChat(chatId, (c) => c.copyWith(isPinned: true));
    try {
      await _repo.pinChat(chatId);
    } catch (_) {
      _updateChat(chatId, (c) => c.copyWith(isPinned: false));
    }
  }

  Future<void> unpinChat(String chatId) async {
    _updateChat(chatId, (c) => c.copyWith(isPinned: false));
    try {
      await _repo.unpinChat(chatId);
    } catch (_) {
      _updateChat(chatId, (c) => c.copyWith(isPinned: true));
    }
  }

  Future<void> archiveChat(String chatId) async {
    _removeChat(chatId);
    try {
      await _repo.archiveChat(chatId);
    } catch (_) {
      await refresh();
    }
  }

  Future<void> unarchiveChat(String chatId) async {
    try {
      await _repo.unarchiveChat(chatId);
    } catch (_) {}
  }

  Future<void> deleteChat(String chatId, String chatType) async {
    _removeChat(chatId);
    try {
      await _repo.deleteChat(chatId, chatType);
    } catch (_) {
      await refresh();
    }
  }

  Future<void> markRead(String chatId) async {
    _updateChat(chatId, (c) => c.copyWith(unreadCount: 0));
    final chatType = state.chats
        .firstWhere((c) => c.id == chatId,
            orElse: () => const ChatModel(id: '', type: ChatType.direct))
        .type == ChatType.group ? 'group' : 'user';
    await _repo.markRead(chatId, chatType);
  }

  Future<void> muteChat(String chatId) async {
    _updateChat(chatId, (c) => c.copyWith(isMuted: true));
    await _repo.muteChat(chatId);
  }

  Future<void> unmuteChat(String chatId) async {
    _updateChat(chatId, (c) => c.copyWith(isMuted: false));
    await _repo.unmuteChat(chatId);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _updateChat(String chatId, ChatModel Function(ChatModel) update) {
    state = state.copyWith(
      chats: state.chats.map((c) => c.id == chatId ? update(c) : c).toList(),
    );
  }

  void _removeChat(String chatId) {
    state = state.copyWith(
      chats: state.chats.where((c) => c.id != chatId).toList(),
    );
  }
}

final chatListViewModelProvider =
    NotifierProvider<ChatListViewModel, ChatListState>(
        ChatListViewModel.new);
