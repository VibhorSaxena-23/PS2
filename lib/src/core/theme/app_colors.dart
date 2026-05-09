import 'package:flutter/material.dart';

/// Central color tokens derived from the FlexiCurl design system.
/// All screens import from here — never use raw hex literals in UI files.
abstract final class AppColors {
  // ── Backgrounds ───────────────────────────────────────────────────────────
  /// Page background for auth / onboarding screens (light sage-white)
  static const Color scaffoldBg = Color(0xFFEEF4F3);

  /// Background for the "Get Started" features screen (slightly richer mint)
  static const Color scaffoldBgMint = Color(0xFFE4F1EC);

  static const Color white = Color(0xFFFFFFFF);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  // ── Brand / Accent ────────────────────────────────────────────────────────
  static const Color accent = Color(0xFF4F46E5);
  static const Color accentGreen = Color(0xFF34D399);
  static const Color accentGreenSoft = Color(0xFFD1FAE5);

  // ── Inputs ────────────────────────────────────────────────────────────────
  static const Color inputBorder = Color(0xFFE2E8E6);
  static const Color inputFocusBorder = Color(0xFF111827);

  // ── Primary button ────────────────────────────────────────────────────────
  static const Color btnDark = Color(0xFF1A1A2E);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFEF4444);
  static const Color errorSoft = Color(0xFFFEE2E2);

  // ── Divider / border ──────────────────────────────────────────────────────
  static const Color divider = Color(0xFFE5E7EB);
}
