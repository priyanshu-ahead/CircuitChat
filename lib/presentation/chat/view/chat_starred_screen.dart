import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/message_model.dart';

// ── State & ViewModel ─────────────────────────────────────────────────────────

class _StarredState {
  const _StarredState({
    this.messages = const [],
    this.isLoading = true,
    this.editMode = false,
    this.selected = const [],
  });

  final List<MessageModel> messages;
  final bool isLoading;
  final bool editMode;
  final List<String> selected;

  _StarredState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? editMode,
    List<String>? selected,
  }) =>
      _StarredState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        editMode: editMode ?? this.editMode,
        selected: selected ?? this.selected,
      );
}

class _StarredNotifier
    extends FamilyNotifier<_StarredState, ChatModel> {
  @override
  _StarredState build(ChatModel arg) {
    _chat = arg;
    _load();
    return const _StarredState();
  }

  late final ChatModel _chat;

  String get _chatType =>
      _chat.type == ChatType.group ? 'group' : 'user';

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    try {
      List<MessageModel> msgs;
      if (_chat.id == 'all') {
        // Aggregate starred messages across all chats via /message/starred
        final raw = await ref
            .read(apiClientProvider)
            .get<Map<String, dynamic>>(
          '/message/starred',
        );
        msgs = (raw['messages'] as List? ?? raw['data'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map((e) => MessageModel.fromJson(e))
            .toList();
      } else {
        final raw = await ref
            .read(apiClientProvider)
            .get<Map<String, dynamic>>(
          ApiEndpoints.messageStarredList(_chat.id, _chatType),
        );
        msgs = (raw['messages'] as List? ?? raw['data'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map((e) => MessageModel.fromJson(e))
            .toList();
      }
      state = state.copyWith(messages: msgs, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void toggleEditMode() {
    state = state.copyWith(
      editMode: !state.editMode,
      selected: [],
    );
  }

  void toggleSelect(String id) {
    final prev = [...state.selected];
    if (prev.contains(id)) {
      prev.remove(id);
    } else {
      prev.add(id);
    }
    state = state.copyWith(selected: prev);
  }

  Future<void> unstarSelected() async {
    final ids = [...state.selected];
    if (ids.isEmpty) return;
    try {
      await ref
          .read(apiClientProvider)
          .post<void>(ApiEndpoints.messageUnstarred, data: {
        'messages': ids,
        'chat': _chat.id,
        'chatType': _chatType,
      });
      state = state.copyWith(
        messages:
            state.messages.where((m) => !ids.contains(m.id)).toList(),
        selected: [],
        editMode: false,
      );
    } catch (_) {}
  }

  Future<void> deleteSelected() async {
    final ids = [...state.selected];
    if (ids.isEmpty) return;
    try {
      await ref.read(chatRepositoryProvider).deleteMessage(ids);
      state = state.copyWith(
        messages:
            state.messages.where((m) => !ids.contains(m.id)).toList(),
        selected: [],
        editMode: false,
      );
    } catch (_) {}
  }
}

final _starredProvider = NotifierProviderFamily<_StarredNotifier,
    _StarredState, ChatModel>(_StarredNotifier.new);

// ── Screen ────────────────────────────────────────────────────────────────────

class ChatStarredScreen extends ConsumerWidget {
  const ChatStarredScreen({super.key, required this.chat});
  final ChatModel chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    final state = ref.watch(_starredProvider(chat));

    return Scaffold(
      backgroundColor: cc.pageBackground,
      appBar: AppBar(
        backgroundColor: cc.pageBackground,
        foregroundColor: cc.primaryText,
        elevation: 0.5,
        title: Text(
          'Starred Messages',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: cc.primaryText),
        ),
        actions: [
          if (state.messages.isNotEmpty)
            TextButton(
              onPressed: () => ref
                  .read(_starredProvider(chat).notifier)
                  .toggleEditMode(),
              child: Text(
                state.editMode ? 'Done' : 'Edit',
                style: TextStyle(color: primary),
              ),
            ),
        ],
      ),
      body: state.isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : state.messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_outline_rounded,
                          size: 56, color: cc.secondaryText),
                      const SizedBox(height: 12),
                      Text('No starred messages',
                          style: TextStyle(
                              color: cc.secondaryText, fontSize: 15)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: state.messages.length,
                        itemBuilder: (_, i) {
                          final msg = state.messages[i];
                          final selected =
                              state.selected.contains(msg.id);
                          return _StarredItem(
                            message: msg,
                            isEditMode: state.editMode,
                            isSelected: selected,
                            onTap: state.editMode
                                ? () => ref
                                    .read(_starredProvider(chat)
                                        .notifier)
                                    .toggleSelect(msg.id)
                                : null,
                          );
                        },
                      ),
                    ),
                    // Edit mode action bar
                    if (state.editMode)
                      _EditBar(
                        selectedCount: state.selected.length,
                        onUnstar: () => ref
                            .read(_starredProvider(chat).notifier)
                            .unstarSelected(),
                        onDelete: () => ref
                            .read(_starredProvider(chat).notifier)
                            .deleteSelected(),
                      ),
                  ],
                ),
    );
  }
}

