import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/group_model.dart';
import '../../../data/repositories/chat_repository.dart';
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
    final cc = context.cc;
    final other = chat.members.isNotEmpty ? chat.members.first : null;

    return Scaffold(
      backgroundColor: cc.surfaceBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: cc.pageBackground,
            foregroundColor: cc.primaryText,
            elevation: 0.5,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _buildHeroAvatar(context, chat.avatar, chat.name ?? ''),
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
              title: Text(chat.name ?? '',
                  style: const TextStyle(color: Colors.white)),
              titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (chat.isOnline)
                  _InfoRow(
                    icon: Icons.circle,
                    iconColor: const Color(0xFF43A047),
                    iconSize: 10,
                    value: 'Online',
                  ),
                if (other?.bio != null && other!.bio!.isNotEmpty)
                  _InfoRow(
                      icon: Icons.info_outline_rounded,
                      label: 'About',
                      value: other.bio!),
                if (other?.phone != null && other!.phone!.isNotEmpty)
                  _InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: other.phone!),
                const SizedBox(height: 8),
                _Divider(),
                // ── Actions as list ───────────────────────────────────────
                _ListAction(
                  icon: Icons.photo_library_outlined,
                  label: 'Media, Links & Docs',
                  onTap: () => context.push(
                      Routes.chatMedia.replaceFirst(':chatId', chat.id),
                      extra: chat),
                ),
                _Divider(),
                _ListAction(
                  icon: Icons.star_outline_rounded,
                  label: 'Starred Messages',
                  onTap: () => context.push(
                      Routes.chatStarred.replaceFirst(':chatId', chat.id),
                      extra: chat),
                ),
                _Divider(),
                const SizedBox(height: 8),
                _Divider(),
                _ListAction(
                  icon: chat.isMuted
                      ? Icons.volume_up_outlined
                      : Icons.volume_off_outlined,
                  label: chat.isMuted ? 'Unmute' : 'Mute Notifications',
                  onTap: () {
                    final repo = ref.read(chatRepositoryProvider);
                    if (chat.isMuted) {
                      repo.unmuteChat(chat.id);
                    } else {
                      repo.muteChat(chat.id);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                _Divider(),
                _ListAction(
                  icon: chat.isBlockedByMe
                      ? Icons.block_flipped
                      : Icons.block_rounded,
                  label: chat.isBlockedByMe ? 'Unblock User' : 'Block User',
                  color: const Color(0xFFE53935),
                  showArrow: false,
                  onTap: () => _confirmBlock(context, ref),
                ),
                _Divider(),
                _ListAction(
                  icon: Icons.flag_outlined,
                  label: 'Report',
                  color: const Color(0xFFE53935),
                  showArrow: false,
                  onTap: () {},
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBlock(BuildContext context, WidgetRef ref) async {
    final cc = context.cc;
    final action = chat.isBlockedByMe ? 'Unblock' : 'Block';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action User'),
        content: Text('$action ${chat.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: cc.secondaryText))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action,
                  style:
                      const TextStyle(color: Color(0xFFE53935)))),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$action action sent.')));
    }
  }
}

// ── Group Chat Profile ────────────────────────────────────────────────────────

class _GroupProfile extends ConsumerWidget {
  const _GroupProfile({required this.chat});
  final ChatModel chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    final groupState = ref.watch(groupViewModelProvider(chat.id));
    final group = groupState.group;

    // ── Member count: use embedded members from getGroupInfo (mirrors RN) ─
    // RN uses group.members.filter(active) directly — same approach here.
    final activeMembers = groupState.members
        .where((m) =>
            m.status == 'active' &&
            m.user.id.isNotEmpty)
        .toList();
    final memberCount = group?.memberCount != null && group!.memberCount > 0
        ? group.memberCount
        : activeMembers.length;

    return Scaffold(
      backgroundColor: cc.surfaceBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: cc.pageBackground,
            foregroundColor: cc.primaryText,
            elevation: 0.5,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _buildHeroAvatar(context,
                      chat.avatar ?? group?.avatar, chat.name ?? ''),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x99000000)
                        ],
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
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                        child:
                            CircularProgressIndicator(color: primary)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // About
                      if (group?.about != null &&
                          group!.about!.isNotEmpty)
                        _InfoRow(
                            icon: Icons.info_outline_rounded,
                            label: 'About',
                            value: group.about!),

                      // Member count — tappable to open full list
                      _InfoRow(
                        icon: Icons.people_outline_rounded,
                        label: 'Members',
                        value: '$memberCount members',
                        onTap: () => context.push(
                          Routes.groupMembers
                              .replaceFirst(':groupId', chat.id),
                        ),
                      ),

                      const SizedBox(height: 8),
                      _Divider(),

                      // ── Members preview (first 2, mirrors RN details.js) ──
                      if (activeMembers.isNotEmpty) ...[
                        _SectionLabel('${activeMembers.length} Members'),
                        Container(
                          color: cc.cardBackground,
                          child: Column(
                            children: [
                              // First 2 active members
                              ...activeMembers.take(2).map((m) =>
                                _MemberTile(member: m, cc: cc)),
                              // "See all" if more than 2
                              if (activeMembers.length > 2 ||
                                  (group?.memberCount ?? 0) > 2)
                                ListTile(
                                  onTap: () => context.push(
                                    Routes.groupMembers
                                        .replaceFirst(':groupId', chat.id),
                                  ),
                                  title: Text(
                                    'See all ${group?.memberCount ?? activeMembers.length} members',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _Divider(),
                      ],
                      _ListAction(
                        icon: Icons.people_outline_rounded,
                        label: 'View Members',
                        onTap: () => context.push(
                          Routes.groupMembers
                              .replaceFirst(':groupId', chat.id),
                        ),
                      ),
                      _Divider(),
                      _ListAction(
                        icon: Icons.photo_library_outlined,
                        label: 'Media, Links & Docs',
                        onTap: () => context.push(
                          Routes.chatMedia
                              .replaceFirst(':chatId', chat.id),
                          extra: chat,
                        ),
                      ),
                      _Divider(),
                      _ListAction(
                        icon: Icons.star_outline_rounded,
                        label: 'Starred Messages',
                        onTap: () => context.push(
                          Routes.chatStarred
                              .replaceFirst(':chatId', chat.id),
                          extra: chat,
                        ),
                      ),
                      _Divider(),
                      _ListAction(
                        icon: Icons.settings_outlined,
                        label: 'Group Settings',
                        onTap: () => context.push(
                          Routes.groupSettings
                              .replaceFirst(':groupId', chat.id),
                        ),
                      ),
                      _Divider(),
                      _ListAction(
                        icon: Icons.link_rounded,
                        label: 'Invite Link',
                        onTap: () => context.push(
                          Routes.groupInvite
                              .replaceFirst(':groupId', chat.id),
                        ),
                      ),
                      _Divider(),
                      _ListAction(
                        icon: Icons.pending_actions_rounded,
                        label: 'Pending Requests',
                        onTap: () => context.push(
                          Routes.groupPending
                              .replaceFirst(':groupId', chat.id),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _Divider(),
                      _ListAction(
                        icon: chat.isMuted
                            ? Icons.volume_up_outlined
                            : Icons.volume_off_outlined,
                        label: chat.isMuted
                            ? 'Unmute Notifications'
                            : 'Mute Notifications',
                        onTap: () {
                          final repo = ref.read(chatRepositoryProvider);
                          if (chat.isMuted) {
                            repo.unmuteChat(chat.id);
                          } else {
                            repo.muteChat(chat.id);
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                      _Divider(),
                      _ListAction(
                        icon: Icons.exit_to_app_rounded,
                        label: 'Leave Group',
                        color: const Color(0xFFE53935),
                        showArrow: false,
                        onTap: () => _confirmLeave(context, ref),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final cc = context.cc;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text(
            'Are you sure you want to leave this group?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: cc.secondaryText))),
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
      if (ok && context.mounted) context.go(Routes.chatList);
    }
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

Widget _buildHeroAvatar(
    BuildContext context, String? url, String name) {
  if (url != null && url.isNotEmpty) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => _fallbackAvatar(context, name),
    );
  }
  return _fallbackAvatar(context, name);
}

Widget _fallbackAvatar(BuildContext context, String name) {
  final primary = Theme.of(context).colorScheme.primary;
  return Container(
    color: primary,
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

// ── Info row — icon + label + value ──────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.value,
    this.label,
    this.iconColor,
    this.iconSize,
    this.onTap,
  });
  final IconData icon;
  final String   value;
  final String?  label;
  final Color?   iconColor;
  final double?  iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: cc.cardBackground,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                color: iconColor ?? cc.secondaryText,
                size: iconSize ?? 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null)
                    Text(label!,
                        style: TextStyle(
                            fontSize: 12,
                            color: cc.secondaryText,
                            fontWeight: FontWeight.w500)),
                  if (label != null) const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          fontSize: 15, color: cc.primaryText)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  color: cc.secondaryText, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Action list item ──────────────────────────────────────────────────────────

class _ListAction extends StatelessWidget {
  const _ListAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.showArrow = true,
  });
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  final Color?       color;
  final bool         showArrow;

  @override
  Widget build(BuildContext context) {
    final cc      = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    final c       = color ?? primary;
    return Material(
      color: cc.cardBackground,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: c.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: c, size: 20),
        ),
        title: Text(label,
            style: TextStyle(
                fontSize: 15,
                color: color ?? cc.primaryText,
                fontWeight: FontWeight.w500)),
        trailing: showArrow
            ? Icon(Icons.chevron_right_rounded,
                color: cc.secondaryText, size: 18)
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return Container(
      color: cc.surfaceBackground,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cc.secondaryText)),
    );
  }
}

// ── Member tile (mirrors RN Member component) ─────────────────────────────────

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.cc});
  final GroupMember       member;
  final CircuitChatColors cc;

  @override
  Widget build(BuildContext context) {
    final user = member.user;
    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: cc.surfaceBackground,
            backgroundImage: user.avatar != null && user.avatar!.isNotEmpty
                ? CachedNetworkImageProvider(user.avatar!)
                : null,
            child: (user.avatar == null || user.avatar!.isEmpty)
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600))
                : null,
          ),
          title: Text(user.name,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cc.primaryText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: user.bio != null && user.bio!.isNotEmpty
              ? Text(user.bio!,
                  style:
                      TextStyle(fontSize: 12, color: cc.secondaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)
              : null,
          trailing: member.isAdmin
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme.primary
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Admin',
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500)),
                )
              : null,
        ),
        Divider(height: 1, indent: 66, color: cc.divider),
      ],
    );
  }
}

// ── Section divider ───────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: 66, color: context.cc.divider);
}
