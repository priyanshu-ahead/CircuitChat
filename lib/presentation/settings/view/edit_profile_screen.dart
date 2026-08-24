import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/providers.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl  = TextEditingController();
  final _bioCtrl   = TextEditingController();
  final _phoneCtrl = TextEditingController();

  File?  _pickedImage;
  bool   _uploading = false;
  bool   _editingName = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authViewModelProvider).user;
    _nameCtrl.text  = user?.name  ?? '';
    _bioCtrl.text   = user?.bio   ?? '';
    _phoneCtrl.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Avatar picker ─────────────────────────────────────────────────────────

  void _showAvatarSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _sheetHandle(),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Library'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFE53935)),
              title: const Text('Remove Photo',
                  style: TextStyle(color: Color(0xFFE53935))),
              onTap: () { Navigator.pop(context); _removeAvatar(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(
        source: source, maxWidth: 800, imageQuality: 85);
    if (xfile == null) return;
    setState(() => _pickedImage = File(xfile.path));
    await _save();
  }

  Future<void> _removeAvatar() async {
    setState(() => _uploading = true);
    final repo = ref.read(userRepositoryProvider);
    final result = await repo.editProfile({'remove_avatar': true});
    _handleResult(result);
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save({bool nameOnly = false}) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name cannot be empty.');
      return;
    }
    setState(() { _uploading = true; _error = null; _editingName = false; });

    final data = <String, dynamic>{'name': name};
    if (!nameOnly) {
      if (_bioCtrl.text.trim().isNotEmpty)   data['bio']   = _bioCtrl.text.trim();
      if (_phoneCtrl.text.trim().isNotEmpty) data['phone'] = _phoneCtrl.text.trim();
      if (_pickedImage != null)              data['avatar'] = _pickedImage!.path;
    }

    final repo   = ref.read(userRepositoryProvider);
    final result = await repo.editProfile(data);
    _handleResult(result);
  }

  void _handleResult(ApiResult<dynamic> result) {
    if (!mounted) return;
    setState(() => _uploading = false);
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')));
      setState(() => _pickedImage = null);
    } else {
      setState(() => _error = result.message ?? 'Update failed.');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authViewModelProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text('Edit Profile',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [
          _uploading
              ? const Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: Center(
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text('Save',
                      style: TextStyle(
                          color: Color(0xFF1976D2),
                          fontWeight: FontWeight.w600)),
                ),
        ],
      ),
      body: ListView(
        children: [
          // ── Avatar ─────────────────────────────────────────────────────────
          const SizedBox(height: 28),
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _showAvatarSheet,
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: const Color(0xFFDDE4EF),
                    backgroundImage: _pickedImage != null
                        ? FileImage(_pickedImage!) as ImageProvider
                        : (user?.avatar != null && user!.avatar!.isNotEmpty
                            ? CachedNetworkImageProvider(user.avatar!)
                            : null),
                    child: _pickedImage == null &&
                            (user?.avatar == null || user!.avatar!.isEmpty)
                        ? Text(
                            (user?.name ?? '?')[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w600),
                          )
                        : null,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _showAvatarSheet,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
                if (_uploading && _pickedImage != null)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Name ───────────────────────────────────────────────────────────
          _SectionLabel('Your Name'),
          _Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      readOnly: !_editingName,
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter your name'),
                    ),
                  ),
                  if (_editingName) ...[
                    TextButton(
                      onPressed: () => _save(nameOnly: true),
                      child: const Text('Save'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _editingName = false;
                          _nameCtrl.text =
                              ref.read(authViewModelProvider).user?.name ?? '';
                        });
                      },
                      child: const Text('Cancel',
                          style: TextStyle(color: Color(0xFF888888))),
                    ),
                  ] else
                    IconButton(
                      icon: const Icon(Icons.edit_rounded,
                          color: Color(0xFF888888), size: 18),
                      onPressed: () => setState(() => _editingName = true),
                    ),
                ],
              ),
            ),
          ),

          // ── Bio ────────────────────────────────────────────────────────────
          const SizedBox(height: 12),
          _SectionLabel('About / Bio'),
          _Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              child: TextField(
                controller: _bioCtrl,
                maxLines: 3,
                maxLength: 200,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Write something about yourself…',
                    counterText: ''),
              ),
            ),
          ),

          // ── Phone ──────────────────────────────────────────────────────────
          const SizedBox(height: 12),
          _SectionLabel('Phone Number'),
          _Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              child: TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '+1 000 000 0000'),
              ),
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFE53935), fontSize: 13)),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Shared ─────────────────────────────────────────────────────────────────────

Widget _sheetHandle() => Center(
      child: Container(
        width: 36, height: 4,
        decoration: BoxDecoration(
            color: const Color(0xFFCCCCCC),
            borderRadius: BorderRadius.circular(2)),
      ),
    );

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF888888))),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

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
        child: child,
      );
}
