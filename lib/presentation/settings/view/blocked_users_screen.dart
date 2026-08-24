import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../data/models/user_model.dart';

// ── State & ViewModel ─────────────────────────────────────────────────────────

class _BlockedState {
  const _BlockedState({
    this.users = const [],
    this.isLoading = true,
    this.actionUserId,
  });
  final List<UserModel> users;
  final bool isLoading;
  final String? actionUserId; // user currently being unblocked

  _BlockedState copyWith({
    List<UserModel>? users,
    bool? isLoading,
    String? actionUserId,
    bool clearAction = false,
  }) =>
      _BlockedState(
        users: users ?? this.users,
        isLoading: isLoading ?? this.isLoading,
        actionUserId:
            clearAction ? null : actionUserId ?? this.actionUserId,
      );
}

class _BlockedNotifier extends Notifier<_BlockedState> {
  @override
  _BlockedState build() {
    _load();
    return const _BlockedState();
  }

  Future<void> _load() async {
    try {
      final raw = await ref
          .read(apiClientProvider)
          .get<dynamic>(ApiEndpoints.friendBlockedList);
      final list = raw is List
          ? raw
          : (raw is Map ? raw['users'] as List? ?? [] : []);
      final users = list
          .whereType<Map<String, dynamic>>()
          .map((e) => UserModel.fromJson(e))
          .toList();
      state = _BlockedState(users: users, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> unblock(String userId) async {
    state = state.copyWith(actionUserId: userId);
    try {
      await ref.read(apiClientProvider).post<void>(
            ApiEndpoints.friendUnblock,
            data: {'user': userId},
          );
      state = state.copyWith(
        users: state.users.where((u) => u.id != userId).toList(),
        clearAction: true,
      );
    } catch (_) {
      state = state.copyWith(clearAction: true);
    }
  }
}

final _blockedProvider =
    NotifierProvider<_BlockedNotifier, _BlockedState>(
        _BlockedNotifier.new);

// ── Screen ────────────────────────────────────────────────────────────────────

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_blockedProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text(
          'Blocked Users',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.users.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block_rounded,
                          size: 56, color: Color(0xFFCCCCCC)),
                      SizedBox(height: 12),
                      Text(
                        'No blocked users',
                        style: TextStyle(
                            color: Color(0xFFAAAAAA), fontSize: 15),
                      ),
                    ],
                  ),
                )
              : Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4)
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: state.users.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, indent: 66, color: Color(0xFFEEEEEE)),
                    itemBuilder: (_, i) {
                      final user = state.users[i];
                      final isActing =
                          state.actionUserId == user.id;
                      return ListTile(
                        leading: _buildAvatar(user),
                        title: Text(
                          user.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500),
                        ),
                        subtitle: user.bio != null
                            ? Text(
                                user.bio!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF888888)),
                              )
                            : null,
                        trailing: isActing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : TextButton(
                                onPressed: () =>
                                    _confirmUnblock(context, ref, user),
                                child: const Text(
                                  'Unblock',
                                  style: TextStyle(
                                      color: Color(0xFF1976D2)),
                                ),
                              ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildAvatar(UserModel user) {
    if (user.avatar != null && user.avatar!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: CachedNetworkImageProvider(user.avatar!),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFF888888),
      child: Text(
        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _confirmUnblock(
      BuildContext context, WidgetRef ref, UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unblock User'),
        content: Text('Unblock ${user.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Unblock',
                  style: TextStyle(color: Color(0xFF1976D2)))),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(_blockedProvider.notifier).unblock(user.id);
    }
  }
}
