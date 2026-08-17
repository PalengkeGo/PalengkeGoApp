import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors - Emerald Harvest Design System
  static const Color primaryGreen = Color(0xFF0B372B); // Deep Emerald
  static const Color accentGreen = Color(0xFF6D9773); // Herbal accent
  static const Color accentYellow = Color(0xFFFFB902); // Status/promos

  // Background and Surface
  static const Color scaffoldBackground = Color(0xFFF6F8F7); // surfaceLight
  static const Color surface = Color(0xFFF8FAFC); // screen surface
  static const Color surfaceColor = Colors.white;
  static const Color surfaceContainerLow = Color(0xFFF1F5F9);
  static const Color surfaceContainer = Color(0xFFE2E8F0);

  // Borders
  static const Color border = Color(0xFFE2E8F0);

  // Typography Colors
  static const Color textPrimary = Color(
    0xFF0B372B,
  ); // onSurface - Deep Emerald
  static const Color textSecondary = Color(0xFF64748B); // onSurfaceVariant
  static const Color muted = Color(0xFF94A3B8); // tertiary gray

  // Semantic Colors
  static const Color success = Color(0xFF166534);
  static const Color warning = Color(0xFFB45309);
  static const Color error = Color(0xFFB42318);
  static const Color statusOpen = Color(0xFF22C55E);
  static const Color statusClosed = Color(0xFF94A3B8);
  static const Color notificationBadge = Color(0xFFEF4444);
  static const Color starRating = Color(0xFFFFB902);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: scaffoldBackground,
      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        secondary: accentYellow,
        surface: surfaceColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          color: textPrimary,
          fontSize: 16,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        hintStyle: const TextStyle(color: textSecondary),
      ),
    );
  }
}
