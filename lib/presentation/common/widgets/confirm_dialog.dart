import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Shared confirmation dialog used throughout the app.
///
/// Example:
///   final ok = await ConfirmDialog.show(context,
///     title:   'Delete Message',
///     message: 'This cannot be undone.',
///     confirm: 'Delete',
///     isDangerous: true,
///   );
class ConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirm      = 'Confirm',
    String cancel       = 'Cancel',
    bool   isDangerous  = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cc      = ctx.cc;
        final primary = Theme.of(ctx).colorScheme.primary;
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(cancel,
                  style: TextStyle(color: cc.secondaryText)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                confirm,
                style: TextStyle(
                  color: isDangerous
                      ? const Color(0xFFE53935)
                      : primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}

