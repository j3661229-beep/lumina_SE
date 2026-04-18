import 'package:flutter/material.dart';

// Category with Material icon instead of emoji for UI consistency
class ExpenseCat {
  const ExpenseCat(this.key, this.emoji, this.color, this.label, {this.icon = Icons.circle});
  final String key, emoji, label;
  final Color color;
  final IconData icon;
}

const cats = [
  ExpenseCat('food',          '🍔', Color(0xFFEF4444), 'Food',          icon: Icons.restaurant_rounded),
  ExpenseCat('transport',     '🚌', Color(0xFF6366F1), 'Transport',     icon: Icons.directions_bus_rounded),
  ExpenseCat('stationery',    '📒', Color(0xFFF59E0B), 'Stationery',    icon: Icons.book_outlined),
  ExpenseCat('fees',          '🎓', Color(0xFF10B981), 'Fees',          icon: Icons.school_rounded),
  ExpenseCat('entertainment', '🎬', Color(0xFFEC4899), 'Fun',           icon: Icons.movie_outlined),
  ExpenseCat('health',        '💊', Color(0xFF14B8A6), 'Health',        icon: Icons.medical_services_outlined),
  ExpenseCat('other',         '💡', Color(0xFF94A3B8), 'Other',         icon: Icons.lightbulb_outline),
];

ExpenseCat catFor(String key) =>
    cats.firstWhere((c) => c.key == key, orElse: () => cats.last);

// For use in list/filter chips
final kExpInsightCats = cats;
