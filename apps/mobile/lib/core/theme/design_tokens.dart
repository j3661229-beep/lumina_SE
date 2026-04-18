import 'package:flutter/material.dart';

// ── Brand accent colours (same in both light and dark) ───────────────────────
class AppColors {
  static const indigo  = Color(0xFF6366F1);
  static const indigoD = Color(0xFF4F52C5);
  static const violet  = Color(0xFFA78BFA);
  static const green   = Color(0xFF10B981);
  static const amber   = Color(0xFFF59E0B);
  static const rose    = Color(0xFFF43F5E);
  static const cyan    = Color(0xFF22D3EE);
  static const pink    = Color(0xFFEC4899);
  static const orange  = Color(0xFFFB923C);

  // Dark-mode surfaces
  static const darkBg      = Color(0xFF080B1F);
  static const darkSurface = Color(0xFF111430);
  static const darkCard    = Color(0xFF161A3A);
  static const darkBorder  = Color(0x1AFFFFFF);

  // Light-mode surfaces
  static const lightBg      = Color(0xFFF1F5F9);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard    = Color(0xFFFFFFFF);
  static const lightBorder  = Color(0xFFE2E8F0);

  // Helpers
  static Color cardBg(BuildContext ctx) =>
      ctx.isDark ? darkCard : lightCard;

  static Color border(BuildContext ctx) =>
      ctx.isDark ? darkBorder : lightBorder;

  static Color surface(BuildContext ctx) =>
      ctx.isDark ? darkSurface : lightSurface;

  static Color surfaceContainer(BuildContext ctx) =>
      ctx.isDark ? const Color(0xFF161A3A) : const Color(0xFFF8FAFC);

  static Color textPrimary(BuildContext ctx) =>
      ctx.isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);

  static Color textSecondary(BuildContext ctx) =>
      ctx.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  static Color textMuted(BuildContext ctx) =>
      ctx.isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);
}

// Quick brightness helper
extension BrightnessX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ── Legacy aliases — used by existing unported screens ───────────────────────
class DesignColor {
  static const Color bg      = AppColors.darkBg;
  static const Color s1      = Color(0x0DFFFFFF);
  static const Color s2      = Color(0x14FFFFFF);
  static const Color border  = AppColors.darkBorder;
  static const Color borderH = Color(0x736366F1);
  static const Color indigo  = AppColors.indigo;
  static const Color indigoD = AppColors.indigoD;
  static const Color indigoGlow = Color(0x406366F1);
  static const Color green   = AppColors.green;
  static const Color amber   = AppColors.amber;
  static const Color rose    = AppColors.rose;
  static const Color cyan    = AppColors.cyan;
  static const Color violet  = AppColors.violet;
  static const Color text    = Color(0xFFF1F5F9);
  static const Color sub     = Color(0xFF94A3B8);
  static const Color muted   = Color(0xFF475569);
  static const Color overlay = Color(0xB2080B1F);
}

// ── Shared decoration helpers ─────────────────────────────────────────────────
class AppStyles {
  static BoxDecoration glassCard(BuildContext context, {bool glow = false}) {
    return BoxDecoration(
      color: AppColors.cardBg(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: glow ? DesignColor.borderH : AppColors.border(context),
      ),
      boxShadow: glow
          ? [const BoxShadow(color: Color(0x406366F1), blurRadius: 24)]
          : !context.isDark
              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))]
              : [],
    );
  }

  static BoxDecoration gradientButton() => BoxDecoration(
    borderRadius: BorderRadius.circular(14),
    gradient: const LinearGradient(
      colors: [AppColors.indigo, AppColors.violet],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boxShadow: const [
      BoxShadow(color: Color(0x406366F1), blurRadius: 22, offset: Offset(0, 8)),
    ],
  );

  static BoxDecoration card(BuildContext ctx, {Color? accent, double radius = 18}) => BoxDecoration(
    color: AppColors.cardBg(ctx),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.border(ctx)),
    boxShadow: ctx.isDark
        ? []
        : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))],
  );
}

typedef DesignStyles = AppStyles;
