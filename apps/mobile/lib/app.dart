import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/design_tokens.dart';
import 'router.dart';

// ── Theme toggle provider ─────────────────────────────────────────────────────
final themeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

class LuminaApp extends ConsumerWidget {
  const LuminaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeProvider);
    return MaterialApp.router(
      title: 'Lumina',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: _light(),
      darkTheme: _dark(),
      routerConfig: router,
    );
  }

  // ── Dark Theme ─────────────────────────────────────────────────────────────
  ThemeData _dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.indigo,
        secondary: AppColors.violet,
        surface: AppColors.darkSurface,
        onSurface: Color(0xFFF1F5F9),
        error: AppColors.rose,
      ),
      textTheme: _textTheme(base.textTheme, const Color(0xFFF1F5F9)),
      appBarTheme: _appBar(const Color(0xFFF1F5F9)),
      inputDecorationTheme: _input(isDark: true),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: AppColors.indigo.withOpacity(0.3)),
        ),
      ),
      pageTransitionsTheme: _transitions(),
    );
  }

  // ── Light Theme ────────────────────────────────────────────────────────────
  ThemeData _light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.indigo,
        secondary: AppColors.violet,
        surface: AppColors.lightSurface,
        onSurface: Color(0xFF0F172A),
        error: AppColors.rose,
      ),
      textTheme: _textTheme(base.textTheme, const Color(0xFF0F172A)),
      appBarTheme: _appBar(const Color(0xFF0F172A)),
      inputDecorationTheme: _input(isDark: false),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.08),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: AppColors.indigo.withOpacity(0.2)),
        ),
      ),
      pageTransitionsTheme: _transitions(),
    );
  }

  TextTheme _textTheme(TextTheme base, Color textColor) =>
      GoogleFonts.dmSansTextTheme(base).copyWith(
        displayLarge:   GoogleFonts.syne(color: textColor, fontWeight: FontWeight.w800),
        displayMedium:  GoogleFonts.syne(color: textColor, fontWeight: FontWeight.w800),
        displaySmall:   GoogleFonts.syne(color: textColor, fontWeight: FontWeight.w800),
        headlineLarge:  GoogleFonts.syne(color: textColor, fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.syne(color: textColor, fontWeight: FontWeight.w700),
        headlineSmall:  GoogleFonts.syne(color: textColor, fontWeight: FontWeight.w700),
        titleLarge:     GoogleFonts.syne(color: textColor, fontWeight: FontWeight.w700),
        bodyLarge:      GoogleFonts.dmSans(color: textColor),
        bodyMedium:     GoogleFonts.dmSans(color: textColor),
      );

  AppBarTheme _appBar(Color fg) => AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    centerTitle: false,
    iconTheme: IconThemeData(color: fg),
    titleTextStyle: GoogleFonts.syne(
      fontSize: 22, fontWeight: FontWeight.w800, color: fg),
  );

  InputDecorationTheme _input({required bool isDark}) => InputDecorationTheme(
    filled: true,
    fillColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.indigo, width: 2),
    ),
    hintStyle: TextStyle(
      color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
      fontSize: 13,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  PageTransitionsTheme _transitions() => const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
    },
  );
}
