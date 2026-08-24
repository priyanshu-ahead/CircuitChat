import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';

// ── State & ViewModel ─────────────────────────────────────────────────────────

class _NotifState {
  const _NotifState({
    this.messages = true,
    this.groups = true,
    this.calls = true,
    this.sound = true,
    this.vibration = true,
    this.preview = true,
    this.isLoading = true,
    this.isSaving = false,
  });

  final bool messages;
  final bool groups;
  final bool calls;
  final bool sound;
  final bool vibration;
  final bool preview;
  final bool isLoading;
  final bool isSaving;

  _NotifState copyWith({
    bool? messages,
    bool? groups,
    bool? calls,
    bool? sound,
    bool? vibration,
    bool? preview,
    bool? isLoading,
    bool? isSaving,
  }) =>
      _NotifState(
        messages: messages ?? this.messages,
        groups: groups ?? this.groups,
        calls: calls ?? this.calls,
        sound: sound ?? this.sound,
        vibration: vibration ?? this.vibration,
        preview: preview ?? this.preview,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
      );

  Map<String, dynamic> toJson() => {
        'messages': messages,
        'groups': groups,
        'calls': calls,
        'sound': sound,
        'vibration': vibration,
        'preview': preview,
      };
}

class _NotifNotifier extends Notifier<_NotifState> {
  @override
  _NotifState build() {
    _load();
    return const _NotifState();
  }

  Future<void> _load() async {
    try {
      final raw = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
              ApiEndpoints.generalSettingsByKey('notification_setting'));
      final n =
          raw['notification_setting'] as Map<String, dynamic>? ?? {};
      state = _NotifState(
        messages: n['messages'] != false,
        groups: n['groups'] != false,
        calls: n['calls'] != false,
        sound: n['sound'] != false,
        vibration: n['vibration'] != false,
        preview: n['preview'] != false,
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
            ApiEndpoints.pushNotification,
            data: state.toJson(),
          );
    } catch (_) {}
    state = state.copyWith(isSaving: false);
  }

  void toggle(String field, bool v) {
    switch (field) {
      case 'messages':
        state = state.copyWith(messages: v);
        break;
      case 'groups':
        state = state.copyWith(groups: v);
        break;
      case 'calls':
        state = state.copyWith(calls: v);
        break;
      case 'sound':
        state = state.copyWith(sound: v);
        break;
      case 'vibration':
        state = state.copyWith(vibration: v);
        break;
      case 'preview':
        state = state.copyWith(preview: v);
        break;
    }
    _save();
  }
}

final _notifProvider =
    NotifierProvider<_NotifNotifier, _NotifState>(_NotifNotifier.new);

// ── Screen ────────────────────────────────────────────────────────────────────

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_notifProvider);
    final vm = ref.read(_notifProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text(
          'Notifications',
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
                _Label('Notify me about'),
                _Card(
                  children: [
                    _SwitchTile(
                      title: 'Messages',
                      subtitle: 'New direct messages',
                      value: state.messages,
                      onChanged: (v) => vm.toggle('messages', v),
                    ),
                    _SwitchTile(
                      title: 'Group Messages',
                      subtitle: 'Messages in groups',
                      value: state.groups,
                      onChanged: (v) => vm.toggle('groups', v),
                    ),
                    _SwitchTile(
                      title: 'Calls',
                      subtitle: 'Incoming voice & video calls',
                      value: state.calls,
                      onChanged: (v) => vm.toggle('calls', v),
                      isLast: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Label('Notification style'),
                _Card(
                  children: [
                    _SwitchTile(
                      title: 'Sound',
                      subtitle: 'Play notification sounds',
                      value: state.sound,
                      onChanged: (v) => vm.toggle('sound', v),
                    ),
                    _SwitchTile(
                      title: 'Vibration',
                      subtitle: 'Vibrate for notifications',
                      value: state.vibration,
                      onChanged: (v) => vm.toggle('vibration', v),
                    ),
                    _SwitchTile(
                      title: 'Message Preview',
                      subtitle:
                          'Show message content in notifications',
                      value: state.preview,
                      onChanged: (v) => vm.toggle('preview', v),
                      isLast: true,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
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

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 4)
          ],
        ),
        child: Column(children: children),
      );
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: Text(title, style: const TextStyle(fontSize: 15)),
          subtitle: Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF888888))),
          value: value,
          activeColor: const Color(0xFF1976D2),
          onChanged: onChanged,
        ),
        if (!isLast)
          const Divider(height: 1, indent: 16, color: Color(0xFFEEEEEE)),
      ],
    );
  }
}
