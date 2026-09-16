import 'package:flutter/material.dart';

final appThemeController = ValueNotifier<ThemeMode>(ThemeMode.dark);

class AppColors {
  static const darkBg = Color(0xFF0A0E14);
  static const darkCard = Color(0xFF10151C);
  static const darkCard2 = Color(0xFF151B23);
  static const darkBorder = Color(0xFF1F2937);
  static const darkText = Color(0xFFE8EBEF);
  static const darkMuted = Color(0xFF8B96A5);

  static const lightBg = Color(0xFFF5F7FB);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightCard2 = Color(0xFFF0F4F8);
  static const lightBorder = Color(0xFFD9E1EC);
  static const lightText = Color(0xFF111827);
  static const lightMuted = Color(0xFF64748B);

  static const bg = darkBg;
  static const card = darkCard;
  static const card2 = darkCard2;
  static const border = darkBorder;
  static const text = darkText;
  static const muted = darkMuted;

  static const accent = Color(0xFF6366F1);
  static const accentSoft = Color(0xFFEEF2FF);
  static const positive = Color(0xFF22C55E);
  static const positiveSoft = Color(0xFFDCFCE7);
  static const negative = Color(0xFFF43F5E);
  static const negativeSoft = Color(0xFFFEE2E2);
  static const warn = Color(0xFFF59E0B);

  static Color bgFor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? darkBg : lightBg;
  static Color cardFor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? darkCard : lightCard;
  static Color card2For(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? darkCard2 : lightCard2;
  static Color borderFor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? darkBorder : lightBorder;
  static Color textFor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? darkText : lightText;
  static Color mutedFor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? darkMuted : lightMuted;
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
  final card = isDark ? AppColors.darkCard : AppColors.lightCard;
  final card2 = isDark ? AppColors.darkCard2 : AppColors.lightCard2;
  final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
  final text = isDark ? AppColors.darkText : AppColors.lightText;
  final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: bg,
    fontFamily: 'Inter',
    colorScheme: isDark
        ? const ColorScheme.dark(
            primary: AppColors.accent,
            surface: AppColors.darkCard,
            onSurface: AppColors.darkText,
            tertiary: AppColors.positive,
          )
        : const ColorScheme.light(
            primary: AppColors.accent,
            surface: AppColors.lightCard,
            onSurface: AppColors.lightText,
            tertiary: AppColors.positive,
          ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: text,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: card,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: muted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    chipTheme: ChipThemeData(
      side: BorderSide(color: border),
      backgroundColor: card2,
      selectedColor: AppColors.accentSoft,
      labelStyle: TextStyle(color: text, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
      checkmarkColor: AppColors.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerColor: border,
  );
}
