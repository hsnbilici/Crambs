import 'package:flutter/material.dart';

/// Artisan palette placeholder — Material 3 seed + tabularFigures.
/// Hex'ler tasarımcı kesinleştirene kadar warm amber seed
/// (visual-design.md artisan dönemi rehberi).
///
/// A11y: FilledButton + TextButton minimumSize 48×48dp — tek noktada
/// Sprint B2 §5 tap target zorunluluğu karşılanır (T16).
class AppTheme {
  const AppTheme._();

  static const _a11yMinTapTarget = Size(48, 48);

  static FilledButtonThemeData _filledButtonTheme() => FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: _a11yMinTapTarget),
      );

  static TextButtonThemeData _textButtonTheme() => TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: _a11yMinTapTarget),
      );

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8A53C),
        ),
        filledButtonTheme: _filledButtonTheme(),
        textButtonTheme: _textButtonTheme(),
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
        filledButtonTheme: _filledButtonTheme(),
        textButtonTheme: _textButtonTheme(),
        textTheme: Typography.material2021().white.copyWith(
              displayLarge: const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
      );
}
