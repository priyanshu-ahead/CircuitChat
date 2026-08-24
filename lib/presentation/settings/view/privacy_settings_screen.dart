import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';

// ── Privacy option values ─────────────────────────────────────────────────────
// Mirrors RN's PRIVACY_OPTION: everyone / contacts / nobody
const _kEveryone = 'everyone';
const _kContacts = 'contacts';
const _kNobody = 'nobody';

// ── State & ViewModel ─────────────────────────────────────────────────────────

class _PrivacyState {
  const _PrivacyState({
    this.lastSeen = _kEveryone,
    this.online = _kEveryone,
    this.profilePhoto = _kEveryone,
    this.about = _kEveryone,
    this.groups = _kEveryone,
    this.readReceipts = true,
    this.isLoading = true,
    this.isSaving = false,
  });

  final String lastSeen;
  final String online;
  final String profilePhoto;
  final String about;
  final String groups;
  final bool readReceipts;
  final bool isLoading;
  final bool isSaving;

  _PrivacyState copyWith({
    String? lastSeen,
    String? online,
    String? profilePhoto,
    String? about,
    String? groups,
    bool? readReceipts,
    bool? isLoading,
    bool? isSaving,
  }) =>
      _PrivacyState(
        lastSeen: lastSeen ?? this.lastSeen,
        online: online ?? this.online,
        profilePhoto: profilePhoto ?? this.profilePhoto,
        about: about ?? this.about,
        groups: groups ?? this.groups,
        readReceipts: readReceipts ?? this.readReceipts,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
      );

  Map<String, dynamic> toJson() => {
        'lastSeen': lastSeen,
        'online': online,
        'profilePhoto': profilePhoto,
        'about': about,
        'groups': groups,
        'readReceipts': readReceipts,
      };
}

class _PrivacyNotifier extends Notifier<_PrivacyState> {
  @override
  _PrivacyState build() {
    _load();
    return const _PrivacyState();
  }

  Future<void> _load() async {
    try {
      final raw = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(ApiEndpoints.generalSettings);
      final privacy = raw['privacy'] as Map<String, dynamic>? ?? {};
      state = _PrivacyState(
        lastSeen: privacy['lastSeen']?.toString() ?? _kEveryone,
        online: privacy['online']?.toString() ?? _kEveryone,
        profilePhoto:
            privacy['profilePhoto']?.toString() ?? _kEveryone,
        about: privacy['about']?.toString() ?? _kEveryone,
        groups: privacy['groups']?.toString() ?? _kEveryone,
        readReceipts: privacy['readReceipts'] != false,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _save() async {
    state = state.copyWith(isSaving: true);
    try {
      await ref.read(apiClientProvider).post<void>(
            ApiEndpoints.generalSettings,
            data: {'privacy': state.toJson()},
          );
    } catch (_) {}
    state = state.copyWith(isSaving: false);
  }

  void setLastSeen(String v) {
    state = state.copyWith(lastSeen: v);
    _save();
  }

  void setOnline(String v) {
    state = state.copyWith(online: v);
    _save();
  }

  void setProfilePhoto(String v) {
    state = state.copyWith(profilePhoto: v);
    _save();
  }

  void setAbout(String v) {
    state = state.copyWith(about: v);
    _save();
  }

  void setGroups(String v) {
    state = state.copyWith(groups: v);
    _save();
  }

  void setReadReceipts(bool v) {
    state = state.copyWith(readReceipts: v);
    _save();
  }
}

final _privacyProvider =
    NotifierProvider<_PrivacyNotifier, _PrivacyState>(
        _PrivacyNotifier.new);

// ── Screen ────────────────────────────────────────────────────────────────────

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_privacyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text(
          'Privacy',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        actions: [
          if (state.isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 12),
                _GroupLabel('Who can see my info'),
                _PrivacyOptionTile(
                  title: 'Last Seen',
                  value: state.lastSeen,
                  onChanged: (v) =>
                      ref.read(_privacyProvider.notifier).setLastSeen(v),
                ),
                _PrivacyOptionTile(
                  title: 'Online Status',
                  value: state.online,
                  onChanged: (v) =>
                      ref.read(_privacyProvider.notifier).setOnline(v),
                ),
                _PrivacyOptionTile(
                  title: 'Profile Photo',
                  value: state.profilePhoto,
                  onChanged: (v) => ref
                      .read(_privacyProvider.notifier)
                      .setProfilePhoto(v),
                ),
                _PrivacyOptionTile(
                  title: 'About',
                  value: state.about,
                  onChanged: (v) =>
                      ref.read(_privacyProvider.notifier).setAbout(v),
                ),
                _PrivacyOptionTile(
                  title: 'Groups',
                  subtitle:
                      'Who can add you to groups',
                  value: state.groups,
                  onChanged: (v) =>
                      ref.read(_privacyProvider.notifier).setGroups(v),
                ),
                const SizedBox(height: 16),
                _GroupLabel('Messages'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4)
                    ],
                  ),
                  child: SwitchListTile(
                    title: const Text('Read Receipts'),
                    subtitle: const Text(
                      'When turned off, others will not see when you\'ve read their messages.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: state.readReceipts,
                    activeColor: const Color(0xFF1976D2),
                    onChanged: (v) => ref
                        .read(_privacyProvider.notifier)
                        .setReadReceipts(v),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ── Privacy option tile with bottom sheet picker ──────────────────────────────

class _PrivacyOptionTile extends StatelessWidget {
  const _PrivacyOptionTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String value;
  final ValueChanged<String> onChanged;
  final String? subtitle;

  static const _labels = {
    _kEveryone: 'Everyone',
    _kContacts: 'My Contacts',
    _kNobody: 'Nobody',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 1),
      color: Colors.white,
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 15)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF888888)))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _labels[value] ?? value,
              style: const TextStyle(
                  color: Color(0xFF1976D2), fontSize: 13),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF888888), size: 20),
          ],
        ),
        onTap: () => _showPicker(context),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const Divider(),
            ...[_kEveryone, _kContacts, _kNobody].map(
              (opt) => RadioListTile<String>(
                title: Text(_labels[opt]!),
                value: opt,
                groupValue: value,
                activeColor: const Color(0xFF1976D2),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF888888),
          ),
        ),
      );
}
