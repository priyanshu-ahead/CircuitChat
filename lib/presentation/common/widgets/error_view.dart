import 'package:flutter/material.dart';
import 'app_button.dart';

/// Full-screen / inline error state with retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.fullScreen = true,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool fullScreen;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 24),
          AppButton(
            label: 'Retry',
            onPressed: onRetry,
            width: 160,
          ),
        ],
      ],
    );

    if (fullScreen) {
      return Scaffold(
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: content)),
      );
    }

    return Center(child: Padding(padding: const EdgeInsets.all(24), child: content));
  }
}
