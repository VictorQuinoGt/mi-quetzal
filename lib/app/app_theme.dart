import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const navy = Color(0xFF112B58);
  static const blue = Color(0xFF1859B5);
  static const red = Color(0xFFC62E40);
  static const background = Color(0xFFF4F6FB);

  static ThemeData get light {
    final colors = ColorScheme.fromSeed(
      seedColor: blue,
      primary: blue,
      secondary: red,
      secondaryContainer: const Color(0xFFFFDADD),
      onSecondaryContainer: const Color(0xFF680019),
      tertiary: red,
      error: red,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.secondaryContainer,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.secondaryContainer,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: blue,
        foregroundColor: Colors.white,
      ),
    );
  }
}
