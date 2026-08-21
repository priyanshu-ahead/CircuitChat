import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/usecases/auth/login_usecase.dart';
import '../../../domain/usecases/auth/me_usecase.dart';
import '../../../domain/usecases/auth/register_usecase.dart';

/// Log tag used by the auth module. In Android Studio open **Logcat** and
/// filter by this exact string: `CircuitChatAuth`
/// (package: `com.example.circuit_chat`).
const String kAuthLogTag = 'CircuitChatAuth';

void _log(String message, {Object? error, StackTrace? stackTrace}) {
  dev.log(
    message,
    name: kAuthLogTag,
    error: error,
    stackTrace: stackTrace,
  );
}

// ── Auth State ────────────────────────────────────────────────────────────────

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  final AuthStatus status;
  final UserEntity? user;
  final String? errorMessage;

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    UserEntity? user,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: clearUser ? null : user ?? this.user,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      );
}

// ── Auth ViewModel ────────────────────────────────────────────────────────────

/// Central presentation controller for all auth-related screens (login,
/// register, forgot-password, verify-email, change-password, edit-profile…).
///
/// Delegates to domain use cases; never touches the data layer directly.
/// Uses `ref.read(...)` to keep build() pure and avoid accidental re-listen.
class AuthViewModel extends Notifier<AuthState> {
  late final LoginUseCase _login;
  late final RegisterUseCase _register;
  late final MeUseCase _me;
  late final AuthRepository _authRepo;
  late final UserRepository _userRepo;

