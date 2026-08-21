import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dart / Flutter convenience extensions used across the app.

// ── String extensions ────────────────────────────────────────────────────────
extension StringX on String {
  bool get isValidEmail =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(this);

  bool get isValidPhone =>
      RegExp(r'^\+?[0-9]{7,15}$').hasMatch(trim());

  bool get isBlank => trim().isEmpty;

  String get capitalised =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  String get titleCase => split(' ').map((w) => w.capitalised).join(' ');

  /// Copy to clipboard.
  Future<void> copyToClipboard() =>
      Clipboard.setData(ClipboardData(text: this));

  /// Returns initials from a display name, e.g. "John Doe" → "JD".
  String get initials {
    final words = trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[words.length - 1][0]}'.toUpperCase();
  }
}

// ── Nullable String ──────────────────────────────────────────────────────────
extension NullableStringX on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
  String get orEmpty => this ?? '';
}

// ── BuildContext extensions ───────────────────────────────────────────────────
extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  bool get isDarkMode =>
      MediaQuery.platformBrightnessOf(this) == Brightness.dark;

  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(this).colorScheme.error : null,
      ),
    );
  }

  void hideKeyboard() => FocusScope.of(this).unfocus();
}

// ── num extensions ────────────────────────────────────────────────────────────
extension NumX on num {
  SizedBox get verticalSpace => SizedBox(height: toDouble());
  SizedBox get horizontalSpace => SizedBox(width: toDouble());

  EdgeInsets get allPadding => EdgeInsets.all(toDouble());
  EdgeInsets get horizontalPadding =>
      EdgeInsets.symmetric(horizontal: toDouble());
  EdgeInsets get verticalPadding =>
      EdgeInsets.symmetric(vertical: toDouble());
}

// ── List extensions ───────────────────────────────────────────────────────────
extension IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
