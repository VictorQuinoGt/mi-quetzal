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

    return _build(colors, background: background, appBarForeground: navy);
  }

  static ThemeData get dark {
    final colors = ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: blue,
      primary: const Color(0xFF8AB4FF),
      onPrimary: const Color(0xFF10264A),
      primaryContainer: const Color(0xFF203B63),
      onPrimaryContainer: const Color(0xFFD8E6FF),
      secondary: const Color(0xFFFF929C),
      onSecondary: const Color(0xFF4C1420),
      secondaryContainer: const Color(0xFF512530),
      onSecondaryContainer: const Color(0xFFFFDADD),
      tertiary: const Color(0xFFFF929C),
      onTertiary: const Color(0xFF4C1420),
      error: const Color(0xFFFF929C),
      onError: const Color(0xFF4C1420),
      errorContainer: const Color(0xFF512530),
      onErrorContainer: const Color(0xFFFFDADD),
      surface: const Color(0xFF172235),
      onSurface: const Color(0xFFE8EEF8),
      onSurfaceVariant: const Color(0xFFAAB8CC),
      surfaceDim: const Color(0xFF0D1422),
      surfaceBright: const Color(0xFF2A3B53),
      surfaceContainerLowest: const Color(0xFF0D1422),
      surfaceContainerLow: const Color(0xFF172235),
      surfaceContainer: const Color(0xFF20304A),
      surfaceContainerHigh: const Color(0xFF263751),
      surfaceContainerHighest: const Color(0xFF2E405A),
      outline: const Color(0xFF7F91AB),
      outlineVariant: const Color(0xFF354762),
    );
    return _build(
      colors,
      background: const Color(0xFF0D1422),
      appBarForeground: colors.onSurface,
    );
  }

  static ThemeData _build(
    ColorScheme colors, {
    required Color background,
    required Color appBarForeground,
  }) {
    final isDark = colors.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: appBarForeground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: isDark,
        fillColor: colors.surfaceContainer,
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
        indicatorColor: isDark
            ? colors.primaryContainer
            : colors.secondaryContainer,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: isDark
            ? colors.primaryContainer
            : colors.secondaryContainer,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
    );
  }
}
