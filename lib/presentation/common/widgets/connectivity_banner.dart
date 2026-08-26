import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _connectivityProvider =
    StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

bool _isOnline(List<ConnectivityResult> results) =>
    results.isNotEmpty &&
    results.any((r) => r != ConnectivityResult.none);

// ── Widget ────────────────────────────────────────────────────────────────────

/// Wraps the entire app. Shows a persistent red banner when offline.
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(_connectivityProvider);

    final offline = connectivity.when(
      data:    (r) => !_isOnline(r),
      loading: ()  => false,
      error:   (_, __) => false,
    );

    return Scaffold(
        body:Column(
      children: [
        Expanded(child: child),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: offline
              ? Container(
                  key: const ValueKey('offline'),
                  width: double.infinity,
                  color: const Color(0xFFE53935),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('No internet connection',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('online')),
        ),
      ],
    )
    );
  }
}
