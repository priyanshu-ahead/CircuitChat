import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();

  File?  _pickedImage;
  bool   _uploading   = false;
  bool   _editingName = false;
  String? _error;

  // Original name — used by Cancel to reset
  String _originalName = '';

  @override
  void initState() {
    super.initState();
    final user = ref.read(authViewModelProvider).user;
    _originalName    = user?.name ?? '';
    _nameCtrl.text   = _originalName;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Avatar picker ─────────────────────────────────────────────────────────

  void _showAvatarSheet() {
    final cc = context.cc;
    showModalBottomSheet(
      context: context,
      backgroundColor: cc.cardBackground,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Library'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFE53935)),
              title: const Text('Remove Photo',
                  style: TextStyle(color: Color(0xFFE53935))),
              onTap: () {
                Navigator.pop(context);
                _removeAvatar();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final xfile = await ImagePicker().pickImage(
        source: source, maxWidth: 800, imageQuality: 85);
    if (xfile == null) return;
    setState(() { _pickedImage = File(xfile.path); _uploading = true; });
    await _saveAvatar(File(xfile.path));
  }

  Future<void> _saveAvatar(File file) async {
    final repo   = ref.read(userRepositoryProvider);
    final result = await repo.editProfile({'avatar': file.path});
    _handleResult(result);
  }

  Future<void> _removeAvatar() async {
    setState(() => _uploading = true);
    final repo   = ref.read(userRepositoryProvider);
    final result = await repo.editProfile({'remove_avatar': true});
    _handleResult(result);
  }

  // ── Save name ─────────────────────────────────────────────────────────────

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name cannot be empty.');
      return;
    }
    setState(() { _uploading = true; _error = null; _editingName = false; });
    final repo   = ref.read(userRepositoryProvider);
    final result = await repo.editProfile({'name': name});
    if (result.success) {
      _originalName = name; // update baseline for future cancels
    }
    _handleResult(result);
  }

  void _cancelEditName() {
    setState(() {
      _editingName    = false;
      _nameCtrl.text  = _originalName; // restore original
      _error          = null;
    });
  }

  void _handleResult(ApiResult<dynamic> result) {
    if (!mounted) return;
    setState(() { _uploading = false; _pickedImage = null; });
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profile updated successfully.'),
            behavior: SnackBarBehavior.floating),
      );
    } else {
      setState(() => _error = result.message ?? 'Update failed.');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cc   = context.cc;
    final user = ref.watch(authViewModelProvider).user;

    return Scaffold(
      backgroundColor: cc.surfaceBackground,
      appBar: AppBar(
        title: Text('Edit Profile',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: cc.primaryText)),
        // No Save button in AppBar — Save/Cancel are inline next to the name
      ),
      body: ListView(
        children: [
          const SizedBox(height: 32),

          // ── Avatar ────────────────────────────────────────────────────────
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _showAvatarSheet,
                  child: CircleAvatar(
                    radius: 54,
                    backgroundColor: cc.surfaceBackground,
                    backgroundImage: _pickedImage != null
                        ? FileImage(_pickedImage!) as ImageProvider
                        : (user?.avatar != null &&
                                user!.avatar!.isNotEmpty
                            ? CachedNetworkImageProvider(user.avatar!)
                            : null),
                    child: _pickedImage == null &&
                            (user?.avatar == null ||
                                user!.avatar!.isEmpty)
                        ? Text(
                            (user?.name ?? '?').isNotEmpty
                                ? user!.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme.primary,
                                fontSize: 42,
                                fontWeight: FontWeight.w600),
                          )
                        : null,
                  ),
                ),
                // Camera badge
                Positioned(
                  right: 0, bottom: 0,
                  child: GestureDetector(
                    onTap: _showAvatarSheet,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: cc.cardBackground, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
                // Upload spinner overlay
                if (_uploading && _pickedImage != null)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
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

          const SizedBox(height: 32),

          // ── Your Name section ─────────────────────────────────────────────
          // Mirrors RN editProfile.js exactly:
          //   "Your Name" label + edit icon (pencil)
          //   When editing: TextInput + Save (blue) + Cancel (grey) inline
          //   When not editing: Text showing current name
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              'Your Name',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cc.secondaryText),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: cc.cardBackground,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04), blurRadius: 4)
              ],
            ),
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: label + save/cancel OR edit icon
                Row(
                  children: [
                    Expanded(
                      child: _editingName
                          // ── Editing: show text field ──────────────────
                          ? TextField(
                              controller: _nameCtrl,
                              autofocus: true,
                              maxLength: 32,
                              enabled: !_uploading,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: cc.primaryText),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme.primary)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme.primary,
                                        width: 1.5)),
                                counterText: '',
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                fillColor: _uploading
                                    ? cc.surfaceBackground
                                    : cc.pageBackground,
                                filled: true,
                              ),
                              onSubmitted: (_) => _saveName(),
                            )
                          // ── Not editing: show static name ──────────────
                          : Text(
                              user?.name ?? '',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: cc.primaryText),
                            ),
                    ),
                    const SizedBox(width: 8),
                    // Save + Cancel (editing) / Edit icon (not editing)
                    if (_editingName) ...[
                      _uploading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : _SaveBtn(
                              label: 'Save',
                              color: const Color(0xFF1877F2),
                              onTap: _saveName,
                            ),
                      const SizedBox(width: 6),
                      _SaveBtn(
                        label: 'Cancel',
                        color: const Color(0xFF8A8D91),
                        onTap: _uploading ? null : _cancelEditName,
                      ),
                    ] else
                      IconButton(
                        icon: Icon(Icons.edit_rounded,
                            color: cc.secondaryText, size: 18),
                        onPressed: () =>
                            setState(() => _editingName = true),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Error message ─────────────────────────────────────────────────
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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

// ── Inline Save / Cancel button ───────────────────────────────────────────────
// Mirrors RN's saveBtn / cancelBtn style from editProfile.js

class _SaveBtn extends StatelessWidget {
  const _SaveBtn({
    required this.label,
    required this.color,
    this.onTap,
  });
  final String       label;
  final Color        color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: onTap != null ? color : color.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
        ),
      );
}
