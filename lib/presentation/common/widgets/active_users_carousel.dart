import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/user_model.dart';
import '../../chat/viewmodel/active_users_viewmodel.dart';

/// Horizontal strip of online friends — mirrors RN `components/chat/activeuser.js`.
///
/// Data comes from `GET /friend/active` plus socket `user_status` / `refresh`.
class ActiveUsersCarousel extends ConsumerWidget {
  const ActiveUsersCarousel({super.key, this.onTap});
  final void Function(UserModel)? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(visibleActiveUsersProvider);
    if (users.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 67,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: users.length,
          itemBuilder: (_, i) => _ActiveUserItem(
            user: users[i],
            onTap: onTap != null ? () => onTap!(users[i]) : null,
          ),
        ),
      ),
    );
  }
}

class _ActiveUserItem extends StatelessWidget {
  const _ActiveUserItem({required this.user, this.onTap});
  final UserModel user;
  final VoidCallback? onTap;

  Color get _statusColor {
    switch (user.state) {
      case 2:
        return const Color(0xFFFFCC00);
      case 3:
        return const Color(0xFFFF0000);
      default:
        return const Color(0xFF0ED00E);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFFDDE4EF),
                      backgroundImage:
                          user.avatar != null && user.avatar!.isNotEmpty
                              ? CachedNetworkImageProvider(user.avatar!)
                              : null,
                      child: (user.avatar == null || user.avatar!.isEmpty)
                          ? Text(
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Color(0xFF1976D2),
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              user.name,
              style: const TextStyle(fontSize: 10, color: Color(0xFF1A1A2E)),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
