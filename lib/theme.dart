import 'package:flutter/material.dart';

/// Material 3 light and dark themes.
///
/// One seed colour drives both so the palette stays consistent, and text
/// scaling is left untouched so the app follows the device font size.
class AppTheme {
  const AppTheme._();

  static const Color seed = Color(0xFF1B6B50);

  /// Used for anything safety related: notices, red flags, warnings.
  static const Color warning = Color(0xFFB3261E);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      // Button minimums are deliberately finite.
      //
      // Size.fromHeight(h) is Size(double.infinity, h). A theme-wide infinite
      // minimum width works only where the parent already constrains width; as
      // a non-flex child of a Row the constraints are unbounded, so the button
      // throws "BoxConstraints forces an infinite width", never lays out, and
      // simply does not paint in a release build. Full-width buttons come from
      // the layout instead: a stretched Column, an Expanded, or a list item.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(88, 52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(88, 48)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Spacing scale, so padding stays consistent without magic numbers.
class Gap {
  const Gap._();

  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;

  static const Widget h4 = SizedBox(height: xs);
  static const Widget h8 = SizedBox(height: s);
  static const Widget h16 = SizedBox(height: m);
  static const Widget h24 = SizedBox(height: l);
  static const Widget h32 = SizedBox(height: xl);
  static const Widget w8 = SizedBox(width: s);
  static const Widget w16 = SizedBox(width: m);
}
