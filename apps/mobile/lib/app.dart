import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/design_tokens.dart';
import 'router.dart';

class LuminaApp extends ConsumerWidget {
  const LuminaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Lumina',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Force Dark mode
      darkTheme: _buildDarkTheme(),
      routerConfig: router,
    );
  }

  ThemeData _buildDarkTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    
    return base.copyWith(
      scaffoldBackgroundColor: DesignColor.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: DesignColor.indigo,
        brightness: Brightness.dark,
        surface: DesignColor.bg,
        onSurface: DesignColor.text,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.syne(color: DesignColor.text, fontWeight: FontWeight.w800),
        displayMedium: GoogleFonts.syne(color: DesignColor.text, fontWeight: FontWeight.w800),
        displaySmall: GoogleFonts.syne(color: DesignColor.text, fontWeight: FontWeight.w800),
        headlineLarge: GoogleFonts.syne(color: DesignColor.text, fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.syne(color: DesignColor.text, fontWeight: FontWeight.w700),
        headlineSmall: GoogleFonts.syne(color: DesignColor.text, fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.syne(color: DesignColor.text, fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: DesignColor.text),
        titleTextStyle: GoogleFonts.syne(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: DesignColor.text,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
