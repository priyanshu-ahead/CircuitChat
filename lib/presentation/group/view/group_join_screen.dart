import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/group_model.dart';
import '../viewmodel/group_viewmodel.dart';

class GroupJoinScreen extends ConsumerStatefulWidget {
  const GroupJoinScreen({super.key, required this.token});
  final String token;

  @override
  ConsumerState<GroupJoinScreen> createState() => _GroupJoinScreenState();
}

class _GroupJoinScreenState extends ConsumerState<GroupJoinScreen> {
  GroupModel? _group;
  bool _loading = true;
  bool _joining = false;
  String? _error;
  bool _needsPassword = false;

  @override
  void initState() {
    super.initState();
    _fetchGroup();
  }

  Future<void> _fetchGroup() async {
    try {
      final api = ref.read(apiClientProvider);
      final raw = await api.get<Map<String, dynamic>>(
        ApiEndpoints.groupById(widget.token),
      );
      if (mounted) {
        setState(() {
          _group = GroupModel.fromJson(raw);
          _loading = false;
          _needsPassword =
              _group?.type == GroupType.passwordProtected;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'Group not found.'; _loading = false; });
      }
    }
  }

  Future<void> _join({String? password}) async {
    final g = _group;
    if (g == null) return;
    setState(() => _joining = true);

    try {
      final repo = ref.read(groupRepositoryProvider);

      if (password != null) {
        final valid = await repo.validatePassword(g.id, password);
        if (!valid.success) {
          setState(() { _joining = false; _error = 'Incorrect password.'; });
          return;
        }
      }

      final result = await repo.joinGroupByLink(g.id);
      if (!mounted) return;
      setState(() => _joining = false);

      if (result.success) {
        context.go(
          Routes.chatDetail.replaceFirst(':chatId', g.chatId ?? g.id),
          extra: ChatModel(
            id:     g.chatId ?? g.id,
            type:   ChatType.group,
            name:   g.name,
            avatar: g.avatar,
          ),
        );
      } else {
        setState(() => _error = result.message ?? 'Failed to join group.');
      }
    } catch (e) {
      if (mounted) {
        setState(() { _joining = false; _error = e.toString(); });
      }
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
        title: const Text('Join Group',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _group == null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Color(0xFF888888))))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final g = _group!;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8)
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Group avatar
            CircleAvatar(
              radius: 44,
              backgroundColor: const Color(0xFF1976D2),
              backgroundImage: g.avatar != null
                  ? NetworkImage(g.avatar!) : null,
              child: g.avatar == null
                  ? Text(g.name.isNotEmpty ? g.name[0].toUpperCase() : 'G',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w700))
                  : null,
            ),
            const SizedBox(height: 14),
            Text(g.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 20)),
            const SizedBox(height: 4),
            Text('${g.memberCount} members',
                style: const TextStyle(
                    color: Color(0xFF888888), fontSize: 13)),
            if (g.about != null && g.about!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(g.about!,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF444444)),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            // Password field
            if (_needsPassword) ...[
              _GroupPasswordField(
                onJoin: (pw) => _join(password: pw),
                joining: _joining,
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _joining ? null : () => _join(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _joining
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Join Group'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFE53935), fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline password entry widget used inside GroupJoinScreen.
class _GroupPasswordField extends StatefulWidget {
  const _GroupPasswordField({
    required this.onJoin,
    required this.joining,
  });
  final void Function(String password) onJoin;
  final bool joining;

  @override
  State<_GroupPasswordField> createState() => _GroupPasswordFieldState();
}

class _GroupPasswordFieldState extends State<_GroupPasswordField> {
  final _ctrl    = TextEditingController();
  bool  _obscure = true;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: _ctrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                hintText: 'Enter group password',
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF888888), size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.joining
                  ? null
                  : () => widget.onJoin(_ctrl.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: widget.joining
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Join Group'),
            ),
          ),
        ],
      );
}
