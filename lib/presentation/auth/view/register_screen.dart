import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../app_init/app_init_viewmodel.dart';
import '../viewmodel/auth_viewmodel.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  String? _selectedLanguageKey;
  String? _selectedLanguageName;

  List<Map<String, dynamic>> _apiLanguages = [];
  bool _loadingLanguages = true;

  List<_LanguageOption> get _languageOptions {
    if (_apiLanguages.isNotEmpty) {
      return _apiLanguages
          .map((e) => _LanguageOption(
                key: (e['key'] ?? e['language_id'] ?? e['id'] ?? '').toString(),
                name: (e['name'] ?? e['title'] ?? e['language'] ?? '').toString(),
              ))
          .where((e) => e.key.isNotEmpty && e.name.isNotEmpty)
          .toList();
    }
    return AppStrings.languages
        .map((e) => _LanguageOption(key: e.toLowerCase().substring(0, 2), name: e))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    final result = await ref.read(authViewModelProvider.notifier).getLanguages();
    if (mounted) {
      setState(() {
        if (result.success && result.data != null) {
          _apiLanguages = List<Map<String, dynamic>>.from(result.data!);
        }
        _loadingLanguages = false;
        final opts = _languageOptions;
        if (opts.isNotEmpty) {
          final defaultEn = opts.firstWhere(
            (o) => o.key.toLowerCase() == 'en',
            orElse: () => opts.first,
          );
          _selectedLanguageKey = defaultEn.key;
          _selectedLanguageName = defaultEn.name;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ref
          .read(authViewModelProvider.notifier)
          .setError(AppStrings.termsNotAgreedError);
      return;
    }
    final success = await ref.read(authViewModelProvider.notifier).register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      confirmPassword: _confirmCtrl.text,
      agreeToTerms: _agreedToTerms,
      language: _selectedLanguageKey ?? 'en',
    );
    if (success && mounted) {
      await ref.read(appInitProvider.notifier).init();
      if (mounted) context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final primary = Theme.of(context).colorScheme.primary;
    final authState = ref.watch(authViewModelProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: cc.surfaceBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
              children: [
                // ── Card ─────────────────────────────────────────────────────
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Title ────────────────────────────────────────────────
                        Center(
                          child: Text(
                            AppStrings.signup,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: cc.primaryText,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Already have account?
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppStrings.alreadyHaveAccount,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: cc.secondaryText,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.go(Routes.login),
                                child: Text(
                                  AppStrings.login,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        Center(
                          child: Text(
                            AppStrings.signupSubtitle,
                            style: TextStyle(fontSize: 13, color: cc.secondaryText),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Name ────────────────────────────────────────────────
                        _FieldLabel(label: AppStrings.name),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameCtrl,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(color: cc.primaryText),
                          decoration: _inputDecoration(context, AppStrings.nameHint),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? AppStrings.nameRequiredError
                              : null,
                        ),
                        const SizedBox(height: 20),

                        // ── Email ────────────────────────────────────────────────
                        _FieldLabel(label: AppStrings.email),
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
                            if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$')
                                .hasMatch(v.trim())) {
                              return AppStrings.emailInvalidError;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // ── Password ─────────────────────────────────────────────
                        _FieldLabel(label: AppStrings.password),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(color: cc.primaryText),
                          decoration: _inputDecoration(context, AppStrings.passwordHint).copyWith(
                            suffixIcon: _eyeIcon(
                              obscure: _obscurePassword,
                              color: cc.secondaryText,
                              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
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

                        // ── Confirm Password ──────────────────────────────────────
                        _FieldLabel(label: AppStrings.confirmPassword),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(color: cc.primaryText),
                          decoration:
                          _inputDecoration(context, AppStrings.confirmPasswordHint).copyWith(
                            suffixIcon: _eyeIcon(
                              obscure: _obscureConfirm,
                              color: cc.secondaryText,
                              onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
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
                        const SizedBox(height: 20),

                        // ── Language dropdown ──────────────────────────────────────
                        _FieldLabel(label: AppStrings.language),
                        const SizedBox(height: 6),
                        _loadingLanguages
                            ? Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: cc.inputBackground,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              )
                            : DropdownButtonFormField<String>(
                                initialValue: _selectedLanguageName,
                                hint: const Text(''),
                                dropdownColor: cc.cardBackground,
                                style: TextStyle(color: cc.primaryText, fontSize: 14),
                                decoration: _inputDecoration(context, '').copyWith(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                ),
                                icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: cc.secondaryText),
                                items: _languageOptions
                                    .map((lang) => DropdownMenuItem<String>(
                                          value: lang.name,
                                          child: Text(lang.name,
                                              style: TextStyle(
                                                  color: cc.primaryText,
                                                  fontSize: 14)),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  final found = _languageOptions.firstWhere(
                                    (o) => o.name == v,
                                    orElse: () => _languageOptions.first,
                                  );
                                  setState(() {
                                    _selectedLanguageKey = found.key;
                                    _selectedLanguageName = found.name;
                                  });
                                },
                                validator: (v) => (v == null)
                                    ? AppStrings.languageRequiredError
                                    : null,
                              ),
                        const SizedBox(height: 24),

                        // ── Terms checkbox ────────────────────────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: _agreedToTerms,
                                activeColor: primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                side: BorderSide(color: cc.border),
                                onChanged: (v) =>
                                    setState(() => _agreedToTerms = v ?? false),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  text: AppStrings.agreeToTerms,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: cc.secondaryText,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: AppStrings.termsAndConditions,
                                      style: TextStyle(
                                        color: primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () {},
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── Error ─────────────────────────────────────────────────
                        if (authState.errorMessage != null) ...[
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
                                    authState.errorMessage!,
                                    style: const TextStyle(
                                        color: Color(0xFFEF4444), fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // ── Signup Button ─────────────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _onSignup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                                : const Text(
                              AppStrings.signup,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ]
          ),
        ),
      ),
    );
  }

  Widget _eyeIcon({required bool obscure, required Color color, required VoidCallback onTap}) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: color,
        size: 22,
      ),
      onPressed: onTap,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

class _LanguageOption {
  const _LanguageOption({required this.key, required this.name});
  final String key;
  final String name;
}