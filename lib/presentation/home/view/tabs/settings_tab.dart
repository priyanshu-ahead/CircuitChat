import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/viewmodel/auth_viewmodel.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authViewModelProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: ListView(
          children: [
            // ── Header ───────────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
            // ── Profile card ─────────────────────────────────────────────────
            GestureDetector(
              onTap: () => context.push(Routes.editProfile),
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4)
                  ],
                ),
                child: Row(
                  children: [
                    _buildAvatar(user?.avatar, user?.name ?? ''),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'User',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          if (user?.bio != null && user!.bio!.isNotEmpty)
                            Text(
                              user.bio!,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[500]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          else
                            Text(
                              user?.email ?? '',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[500]),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFFAAAAAA)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── Preferences group ────────────────────────────────────────────
            _GroupCard(
              children: [
                _Tile(
                  icon: Icons.notifications_outlined,
                  iconColor: const Color(0xFFE91E63),
                  label: 'Notifications',
                  onTap: () => context.push(Routes.notificationSettings),
                ),
                _Tile(
                  icon: Icons.lock_outline_rounded,
                  iconColor: const Color(0xFF607D8B),
                  label: 'Privacy',
                  onTap: () => context.push(Routes.privacySettings),
                ),
                _Tile(
                  icon: Icons.manage_accounts_outlined,
                  iconColor: const Color(0xFF1976D2),
                  label: 'Account',
                  onTap: () => context.push(Routes.accountSettings),
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Content group ────────────────────────────────────────────────
            _GroupCard(
              children: [
                _Tile(
                  icon: Icons.star_outline_rounded,
                  iconColor: const Color(0xFFFFC107),
                  label: 'Starred Messages',
                  onTap: () => context.push(Routes.starredMessages),
                ),
                _Tile(
                  icon: Icons.block_rounded,
                  iconColor: const Color(0xFFE53935),
                  label: 'Blocked Users',
                  onTap: () => context.push(Routes.blockedUsers),
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Info group ───────────────────────────────────────────────────
            _GroupCard(
              children: [
                _Tile(
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF00BCD4),
                  label: 'About CircuitChat',
                  onTap: () {},
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Logout ───────────────────────────────────────────────────────
            _GroupCard(
              children: [
                _Tile(
                  icon: Icons.logout_rounded,
                  iconColor: const Color(0xFFEF4444),
                  label: 'Log Out',
                  labelColor: const Color(0xFFEF4444),
                  onTap: () async {
                    await ref
                        .read(authViewModelProvider.notifier)
                        .logout();
                    if (context.mounted) context.go(Routes.login);
                  },
                  showArrow: false,
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
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
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 4)
          ],
        ),
        child: Column(children: children),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.showArrow = true,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;
  final bool showArrow;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: labelColor ?? const Color(0xFF1A1A2E),
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: showArrow
              ? const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFAAAAAA), size: 20)
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        ),
        if (!isLast)
          const Divider(
              height: 1, indent: 60, endIndent: 0,
              color: Color(0xFFEEEEEE)),
      ],
    );
  }
}
