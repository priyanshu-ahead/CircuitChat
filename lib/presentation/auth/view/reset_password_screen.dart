import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../viewmodel/auth_viewmodel.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.token = '', this.email});

  final String token;
  final String? email;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _success = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.token.isNotEmpty) _codeCtrl.text = widget.token;
    if (widget.email != null) _emailCtrl.text = widget.email!;
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _codeCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _onReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result =
        await ref.read(authViewModelProvider.notifier).resetPassword(
              email: _emailCtrl.text.trim(),
              code: _codeCtrl.text.trim(),
              newPassword: _passwordCtrl.text,
            );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.success) {
        _success = true;
      } else {
        _errorMessage = result.message ?? AppStrings.somethingWentWrong;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return Scaffold(
      backgroundColor: cc.surfaceBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Column(
            children: [
              Container(
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
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                child: _success ? _buildSuccessView(context) : _buildFormView(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormView(BuildContext context) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              AppStrings.resetPasswordTitle,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: cc.primaryText,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              AppStrings.resetPasswordSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cc.secondaryText),
            ),
          ),
          const SizedBox(height: 28),
          const _FieldLabel(label: AppStrings.email),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: cc.primaryText),
            decoration: _inputDecoration(context, AppStrings.emailHint),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return AppStrings.emailRequiredError;
              }
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                  .hasMatch(v.trim())) {
                return AppStrings.emailInvalidError;
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          const _FieldLabel(label: 'Verification Code'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _codeCtrl,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: cc.primaryText),
            decoration: _inputDecoration(context, 'Enter code from email'),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Verification code is required'
                : null,
          ),
          const SizedBox(height: 20),
          const _FieldLabel(label: AppStrings.password),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: cc.primaryText),
            decoration:
                _inputDecoration(context, AppStrings.newPasswordHint).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: cc.secondaryText,
                  size: 22,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return AppStrings.passwordRequiredError;
              }
              final regExp = RegExp(
                r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\w\s])[A-Za-z\d\W]{8,}$',
              );
              if (!regExp.hasMatch(v)) {
                return AppStrings.passwordMinLengthError;
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          const _FieldLabel(label: AppStrings.confirmPassword),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            style: TextStyle(color: cc.primaryText),
            onFieldSubmitted: (_) => _onReset(),
            decoration: _inputDecoration(context, AppStrings.confirmPasswordHint)
                .copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: cc.secondaryText,
                  size: 22,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return AppStrings.confirmPasswordRequiredError;
              }
              if (v != _passwordCtrl.text) {
                return AppStrings.passwordsDoNotMatchError;
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFEF4444), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: Color(0xFFEF4444), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _onReset,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      AppStrings.resetPasswordButton,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => context.go(Routes.login),
              child: Text(
                AppStrings.backToLogin,
                style: TextStyle(
                  color: primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Color(0xFFE6F7EE),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 40, color: Color(0xFF10B981)),
        ),
        const SizedBox(height: 20),
        Text(
          AppStrings.passwordResetSuccess,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
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

  InputDecoration _inputDecoration(BuildContext context, String hint) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    return InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: cc.secondaryText, fontSize: 14),
        filled: true,
        fillColor: cc.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cc.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cc.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return RichText(
      text: TextSpan(
        text: '$label: ',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: cc.primaryText,
        ),
        children: const [
          TextSpan(
            text: '*',
            style: TextStyle(color: Color(0xFFEF4444)),
          ),
        ],
      ),
    );
  }
}
