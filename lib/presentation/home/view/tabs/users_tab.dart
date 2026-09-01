import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
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

  /// Contacts filtered by search query, sorted A→Z by name — mirrors RN's
  /// filterChat.sort((a,b) => a.name.localeCompare(b.name))
  List<ChatModel> get filtered {
    var list = contacts;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list
          .where((c) => (c.name ?? '').toLowerCase().contains(q))
          .toList();
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
      // SE /chat/new-chat returns the array directly (response.data IS the array)
      // Mirrors RN: return { success: true, chats: response.data }
      final raw = await api.get<dynamic>(
        ApiEndpoints.chatNewChat,
        queryParameters: query.isNotEmpty ? {'search': query} : null,
      );

      List<dynamic> rawList;
      if (raw is List) {
        // API returned the array directly — this is the expected case
        rawList = raw;
      } else if (raw is Map<String, dynamic>) {
        // Fallback: wrapped response
        rawList = (raw['chats'] as List?) ??
            (raw['users'] as List?) ??
            (raw['data']  as List?) ??
            [];
      } else {
        rawList = [];
      }

      final contacts = rawList
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
    final cc      = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    final state   = ref.watch(_usersProvider);

    // ── Frequently contacted: today's chats sorted by last message ────────
    // Mirrors RN: filter chats from today, sort by createdAt, take first 2
    final allChats = ref.watch(
      chatListViewModelProvider.select((s) => s.chats),
    );
    final today = DateTime.now();
    final frequent = allChats
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
        });
    final frequentList = frequent.take(2).toList();

    return Scaffold(
      backgroundColor: cc.pageBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title — top left corner ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Text(
                'Users',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: cc.primaryText),
              ),
            ),
            // ── Search bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(color: cc.primaryText),
                decoration: InputDecoration(
                  hintText: 'Search contacts…',
                  hintStyle:
                      TextStyle(color: cc.secondaryText, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: cc.secondaryText, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 18, color: cc.secondaryText),
                          onPressed: () {
                            _searchCtrl.clear();
                            ref.read(_usersProvider.notifier).search('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: cc.searchBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // ── List body ──────────────────────────────────────────────────
            Expanded(
              child: state.isLoading
                  // Show shimmer while loading (not blank)
                  ? const ChatListShimmer()
                  : RefreshIndicator(
                      color: primary,
                      onRefresh: () async =>
                          ref.read(_usersProvider.notifier).refresh(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          // ── Create New Group ─────────────────────────────
                          if (state.query.isEmpty) ...[
                            _ContactTile(
                              leading: CircleAvatar(
                                radius: 23,
                                backgroundColor: primary,
                                child: const Icon(Icons.group_add_rounded,
                                    color: Colors.white, size: 22),
                              ),
                              name: 'New Group',
                              subtitle: null,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const CreateGroupScreen()),
                              ),
                            ),
                          ],

                          // ── Frequently Contacted ─────────────────────────
                          if (state.query.isEmpty &&
                              frequentList.isNotEmpty) ...[
                            _SectionSeparator(
                                label: 'Frequently Contacted', cc: cc),
                            ...frequentList.map((c) => _ChatContactRow(
                                  chat: c,
                                  cc: cc,
                                  onTap: () => context.push(
                                      Routes.chatDetail, extra: c),
                                )),
                          ],

                          // ── Chats (alphabetically grouped) ────────────────
                          _SectionSeparator(label: 'Chats', cc: cc),

                          if (state.filtered.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Text(
                                  state.initialized
                                      ? 'No contacts found'
                                      : 'Loading…',
                                  style: TextStyle(
                                      color: cc.secondaryText,
                                      fontSize: 14),
                                ),
                              ),
                            )
                          else
                            ..._buildAlphabetSections(
                                state.filtered, context, cc),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the alphabetically-grouped contact list.
  /// Mirrors RN's logic:
  ///   index==0 OR name[0] differs from previous name[0] → show letter separator
  List<Widget> _buildAlphabetSections(
      List<ChatModel> contacts, BuildContext context, CircuitChatColors cc) {
    final widgets = <Widget>[];
    String? lastLetter;

    for (int i = 0; i < contacts.length; i++) {
      final chat   = contacts[i];
      final name   = chat.name ?? '';
      final letter = name.isNotEmpty ? name[0].toUpperCase() : '#';

      // New letter group → show separator (mirrors RN searchresultsep)
      if (letter != lastLetter) {
        widgets.add(_AlphabetSeparator(letter: letter, cc: cc));
        lastLetter = letter;
      }

      widgets.add(_ChatContactRow(
        chat: chat,
        cc:   cc,
        onTap: () => context.push(Routes.chatDetail, extra: chat),
      ));
    }
    return widgets;
  }
}

// ── Section separator — shows a label (e.g. "Frequently Contacted") ──────────
// Mirrors RN's searchresultcontainer/searchresulthead row.

class _SectionSeparator extends StatelessWidget {
  const _SectionSeparator({required this.label, required this.cc});
  final String          label;
  final CircuitChatColors cc;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cc.surfaceBackground,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cc.secondaryText,
        ),
      ),
    );
  }
}

// ── Alphabet letter separator — shows a single letter (A, B, C…) ─────────────
// Mirrors RN's searchresultsep with the letter text inside.

class _AlphabetSeparator extends StatelessWidget {
  const _AlphabetSeparator({required this.letter, required this.cc});
  final String          letter;
  final CircuitChatColors cc;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cc.surfaceBackground,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: cc.secondaryText,
        ),
      ),
    );
  }
}

// ── Single contact row — avatar + name + about ────────────────────────────────
// Mirrors RN's chatListItem with avatar, name, and about text.

class _ChatContactRow extends StatelessWidget {
  const _ChatContactRow({
    required this.chat,
    required this.cc,
    required this.onTap,
  });
  final ChatModel       chat;
  final CircuitChatColors cc;
  final VoidCallback    onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // ── Avatar with online indicator ───────────────────────────
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: cc.surfaceBackground,
                      backgroundImage:
                          chat.avatar != null && chat.avatar!.isNotEmpty
                              ? CachedNetworkImageProvider(chat.avatar!)
                              : null,
                      child: (chat.avatar == null || chat.avatar!.isEmpty)
                          ? Icon(
                              chat.type == ChatType.group
                                  ? Icons.group_rounded
                                  : Icons.person_rounded,
                              color: cc.secondaryText,
                              size: 22)
                          : null,
                    ),
                    if (chat.isOnline)
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 11, height: 11,
                          decoration: BoxDecoration(
                            color: const Color(0xFF43A047),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: cc.pageBackground, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // ── Name + about ───────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat.name ?? 'Unknown',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: cc.primaryText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (chat.members.isNotEmpty &&
                          chat.members.first.bio != null &&
                          chat.members.first.bio!.isNotEmpty)
                        Text(
                          chat.members.first.bio!,
                          style: TextStyle(
                              fontSize: 12, color: cc.secondaryText),
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
        Divider(height: 1, indent: 70, color: cc.border),
      ],
    );
  }
}

// ── Generic contact tile (for "New Group" row) ────────────────────────────────

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.leading,
    required this.name,
    this.subtitle,
    required this.onTap,
  });
  final Widget       leading;
  final String       name;
  final String?      subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return Column(
      children: [
        InkWell(
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
                      Text(name,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: cc.primaryText)),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: TextStyle(
                                fontSize: 12, color: cc.secondaryText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, indent: 70, color: cc.border),
      ],
    );
  }
}
