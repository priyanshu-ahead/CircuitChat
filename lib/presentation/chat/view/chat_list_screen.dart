import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/user_model.dart';
import '../../../presentation/common/widgets/active_users_carousel.dart';
import '../../../presentation/common/widgets/shimmer_list.dart';
import '../viewmodel/chat_list_viewmodel.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(() {
      ref
          .read(chatListViewModelProvider.notifier)
          .setSearchQuery(_searchCtrl.text);
    });
    // Lazy-load: only fetch when this screen actually mounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatListViewModelProvider.notifier).loadOnce();
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(chatListViewModelProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatListViewModelProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(state),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(Routes.newChat),
        backgroundColor: const Color(0xFF1976D2),
        shape: const CircleBorder(),
        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  // ── Header: title + search + filter chips ─────────────────────────────────
  Widget _buildHeader(ChatListState state) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Chats',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
              if (state.archiveCount > 0)
                TextButton.icon(
                  onPressed: () => context.push(Routes.archivedChats),
                  icon: const Icon(Icons.archive_outlined,
                      size: 18, color: Color(0xFF1976D2)),
                  label: Text(
                    'Archived (${state.archiveCount})',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF1976D2)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Search bar
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search chats…',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon:
                  Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
              suffixIcon: state.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        ref
                            .read(chatListViewModelProvider.notifier)
                            .setSearchQuery('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF2F4F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          // ── Online users strip (mirrors RN ActiveUsers between search & filter tabs)
          ActiveUsersCarousel(
            onTap: (UserModel user) {
              final chat = ChatModel(
                id:     user.id,
                type:   ChatType.direct,
                name:   user.name,
                avatar: user.avatar,
              );
              context.push(Routes.chatDetail, extra: chat);
            },
          ),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
            child: Row(
              children: [
                const SizedBox(width: 16),
                _FilterChip(
                  label: 'All',
                  selected: state.filter == ChatFilter.all,
                  onTap: () => ref
                      .read(chatListViewModelProvider.notifier)
                      .setFilter(ChatFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Unread',
                  selected: state.filter == ChatFilter.unread,
                  onTap: () => ref
                      .read(chatListViewModelProvider.notifier)
                      .setFilter(ChatFilter.unread),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Groups',
                  selected: state.filter == ChatFilter.group,
                  onTap: () => ref
                      .read(chatListViewModelProvider.notifier)
                      .setFilter(ChatFilter.group),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody(ChatListState state) {
    if (state.isLoading) {
      return const ChatListShimmer();
    }

    if (state.status == ChatListStatus.initial) {
      return const SizedBox.shrink(); // not yet mounted — show nothing
    }

    if (state.status == ChatListStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.signal_wifi_off_rounded,
                size: 54, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              state.errorMessage ?? 'Failed to load chats.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(chatListViewModelProvider.notifier).refresh(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2)),
              child: const Text('Retry',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final chats = state.filtered;
    if (chats.isEmpty) {
      return _buildEmptyState(state);
    }

    return RefreshIndicator(
      color: const Color(0xFF1976D2),
      onRefresh: () =>
          ref.read(chatListViewModelProvider.notifier).refresh(),
      child: ListView.separated(
        controller: _scrollCtrl,
        itemCount: chats.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(
          height: 0,
          indent: 72,
          color: Color(0xFFF0F0F0),
        ),
        itemBuilder: (ctx, i) {
          if (i == chats.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child:
                    CircularProgressIndicator(color: Color(0xFF1976D2)),
              ),
            );
          }
          return _ChatTile(
            chat: chats[i],
            onTap: () {
              ref
                  .read(chatListViewModelProvider.notifier)
                  .markRead(chats[i].id);
              context.push(Routes.chatDetail, extra: chats[i]);
            },
            onPin: () => chats[i].isPinned
                ? ref
                    .read(chatListViewModelProvider.notifier)
                    .unpinChat(chats[i].id)
                : ref
                    .read(chatListViewModelProvider.notifier)
                    .pinChat(chats[i].id),
            onArchive: () => ref
                .read(chatListViewModelProvider.notifier)
                .archiveChat(chats[i].id),
            onDelete: () => _confirmDelete(chats[i]),
            onMute: () => chats[i].isMuted
                ? ref
                    .read(chatListViewModelProvider.notifier)
                    .unmuteChat(chats[i].id)
                : ref
                    .read(chatListViewModelProvider.notifier)
                    .muteChat(chats[i].id),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ChatListState state) {
    final isFiltered =
        state.filter != ChatFilter.all || state.searchQuery.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFiltered ? Icons.search_off_rounded : Icons.chat_bubble_outline_rounded,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            isFiltered ? 'No chats match your filter.' : 'No chats yet.\nStart a new conversation!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(ChatModel chat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text('Delete your conversation with ${chat.name ?? 'this chat'}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final chatType =
          chat.type == ChatType.group ? 'group' : 'user';
      ref
          .read(chatListViewModelProvider.notifier)
          .deleteChat(chat.id, chatType);
    }
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE3EEFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF1976D2)
                : const Color(0xFFDDDDDD),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? const Color(0xFF1976D2)
                : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }
}

// ── Chat tile ─────────────────────────────────────────────────────────────────
class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chat,
    required this.onTap,
    required this.onPin,
    required this.onArchive,
    required this.onDelete,
    required this.onMute,
  });

  final ChatModel chat;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onMute;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: () => _showContextMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            _Avatar(chat: chat),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (chat.isPinned) ...[
                        const Icon(Icons.push_pin_rounded,
                            size: 13, color: Color(0xFF9AA6B8)),
                        const SizedBox(width: 3),
                      ],
                      Expanded(
                        child: Text(
                          chat.name ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(chat.lastMessage?.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: chat.unreadCount > 0
                              ? const Color(0xFF1976D2)
                              : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Delivery icon for own last message
                      if (chat.lastMessage?.fromMe == true)
                        Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: _DeliveryIcon(
                              status: chat.lastMessage!.status),
                        ),
                      Expanded(
                        child: Text(
                          _lastMessagePreview(chat.lastMessage),
                          style: TextStyle(
                            fontSize: 13,
                            color: chat.unreadCount > 0
                                ? const Color(0xFF1A1A2E)
                                : Colors.grey[500],
                            fontWeight: chat.unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (chat.isMuted)
                        const Icon(Icons.volume_off_rounded,
                            size: 14, color: Color(0xFF9AA6B8)),
                      if (chat.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: chat.isMuted
                                ? const Color(0xFF9AA6B8)
                                : const Color(0xFF1976D2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${chat.unreadCount > 99 ? '99+' : chat.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(
                chat.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                color: const Color(0xFF1976D2),
              ),
              title: Text(chat.isPinned ? 'Unpin Chat' : 'Pin Chat'),
              onTap: () {
                Navigator.pop(context);
                onPin();
              },
            ),
            ListTile(
              leading: Icon(
                chat.isMuted
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: const Color(0xFF1976D2),
              ),
              title: Text(chat.isMuted ? 'Unmute' : 'Mute'),
              onTap: () {
                Navigator.pop(context);
                onMute();
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined,
                  color: Color(0xFF1976D2)),
              title: const Text('Archive Chat'),
              onTap: () {
                Navigator.pop(context);
                onArchive();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444)),
              title: const Text('Delete Chat',
                  style: TextStyle(color: Color(0xFFEF4444))),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day &&
          dt.month == now.month &&
          dt.year == now.year) {
        return DateFormat('h:mm a').format(dt);
      }
      final yesterday = now.subtract(const Duration(days: 1));
      if (dt.day == yesterday.day &&
          dt.month == yesterday.month &&
          dt.year == yesterday.year) {
        return 'Yesterday';
      }
      if (now.difference(dt).inDays < 7) {
        return DateFormat('EEE').format(dt);
      }
      return DateFormat('d/M/yy').format(dt);
    } catch (_) {
      return '';
    }
  }

  static String _lastMessagePreview(MessageModel? msg) {
    if (msg == null) return '';
    if (msg.isDeleted) return 'This message was deleted';
    switch (msg.contentType) {
      case ContentType.image:
        return '📷 Photo';
      case ContentType.video:
        return '🎥 Video';
      case ContentType.audio:
        return '🎵 Audio';
      case ContentType.file:
        return '📎 File';
      case ContentType.location:
        return '📍 Location';
      case ContentType.call:
        return '📞 Call';
      case ContentType.sticker:
        return '🎭 Sticker';
      case ContentType.gif:
        return 'GIF';
      default:
        return msg.text ?? '';
    }
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  const _Avatar({required this.chat});
  final ChatModel chat;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: const Color(0xFFDDE4EF),
          backgroundImage:
              chat.avatar != null ? NetworkImage(chat.avatar!) : null,
          child: chat.avatar == null
              ? Icon(
                  chat.type == ChatType.group
                      ? Icons.group_rounded
                      : Icons.person_rounded,
                  color: const Color(0xFF9AA6B8),
                  size: 26,
                )
              : null,
        ),
        if (chat.isOnline && chat.type == ChatType.direct)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Delivery status icon ──────────────────────────────────────────────────────
class _DeliveryIcon extends StatelessWidget {
  const _DeliveryIcon({required this.status});
  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time_rounded,
            size: 13, color: Color(0xFF9AA6B8));
      case MessageStatus.sent:
        return const Icon(Icons.check_rounded,
            size: 14, color: Color(0xFF9AA6B8));
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded,
            size: 14, color: Color(0xFF9AA6B8));
      case MessageStatus.seen:
        return const Icon(Icons.done_all_rounded,
            size: 14, color: Color(0xFF1976D2));
      case MessageStatus.failed:
        return const Icon(Icons.error_outline_rounded,
            size: 13, color: Color(0xFFEF4444));
      default:
        return const SizedBox.shrink();
    }
  }
}
