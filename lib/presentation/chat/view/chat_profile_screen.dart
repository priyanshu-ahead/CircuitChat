import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../core/di/providers.dart';
import '../../../data/models/group_model.dart';
import '../../group/viewmodel/group_viewmodel.dart';

class ChatProfileScreen extends ConsumerStatefulWidget {
  const ChatProfileScreen({super.key, required this.chat});
  final ChatModel chat;

  @override
  ConsumerState<ChatProfileScreen> createState() => _ChatProfileScreenState();
}

class _ChatProfileScreenState extends ConsumerState<ChatProfileScreen> {
  bool get _isGroup => widget.chat.type == ChatType.group;

  @override
  Widget build(BuildContext context) {
    return _isGroup
        ? _GroupProfile(chat: widget.chat)
        : _DirectProfile(chat: widget.chat);
  }
}

// ── Direct Chat Profile ───────────────────────────────────────────────────────

class _DirectProfile extends ConsumerWidget {
  const _DirectProfile({required this.chat});
  final ChatModel chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final other = chat.members.isNotEmpty ? chat.members.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0.5,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _buildHeroAvatar(chat.avatar, chat.name ?? ''),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x99000000),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(
                chat.name ?? '',
                style: const TextStyle(color: Colors.white),
              ),
              titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Online status
                if (chat.isOnline)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: const Row(
                      children: [
                        CircleAvatar(
                            radius: 5,
                            backgroundColor: Color(0xFF43A047)),
                        SizedBox(width: 6),
                        Text('Online',
                            style: TextStyle(
                                color: Color(0xFF43A047),
                                fontSize: 13)),
                      ],
                    ),
                  ),
                // About / Bio
                if (other?.bio != null && other!.bio!.isNotEmpty)
                  _InfoCard(
                    label: 'About',
                    value: other.bio!,
                  ),
                // Phone
                if (other?.phone != null && other!.phone!.isNotEmpty)
                  _InfoCard(label: 'Phone', value: other.phone!),
                const SizedBox(height: 12),
                // Actions
                _ActionsCard(
                  actions: [
                    _ProfileAction(
                      icon: Icons.photo_library_outlined,
                      label: 'Media',
                      onTap: () => context.push(
                        Routes.chatMedia
                            .replaceFirst(':chatId', chat.id),
                        extra: chat,
                      ),
                    ),
                    _ProfileAction(
                      icon: Icons.star_outline_rounded,
                      label: 'Starred',
                      onTap: () => context.push(
                        Routes.chatStarred
                            .replaceFirst(':chatId', chat.id),
                        extra: chat,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Block / Mute
                _ActionsCard(
                  actions: [
                    _ProfileAction(
                      icon: chat.isMuted
                          ? Icons.volume_up_outlined
                          : Icons.volume_off_outlined,
                      label: chat.isMuted ? 'Unmute' : 'Mute',
                      onTap: () => _toggleMute(context, ref),
                    ),
                    _ProfileAction(
                      icon: chat.isBlockedByMe
                          ? Icons.block_flipped
                          : Icons.block_rounded,
                      label: chat.isBlockedByMe ? 'Unblock' : 'Block',
                      color: const Color(0xFFE53935),
                      onTap: () => _confirmBlock(context, ref),
                    ),
                    _ProfileAction(
                      icon: Icons.flag_outlined,
                      label: 'Report',
                      color: const Color(0xFFE53935),
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleMute(BuildContext context, WidgetRef ref) {
    final repo = ref.read(chatRepositoryProvider);
    if (chat.isMuted) {
      repo.unmuteChat(chat.id);
    } else {
      repo.muteChat(chat.id);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(chat.isMuted ? 'Chat unmuted.' : 'Chat muted.')),
    );
  }

  Future<void> _confirmBlock(BuildContext context, WidgetRef ref) async {
    final action = chat.isBlockedByMe ? 'Unblock' : 'Block';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action User'),
        content: Text('$action ${chat.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action,
                  style: const TextStyle(color: Color(0xFFE53935)))),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$action action sent.')),
      );
    }
  }
}

// ── Group Chat Profile ────────────────────────────────────────────────────────

class _GroupProfile extends ConsumerWidget {
  const _GroupProfile({required this.chat});
  final ChatModel chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupState = ref.watch(groupViewModelProvider(chat.id));
    final group = groupState.group;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0.5,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _buildHeroAvatar(
                      chat.avatar ?? group?.avatar, chat.name ?? ''),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x99000000)],
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(chat.name ?? group?.name ?? '',
                  style: const TextStyle(color: Colors.white)),
              titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
            ),
          ),
          SliverToBoxAdapter(
            child: groupState.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Member count
                      _InfoCard(
                        label: 'Members',
                        value:
                            '${group?.memberCount ?? chat.members.length}',
                      ),
                      if (group?.about != null && group!.about!.isNotEmpty)
                        _InfoCard(label: 'About', value: group.about!),
                      const SizedBox(height: 12),
                      // Quick actions
                      _ActionsCard(actions: [
                        _ProfileAction(
                          icon: Icons.people_outline_rounded,
                          label: 'Members',
                          onTap: () => context.push(
                            Routes.groupMembers
                                .replaceFirst(':groupId', chat.id),
                          ),
                        ),
                        _ProfileAction(
                          icon: Icons.photo_library_outlined,
                          label: 'Media',
                          onTap: () => context.push(
                            Routes.chatMedia
                                .replaceFirst(':chatId', chat.id),
                            extra: chat,
                          ),
                        ),
                        _ProfileAction(
                          icon: Icons.star_outline_rounded,
                          label: 'Starred',
                          onTap: () => context.push(
                            Routes.chatStarred
                                .replaceFirst(':chatId', chat.id),
                            extra: chat,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      // Group management
                      _ActionsCard(actions: [
                        _ProfileAction(
                          icon: Icons.settings_outlined,
                          label: 'Group Settings',
                          onTap: () => context.push(
                            Routes.groupSettings
                                .replaceFirst(':groupId', chat.id),
                          ),
                        ),
                        _ProfileAction(
                          icon: Icons.link_rounded,
                          label: 'Invite Link',
                          onTap: () => context.push(
                            Routes.groupInvite
                                .replaceFirst(':groupId', chat.id),
                          ),
                        ),
                        _ProfileAction(
                          icon: Icons.pending_actions_rounded,
                          label: 'Pending',
                          onTap: () => context.push(
                            Routes.groupPending
                                .replaceFirst(':groupId', chat.id),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      // Leave / Mute
                      _ActionsCard(actions: [
                        _ProfileAction(
                          icon: chat.isMuted
                              ? Icons.volume_up_outlined
                              : Icons.volume_off_outlined,
                          label: chat.isMuted ? 'Unmute' : 'Mute',
                          onTap: () {
                            final repo = ref.read(chatRepositoryProvider);
                            if (chat.isMuted) {
                              repo.unmuteChat(chat.id);
                            } else {
                              repo.muteChat(chat.id);
                            }
                          },
                        ),
                        _ProfileAction(
                          icon: Icons.exit_to_app_rounded,
                          label: 'Leave Group',
                          color: const Color(0xFFE53935),
                          onTap: () => _confirmLeave(context, ref),
                        ),
                      ]),
                      const SizedBox(height: 32),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text(
            'Are you sure you want to leave this group?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Leave',
                  style: TextStyle(color: Color(0xFFE53935)))),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final ok = await ref
          .read(groupViewModelProvider(chat.id).notifier)
          .leaveGroup();
      if (ok && context.mounted) {
        context.go(Routes.chatList);
      }
    }
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

Widget _buildHeroAvatar(String? url, String name) {
  if (url != null && url.isNotEmpty) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => _fallbackAvatar(name),
    );
  }
  return _fallbackAvatar(name);
}

Widget _fallbackAvatar(String name) {
  return Container(
    color: const Color(0xFF1976D2),
    child: Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: Colors.white,
            fontSize: 80,
            fontWeight: FontWeight.w300),
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontSize: 15, color: Colors.black87)),
        ],
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({required this.actions});
  final List<_ProfileAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: actions
            .map((a) => Expanded(child: _ActionButton(action: a)))
            .toList(),
      ),
    );
  }
}

class _ProfileAction {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});
  final _ProfileAction action;

  @override
  Widget build(BuildContext context) {
    final color = action.color ?? const Color(0xFF1976D2);
    return InkWell(
      onTap: action.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(action.icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(action.label,
                style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}
