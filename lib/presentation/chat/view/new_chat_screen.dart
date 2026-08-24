import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/router/app_router.dart';
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
    final state = ref.watch(_newChatProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text(
          'New Chat',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search contacts…',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFF888888)),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Color(0xFF888888)),
                        onPressed: () {
                          _searchCtrl.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF0F0F0),
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
                ? const Center(child: CircularProgressIndicator())
                : state.users.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search_rounded,
                                size: 56,
                                color: Color(0xFFCCCCCC)),
                            SizedBox(height: 12),
                            Text('No contacts found',
                                style: TextStyle(
                                    color: Color(0xFFAAAAAA),
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
                            onTap: () => context.go(
                              Routes.chatDetail.replaceFirst(
                                  ':chatId', chat.id),
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
    return ListTile(
      onTap: onTap,
      leading: _buildAvatar(),
      title: Text(
        chat.name ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: chat.members.isNotEmpty &&
              chat.members.first.bio != null
          ? Text(
              chat.members.first.bio!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF888888)),
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

  Widget _buildAvatar() {
    final url = chat.avatar;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: CachedNetworkImageProvider(url),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFF1976D2),
      child: Text(
        (chat.name ?? '?')[0].toUpperCase(),
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}
