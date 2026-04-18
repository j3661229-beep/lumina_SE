import 'package:flutter/material.dart';

// ── Shared category metadata ─────────────────────────────────────────────────
const cats = [
  ExpenseCat('food',           '🍔', Color(0xFFEF4444), 'Food & Dining'),
  ExpenseCat('transport',      '🚌', Color(0xFF6366F1), 'Transport'),
  ExpenseCat('stationery',     '📒', Color(0xFFF59E0B), 'Stationery'),
  ExpenseCat('fees',           '🎓', Color(0xFF10B981), 'Fees'),
  ExpenseCat('entertainment',  '🎬', Color(0xFFEC4899), 'Entertainment'),
  ExpenseCat('health',         '💊', Color(0xFF14B8A6), 'Health'),
  ExpenseCat('other',          '💡', Color(0xFF94A3B8), 'Other'),
];

ExpenseCat catFor(String key) =>
    cats.firstWhere((c) => c.key == key, orElse: () => cats.last);

class ExpenseCat {
  const ExpenseCat(this.key, this.emoji, this.color, this.label);
  final String key, emoji, label;
  final Color color;
}
