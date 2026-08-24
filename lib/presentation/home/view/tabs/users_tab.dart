import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/router/app_router.dart';
import '../../../../data/models/chat_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../presentation/common/widgets/shimmer_list.dart';
import '../../../chat/viewmodel/chat_list_viewmodel.dart';
import '../../../group/view/create_group_screen.dart';

// ── State & ViewModel ─────────────────────────────────────────────────────────

class _UsersState {
  const _UsersState({
    this.contacts    = const [],
    this.isLoading   = false,
    this.initialized = false,
    this.query       = '',
  });

  final List<ChatModel> contacts;
  final bool            isLoading;
  final bool            initialized;
  final String          query;

  /// Contacts filtered by search query, sorted A→Z by name.
  List<ChatModel> get filtered {
    var list = contacts;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list.where((c) => (c.name ?? '').toLowerCase().contains(q)).toList();
    }
    list = [...list]..sort((a, b) {
        if ((a.name ?? '').isEmpty) return 1;
        if ((b.name ?? '').isEmpty) return -1;
        return (a.name ?? '').compareTo(b.name ?? '');
      });
    return list;
  }

  _UsersState copyWith({
    List<ChatModel>? contacts,
    bool?            isLoading,
    bool?            initialized,
    String?          query,
  }) =>
      _UsersState(
        contacts:    contacts    ?? this.contacts,
        isLoading:   isLoading   ?? this.isLoading,
        initialized: initialized ?? this.initialized,
        query:       query       ?? this.query,
      );
}

class _UsersNotifier extends Notifier<_UsersState> {
  @override
  _UsersState build() => const _UsersState();

  bool _loaded = false;

  Future<void> loadOnce() async {
    if (_loaded) return;
    _loaded = true;
    await _load('');
  }

