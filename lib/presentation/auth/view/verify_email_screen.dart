import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../viewmodel/auth_viewmodel.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({
    super.key,
    this.token = '',
    this.email,
  });

  final String token;
  final String? email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _pending = true;
  bool _verified = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  Future<void> _verify() async {
    if (widget.token.isEmpty) {
      setState(() {
        _pending = false;
        _verified = false;
      });
      return;
    }
    final result =
        await ref.read(authViewModelProvider.notifier).verifyEmail(
              code: widget.token,
              email: widget.email,
            );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _verified = result.success;
      if (!result.success) {
        _errorMessage = result.message ?? AppStrings.emailVerificationFailed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return Scaffold(
      backgroundColor: cc.surfaceBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
              decoration: BoxDecoration(
                color: cc.cardBackground,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.07),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _pending ? _buildPending(context) : _buildResult(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPending(BuildContext context) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          AppStrings.verifying,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: cc.primaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color:
                _verified ? const Color(0xFFE6F7EE) : const Color(0xFFFFEBEB),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _verified ? Icons.check : Icons.close,
            size: 40,
            color: _verified
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _verified
              ? AppStrings.emailVerifiedSuccess
              : (_errorMessage ?? AppStrings.emailVerificationFailed),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: cc.primaryText,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => context.go(Routes.login),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: const Text(
              AppStrings.backToLogin,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
