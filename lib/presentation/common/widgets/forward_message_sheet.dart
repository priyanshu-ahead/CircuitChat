import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/chat_model.dart';
import '../../chat/viewmodel/chat_list_viewmodel.dart';
import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_theme.dart';

/// Shows a bottom sheet listing all chats.
/// The caller provides either message IDs or a text link to forward.
///
/// Usage:
///   ForwardMessageSheet.show(context, messageIds: ['id1']);
///   ForwardMessageSheet.show(context, linkText: 'https://…');
class ForwardMessageSheet extends ConsumerStatefulWidget {
  const ForwardMessageSheet({
    super.key,
    this.messageIds = const [],
    this.linkText,
  });

  final List<String> messageIds;
  final String?      linkText;

  static Future<void> show(
    BuildContext context, {
    List<String> messageIds = const [],
    String?      linkText,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ForwardMessageSheet(
          messageIds: messageIds, linkText: linkText),
    );
  }

  @override
  ConsumerState<ForwardMessageSheet> createState() =>
      _ForwardMessageSheetState();
}

class _ForwardMessageSheetState
    extends ConsumerState<ForwardMessageSheet> {
  final _selected = <String>{};
  bool  _sending  = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    final chats = ref.watch(chatListViewModelProvider).chats;
    final filtered = _query.isEmpty
        ? chats
        : chats
            .where((c) =>
                (c.name ?? '').toLowerCase().contains(_query))
            .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        color: cc.pageBackground,
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: cc.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 8),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Forward to',
                        style: TextStyle(
                            color: cc.primaryText,
                            fontWeight: FontWeight.w700, fontSize: 17)),
                  ),
                  if (_selected.isNotEmpty)
                    ElevatedButton(
                      onPressed: _sending ? null : _forward,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text('Send (${_selected.length})'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(color: cc.primaryText),
                decoration: InputDecoration(
                  hintText: 'Search chats…',
                  hintStyle: TextStyle(color: cc.secondaryText),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: cc.secondaryText),
                  filled: true,
                  fillColor: cc.searchBackground,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // List
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final chat     = filtered[i];
                  final isSelected = _selected.contains(chat.id);
                  return ListTile(
                    onTap: () => setState(() {
                      if (isSelected) {
                        _selected.remove(chat.id);
                      } else {
                        _selected.add(chat.id);
                      }
                    }),
                    leading: _Avatar(url: chat.avatar, name: chat.name ?? '?'),
                    title: Text(chat.name ?? 'Unknown',
                        style: TextStyle(
                            color: cc.primaryText,
                            fontWeight: FontWeight.w500)),
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded,
                            color: primary)
                        : Icon(Icons.radio_button_unchecked_rounded,
                            color: cc.secondaryText),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _forward() async {
    if (_selected.isEmpty) return;
    setState(() => _sending = true);
    try {
      final api       = ref.read(apiClientProvider);
      final targetIds = _selected.toList();

      if (widget.linkText != null) {
        // Forward as text messages to each target
        for (final chatId in targetIds) {
          await api.post<void>(ApiEndpoints.sendMessage, data: {
            'chat':        chatId,
            'chatType':    'user',
            'contentType': 'text',
            'text':        widget.linkText,
          });
        }
      } else if (widget.messageIds.isNotEmpty) {
        await api.post<void>(ApiEndpoints.messageForward, data: {
          'messages': widget.messageIds,
          'chats':    targetIds,
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              'Forwarded to ${_selected.length} chat${_selected.length > 1 ? 's' : ''}.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to forward. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});
  final String? url;
  final String  name;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: CachedNetworkImageProvider(url!),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}
