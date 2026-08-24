import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState
    extends ConsumerState<AccountSettingsScreen> {
  // ── Change password form ──────────────────────────────────────────────────
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text(
          'Account',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Change Password ───────────────────────────────────────────────
          _SectionLabel('Change Password'),
          _Card(
            child: Column(
              children: [
                _PwField(
                  label: 'Current Password',
                  controller: _currentPwCtrl,
                  obscure: _obscureCurrent,
                  onToggle: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
                const Divider(height: 1, indent: 14),
                _PwField(
                  label: 'New Password',
                  controller: _newPwCtrl,
                  obscure: _obscureNew,
                  onToggle: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
                const Divider(height: 1, indent: 14),
                _PwField(
                  label: 'Confirm New Password',
                  controller: _confirmPwCtrl,
                  obscure: _obscureConfirm,
                  onToggle: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFE53935), fontSize: 13)),
            ),
          if (_success != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(_success!,
                  style: const TextStyle(
                      color: Color(0xFF43A047), fontSize: 13)),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _saving ? null : _changePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Update Password'),
          ),
          const SizedBox(height: 32),
          // ── Delete Account ────────────────────────────────────────────────
          _SectionLabel('Danger Zone'),
          _Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever_rounded,
                  color: Color(0xFFE53935)),
              title: const Text(
                'Delete Account',
                style: TextStyle(
                    color: Color(0xFFE53935),
                    fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Permanently delete your account and all data.',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () => _confirmDelete(context),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final current = _currentPwCtrl.text.trim();
    final next = _newPwCtrl.text;
    final confirm = _confirmPwCtrl.text;

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      setState(() {
        _error = 'Please fill in all fields.';
        _success = null;
      });
      return;
    }
    if (next != confirm) {
      setState(() {
        _error = 'New passwords do not match.';
        _success = null;
      });
      return;
    }
    if (next.length < 6) {
      setState(() {
        _error = 'Password must be at least 6 characters.';
        _success = null;
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });

    final result = await ref
        .read(authViewModelProvider.notifier)
        .changePassword(
          currentPassword: current,
          newPassword: next,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.success) {
      _currentPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
      setState(() => _success = 'Password updated successfully.');
    } else {
      setState(
          () => _error = result.message ?? 'Failed to update password.');
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all your data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(authViewModelProvider.notifier).logout();
      if (context.mounted) context.go(Routes.login);
    }
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
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
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
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

class _PwField extends StatelessWidget {
  const _PwField({
    required this.label,
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            labelText: label,
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFF888888),
                size: 20,
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      );
}
