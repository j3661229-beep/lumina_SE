import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AppTheme — Material 3 Light/Dark theme definitions for Lumina.
/// Screens should read colors from [Theme.of(context).colorScheme] only.
class AppTheme {
  AppTheme._();

  // ── Seed color ──────────────────────────────────────────────────────────────
  static const Color _seed = Color(0xFF6366F1); // Indigo 500

  // ── Light theme ─────────────────────────────────────────────────────────────
  static ThemeData get light {
    final cs = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
      surface: const Color(0xFFF5F7FF),
      onSurface: const Color(0xFF1A1A1A),
    );
    return _base(cs);
  }

  // ── Dark theme ──────────────────────────────────────────────────────────────
  static ThemeData get dark {
    final cs = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF0F172A),
      onSurface: const Color(0xFFF1F5F9),
      surfaceContainerHighest: const Color(0xFF1E293B),
    );
    return _base(cs);
  }

  // ── Shared builder ──────────────────────────────────────────────────────────
  static ThemeData _base(ColorScheme cs) {
    final textTheme = GoogleFonts.nunitoSansTextTheme().copyWith(
      displayLarge: GoogleFonts.syne(fontWeight: FontWeight.w800),
      displayMedium: GoogleFonts.syne(fontWeight: FontWeight.w800),
      displaySmall: GoogleFonts.syne(fontWeight: FontWeight.w700),
      headlineLarge: GoogleFonts.syne(fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.syne(fontWeight: FontWeight.w700),
      headlineSmall: GoogleFonts.syne(fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.syne(fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.nunitoSans(),
      bodyMedium: GoogleFonts.nunitoSans(),
      bodySmall: GoogleFonts.nunitoSans(),
      labelLarge: GoogleFonts.nunitoSans(fontWeight: FontWeight.w700),
      labelMedium: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600),
      labelSmall: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: textTheme,
      scaffoldBackgroundColor: cs.surface,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        titleTextStyle: GoogleFonts.syne(
          color: cs.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: cs.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: cs.surfaceContainerHighest,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.onSurface.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: cs.onSurface.withOpacity(0.6)),
        hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: StadiumBorder(
          side: BorderSide(color: cs.onSurface.withOpacity(0.1)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: cs.onSurface.withOpacity(0.08),
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cs.surface,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurface.withOpacity(0.5),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
