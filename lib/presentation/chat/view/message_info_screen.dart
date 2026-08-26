import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';

class MessageInfoScreen extends ConsumerStatefulWidget {
  const MessageInfoScreen({super.key, required this.messageId});
  final String messageId;

  @override
  ConsumerState<MessageInfoScreen> createState() => _MessageInfoScreenState();
}

class _MessageInfoScreenState extends ConsumerState<MessageInfoScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _deliveredTo = [];
  List<Map<String, dynamic>> _seenBy      = [];
  String? _sentAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final raw = await api.get<Map<String, dynamic>>(
        ApiEndpoints.messageInfo(widget.messageId),
      );
      if (mounted) {
        setState(() {
          _sentAt      = raw['sentAt']?.toString();
          _deliveredTo = List<Map<String, dynamic>>.from(
              raw['deliveredTo'] as List? ?? []);
          _seenBy      = List<Map<String, dynamic>>.from(
              raw['seenBy'] as List? ?? []);
          _loading     = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: cc.surfaceBackground,
      appBar: AppBar(
        backgroundColor: cc.pageBackground,
        foregroundColor: cc.primaryText,
        elevation: 0.5,
        title: Text('Message Info',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: cc.primaryText)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primary))
          : ListView(
              children: [
                if (_sentAt != null) ...[
                  _label('Sent'),
                  _timeCard(_sentAt!),
                ],
                const SizedBox(height: 8),
                _label('Read by (${_seenBy.length})'),
                if (_seenBy.isEmpty)
                  _emptyHint('Not yet read')
                else
                  _userList(_seenBy, icon: Icons.done_all_rounded,
                      color: primary),
                const SizedBox(height: 8),
                _label('Delivered to (${_deliveredTo.length})'),
                if (_deliveredTo.isEmpty)
                  _emptyHint('Not yet delivered')
                else
                  _userList(_deliveredTo,
                      icon: Icons.done_all_rounded,
                      color: cc.secondaryText),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _label(String text) {
    final cc = context.cc;
    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cc.secondaryText)),
      );
  }

  Widget _timeCard(String iso) {
    final cc = context.cc;
    return Container(
        color: cc.cardBackground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(_fmt(iso),
            style: TextStyle(fontSize: 14, color: cc.primaryText)),
      );
  }

  Widget _emptyHint(String text) {
    final cc = context.cc;
    return Container(
        color: cc.cardBackground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(text,
            style: TextStyle(
                fontSize: 13, color: cc.secondaryText,
                fontStyle: FontStyle.italic)),
      );
  }

  Widget _userList(List<Map<String, dynamic>> list,
      {required IconData icon, required Color color}) {
    final cc = context.cc;
    return Container(
      color: cc.cardBackground,
      child: Column(
        children: list.asMap().entries.map((entry) {
          final i   = entry.key;
          final raw = entry.value;
          final user = UserModel.fromJson(
              raw['user'] is Map<String, dynamic>
                  ? raw['user'] as Map<String, dynamic>
                  : raw);
          final ts  = raw['at']?.toString() ?? raw['readAt']?.toString();
          return Column(
            children: [
              ListTile(
                leading: _avatar(user),
                title: Text(user.name,
                    style: TextStyle(fontWeight: FontWeight.w500, color: cc.primaryText)),
                subtitle: ts != null
                    ? Text(_fmt(ts),
                        style: TextStyle(
                            fontSize: 11, color: cc.secondaryText))
                    : null,
                trailing: Icon(icon, color: color, size: 18),
              ),
              if (i < list.length - 1)
                Divider(height: 1, indent: 66, color: cc.divider),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _avatar(UserModel user) {
    final primary = Theme.of(context).colorScheme.primary;
    if (user.avatar != null && user.avatar!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: CachedNetworkImageProvider(user.avatar!),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: primary,
      child: Text(
        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _fmt(String iso) {
    try {
      return DateFormat('MMM d, yyyy h:mm a')
          .format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }
}
