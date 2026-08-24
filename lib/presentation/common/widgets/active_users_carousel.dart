import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/chat_model.dart';
import '../../../data/models/user_model.dart';
import '../../chat/viewmodel/chat_list_viewmodel.dart';

// ── Widget ────────────────────────────────────────────────────────────────────

/// Horizontal carousel of online/active friends — mirrors RN's
/// components/chat/activeuser.js.
///
/// RN drives online status from the Redux `users` store (updated by
/// socket `online`/`offline` events). Flutter drives the same from
/// [ChatListViewModel] which already handles those socket events and
/// marks chats with `isOnline: true` on direct chats.
/// No separate API call needed — the data is already live.
class ActiveUsersCarousel extends ConsumerWidget {
  const ActiveUsersCarousel({super.key, this.onTap});
  final void Function(UserModel)? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pull online direct-chat users straight from the already-loaded chat list.
    final chats = ref.watch(
      chatListViewModelProvider.select((s) => s.chats),
    );

    final onlineUsers = chats
        .where((c) =>
            c.type == ChatType.direct &&
            c.isOnline &&
            c.members.isNotEmpty)
        .map((c) => UserModel(
              id:          c.members.first.id,
              username:    c.name ?? c.members.first.username,
              email:       c.members.first.email,
              displayName: c.name ?? c.members.first.displayName,
              avatar:      c.avatar ?? c.members.first.avatar,
            ))
        .toList();

    if (onlineUsers.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 86,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: onlineUsers.length,
        itemBuilder: (_, i) => _ActiveUserItem(
          user: onlineUsers[i],
          onTap: onTap != null ? () => onTap!(onlineUsers[i]) : null,
        ),
      ),
    );
  }
}

class _ActiveUserItem extends StatelessWidget {
  const _ActiveUserItem({required this.user, this.onTap});
  final UserModel     user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFDDE4EF),
                  backgroundImage: user.avatar != null &&
                          user.avatar!.isNotEmpty
                      ? CachedNetworkImageProvider(user.avatar!)
                      : null,
                  child: (user.avatar == null || user.avatar!.isEmpty)
                      ? Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Color(0xFF1976D2),
                              fontWeight: FontWeight.w600),
                        )
                      : null,
                ),
                // Green online dot
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: const Color(0xFF43A047),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 54,
              child: Text(
                user.name.split(' ').first,
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
