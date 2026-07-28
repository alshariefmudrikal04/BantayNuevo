import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles the app-wide [ThemeData] from the design tokens in
/// app_colors.dart / app_typography.dart / app_spacing.dart.
///
/// Feature screens should pull colors/text styles from AppColors /
/// AppTypography directly (or via Theme.of(context)) rather than hardcoding
/// new values — see AGENTS.md §8.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navy,
        primary: AppColors.navy,
        secondary: AppColors.teal,
        error: AppColors.urgent,
        surface: AppColors.panel,
        brightness: Brightness.light,
      ),
      dividerColor: AppColors.line,
      textTheme: TextTheme(
        displayLarge: AppTypography.display(fontSize: 30),
        displayMedium: AppTypography.display(fontSize: 22),
        titleLarge: AppTypography.display(fontSize: 17),
        titleMedium: AppTypography.display(fontSize: 15),
        bodyLarge: AppTypography.body(fontSize: 14.5),
        bodyMedium: AppTypography.body(fontSize: 13),
        bodySmall: AppTypography.bodySoft(fontSize: 11.5),
        labelSmall: AppTypography.mono(),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.panel,
        foregroundColor: AppColors.navyDeep,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.display(fontSize: 15),
      ),
      cardTheme: CardThemeData(
        color: AppColors.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.cardRadius,
          side: const BorderSide(color: AppColors.line, width: AppSpacing.hairline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          textStyle: AppTypography.body(fontSize: 12.5, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: AppSpacing.buttonRadius),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.navy),
          textStyle: AppTypography.body(fontSize: 12.5, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: AppSpacing.buttonRadius),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.panel,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.navy, width: 1.4),
        ),
      ),
    );
  }
}
