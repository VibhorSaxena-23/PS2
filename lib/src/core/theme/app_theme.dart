import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF16A34A),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF1F2937),
          secondary: const Color(0xFF16A34A),
          error: const Color(0xFFEF4444),
          surface: const Color(0xFFF5F7FA),
          onSurface: const Color(0xFF111827),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        headlineLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          fontSize: 32,
          color: colorScheme.onSurface,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          fontSize: 24,
          color: colorScheme.onSurface,
        ),
        titleLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: colorScheme.onSurface,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          fontSize: 16,
          color: colorScheme.onSurface,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: const Color(0xFF6B7280),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.3),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: colorScheme.primary,
          side: const BorderSide(color: Color(0xFFD1D5DB)),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        selectedColor: const Color(0xFFDCFCE7),
        disabledColor: const Color(0xFFF3F4F6),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}
