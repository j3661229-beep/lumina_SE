import 'package:flutter/material.dart';

class DesignColor {
  static const Color bg = Color(0xFF07091A);
  static const Color s1 = Color(0x0DFFFFFF); // ~5% white
  static const Color s2 = Color(0x14FFFFFF); // ~8% white
  static const Color border = Color(0x14FFFFFF); // ~8% white
  static const Color borderH = Color(0x736366F1); // 45% indigo
  static const Color indigo = Color(0xFF6366F1);
  static const Color indigoD = Color(0xFF4F52C5);
  static const Color indigoGlow = Color(0x406366F1); // 25% indigo
  static const Color green = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color rose = Color(0xFFF43F5E);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color violet = Color(0xFFA78BFA);
  static const Color text = Color(0xFFF1F5F9);
  static const Color sub = Color(0xFF94A3B8);
  static const Color muted = Color(0xFF475569);
  static const Color overlay = Color(0xB207091A); // 70% background
}

class DesignStyles {
  static BoxDecoration glassCard({bool glow = false}) {
    return BoxDecoration(
      color: DesignColor.s1,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: glow ? DesignColor.borderH : DesignColor.border),
      boxShadow: glow
          ? [BoxShadow(color: DesignColor.indigoGlow, blurRadius: 24, offset: Offset.zero)]
          : [],
    );
  }

  static BoxDecoration gradientButton() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: const LinearGradient(
        colors: [DesignColor.indigo, DesignColor.violet],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: const [
        BoxShadow(color: DesignColor.indigoGlow, blurRadius: 22, offset: Offset(0, 8))
      ],
    );
  }
}
