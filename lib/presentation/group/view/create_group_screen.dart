import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/user_model.dart';
import '../../chat/viewmodel/chat_list_viewmodel.dart';
import '../viewmodel/group_viewmodel.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() =>
      _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  // Step 0 = member picker, Step 1 = details
  int _step = 0;

  // Step 0
  final Map<String, UserModel> _selected = {};
  final _searchCtrl = TextEditingController();
  String _query     = '';
  List<ChatModel> _contacts = [];
  bool _contactsLoading = true;

  // Step 1
  final _nameCtrl     = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _pwCtrl       = TextEditingController();
  String _privacyType = 'open'; // open | private | password_protected
  bool   _obscurePw   = true;
  File?  _avatar;
  bool   _creating    = false;

  @override
  void initState() {
    super.initState();
    _loadContacts('');
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.toLowerCase());
      _loadContacts(_searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContacts(String q) async {
    setState(() => _contactsLoading = true);
    try {
      final api  = ref.read(apiClientProvider);
      final raw  = await api.get<Map<String, dynamic>>(
        ApiEndpoints.groupCreateSearch,
        queryParameters: q.isNotEmpty ? {'search': q} : null,
      );
      final list = (raw['chats'] as List? ?? raw['users'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((e) => ChatModel.fromJson(e))
          .toList();
      if (mounted) setState(() { _contacts = list; _contactsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _contactsLoading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final xf = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xf != null) setState(() => _avatar = File(xf.path));
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group name is required.')));
      return;
    }
    if (_privacyType == 'password_protected' && _pwCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a group password.')));
      return;
    }
    setState(() => _creating = true);

    final repo = ref.read(groupRepositoryProvider);
    final data = <String, dynamic>{
      'name':  name,
      'type':  _privacyType,
      'users': _selected.keys.toList(),
      if (_descCtrl.text.trim().isNotEmpty) 'metadata': _descCtrl.text.trim(),
      if (_privacyType == 'password_protected' && _pwCtrl.text.isNotEmpty)
        'password': _pwCtrl.text,
      if (_avatar != null) 'avatar': _avatar!.path,
    };

    final result = await repo.createGroup(data);
    if (!mounted) return;
    setState(() => _creating = false);

    if (result.success && result.data != null) {
      final group = result.data!;
      context.go(
        Routes.chatDetail.replaceFirst(':chatId', group.chatId ?? group.id),
        extra: ChatModel(
          id: group.chatId ?? group.id,
          type: ChatType.group,
          name: group.name,
          avatar: group.avatar,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Failed to create group.')));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: cc.pageBackground,
      appBar: AppBar(
        backgroundColor: cc.pageBackground,
        foregroundColor: cc.primaryText,
        elevation: 0.5,
        leading: _step == 1
            ? IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: cc.primaryText),
                onPressed: () => setState(() => _step = 0),
              )
            : null,
        title: Text(_step == 0 ? 'New Group' : 'Group Details',
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 17, color: cc.primaryText)),
        actions: [
          if (_step == 0)
            TextButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () => setState(() => _step = 1),
              child: Text(
                'Next',
                style: TextStyle(
                  color: _selected.isEmpty
                      ? cc.border
                      : primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _creating ? null : _create,
              child: _creating
                  ? SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primary))
                  : Text('Create',
                      style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _step == 0 ? _buildStep0() : _buildStep1(),
    );
  }

  // ── Step 0: Member Picker ─────────────────────────────────────────────────

  Widget _buildStep0() {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    final filtered = _query.isEmpty
        ? _contacts
        : _contacts.where((c) =>
            (c.name ?? '').toLowerCase().contains(_query)).toList();

    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(color: cc.primaryText),
            decoration: InputDecoration(
              hintText: 'Search contacts…',
              hintStyle: TextStyle(color: cc.secondaryText),
              prefixIcon: Icon(Icons.search_rounded,
                  color: cc.secondaryText),
              filled: true,
              fillColor: cc.searchBackground,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // Selected chips
        if (_selected.isNotEmpty)
          SizedBox(
            height: 70,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _selected.values.map((u) => _Chip(
                    user: u,
                    onRemove: () => setState(() =>
                        _selected.remove(u.id)),
                  )).toList(),
            ),
          ),
        // Contact list
        Expanded(
          child: _contactsLoading
              ? Center(child: CircularProgressIndicator(color: primary))
              : filtered.isEmpty
                  ? Center(
                      child: Text('No contacts found',
                          style: TextStyle(color: cc.secondaryText)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final chat = filtered[i];
                        final sel  = _selected.containsKey(chat.id);
                        return ListTile(
                          onTap: () => setState(() {
                            if (sel) {
                              _selected.remove(chat.id);
                            } else {
                              _selected[chat.id] = UserModel(
                                id: chat.id,
                                username: chat.name ?? '',
                                email:    '',
                                displayName: chat.name,
                                avatar: chat.avatar,
                              );
                            }
                          }),
                          leading: _buildAvatar(chat.avatar, chat.name ?? '?'),
                          title: Text(chat.name ?? 'Unknown', style: TextStyle(color: cc.primaryText)),
                          trailing: sel
                              ? Icon(Icons.check_circle_rounded,
                                  color: primary)
                              : Icon(
                                  Icons.radio_button_unchecked_rounded,
                                  color: cc.border),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ── Step 1: Group Details ─────────────────────────────────────────────────

  Widget _buildStep1() {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Avatar picker
        Center(
          child: GestureDetector(
            onTap: _pickAvatar,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: primary.withValues(alpha: 0.12),
                  backgroundImage:
                      _avatar != null ? FileImage(_avatar!) : null,
                  child: _avatar == null
                      ? Icon(Icons.camera_alt_rounded,
                          color: primary, size: 32)
                      : null,
                ),
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: cc.cardBackground, width: 2),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Name
        _field(_nameCtrl, 'Group Name', maxLength: 32),
        const SizedBox(height: 12),
        // Description
        _field(_descCtrl, 'Description (optional)', maxLines: 2, maxLength: 200),
        const SizedBox(height: 16),
        // Privacy type
        Text('Group Privacy',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cc.secondaryText)),
        const SizedBox(height: 6),
        _privacyCard(),
        // Password field (if password_protected)
        if (_privacyType == 'password_protected') ...[
          const SizedBox(height: 12),
          _passwordField(),
        ],
        // Selected members preview
        const SizedBox(height: 16),
        Text('Members',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cc.secondaryText)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _selected.values
              .map((u) => _Chip(user: u, onRemove: null))
              .toList(),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String hint,
      {int maxLines = 1, int? maxLength}) {
    final cc = context.cc;
    return Container(
        decoration: BoxDecoration(
          color: cc.inputBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: TextField(
          controller: ctrl,
          maxLines: maxLines,
          maxLength: maxLength,
          style: TextStyle(color: cc.primaryText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: cc.secondaryText),
            border: InputBorder.none,
            counterText: '',
          ),
        ),
      );
  }

  Widget _privacyCard() {
    final cc = context.cc;
    return Container(
        decoration: BoxDecoration(
          color: cc.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cc.border),
        ),
        child: Column(
          children: [
            _privacyOption('open',                'Public',    'Anyone can join'),
            _privacyOption('private',             'Private',   'Admin must approve'),
            _privacyOption('password_protected',  'Password',  'Require a password'),
          ],
        ),
      );
  }

  Widget _privacyOption(String val, String label, String sub) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    return RadioListTile<String>(
        value:    val,
        groupValue: _privacyType,
        title:    Text(label, style: TextStyle(color: cc.primaryText)),
        subtitle: Text(sub, style: TextStyle(fontSize: 12, color: cc.secondaryText)),
        activeColor: primary,
        dense: true,
        onChanged: (v) => setState(() { if (v != null) _privacyType = v; }),
      );
  }

  Widget _passwordField() {
    final cc = context.cc;
    return Container(
        decoration: BoxDecoration(
          color: cc.inputBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: TextField(
          controller: _pwCtrl,
          obscureText: _obscurePw,
          style: TextStyle(color: cc.primaryText),
          decoration: InputDecoration(
            hintText: 'Group password',
            hintStyle: TextStyle(color: cc.secondaryText),
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePw
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: cc.secondaryText, size: 20,
              ),
              onPressed: () => setState(() => _obscurePw = !_obscurePw),
            ),
          ),
        ),
      );
  }

  Widget _buildAvatar(String? url, String name) {
    final primary = Theme.of(context).colorScheme.primary;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
          radius: 22, backgroundImage: CachedNetworkImageProvider(url));
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: primary,
      child: Text(name[0].toUpperCase(),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.user, required this.onRemove});
  final UserModel  user;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: primary,
                backgroundImage: user.avatar != null
                    ? CachedNetworkImageProvider(user.avatar!)
                    : null,
                child: user.avatar == null
                    ? Text(user.name[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600))
                    : null,
              ),
              if (onRemove != null)
                Positioned(
                  right: -4, top: -4,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                          color: cc.secondaryText, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 12),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 52,
            child: Text(
              user.name.split(' ').first,
              style: TextStyle(fontSize: 11, color: cc.primaryText),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
  }
}
