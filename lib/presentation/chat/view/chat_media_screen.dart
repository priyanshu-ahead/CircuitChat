import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/message_model.dart';

// ── State & ViewModel ─────────────────────────────────────────────────────────

enum MediaTab { media, links, docs }

class _MediaState {
  const _MediaState({
    this.items = const [],
    this.hasMore = true,
    this.isLoading = false,
  });
  final List<MessageModel> items;
  final bool hasMore;
  final bool isLoading;

  _MediaState copyWith({
    List<MessageModel>? items,
    bool? hasMore,
    bool? isLoading,
  }) =>
      _MediaState(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        isLoading: isLoading ?? this.isLoading,
      );
}

class _ChatMediaNotifier
    extends FamilyNotifier<Map<MediaTab, _MediaState>, ChatModel> {
  @override
  Map<MediaTab, _MediaState> build(ChatModel arg) {
    _chat = arg;
    _loadTab(MediaTab.media);
    return {
      MediaTab.media: const _MediaState(isLoading: true),
      MediaTab.links: const _MediaState(),
      MediaTab.docs: const _MediaState(),
    };
  }

  late final ChatModel _chat;

  static String _mediaTypeString(MediaTab tab) {
    switch (tab) {
      case MediaTab.media:
        return 'media';
      case MediaTab.links:
        return 'link';
      case MediaTab.docs:
        return 'docs';
    }
  }

  static String _chatTypeString(ChatType t) =>
      t == ChatType.group ? '1' : '0';

  Future<void> _loadTab(MediaTab tab, {bool loadMore = false}) async {
    final current = state[tab]!;
    if (current.isLoading || (!current.hasMore && loadMore)) return;

    state = {...state, tab: current.copyWith(isLoading: true)};

    try {
      final lastId = loadMore && current.items.isNotEmpty
          ? current.items.last.id
          : null;

      final url = ApiEndpoints.messageMediaList(
        _chat.id,
        _chatTypeString(_chat.type),
        _mediaTypeString(tab),
      );

      final raw = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
        url,
        queryParameters: {
          'limit': 30,
          if (lastId != null) 'lastMessage': lastId,
        },
      );

      final newItems = (raw['messages'] as List? ?? raw['data'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((e) => MessageModel.fromJson(e))
          .toList();

      final merged = loadMore
          ? [...current.items, ...newItems]
          : newItems;

      state = {
        ...state,
        tab: _MediaState(
          items: merged,
          hasMore: raw['more'] == true,
          isLoading: false,
        ),
      };
    } catch (_) {
      state = {
        ...state,
        tab: current.copyWith(isLoading: false, hasMore: false),
      };
    }
  }

  void switchTab(MediaTab tab) {
    final s = state[tab]!;
    if (s.items.isEmpty && !s.isLoading) {
      _loadTab(tab);
    }
  }

  void loadMore(MediaTab tab) => _loadTab(tab, loadMore: true);
}

final _chatMediaProvider = NotifierProviderFamily<_ChatMediaNotifier,
    Map<MediaTab, _MediaState>, ChatModel>(_ChatMediaNotifier.new);

// ── Screen ────────────────────────────────────────────────────────────────────

class ChatMediaScreen extends ConsumerStatefulWidget {
  const ChatMediaScreen({super.key, required this.chat});
  final ChatModel chat;

  @override
  ConsumerState<ChatMediaScreen> createState() => _ChatMediaScreenState();
}

class _ChatMediaScreenState extends ConsumerState<ChatMediaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        final tab = MediaTab.values[_tabCtrl.index];
        ref
            .read(_chatMediaProvider(widget.chat).notifier)
            .switchTab(tab);
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allState = ref.watch(_chatMediaProvider(widget.chat));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text(
          'Media, Links & Docs',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF1976D2),
          unselectedLabelColor: const Color(0xFF888888),
          indicatorColor: const Color(0xFF1976D2),
          tabs: const [
            Tab(text: 'Media'),
            Tab(text: 'Links'),
            Tab(text: 'Docs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _MediaGrid(
            state: allState[MediaTab.media]!,
            onLoadMore: () => ref
                .read(_chatMediaProvider(widget.chat).notifier)
                .loadMore(MediaTab.media),
          ),
          _LinksList(
            state: allState[MediaTab.links]!,
            onLoadMore: () => ref
                .read(_chatMediaProvider(widget.chat).notifier)
                .loadMore(MediaTab.links),
          ),
          _DocsList(
            state: allState[MediaTab.docs]!,
            onLoadMore: () => ref
                .read(_chatMediaProvider(widget.chat).notifier)
                .loadMore(MediaTab.docs),
          ),
        ],
      ),
    );
  }
}

