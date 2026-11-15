import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/app/app_theme.dart';

double contrast(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

void main() {
  test('Los textos y botones oscuros mantienen contraste mínimo de 4.5:1', () {
    final theme = AppTheme.dark;
    final colors = theme.colorScheme;
    for (final surface in [
      theme.scaffoldBackgroundColor,
      colors.surface,
      colors.surfaceContainer,
      colors.surfaceContainerHigh,
      colors.surfaceContainerHighest,
    ]) {
      for (final text in [
        colors.onSurface,
        colors.onSurfaceVariant,
        colors.primary,
        colors.error,
      ]) {
        expect(contrast(text, surface), greaterThanOrEqualTo(4.5));
      }
    }
    for (final pair in [
      (colors.onPrimary, colors.primary),
      (colors.onPrimaryContainer, colors.primaryContainer),
      (colors.onSecondary, colors.secondary),
      (colors.onSecondaryContainer, colors.secondaryContainer),
      (colors.onError, colors.error),
      (colors.onErrorContainer, colors.errorContainer),
    ]) {
      expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
    }
  });
}
