import 'package:flutter/material.dart';

/// Central colour palette for CircuitChat.
/// Use these instead of hard-coding colours in widgets.
class AppColors {
  AppColors._();

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF0057FF);
  static const Color primaryLight = Color(0xFF4D8DFF);
  static const Color primaryDark = Color(0xFF003DBD);
  static const Color accent = Color(0xFF00D4AA);

  // ── Background ────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF5F7FA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E2E);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFFB0B7C3);
  static const Color textInverted = Color(0xFFFFFFFF);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Chat Bubbles ──────────────────────────────────────────────────────────
  static const Color bubbleSent = Color(0xFF0057FF);
  static const Color bubbleReceived = Color(0xFFEEF2FF);
  static const Color bubbleSentText = Color(0xFFFFFFFF);
  static const Color bubbleReceivedText = Color(0xFF1A1A2E);

  // ── Divider / Border ──────────────────────────────────────────────────────
  static const Color divider = Color(0xFFE5E7EB);
  static const Color border = Color(0xFFD1D5DB);

  // ── Online indicator ─────────────────────────────────────────────────────
  static const Color online = Color(0xFF22C55E);
  static const Color offline = Color(0xFF9CA3AF);
}
