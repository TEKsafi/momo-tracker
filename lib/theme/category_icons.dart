import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Maps a category name to an icon + accent color so transaction rows and
/// category breakdowns look like a designed product instead of a plain list.
/// Falls back gracefully for any custom category a user adds in Settings.
class CategoryStyle {
  final IconData icon;
  final Color color;
  const CategoryStyle(this.icon, this.color);

  static const _map = <String, CategoryStyle>{
    'Food': CategoryStyle(Icons.restaurant_outlined, Color(0xFFF59E0B)),
    'Transport': CategoryStyle(Icons.directions_bus_outlined, Color(0xFF0EA5E9)),
    'Rent': CategoryStyle(Icons.home_outlined, Color(0xFF6366F1)),
    'Utilities': CategoryStyle(Icons.bolt_outlined, Color(0xFFEAB308)),
    'Airtime/Data': CategoryStyle(Icons.sim_card_outlined, Color(0xFFA855F7)),
    'Savings': CategoryStyle(Icons.savings_outlined, Color(0xFF22C55E)),
    'Health': CategoryStyle(Icons.favorite_outline, Color(0xFFF43F5E)),
    'Entertainment': CategoryStyle(Icons.movie_outlined, Color(0xFFEC4899)),
    'Education': CategoryStyle(Icons.school_outlined, Color(0xFF10B981)),
    'Other': CategoryStyle(Icons.category_outlined, Color(0xFF8B96A5)),
  };

  static CategoryStyle of(String category) => _map[category] ?? const CategoryStyle(Icons.category_outlined, AppColors.darkMuted);
}
