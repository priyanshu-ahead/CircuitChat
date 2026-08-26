import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/user_model.dart';

// ── State & ViewModel ─────────────────────────────────────────────────────────

class _NewChatState {
  const _NewChatState({
    this.users = const [],
    this.isLoading = false,
    this.query = '',
  });
  final List<ChatModel> users;
  final bool isLoading;
  final String query;

  _NewChatState copyWith({
    List<ChatModel>? users,
    bool? isLoading,
    String? query,
  }) =>
      _NewChatState(
        users: users ?? this.users,
        isLoading: isLoading ?? this.isLoading,
        query: query ?? this.query,
      );
}

class _NewChatNotifier extends Notifier<_NewChatState> {
  @override
  _NewChatState build() {
    _search('');
    return const _NewChatState(isLoading: true);
  }

  Future<void> _search(String query) async {
    state = state.copyWith(isLoading: true, query: query);
    try {
      final raw = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
        ApiEndpoints.chatNewChat,
        queryParameters: {
          if (query.isNotEmpty) 'search': query,
        },
      );
      final items =
          (raw['chats'] as List? ?? raw['data'] as List? ?? [])
              .whereType<Map<String, dynamic>>()
              .map((e) => ChatModel.fromJson(e))
              .toList();
      state = state.copyWith(users: items, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void setQuery(String q) => _search(q);
}

final _newChatProvider =
    NotifierProvider<_NewChatNotifier, _NewChatState>(
        _NewChatNotifier.new);

// ── Screen ────────────────────────────────────────────────────────────────────

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() =>
      _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      ref
          .read(_newChatProvider.notifier)
          .setQuery(_searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    final state = ref.watch(_newChatProvider);

    return Scaffold(
      backgroundColor: cc.pageBackground,
      appBar: AppBar(
        backgroundColor: cc.pageBackground,
        foregroundColor: cc.primaryText,
        elevation: 0.5,
        title: Text(
          'New Chat',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: cc.primaryText),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: cc.primaryText),
              decoration: InputDecoration(
                hintText: 'Search contacts…',
                hintStyle: TextStyle(color: cc.secondaryText, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded,
                    color: cc.secondaryText),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: cc.secondaryText),
                        onPressed: () {
                          _searchCtrl.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: cc.searchBackground,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // List
          Expanded(
            child: state.isLoading
                ? Center(child: CircularProgressIndicator(color: primary))
                : state.users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search_rounded,
                                size: 56,
                                color: cc.secondaryText),
                            const SizedBox(height: 12),
                            Text('No contacts found',
                                style: TextStyle(
                                    color: cc.secondaryText,
                                    fontSize: 15)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: state.users.length,
                        itemBuilder: (_, i) {
                          final chat = state.users[i];
                          return _ContactTile(
                            chat: chat,
                            onTap: () => context.push(
                              Routes.chatDetailPath(chat.id),
                              extra: chat,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.chat,
    required this.onTap,
  });
  final ChatModel chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return ListTile(
      onTap: onTap,
      leading: _buildAvatar(context),
      title: Text(
        chat.name ?? 'Unknown',
        style: TextStyle(fontWeight: FontWeight.w500, color: cc.primaryText),
      ),
      subtitle: chat.members.isNotEmpty &&
              chat.members.first.bio != null
          ? Text(
              chat.members.first.bio!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, color: cc.secondaryText),
            )
          : null,
      trailing: chat.isOnline
          ? const CircleAvatar(
              radius: 5,
              backgroundColor: Color(0xFF43A047),
            )
          : null,
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final url = chat.avatar;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: CachedNetworkImageProvider(url),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: primary,
      child: Text(
        (chat.name ?? '?')[0].toUpperCase(),
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}
