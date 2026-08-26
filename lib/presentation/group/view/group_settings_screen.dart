import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/group_model.dart';
import '../viewmodel/group_viewmodel.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  // Local copy of settings so toggles feel instant.
  GroupPermissions? _local;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupViewModelProvider(widget.groupId));

    // Seed local settings once group loads.
    if (_local == null && state.group?.settings != null) {
      _local = state.group!.settings;
    }

    return Scaffold(
      backgroundColor: context.cc.surfaceBackground,
      appBar: AppBar(
        elevation: 0.5,
        title: const Text(
          'Group Settings',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      body: state.isLoading || _local == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 12),
                _SectionHeader('Members can:'),
                _SettingsCard(children: [
                  _SettingTile(
                    icon: Icons.edit_rounded,
                    iconColor: const Color(0xFF057EFC),
                    title: 'Edit Group Info',
                    subtitle:
                        'Allow members to change group name and photo.',
                    value: _local!.editDetails,
                    onChanged: (v) => _toggle(editDetails: v),
                  ),
                  _SettingTile(
                    icon: Icons.campaign_rounded,
                    iconColor: const Color(0xFF057EFC),
                    title: 'Send Messages',
                    subtitle: 'Allow members to send messages in this group.',
                    value: _local!.sendMessage,
                    onChanged: (v) => _toggle(sendMessage: v),
                  ),
                  _SettingTile(
                    icon: Icons.call_rounded,
                    iconColor: const Color(0xFF4CAF50),
                    title: 'Start Calls',
                    subtitle: 'Allow members to initiate group calls.',
                    value: _local!.call,
                    onChanged: (v) => _toggle(call: v),
                  ),
                  _SettingTile(
                    icon: Icons.person_add_rounded,
                    iconColor: const Color(0xFF9C27B0),
                    title: 'Add Members',
                    subtitle:
                        'Allow members to add new people to this group.',
                    value: _local!.addMember,
                    onChanged: (v) => _toggle(addMember: v),
                    isLast: true,
                  ),
                ]),
                const SizedBox(height: 12),
                _SectionHeader('Admin settings:'),
                _SettingsCard(children: [
                  _SettingTile(
                    icon: Icons.how_to_reg_rounded,
                    iconColor: const Color(0xFFFF9800),
                    title: 'Approve New Members',
                    subtitle:
                        'New members must be approved by an admin before joining.',
                    value: _local!.approveMember,
                    onChanged: (v) => _toggle(approveMember: v),
                    isLast: true,
                  ),
                ]),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  void _toggle({
    bool? editDetails,
    bool? sendMessage,
    bool? call,
    bool? addMember,
    bool? approveMember,
  }) {
    final updated = GroupPermissions(
      editDetails: editDetails ?? _local!.editDetails,
      sendMessage: sendMessage ?? _local!.sendMessage,
      call: call ?? _local!.call,
      addMember: addMember ?? _local!.addMember,
      approveMember: approveMember ?? _local!.approveMember,
    );
    setState(() => _local = updated);
    ref
        .read(groupViewModelProvider(widget.groupId).notifier)
        .updateSettings(updated.toApiJson());
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: context.cc.secondaryText,
          ),
        ),
      );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: context.cc.cardBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(children: children),
      );
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: context.cc.secondaryText)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: const Color(0xFF057EFC),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 62, endIndent: 0,
              color: Color(0xFFEEEEEE)),
      ],
    );
  }
}
