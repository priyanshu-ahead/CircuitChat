import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/repositories/chat_repository.dart';

// ── State & ViewModel ─────────────────────────────────────────────────────────

enum _ArchiveStatus { loading, success, error }

class _ArchiveState {
  const _ArchiveState({
    this.chats = const [],
    this.status = _ArchiveStatus.loading,
    this.hasMore = true,
  });
  final List<ChatModel> chats;
  final _ArchiveStatus status;
  final bool hasMore;

  bool get isLoading => status == _ArchiveStatus.loading;

  _ArchiveState copyWith({
    List<ChatModel>? chats,
    _ArchiveStatus? status,
    bool? hasMore,
  }) =>
      _ArchiveState(
        chats: chats ?? this.chats,
        status: status ?? this.status,
        hasMore: hasMore ?? this.hasMore,
      );
}

class _ArchiveNotifier extends Notifier<_ArchiveState> {
  @override
  _ArchiveState build() {
    _load();
    return const _ArchiveState();
  }

  String? _lastMessage;
  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      _lastMessage = null;
      state = const _ArchiveState();
    }
    try {
      final result = await _repo.fetchChats(FetchChatsParams(
        archive: true,
        lastMessage: _lastMessage,
      ));
      if (result.items.isNotEmpty) {
        _lastMessage = result.items.last.lastMessage?.id;
      }
      state = state.copyWith(
        chats: refresh
            ? result.items
            : [...state.chats, ...result.items],
        status: _ArchiveStatus.success,
        hasMore: result.hasMore,
      );
    } catch (_) {
      state = state.copyWith(status: _ArchiveStatus.error);
    }
  }

  Future<void> refresh() => _load(refresh: true);
  Future<void> loadMore() {
    if (!state.hasMore || state.isLoading) {
      return Future.value();
    }
    return _load();
  }

  Future<void> unarchiveChat(String chatId) async {
    state = state.copyWith(
      chats: state.chats.where((c) => c.id != chatId).toList(),
    );
    await _repo.unarchiveChat(chatId);
  }
}

final _archiveProvider =
    NotifierProvider<_ArchiveNotifier, _ArchiveState>(
        _ArchiveNotifier.new);

// ── Screen ────────────────────────────────────────────────────────────────────

class ArchivedChatsScreen extends ConsumerStatefulWidget {
  const ArchivedChatsScreen({super.key});

  @override
  ConsumerState<ArchivedChatsScreen> createState() =>
      _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState
    extends ConsumerState<ArchivedChatsScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(_archiveProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_archiveProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text(
          'Archived Chats',
          style:
              TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      body: state.isLoading && state.chats.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.chats.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.archive_outlined,
                          size: 56, color: Color(0xFFCCCCCC)),
                      SizedBox(height: 12),
                      Text('No archived chats',
                          style: TextStyle(
                              color: Color(0xFFAAAAAA),
                              fontSize: 15)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(_archiveProvider.notifier).refresh(),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    itemCount: state.chats.length +
                        (state.hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == state.chats.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                              child: CircularProgressIndicator()),
                        );
                      }
                      final chat = state.chats[i];
                      return _ArchiveChatTile(
                        chat: chat,
                        onTap: () => context.push(
                          Routes.chatDetail
                              .replaceFirst(':chatId', chat.id),
                          extra: chat,
                        ),
                        onUnarchive: () => ref
                            .read(_archiveProvider.notifier)
                            .unarchiveChat(chat.id),
                      );
                    },
                  ),
                ),
    );
  }
}

class _ArchiveChatTile extends StatelessWidget {
  const _ArchiveChatTile({
    required this.chat,
    required this.onTap,
    required this.onUnarchive,
  });

  final ChatModel chat;
  final VoidCallback onTap;
  final VoidCallback onUnarchive;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('archive_${chat.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: const Color(0xFF1976D2),
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.unarchive_rounded, color: Colors.white),
            Text('Unarchive',
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onUnarchive();
        return false; // ViewModel handles removal
      },
      child: ListTile(
        onTap: onTap,
        leading: _buildAvatar(),
        title: Text(
          chat.name ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: chat.lastMessage != null
            ? Text(
                _previewText(chat.lastMessage!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF888888)),
              )
            : null,
        trailing: chat.lastMessage?.createdAt != null
            ? Text(
                _formatTime(chat.lastMessage!.createdAt),
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF888888)),
              )
            : null,
      ),
    );
  }

  Widget _buildAvatar() {
    final url = chat.avatar;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: CachedNetworkImageProvider(url),
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF1976D2),
      child: Text(
        (chat.name ?? '?')[0].toUpperCase(),
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _previewText(dynamic msg) {
    if (msg == null) return '';
    if (msg.text != null && msg.text!.isNotEmpty) return msg.text!;
    return '📎 Attachment';
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day) {
        return DateFormat('h:mm a').format(dt);
      }
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return '';
    }
  }
}
