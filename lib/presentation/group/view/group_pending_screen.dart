import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/group_model.dart';
import '../viewmodel/group_viewmodel.dart';

class GroupPendingScreen extends ConsumerStatefulWidget {
  const GroupPendingScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<GroupPendingScreen> createState() => _GroupPendingScreenState();
}

class _GroupPendingScreenState extends ConsumerState<GroupPendingScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPending();
  }

  Future<void> _fetchPending() async {
    await ref
        .read(groupViewModelProvider(widget.groupId).notifier)
        .loadPendingMembers();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupViewModelProvider(widget.groupId));
    final members = state.pendingMembers;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text(
          'Pending Requests',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Text(
              'Pending requests require admin approval. '
              'Change this in Group Settings.',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF888888)),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : members.isEmpty
                    ? const Center(
                        child: Text(
                          'No pending requests',
                          style: TextStyle(color: Color(0xFF888888)),
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
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: members.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1, indent: 66),
                          itemBuilder: (_, i) =>
                              _PendingTile(
                            member: members[i],
                            onAccept: () => _handleAction(
                                members[i].user.id, true),
                            onReject: () => _handleAction(
                                members[i].user.id, false),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(String userId, bool accept) async {
    final vm = ref.read(
        groupViewModelProvider(widget.groupId).notifier);
    final ok = accept
        ? await vm.approvePending(userId)
        : await vm.rejectPending(userId);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action failed. Please try again.')),
      );
    }
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({
    required this.member,
    required this.onAccept,
    required this.onReject,
  });

  final GroupPendingMember member;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Avatar
          _buildAvatar(),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              member.user.name,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          // Reject
          _ActionButton(
            icon: Icons.close_rounded,
            color: const Color(0xFFE53935),
            onTap: onReject,
          ),
          const SizedBox(width: 8),
          // Accept
          _ActionButton(
            icon: Icons.check_rounded,
            color: const Color(0xFF43A047),
            onTap: onAccept,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final url = member.user.avatar;
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
        member.user.name.isNotEmpty ? member.user.name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
