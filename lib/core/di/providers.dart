import 'dart:io' show Platform;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';
import '../storage/shared_prefs.dart';
import '../../data/datasources/local/auth_local_ds.dart';
import '../../data/datasources/remote/auth_remote_ds.dart';
import '../../data/datasources/remote/user_remote_ds.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/usecases/auth/login_usecase.dart';
import '../../domain/usecases/auth/logout_usecase.dart';
import '../../domain/usecases/auth/me_usecase.dart';
import '../../domain/usecases/auth/register_usecase.dart';
import '../../domain/usecases/user/edit_profile_usecase.dart';

// ── Secure Storage ───────────────────────────────────────────────────────────
final flutterSecureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final secureStorageProvider = Provider<SecureStorage>(
  (ref) => SecureStorage(ref.read(flutterSecureStorageProvider)),
);

// ── Shared Preferences ───────────────────────────────────────────────────────
final sharedPrefsProvider = Provider<AppSharedPrefs>(
  (_) => throw UnimplementedError('Override in ProviderScope'),
);

// ── Networking ───────────────────────────────────────────────────────────────
final cookieJarProvider = Provider<CookieJar>((_) => CookieJar());

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiUrl,
      connectTimeout: const Duration(milliseconds: AppConstants.connectTimeoutMs),
      receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeoutMs),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Client-ID': AppConstants.clientId,
        'Client-Secret': AppConstants.clientSecret,
        'Platform': Platform.operatingSystem,
      },
    ),
  );
  dio.interceptors.add(CookieManager(ref.read(cookieJarProvider)));
  return dio;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.read(dioProvider), ref.read(secureStorageProvider)),
);

// ── Auth — local + remote data sources ──────────────────────────────────────
final authLocalDataSourceProvider = Provider<AuthLocalDataSource>(
  (ref) => AuthLocalDataSource(
    ref.read(sharedPrefsProvider),
    ref.read(secureStorageProvider),
  ),
);

/// The "real" data-layer impl of [AuthRepository] — goes to the SE backend.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRemoteDataSource(
    ref.read(apiClientProvider),
    ref.read(secureStorageProvider),
  ),
);

// ── User repository ──────────────────────────────────────────────────────────
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRemoteDataSource(ref.read(apiClientProvider)),
);

// ── Domain use cases (auth) ─────────────────────────────────────────────────
final loginUseCaseProvider = Provider<LoginUseCase>(
  (ref) => LoginUseCase(ref.read(authRepositoryProvider)),
);

final registerUseCaseProvider = Provider<RegisterUseCase>(
  (ref) => RegisterUseCase(ref.read(authRepositoryProvider)),
);

final meUseCaseProvider = Provider<MeUseCase>(
  (ref) => MeUseCase(ref.read(authRepositoryProvider)),
);

final logoutUseCaseProvider = Provider<LogoutUseCase>(
  (ref) => LogoutUseCase(ref.read(authRepositoryProvider)),
);

// ── Domain use cases (user / profile) ────────────────────────────────────────
final editProfileUseCaseProvider = Provider<EditProfileUseCase>(
  (ref) => EditProfileUseCase(ref.read(userRepositoryProvider)),
);
