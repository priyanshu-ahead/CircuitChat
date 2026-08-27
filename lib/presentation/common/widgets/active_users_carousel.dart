import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
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
    final cc = context.cc;
    final users = ref.watch(visibleActiveUsersProvider);
    if (users.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: cc.pageBackground,
        border: Border(
          bottom: BorderSide(color: cc.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 73,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
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
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 73,
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
                      backgroundColor: cc.surfaceBackground,
                      backgroundImage:
                          user.avatar != null && user.avatar!.isNotEmpty
                              ? CachedNetworkImageProvider(user.avatar!)
                              : null,
                      child: (user.avatar == null || user.avatar!.isEmpty)
                          ? Text(
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: primary,
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
                        border: Border.all(color: cc.pageBackground, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              user.name,
              style: TextStyle(fontSize: 10, color: cc.primaryText),
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