  @override
  AuthState build() {
    _login = ref.read(loginUseCaseProvider);
    _register = ref.read(registerUseCaseProvider);
    _me = ref.read(meUseCaseProvider);
    _authRepo = ref.read(authRepositoryProvider);
    _userRepo = ref.read(userRepositoryProvider);
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  // ── Core auth ────────────────────────────────────────────────────────────

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _log('➡️  login() called — email: $email');
    final stopwatch = Stopwatch()..start();
    state = state.copyWith(
      status: AuthStatus.loading,
      clearError: true,
    );
    try {
      final result = await _login(email: email, password: password);
      stopwatch.stop();
      if (result.success && result.data != null) {
        _log('✅ login() SUCCESS (${stopwatch.elapsedMilliseconds}ms) '
            '— user=${result.data!.id}, '
            'email=${result.data!.email}, '
            'name=${result.data!.name}, '
            'avatar=${result.data!.avatar}');
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: result.data,
          clearError: true,
        );
        return true;
      }
      _log('❌ login() FAILED (${stopwatch.elapsedMilliseconds}ms) '
          '— success=${result.success}, message="${result.message}"');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: result.message ?? 'Login failed.',
      );
      return false;
    } catch (e, st) {
      _log('💥 login() EXCEPTION: $e', error: e, stackTrace: st);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required bool agreeToTerms,
    String language = 'en',
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      'username': name.trim().toLowerCase().replaceAll(' ', '_'),
      'email': email.trim().toLowerCase(),
      'password': '***',
      'confirmPassword': '***',
      'language': language,
      'agreeToTerms': agreeToTerms,
    };
    _log('➡️  register() called — payload: $payload');
    final stopwatch = Stopwatch()..start();
    state = state.copyWith(
      status: AuthStatus.loading,
      clearError: true,
    );
    final innerPayload = <String, dynamic>{
      'name': name.trim(),
      'username': name.trim().toLowerCase().replaceAll(' ', '_'),
      'email': email.trim().toLowerCase(),
      'password': password,
      'confirmPassword': confirmPassword,
      'language': language,
      'agreeToTerms': agreeToTerms,
    };
    try {
      final result = await _register(innerPayload);
      stopwatch.stop();
      if (result.success && result.data != null) {
        _log('✅ register() SUCCESS (${stopwatch.elapsedMilliseconds}ms) '
            '— user=${result.data!.id}, '
            'email=${result.data!.email}, '
            'name=${result.data!.name}');
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: result.data,
          clearError: true,
        );
        return true;
      }
      _log('❌ register() FAILED (${stopwatch.elapsedMilliseconds}ms) '
          '— success=${result.success}, message="${result.message}"');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: result.message ?? 'Signup failed.',
      );
      return false;
    } catch (e, st) {
      _log('💥 register() EXCEPTION: $e', error: e, stackTrace: st);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  // ── Languages ────────────────────────────────────────────────────────────

  Future<ApiResult<List<dynamic>>> getLanguages() => _userRepo.getLanguages();

  /// Populate state from `/user/me` — useful on app boot after the splash
  /// screen when a cached auth token exists.
  Future<bool> restoreSession() async {
    _log('➡️  restoreSession() — calling /user/me to validate cached token');
    try {
      final result = await _me();
      if (result.success && result.data != null) {
        _log('✅ restoreSession() SUCCESS — '
            'user=${result.data!.id}, email=${result.data!.email}');
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: result.data,
          clearError: true,
        );
        return true;
      }
      _log('❌ restoreSession() FAILED — success=${result.success}, '
          'message="${result.message}"');
      state = const AuthState(status: AuthStatus.unauthenticated);
      return false;
    } catch (e, st) {
      _log('💥 restoreSession() EXCEPTION: $e', error: e, stackTrace: st);
      state = const AuthState(status: AuthStatus.unauthenticated);
      return false;
    }
  }

  Future<void> logout() async {
    _log('➡️  logout() called');
    try {
      await _authRepo.logout();
      _log('✅ logout() SUCCESS — cleared auth state');
    } catch (e, st) {
      _log('💥 logout() EXCEPTION: $e', error: e, stackTrace: st);
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // ── Password flow ─────────────────────────────────────────────────────────

  Future<ApiResult<void>> forgotPassword(String email) async {
    final normalized = email.trim().toLowerCase();
    _log('➡️  forgotPassword() — email: $normalized');
    try {
      final result =
          await _authRepo.forgetPassword({'email': normalized});
      _log(result.success
          ? '✅ forgotPassword() SUCCESS — reset link sent'
          : '❌ forgotPassword() FAILED — message="${result.message}"');
      return result;
    } catch (e, st) {
      _log('💥 forgotPassword() EXCEPTION: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<ApiResult<void>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    _log('➡️  resetPassword() — email=${email.trim().toLowerCase()}, '
        'codeLen=${code.length}');
    try {
      final result = await _authRepo.resetPassword({
        'email': email.trim().toLowerCase(),
        'code': code,
        'password': newPassword,
      });
      _log(result.success
          ? '✅ resetPassword() SUCCESS'
          : '❌ resetPassword() FAILED — message="${result.message}"');
      return result;
    } catch (e, st) {
      _log('💥 resetPassword() EXCEPTION: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<ApiResult<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _log('➡️  changePassword() called');
    try {
      final result = await _authRepo.changePassword({
        'current_password': currentPassword,
        'password': newPassword,
      });
      _log(result.success
          ? '✅ changePassword() SUCCESS'
          : '❌ changePassword() FAILED — message="${result.message}"');
      return result;
    } catch (e, st) {
      _log('💥 changePassword() EXCEPTION: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Email / misc ──────────────────────────────────────────────────────────

  Future<ApiResult<void>> verifyEmail({required String code, String? email}) {
    _log('➡️  verifyEmail() — codeLen=${code.length}, '
        'email=${email?.trim().toLowerCase() ?? '(none)'}');
    return _authRepo.verifyEmail({
      if (email != null) 'email': email.trim().toLowerCase(),
      'code': code,
    }).then((r) {
      _log(r.success
          ? '✅ verifyEmail() SUCCESS'
          : '❌ verifyEmail() FAILED — message="${r.message}"');
      return r;
    });
  }

  Future<ApiResult<void>> addPushToken(Map<String, dynamic> data) =>
      _authRepo.addPushNotificationToken(data);

  Future<ApiResult<void>> removePushToken(Map<String, dynamic> data) =>
      _authRepo.removePushNotificationToken(data);

  /// Sets an error state from the UI (e.g. terms checkbox not checked).
  void setError(String errorMessage) {
    state = state.copyWith(
      status: AuthStatus.error,
      errorMessage: errorMessage,
    );
  }

  /// Clears any previous error state.
  void clearError() {
    state = state.copyWith(
      status: state.status == AuthStatus.error
          ? AuthStatus.unauthenticated
          : state.status,
      clearError: true,
    );
  }
}

final authViewModelProvider =
    NotifierProvider<AuthViewModel, AuthState>(AuthViewModel.new);