// ── Media Grid (photos + videos) ──────────────────────────────────────────────

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.state, required this.onLoadMore});
  final _MediaState state;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!state.isLoading && state.items.isEmpty) {
      return const _EmptyView(
          icon: Icons.photo_library_outlined, label: 'No photos or videos');
    }

    // Group by date
    final grouped = <String, List<MessageModel>>{};
    for (final m in state.items) {
      final key = _dayKey(m.createdAt);
      grouped.putIfAbsent(key, () => []).add(m);
    }
    final days = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.extentAfter < 200 &&
            state.hasMore &&
            !state.isLoading) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(4),
        itemCount: days.length + (state.isLoading ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == days.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final day = days[i];
          final msgs = grouped[day]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                child: Text(
                  _formatDay(day),
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF888888),
                      fontWeight: FontWeight.w500),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: msgs.length,
                itemBuilder: (_, j) => _MediaCell(message: msgs[j]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MediaCell extends StatelessWidget {
  const _MediaCell({required this.message});
  final MessageModel message;

  @override
  Widget build(BuildContext context) {
    final isVideo = message.contentType == ContentType.video;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (message.mediaUrl != null)
          CachedNetworkImage(
            imageUrl: message.mediaUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                const ColoredBox(color: Color(0xFFEEEEEE)),
            errorWidget: (_, __, ___) =>
                const ColoredBox(color: Color(0xFFEEEEEE)),
          )
        else
          const ColoredBox(color: Color(0xFFEEEEEE)),
        if (isVideo)
          const Center(
            child: Icon(Icons.play_circle_filled_rounded,
                color: Colors.white70, size: 32),
          ),
      ],
    );
  }
}

// ── Links List ────────────────────────────────────────────────────────────────

class _LinksList extends StatelessWidget {
  const _LinksList({required this.state, required this.onLoadMore});
  final _MediaState state;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!state.isLoading && state.items.isEmpty) {
      return const _EmptyView(
          icon: Icons.link_rounded, label: 'No links shared');
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.extentAfter < 200 &&
            state.hasMore &&
            !state.isLoading) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.separated(
        itemCount: state.items.length + (state.isLoading ? 1 : 0),
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (_, i) {
          if (i == state.items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final msg = state.items[i];
          final url = msg.text ?? msg.mediaUrl ?? '';
          return ListTile(
            leading: const Icon(Icons.link_rounded,
                color: Color(0xFF1976D2)),
            title: Text(
              url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFF1976D2),
                  decoration: TextDecoration.underline,
                  fontSize: 13),
            ),
            subtitle: Text(
              _formatDate(msg.createdAt),
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF888888)),
            ),
            onTap: () async {
              final uri = Uri.tryParse(url);
              if (uri != null) await launchUrl(uri);
            },
          );
        },
      ),
    );
  }
}

// ── Docs List ─────────────────────────────────────────────────────────────────

class _DocsList extends StatelessWidget {
  const _DocsList({required this.state, required this.onLoadMore});
  final _MediaState state;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!state.isLoading && state.items.isEmpty) {
      return const _EmptyView(
          icon: Icons.insert_drive_file_outlined,
          label: 'No files shared');
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.extentAfter < 200 &&
            state.hasMore &&
            !state.isLoading) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.separated(
        itemCount: state.items.length + (state.isLoading ? 1 : 0),
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 64, endIndent: 16),
        itemBuilder: (_, i) {
          if (i == state.items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final msg = state.items[i];
          final fileName = msg.mediaUrl?.split('/').last ?? 'file';
          final sizeKb = msg.mediaSize != null
              ? '${(msg.mediaSize! / 1024).toStringAsFixed(1)} KB'
              : '';
          return ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.insert_drive_file_rounded,
                  color: Color(0xFF1976D2)),
            ),
            title: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${_formatDate(msg.createdAt)}${sizeKb.isNotEmpty ? '  •  $sizeKb' : ''}',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF888888)),
            ),
            trailing: const Icon(Icons.download_outlined,
                color: Color(0xFF888888)),
            onTap: () async {
              final url = msg.mediaUrl;
              if (url != null) {
                final uri = Uri.tryParse(url);
                if (uri != null) await launchUrl(uri);
              }
            },
          );
        },
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: const Color(0xFFCCCCCC)),
          const SizedBox(height: 12),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFFAAAAAA), fontSize: 15)),
        ],
      ),
    );
  }
}

String _dayKey(String iso) {
  try {
    final d = DateTime.parse(iso).toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}

String _formatDay(String dayKey) {
  try {
    final d = DateTime.parse(dayKey);
    final now = DateTime.now();
    if (d.year == now.year &&
        d.month == now.month &&
        d.day == now.day) return 'Today';
    return DateFormat('MMM d, yyyy').format(d);
  } catch (_) {
    return dayKey;
  }
}

String _formatDate(String iso) {
  try {
    return DateFormat('MMM d, yyyy').format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}