// ── Starred item ──────────────────────────────────────────────────────────────

class _StarredItem extends StatelessWidget {
  const _StarredItem({
    required this.message,
    required this.isEditMode,
    required this.isSelected,
    this.onTap,
  });

  final MessageModel message;
  final bool isEditMode;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.15)
              : cc.pageBackground,
          border: Border(
              bottom: BorderSide(
                  color: cc.border, width: 0.8)),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Select checkbox in edit mode
            if (isEditMode) ...[
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? primary
                    : cc.secondaryText,
              ),
              const SizedBox(width: 10),
            ],
            // Avatar
            _buildAvatar(context, message),
            const SizedBox(width: 10),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // From → To
                  Row(
                    children: [
                      Text(
                        message.fromMe ? 'You' : 'Contact',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: cc.primaryText),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: cc.secondaryText),
                      ),
                      Expanded(
                        child: Text(
                          'Chat',
                          style: TextStyle(
                              fontSize: 13,
                              color: cc.secondaryText),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatDate(message.createdAt),
                        style: TextStyle(
                            fontSize: 11,
                            color: cc.secondaryText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Message body
                  _buildContent(context),
                ],
              ),
            ),
            // Star icon
            if (!isEditMode)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.star_rounded,
                    color: Color(0xFFFFC107), size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, MessageModel msg) {
    final primary = Theme.of(context).colorScheme.primary;
    return CircleAvatar(
      radius: 18,
      backgroundColor: primary,
      child: const Icon(Icons.person_rounded,
          color: Colors.white, size: 18),
    );
  }

  Widget _buildContent(BuildContext context) {
    final cc = context.cc;
    switch (message.contentType) {
      case ContentType.image:
        return Row(
          children: [
            Icon(Icons.photo_outlined,
                size: 14, color: cc.secondaryText),
            const SizedBox(width: 4),
            Text('Photo',
                style: TextStyle(
                    fontSize: 13, color: cc.secondaryText)),
          ],
        );
      case ContentType.video:
        return Row(children: [
          Icon(Icons.videocam_outlined,
              size: 14, color: cc.secondaryText),
          const SizedBox(width: 4),
          Text('Video',
              style: TextStyle(
                  fontSize: 13, color: cc.secondaryText)),
        ]);
      case ContentType.audio:
        return Row(children: [
          Icon(Icons.mic_none_rounded,
              size: 14, color: cc.secondaryText),
          const SizedBox(width: 4),
          Text('Audio',
              style: TextStyle(
                  fontSize: 13, color: cc.secondaryText)),
        ]);
      case ContentType.file:
        return Row(children: [
          Icon(Icons.attach_file_rounded,
              size: 14, color: cc.secondaryText),
          const SizedBox(width: 4),
          Text('File',
              style: TextStyle(
                  fontSize: 13, color: cc.secondaryText)),
        ]);
      default:
        return Text(
          message.text ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style:
              TextStyle(fontSize: 13, color: cc.primaryText),
        );
    }
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('MMM d, yyyy')
          .format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }
}

// ── Edit mode action bar ──────────────────────────────────────────────────────

class _EditBar extends StatelessWidget {
  const _EditBar({
    required this.selectedCount,
    required this.onUnstar,
    required this.onDelete,
  });

  final int selectedCount;
  final VoidCallback onUnstar;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: cc.cardBackground,
        border: Border(
            top: BorderSide(color: cc.border, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BarAction(
            icon: Icons.star_border_rounded,
            label: 'Unstar',
            enabled: selectedCount > 0,
            onTap: onUnstar,
          ),
          _BarAction(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: const Color(0xFFE53935),
            enabled: selectedCount > 0,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.enabled = true,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    final c = enabled
        ? (color ?? primary)
        : cc.secondaryText;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 24, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: c)),
          ],
        ),
      ),
    );
  }
}
