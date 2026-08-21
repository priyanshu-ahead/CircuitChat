import 'package:flutter/material.dart';

/// Chats tab — matches the provided screenshot:
/// Stories row → Filter chips (All / Unread / Group) → Chat list
class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  int _selectedFilter = 0; // 0=All 1=Unread 2=Group
  final _searchCtrl = TextEditingController();

  // ── Dummy data (replace with Riverpod provider) ────────────────────────────
  static final _stories = [
    _StoryUser('Bharat Singh', null, true),
    _StoryUser('Yogesh Ver...', null, true),
    _StoryUser('Vijay Garg', null, false),
    _StoryUser('Kapil Singhal', null, true),
    _StoryUser('Abhishek Ku...', null, true),
    _StoryUser('Praveen Ve...', null, false),
  ];

  static final _chats = [
    _ChatItem(
      name: 'Yogesh Verma',
      lastMsg: '✓✓ ok',
      time: '3:08 PM',
      isOnline: true,
      unread: 0,
      isGroup: false,
    ),
    _ChatItem(
      name: 'Praveen Verma',
      lastMsg: 'name: se_app...',
      time: '2:51 PM',
      isOnline: true,
      unread: 0,
      isGroup: false,
    ),
    _ChatItem(
      name: 'Android App Issues',
      lastMsg: 'Srishty: https://github.com/Ahead-WebSoft-Te...',
      time: '2:26 PM',
      isOnline: false,
      unread: 2,
      isGroup: true,
    ),
    _ChatItem(
      name: 'Vaibhav Agarwal',
      lastMsg: 'https://github.com/Ahead-WebSoft-Technologies/c...',
      time: '2:24 PM',
      isOnline: false,
      unread: 0,
      isGroup: false,
    ),
    _ChatItem(
      name: 'Suryansh Tak',
      lastMsg: 'disha ko bolna msg dekhe',
      time: '2:23 PM',
      isOnline: false,
      unread: 0,
      isGroup: false,
    ),
    _ChatItem(
      name: 'Srishty',
      lastMsg: '✓ https://wetransfer.com/previews/d2e1ecec517...',
      time: '10:48 AM',
      isOnline: false,
      unread: 0,
      isGroup: false,
    ),
    _ChatItem(
      name: 'Team Ahead',
      lastMsg: 'Join the meeting now',
      time: '10:12 AM',
      isOnline: false,
      unread: 0,
      isGroup: true,
    ),
  ];

  List<_ChatItem> get _filteredChats {
    var list = _chats;
    if (_selectedFilter == 1) list = list.where((c) => c.unread > 0).toList();
    if (_selectedFilter == 2) list = list.where((c) => c.isGroup).toList();
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) => c.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ──────────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                'Chats',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),

            // ── Search bar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: Colors.grey[400], size: 22),
                  filled: true,
                  fillColor: const Color(0xFFF2F4F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Stories row ───────────────────────────────────────────────
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _stories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (_, i) => _StoryAvatar(_stories[i]),
              ),
            ),
            const SizedBox(height: 16),

            // ── Filter chips ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _selectedFilter == 0,
                    onTap: () => setState(() => _selectedFilter = 0),
                  ),
                  const SizedBox(width: 10),
                  _FilterChip(
                    label: 'Unread',
                    selected: _selectedFilter == 1,
                    onTap: () => setState(() => _selectedFilter = 1),
                  ),
                  const SizedBox(width: 10),
                  _FilterChip(
                    label: 'Group',
                    selected: _selectedFilter == 2,
                    onTap: () => setState(() => _selectedFilter = 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Chat list ─────────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                itemCount: _filteredChats.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 0,
                  indent: 72,
                  color: Color(0xFFF0F0F0),
                ),
                itemBuilder: (_, i) => _ChatListTile(_filteredChats[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Story avatar ──────────────────────────────────────────────────────────────
class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar(this.user);
  final _StoryUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFFDDE4EF),
              child: const Icon(Icons.person, size: 30, color: Color(0xFF9AA6B8)),
            ),
            if (user.isOnline)
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 62,
          child: Text(
            user.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF444444)),
          ),
        ),
      ],
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE3EEFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF1976D2) : const Color(0xFFDDDDDD),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF1976D2) : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }
}

// ── Chat list tile ────────────────────────────────────────────────────────────
class _ChatListTile extends StatelessWidget {
  const _ChatListTile(this.chat);
  final _ChatItem chat;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: chat.isGroup
                      ? const Color(0xFFDDE4EF)
                      : const Color(0xFFDDE4EF),
                  child: Icon(
                    chat.isGroup ? Icons.group_rounded : Icons.person_rounded,
                    color: const Color(0xFF9AA6B8),
                    size: 26,
                  ),
                ),
                if (chat.isOnline)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Name + last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    chat.lastMsg,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Time + badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  chat.time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 4),
                if (chat.unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${chat.unread}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data models (local, will be replaced by real entities) ───────────────────

class _StoryUser {
  const _StoryUser(this.name, this.avatarUrl, this.isOnline);
  final String name;
  final String? avatarUrl;
  final bool isOnline;
}

class _ChatItem {
  const _ChatItem({
    required this.name,
    required this.lastMsg,
    required this.time,
    required this.isOnline,
    required this.unread,
    required this.isGroup,
  });
  final String name;
  final String lastMsg;
  final String time;
  final bool isOnline;
  final int unread;
  final bool isGroup;
}