  Future<void> _load(String query) async {
    state = state.copyWith(isLoading: true);
    try {
      final api = ref.read(apiClientProvider);
      final raw = await api.get<Map<String, dynamic>>(
        ApiEndpoints.chatNewChat,
        queryParameters: query.isNotEmpty ? {'search': query} : null,
      );
      final contacts = (raw['chats'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((e) => ChatModel.fromJson(e))
          .toList();
      state = state.copyWith(
        contacts:    contacts,
        isLoading:   false,
        initialized: true,
        query:       query,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, initialized: true);
    }
  }

  void search(String q) => _load(q);
  void refresh()        => _load(state.query);
}

final _usersProvider =
    NotifierProvider<_UsersNotifier, _UsersState>(_UsersNotifier.new);

// ── Screen ────────────────────────────────────────────────────────────────────

class UsersTab extends ConsumerStatefulWidget {
  const UsersTab({super.key});

  @override
  ConsumerState<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<UsersTab> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => ref.read(_usersProvider.notifier).search(_searchCtrl.text.trim()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_usersProvider.notifier).loadOnce();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_usersProvider);

    // ── Frequently contacted: last 2 unique chats from today ─────────────
    final allChats = ref.watch(
      chatListViewModelProvider.select((s) => s.chats),
    );
    final today = DateTime.now();
    final frequentlyContacted = allChats
        .where((c) {
          if (c.lastMessage == null) return false;
          try {
            final d = DateTime.parse(c.lastMessage!.createdAt).toLocal();
            return d.year == today.year &&
                d.month == today.month &&
                d.day == today.day &&
                !c.isBlocked;
          } catch (_) {
            return false;
          }
        })
        .toList()
      ..sort((a, b) {
          try {
            return DateTime.parse(b.lastMessage!.createdAt)
                .compareTo(DateTime.parse(a.lastMessage!.createdAt));
          } catch (_) {
            return 0;
          }
        })
      ..take(2);
    final frequent = frequentlyContacted.take(2).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Title + search ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('People',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A2E))),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search contacts…',
                  hintStyle:
                      TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: Colors.grey[400], size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            ref.read(_usersProvider.notifier).search('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF2F4F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── List body ──────────────────────────────────────────────────
            Expanded(
              child: !state.initialized
                  ? const SizedBox.shrink()
                  : state.isLoading
                      ? const ChatListShimmer()
                      : RefreshIndicator(
                          color: const Color(0xFF1976D2),
                          onRefresh: () async =>
                              ref.read(_usersProvider.notifier).refresh(),
                          child: ListView(
                            children: [
                              // ── 1. Create New Group ─────────────────────
                              if (state.query.isEmpty) ...[
                                _ListTile(
                                  leading: Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color:
                                          const Color(0xFF1976D2),
                                      borderRadius:
                                          BorderRadius.circular(23),
                                    ),
                                    child: const Icon(
                                        Icons.group_add_rounded,
                                        color: Colors.white,
                                        size: 22),
                                  ),
                                  title: 'New Group',
                                  subtitle: null,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const CreateGroupScreen()),
                                  ),
                                ),
                                const Divider(
                                    height: 1,
                                    indent: 70,
                                    color: Color(0xFFF0F0F0)),
                              ],

                              // ── 2. Frequently Contacted ─────────────────
                              if (state.query.isEmpty &&
                                  frequent.isNotEmpty) ...[
                                _SectionHeader('Frequently Contacted'),
                                ...frequent.map((c) => _ChatContactTile(
                                    chat: c,
                                    onTap: () => context.push(
                                          Routes.chatDetail,
                                          extra: c,
                                        ))),
                              ],

                              // ── 3. Chats section with letter separators ──
                              _SectionHeader('Chats'),
                              if (state.filtered.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(
                                    child: Text('No contacts found',
                                        style: TextStyle(
                                            color: Color(0xFF888888),
                                            fontSize: 14)),
                                  ),
                                )
                              else
                                ..._buildAlphabetList(
                                    state.filtered, context),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // Build contacts list with letter dividers (A, B, C…)
  List<Widget> _buildAlphabetList(
      List<ChatModel> contacts, BuildContext context) {
    final widgets = <Widget>[];
    String? lastLetter;

    for (int i = 0; i < contacts.length; i++) {
      final chat  = contacts[i];
      final name  = chat.name ?? '';
      final letter =
          name.isNotEmpty ? name[0].toUpperCase() : '#';

      if (letter != lastLetter) {
        widgets.add(_LetterDivider(letter: letter));
        lastLetter = letter;
      }

      widgets.add(_ChatContactTile(
        chat: chat,
        onTap: () => context.push(Routes.chatDetail, extra: chat),
      ));
    }
    return widgets;
  }
}

// ── Shared section helpers ────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFF8F8F8),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF888888),
          ),
        ),
      );
}

class _LetterDivider extends StatelessWidget {
  const _LetterDivider({required this.letter});
  final String letter;

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFF8F8F8),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          letter,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF666666),
          ),
        ),
      );
}

class _ListTile extends StatelessWidget {
  const _ListTile({
    required this.leading,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
  final Widget  leading;
  final String  title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1A2E))),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF888888)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFAAAAAA), size: 18),
            ],
          ),
        ),
      );
}

class _ChatContactTile extends StatelessWidget {
  const _ChatContactTile({required this.chat, required this.onTap});
  final ChatModel    chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Avatar with online dot
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: const Color(0xFFDDE4EF),
                      backgroundImage: chat.avatar != null &&
                              chat.avatar!.isNotEmpty
                          ? CachedNetworkImageProvider(chat.avatar!)
                          : null,
                      child: (chat.avatar == null ||
                              chat.avatar!.isEmpty)
                          ? Icon(
                              chat.type == ChatType.group
                                  ? Icons.group_rounded
                                  : Icons.person_rounded,
                              color: const Color(0xFF9AA6B8),
                              size: 22)
                          : null,
                    ),
                    if (chat.isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: const Color(0xFF43A047),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat.name ?? 'Unknown',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1A2E)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (chat.members.isNotEmpty &&
                          chat.members.first.bio != null &&
                          chat.members.first.bio!.isNotEmpty)
                        Text(
                          chat.members.first.bio!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF888888)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(
            height: 1, indent: 70, color: Color(0xFFF0F0F0)),
      ],
    );
  }
}
