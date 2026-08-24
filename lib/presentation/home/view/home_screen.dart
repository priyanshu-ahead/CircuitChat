import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/app_init/app_init_viewmodel.dart';
import 'tabs/chats_tab.dart';
import 'tabs/calls_tab.dart';
import 'tabs/settings_tab.dart';
import 'tabs/users_tab.dart';

final homeTabIndexProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _tabs = [
    ChatsTab(),
    UsersTab(),
    CallsTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(homeTabIndexProvider);
    // Live unread count from AppInitViewModel (decremented by socket events)
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: _tabs),
      bottomNavigationBar: _AppBottomNavBar(
        currentIndex: currentIndex,
        unreadCount: unread,
        onTap: (i) => ref.read(homeTabIndexProvider.notifier).state = i,
      ),
    );
  }
}

// ── Bottom nav bar ─────────────────────────────────────────────────────────────

class _AppBottomNavBar extends StatelessWidget {
  const _AppBottomNavBar({
    required this.currentIndex,
    required this.onTap,
    this.unreadCount = 0,
  });

  final int currentIndex;
  final int unreadCount;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon:        Icons.chat_bubble_outline_rounded,
                activeIcon:  Icons.chat_bubble_rounded,
                label:       'Chats',
                index:       0,
                currentIndex: currentIndex,
                badge:       unreadCount,
                onTap:       onTap,
              ),
              _NavItem(
                icon:        Icons.person_outline_rounded,
                activeIcon:  Icons.person_rounded,
                label:       'Users',
                index:       1,
                currentIndex: currentIndex,
                onTap:       onTap,
              ),
              _NavItem(
                icon:        Icons.phone_outlined,
                activeIcon:  Icons.phone_rounded,
                label:       'Calls',
                index:       2,
                currentIndex: currentIndex,
                onTap:       onTap,
              ),
              _NavItem(
                icon:        Icons.settings_outlined,
                activeIcon:  Icons.settings_rounded,
                label:       'Settings',
                index:       3,
                currentIndex: currentIndex,
                onTap:       onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nav item ───────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final void Function(int) onTap;
  final int? badge;

  bool get _isActive => index == currentIndex;
  static const _activeColor   = Color(0xFF1976D2);
  static const _inactiveColor = Color(0xFF888888);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  _isActive ? activeIcon : icon,
                  color: _isActive ? _activeColor : _inactiveColor,
                  size: 26,
                ),
                if (badge != null && badge! > 0)
                  Positioned(
                    right: -10,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: _activeColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge! > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: _isActive ? _activeColor : _inactiveColor,
                fontWeight: _isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
