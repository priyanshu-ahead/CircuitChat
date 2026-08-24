import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text('Message Info',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
                      color: const Color(0xFF1976D2)),
                const SizedBox(height: 8),
                _label('Delivered to (${_deliveredTo.length})'),
                if (_deliveredTo.isEmpty)
                  _emptyHint('Not yet delivered')
                else
                  _userList(_deliveredTo,
                      icon: Icons.done_all_rounded,
                      color: const Color(0xFF9AA6B8)),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF888888))),
      );

  Widget _timeCard(String iso) => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(_fmt(iso),
            style: const TextStyle(fontSize: 14, color: Colors.black87)),
      );

  Widget _emptyHint(String text) => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF888888),
                fontStyle: FontStyle.italic)),
      );

  Widget _userList(List<Map<String, dynamic>> list,
      {required IconData icon, required Color color}) {
    return Container(
      color: Colors.white,
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
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: ts != null
                    ? Text(_fmt(ts),
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF888888)))
                    : null,
                trailing: Icon(icon, color: color, size: 18),
              ),
              if (i < list.length - 1)
                const Divider(height: 1, indent: 66),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _avatar(UserModel user) {
    if (user.avatar != null && user.avatar!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: CachedNetworkImageProvider(user.avatar!),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFF1976D2),
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
