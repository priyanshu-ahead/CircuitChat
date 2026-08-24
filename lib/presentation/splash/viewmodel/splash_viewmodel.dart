import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../app_init/app_init_viewmodel.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

enum SplashStatus { initial, loading, authenticated, unauthenticated, error }

class SplashState {
  const SplashState({
    this.status = SplashStatus.initial,
    this.errorMessage,
  });
  final SplashStatus status;
  final String? errorMessage;
}

class SplashViewModel extends Notifier<SplashState> {
  @override
  SplashState build() {
    _bootstrap();
    return const SplashState();
  }

  Future<void> _bootstrap() async {
    state = const SplashState(status: SplashStatus.loading);
    await Future.delayed(const Duration(milliseconds: 600));

    final storage = ref.read(secureStorageProvider);
    final token   = await storage.getAuthToken();

    if (token == null || token.isEmpty) {
      state = const SplashState(status: SplashStatus.unauthenticated);
      return;
    }

    final restored = await ref
        .read(authViewModelProvider.notifier)
        .restoreSession();

    if (restored) {
      // Run the full app boot sequence (permissions, socket, FCM token, etc.)
      await ref.read(appInitProvider.notifier).init();
      state = const SplashState(status: SplashStatus.authenticated);
    } else {
      await storage.deleteAuthToken();
      await storage.deleteRefreshToken();
      state = const SplashState(status: SplashStatus.unauthenticated);
    }
  }
}

final splashViewModelProvider =
    NotifierProvider<SplashViewModel, SplashState>(SplashViewModel.new);
