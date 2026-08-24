import 'package:flutter/material.dart';

enum ToastType { success, error, info, warning }

/// Lightweight toast helper using Flutter's built-in SnackBar.
/// Usage: ToastHelper.show(context, 'Message saved', type: ToastType.success);
class ToastHelper {
  static void show(
    BuildContext context,
    String message, {
    ToastType type     = ToastType.info,
    Duration duration  = const Duration(seconds: 3),
  }) {
    final color = switch (type) {
      ToastType.success => const Color(0xFF43A047),
      ToastType.error   => const Color(0xFFE53935),
      ToastType.warning => const Color(0xFFFB8C00),
      ToastType.info    => const Color(0xFF1976D2),
    };

    final icon = switch (type) {
      ToastType.success => Icons.check_circle_rounded,
      ToastType.error   => Icons.error_rounded,
      ToastType.warning => Icons.warning_rounded,
      ToastType.info    => Icons.info_rounded,
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
