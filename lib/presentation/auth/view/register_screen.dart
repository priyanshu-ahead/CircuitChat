import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
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
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFEFF2F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
              children: [
                // ── Card ─────────────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
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
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A2E),
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
                                  color: Colors.grey[700],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.go(Routes.login),
                                child: const Text(
                                  AppStrings.login,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1976D2),
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
                            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Name ────────────────────────────────────────────────
                        _FieldLabel(label: AppStrings.name),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(AppStrings.nameHint),
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
                          decoration: _inputDecoration(AppStrings.emailHint),
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
                          decoration: _inputDecoration(AppStrings.passwordHint).copyWith(
                            suffixIcon: _eyeIcon(
                              obscure: _obscurePassword,
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
                          decoration:
                          _inputDecoration(AppStrings.confirmPasswordHint).copyWith(
                            suffixIcon: _eyeIcon(
                              obscure: _obscureConfirm,
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
                                  color: const Color(0xFFF2F4F8),
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
                                decoration: _inputDecoration('').copyWith(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                ),
                                icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Color(0xFF555555)),
                                items: _languageOptions
                                    .map((lang) => DropdownMenuItem<String>(
                                          value: lang.name,
                                          child: Text(lang.name,
                                              style:
                                                  const TextStyle(fontSize: 14)),
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
                                activeColor: const Color(0xFF1976D2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                side: BorderSide(color: Colors.grey[400]!),
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
                                    color: Colors.grey[700],
                                  ),
                                  children: [
                                    TextSpan(
                                      text: AppStrings.termsAndConditions,
                                      style: const TextStyle(
                                        color: Color(0xFF1976D2),
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
                              backgroundColor: const Color(0xFF1976D2),
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

  Widget _eyeIcon({required bool obscure, required VoidCallback onTap}) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: Colors.grey[500],
        size: 22,
      ),
      onPressed: onTap,
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
    filled: true,
    fillColor: const Color(0xFFF2F4F8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: '$label: ',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1A2E),
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