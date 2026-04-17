import 'package:flutter/material.dart';

/// Artisan palette placeholder — Material 3 seed + tabularFigures.
/// Hex'ler tasarımcı kesinleştirene kadar warm amber seed
/// (visual-design.md artisan dönemi rehberi).
class AppTheme {
  const AppTheme._();

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8A53C),
        ),
        textTheme: Typography.material2021().black.copyWith(
              displayLarge: const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8A53C),
          brightness: Brightness.dark,
        ),
        textTheme: Typography.material2021().white.copyWith(
              displayLarge: const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
      );
}
