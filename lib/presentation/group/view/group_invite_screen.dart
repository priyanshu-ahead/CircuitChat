import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../viewmodel/group_viewmodel.dart';

class GroupInviteScreen extends ConsumerStatefulWidget {
  const GroupInviteScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<GroupInviteScreen> createState() => _GroupInviteScreenState();
}

class _GroupInviteScreenState extends ConsumerState<GroupInviteScreen> {
  bool _linkLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLink();
  }

  Future<void> _loadLink() async {
    await ref
        .read(groupViewModelProvider(widget.groupId).notifier)
        .loadInviteLink();
    if (mounted) setState(() => _linkLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupViewModelProvider(widget.groupId));
    final group = state.group;
    final link = state.inviteLink;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text(
          'Invite to Group',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      body: state.isLoading || group == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 16),
                // Group card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4)
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildAvatar(group.avatar, group.name),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _linkLoading
                                ? const SizedBox(
                                    height: 14,
                                    width: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Text(
                                    link ?? '—',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF888888)),
                                    maxLines: 2,
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Approval warning
                if (group.settings?.approveMember == true)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      'New members need admin approval before joining.',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF888888)),
                    ),
                  ),
                const SizedBox(height: 16),
                // Actions
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4)
                    ],
                  ),
                  child: Column(
                    children: [
                      _ActionTile(
                        icon: Icons.share_rounded,
                        title: 'Send via Chat',
                        onTap: () {
                          // Forward to chat — placeholder (ForwardModel not yet built)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Forward to chat coming soon.')),
                          );
                        },
                        isFirst: true,
                      ),
                      _ActionTile(
                        icon: Icons.copy_rounded,
                        title: 'Copy Link',
                        onTap: link == null
                            ? null
                            : () {
                                Clipboard.setData(
                                    ClipboardData(text: link));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Link copied to clipboard.')),
                                );
                              },
                      ),
                      _ActionTile(
                        icon: Icons.qr_code_2_rounded,
                        title: 'QR Code',
                        onTap: () => context.push(
                          Routes.groupQR
                              .replaceFirst(':groupId', widget.groupId),
                        ),
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Reset link
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4)
                    ],
                  ),
                  child: ListTile(
                    onTap: _resetLink,
                    title: const Text(
                      'Reset Invite Link',
                      style: TextStyle(
                          color: Color(0xFFE53935),
                          fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Future<void> _resetLink() async {
    setState(() => _linkLoading = true);
    await ref
        .read(groupViewModelProvider(widget.groupId).notifier)
        .resetInviteLink();
    if (mounted) setState(() => _linkLoading = false);
  }

  Widget _buildAvatar(String? url, String name) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: CachedNetworkImageProvider(url),
      );
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: const Color(0xFF1976D2),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'G',
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 22),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF1976D2), size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              color: onTap == null
                  ? const Color(0xFFBBBBBB)
                  : Colors.black87,
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 62, color: Color(0xFFEEEEEE)),
      ],
    );
  }
}
