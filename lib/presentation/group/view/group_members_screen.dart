import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/group_model.dart';
import '../viewmodel/group_viewmodel.dart';

class GroupMembersScreen extends ConsumerStatefulWidget {
  const GroupMembersScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends ConsumerState<GroupMembersScreen> {
  bool _searchActive = false;
  final _searchCtrl = TextEditingController();
  String _query = '';
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // Load first page of members
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(groupViewModelProvider(widget.groupId).notifier)
          .loadMembers(refresh: true);
    });
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref
          .read(groupViewModelProvider(widget.groupId).notifier)
          .loadMembers();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupViewModelProvider(widget.groupId));
    final allMembers = state.members
        .where((m) =>
            m.status == 'active' &&
            m.user.id.isNotEmpty)
        .toList();
    final filtered = _query.isEmpty
        ? allMembers
        : allMembers
            .where((m) => m.user.name
                .toLowerCase()
                .contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: _searchActive
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search members…',
                  border: InputBorder.none,
                ),
              )
            : Text(
                'Members (${allMembers.length})',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 17),
              ),
        leading: _searchActive
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() {
                    _searchActive = false;
                    _searchCtrl.clear();
                  });
                },
              )
            : null,
        actions: [
          if (!_searchActive)
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => setState(() => _searchActive = true),
            ),
          if (_searchActive && _query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() => _searchCtrl.clear()),
            ),
        ],
      ),
      body: state.isLoading && allMembers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty
              ? Center(
                  child: Text(
                    _query.isNotEmpty ? 'No results for "$_query"' : 'No members',
                    style: const TextStyle(color: Color(0xFF888888)),
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  itemCount: filtered.length + (state.membersHasMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == filtered.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _MemberTile(
                      member: filtered[i],
                      onMakeAdmin: () => _confirmAction(
                        'Make Admin',
                        'Promote ${filtered[i].user.name} to group admin?',
                        () => ref
                            .read(groupViewModelProvider(widget.groupId)
                                .notifier)
                            .makeAdmin(filtered[i].user.id),
                      ),
                      onDismissAdmin: () => _confirmAction(
                        'Dismiss Admin',
                        'Remove admin role from ${filtered[i].user.name}?',
                        () => ref
                            .read(groupViewModelProvider(widget.groupId)
                                .notifier)
                            .dismissAdmin(filtered[i].user.id),
                      ),
                      onRemove: () => _confirmAction(
                        'Remove Member',
                        'Remove ${filtered[i].user.name} from the group?',
                        () => ref
                            .read(groupViewModelProvider(widget.groupId)
                                .notifier)
                            .removeMember(filtered[i].user.id),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _confirmAction(
      String title, String message, Future<bool> Function() action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(title,
                  style: const TextStyle(color: Color(0xFFE53935)))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final ok = await action();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action failed. Please try again.')),
        );
      }
    }
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.onMakeAdmin,
    required this.onDismissAdmin,
    required this.onRemove,
  });

  final GroupMember member;
  final VoidCallback onMakeAdmin;
  final VoidCallback onDismissAdmin;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _Avatar(url: member.user.avatar, name: member.user.name),
      title: Text(
        member.user.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: member.isAdmin
          ? const Text('Admin',
              style: TextStyle(
                  color: Color(0xFF057EFC), fontSize: 12))
          : null,
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF888888)),
        onSelected: (v) {
          switch (v) {
            case 'make_admin':
              onMakeAdmin();
              break;
            case 'dismiss_admin':
              onDismissAdmin();
              break;
            case 'remove':
              onRemove();
              break;
          }
        },
        itemBuilder: (_) => [
          if (!member.isAdmin)
            const PopupMenuItem(
              value: 'make_admin',
              child: Text('Make Admin'),
            ),
          if (member.isAdmin)
            const PopupMenuItem(
              value: 'dismiss_admin',
              child: Text('Dismiss Admin'),
            ),
          const PopupMenuItem(
            value: 'remove',
            child: Text('Remove',
                style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url, required this.name});
  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: CachedNetworkImageProvider(url!),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFF1976D2),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}
