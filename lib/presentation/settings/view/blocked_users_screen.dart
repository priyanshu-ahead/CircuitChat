import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';

// ── State & ViewModel ─────────────────────────────────────────────────────────

class _BlockedState {
  const _BlockedState({
    this.users = const [],
    this.isLoading = false,  // start false
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
    Future.microtask(_load);
    return const _BlockedState(isLoading: true);
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    try {
      // SE /friend/block returns the list directly OR wrapped
      final raw = await ref
          .read(apiClientProvider)
          .get<dynamic>(ApiEndpoints.friendBlockedList);
      List<dynamic> rawList;
      if (raw is List) {
        rawList = raw;
      } else if (raw is Map) {
        rawList = (raw['users'] as List?) ??
            (raw['data']  as List?) ??
            (raw['chats'] as List?) ??
            [];
      } else {
        rawList = [];
      }
      final users = rawList
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
    final cc      = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    final state   = ref.watch(_blockedProvider);

    return Scaffold(
      backgroundColor: cc.surfaceBackground,
      appBar: AppBar(
        title: Text('Blocked Users',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: cc.primaryText)),
      ),
      body: state.isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : state.users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block_rounded,
                          size: 56, color: cc.secondaryText),
                      const SizedBox(height: 12),
                      Text(
                        'No blocked users',
                        style: TextStyle(
                            color: cc.secondaryText, fontSize: 15),
                      ),
                    ],
                  ),
                )
              : Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cc.cardBackground,
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
                    separatorBuilder: (_, __) => Divider(
                        height: 1, indent: 66, color: cc.divider),
                    itemBuilder: (_, i) {
                      final user     = state.users[i];
                      final isActing = state.actionUserId == user.id;
                      return ListTile(
                        leading: _buildAvatar(user, cc),
                        title: Text(
                          user.name,
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: cc.primaryText),
                        ),
                        subtitle: user.bio != null
                            ? Text(
                                user.bio!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: cc.secondaryText),
                              )
                            : null,
                        trailing: isActing
                            ? SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: primary))
                            : TextButton(
                                onPressed: () =>
                                    _confirmUnblock(context, ref, user),
                                child: Text(
                                  'Unblock',
                                  style: TextStyle(color: primary),
                                ),
                              ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildAvatar(UserModel user, CircuitChatColors cc) {
    if (user.avatar != null && user.avatar!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: CachedNetworkImageProvider(user.avatar!),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: cc.surfaceBackground,
      child: Text(
        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
        style: TextStyle(
            color: cc.secondaryText, fontWeight: FontWeight.w600),
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
