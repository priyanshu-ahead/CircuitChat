import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_theme.dart';

// ── Privacy option values ─────────────────────────────────────────────────────
// Mirrors RN's PRIVACY_OPTION: everyone / contacts / nobody
const _kEveryone = 'everyone';
const _kContacts = 'contacts';
const _kNobody = 'nobody';

// ── State & ViewModel ─────────────────────────────────────────────────────────

class _PrivacyState {
  const _PrivacyState({
    this.profilePhoto = _kEveryone,
    this.about = _kEveryone,
    this.isLoading = false,
    this.isSaving = false,
  });

  final String profilePhoto;
  final String about;
  final bool isLoading;
  final bool isSaving;

  _PrivacyState copyWith({
    String? profilePhoto,
    String? about,
    bool? isLoading,
    bool? isSaving,
  }) =>
      _PrivacyState(
        profilePhoto: profilePhoto ?? this.profilePhoto,
        about:        about        ?? this.about,
        isLoading:    isLoading    ?? this.isLoading,
        isSaving:     isSaving     ?? this.isSaving,
      );

  Map<String, dynamic> toJson() => {
        'profilePhoto': profilePhoto,
        'about':        about,
      };
}

class _PrivacyNotifier extends Notifier<_PrivacyState> {
  @override
  _PrivacyState build() {
    Future.microtask(_load);
    return const _PrivacyState(isLoading: true);
  }

  Future<void> _load() async {
    try {
      final raw = await ref
          .read(apiClientProvider)
          .get<dynamic>(ApiEndpoints.generalSettings);
      Map<String, dynamic> privacy = {};
      if (raw is Map<String, dynamic>) {
        privacy = raw['privacy'] as Map<String, dynamic>? ?? {};
      }
      state = _PrivacyState(
        profilePhoto: privacy['profilePhoto']?.toString() ?? _kEveryone,
        about:        privacy['about']?.toString()        ?? _kEveryone,
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

  void setProfilePhoto(String v) {
    state = state.copyWith(profilePhoto: v);
    _save();
  }

  void setAbout(String v) {
    state = state.copyWith(about: v);
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
    final cc    = context.cc;
    final state = ref.watch(_privacyProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: cc.surfaceBackground,
      appBar: AppBar(
        title: Text('Privacy',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: cc.primaryText)),
        actions: [
          if (state.isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: primary),
                ),
              ),
            ),
        ],
      ),
      body: state.isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : ListView(
              children: [
                const SizedBox(height: 12),
                _GroupLabel('Who can see my info', cc: cc),

                // ── Only Profile Photo and About ───────────────────────────
                _PrivacyCard(cc: cc, children: [
                  _PrivacyOptionTile(
                    title: 'Profile Photo',
                    subtitle: 'Who can see your profile photo',
                    value: state.profilePhoto,
                    cc: cc,
                    onChanged: (v) => ref
                        .read(_privacyProvider.notifier)
                        .setProfilePhoto(v),
                  ),
                  _PrivacyDivider(cc: cc),
                  _PrivacyOptionTile(
                    title: 'About',
                    subtitle: 'Who can see your about / bio',
                    value: state.about,
                    cc: cc,
                    onChanged: (v) =>
                        ref.read(_privacyProvider.notifier).setAbout(v),
                  ),
                ]),

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ── Privacy card container ────────────────────────────────────────────────────

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.children, required this.cc});
  final List<Widget> children;
  final CircuitChatColors cc;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: cc.cardBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 4)
          ],
        ),
        child: Column(children: children),
      );
}

class _PrivacyDivider extends StatelessWidget {
  const _PrivacyDivider({required this.cc});
  final CircuitChatColors cc;

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: 16, color: cc.divider);
}

// ── Privacy option tile with bottom sheet picker ──────────────────────────────

class _PrivacyOptionTile extends StatelessWidget {
  const _PrivacyOptionTile({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.cc,
    this.subtitle,
  });

  final String title;
  final String value;
  final ValueChanged<String> onChanged;
  final CircuitChatColors cc;
  final String? subtitle;

  static const _labels = {
    _kEveryone: 'Everyone',
    _kContacts: 'My Contacts',
    _kNobody: 'Nobody',
  };

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      title: Text(title,
          style: TextStyle(fontSize: 15, color: cc.primaryText)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: TextStyle(fontSize: 12, color: cc.secondaryText))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _labels[value] ?? value,
            style: TextStyle(color: primary, fontSize: 13),
          ),
          Icon(Icons.chevron_right_rounded,
              color: cc.secondaryText, size: 20),
        ],
      ),
      onTap: () => _showPicker(context),
    );
  }

  void _showPicker(BuildContext context) {
    final cc      = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: cc.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: cc.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: cc.primaryText),
            ),
            Divider(color: cc.divider),
            ...[_kEveryone, _kContacts, _kNobody].map(
              (opt) => RadioListTile<String>(
                title: Text(_labels[opt]!,
                    style: TextStyle(color: cc.primaryText)),
                value: opt,
                groupValue: value,
                activeColor: primary,
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
  const _GroupLabel(this.text, {required this.cc});
  final String text;
  final CircuitChatColors cc;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cc.secondaryText,
          ),
        ),
      );
}
