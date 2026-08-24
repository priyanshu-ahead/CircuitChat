import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/viewmodel/auth_viewmodel.dart';

// ── Dark-mode provider ─────────────────────────────────────────────────────────
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  bool _joinGroupInputVisible = false;
  final _joinCtrl = TextEditingController();
  String _selectedLanguage = 'English';
  static const _languages = [
    'English', 'Spanish', 'French', 'German',
    'Arabic', 'Hindi', 'Portuguese', 'Russian',
  ];

  @override
  void dispose() {
    _joinCtrl.dispose();
    super.dispose();
  }

  void _handleJoinGroup() {
    final text = _joinCtrl.text.trim();
    if (text.isNotEmpty) {
      final token = text.split('/').last;
      _joinCtrl.clear();
      setState(() => _joinGroupInputVisible = false);
      context.push(Routes.groupJoin.replaceFirst(':token', token));
    }
  }

  Future<void> _showLanguagePicker() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Text('Select Language',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const Divider(),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: _languages
                  .map((lang) => ListTile(
                        title: Text(lang),
                        trailing: lang == _selectedLanguage
                            ? const Icon(Icons.check_rounded,
                                color: Color(0xFF1976D2))
                            : null,
                        onTap: () => Navigator.pop(context, lang),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (chosen != null) setState(() => _selectedLanguage = chosen);
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'This will permanently delete your account and all data. '
            'This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Color(0xFFE53935)))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(authViewModelProvider.notifier).logout();
      if (context.mounted) context.go(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authViewModelProvider).user;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    const blue = Color(0xFF1976D2);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // ── Header ────────────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text('Settings',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E))),
            ),

            // ── Profile card ──────────────────────────────────────────────────
            _Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                leading: _buildAvatar(user?.avatar, user?.name ?? ''),
                title: Text(user?.name ?? 'User',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF1A1A2E))),
                subtitle: Text(
                  user?.bio?.isNotEmpty == true
                      ? user!.bio!
                      : (user?.email ?? ''),
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFAAAAAA)),
                onTap: () => context.push(Routes.editProfile),
              ),
            ),

            const SizedBox(height: 12),

            // ── Main options (flat list matching RN body.js) ───────────────────
            _Card(
              child: Column(
                children: [
                  _Tile(
                      icon: Icons.edit_outlined,
                      iconColor: blue,
                      label: 'Edit Profile',
                      onTap: () => context.push(Routes.editProfile)),
                  _Tile(
                      icon: Icons.star_outline_rounded,
                      iconColor: const Color(0xFFFFC107),
                      label: 'Starred Messages',
                      onTap: () => context.push(Routes.starredMessages)),
                  _Tile(
                      icon: Icons.block_rounded,
                      iconColor: const Color(0xFFE53935),
                      label: 'Blocked Users',
                      onTap: () => context.push(Routes.blockedUsers)),
                  _Tile(
                      icon: Icons.lock_outline_rounded,
                      iconColor: const Color(0xFF607D8B),
                      label: 'Privacy',
                      onTap: () => context.push(Routes.privacySettings)),
                  _Tile(
                      icon: Icons.notifications_outlined,
                      iconColor: const Color(0xFFE91E63),
                      label: 'Notifications',
                      onTap: () =>
                          context.push(Routes.notificationSettings)),

                  // Join Group — inline input matching RN enableInput toggle
                  if (_joinGroupInputVisible)
                    _joinGroupRow(blue)
                  else
                    _Tile(
                        icon: Icons.group_outlined,
                        iconColor: blue,
                        label: 'Join Group',
                        onTap: () =>
                            setState(() => _joinGroupInputVisible = true)),

                  _Tile(
                      icon: Icons.language_outlined,
                      iconColor: const Color(0xFF009688),
                      label: 'Language',
                      trailing: Text(_selectedLanguage,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF888888))),
                      onTap: _showLanguagePicker),
                  _Tile(
                      icon: Icons.lock_reset_outlined,
                      iconColor: const Color(0xFF5C6BC0),
                      label: 'Change Password',
                      onTap: () => context.push(Routes.accountSettings)),
                  _Tile(
                      icon: Icons.delete_outline_rounded,
                      iconColor: const Color(0xFFE53935),
                      label: 'Delete Account',
                      labelColor: const Color(0xFFE53935),
                      onTap: _confirmDeleteAccount),
                  _Tile(
                      icon: Icons.info_outline_rounded,
                      iconColor: const Color(0xFF00BCD4),
                      label: 'App Info',
                      onTap: () => context.push(Routes.aboutApp),
                      isLast: true),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Dark Mode toggle (separate card matching RN) ───────────────────
            _Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF37474F).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.dark_mode_outlined,
                      color: Color(0xFF37474F), size: 19),
                ),
                title: const Text('Dark Mode',
                    style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF1A1A2E),
                        fontWeight: FontWeight.w500)),
                trailing: Switch(
                  value: isDark,
                  activeColor: blue,
                  onChanged: (val) =>
                      ref.read(themeModeProvider.notifier).state =
                          val ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Logout ────────────────────────────────────────────────────────
            _Card(
              child: _Tile(
                icon: Icons.logout_rounded,
                iconColor: const Color(0xFFEF4444),
                label: 'Log Out',
                labelColor: const Color(0xFFEF4444),
                showArrow: false,
                isLast: true,
                onTap: () async {
                  await ref
                      .read(authViewModelProvider.notifier)
                      .logout();
                  if (context.mounted) context.go(Routes.login);
                },
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _joinGroupRow(Color blue) {
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.group_outlined, color: blue, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _joinCtrl,
                  autofocus: true,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Enter group URL…',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _handleJoinGroup(),
                ),
              ),
              IconButton(
                icon: Icon(Icons.check_rounded, color: blue),
                onPressed: _handleJoinGroup,
              ),
            ],
          ),
        ),
        const Divider(
            height: 1, indent: 60, endIndent: 0,
            color: Color(0xFFEEEEEE)),
      ],
    );
  }

  Widget _buildAvatar(String? url, String name) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
          radius: 26,
          backgroundImage: CachedNetworkImageProvider(url));
    }
    return CircleAvatar(
      radius: 26,
      backgroundColor: const Color(0xFF1976D2),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4)
          ],
        ),
        child: child,
      );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.trailing,
    this.showArrow = true,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;
  final Widget? trailing;
  final bool showArrow;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          title: Text(label,
              style: TextStyle(
                  fontSize: 15,
                  color: labelColor ?? const Color(0xFF1A1A2E),
                  fontWeight: FontWeight.w500)),
          trailing: trailing ??
              (showArrow
                  ? const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFFAAAAAA), size: 20)
                  : null),
        ),
        if (!isLast)
          const Divider(
              height: 1,
              indent: 60,
              endIndent: 0,
              color: Color(0xFFEEEEEE)),
      ],
    );
  }
}
