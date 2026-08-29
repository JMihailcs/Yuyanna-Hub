import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final ColorScheme scheme = const ColorScheme.light(
      primary: AppColors.red,
      onPrimary: Colors.white,
      secondary: AppColors.blue,
      onSecondary: Colors.white,
      tertiary: AppColors.gold,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.red,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.paper,
      colorScheme: scheme,
      textTheme: AppTypography.textTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.display(size: 20, weight: FontWeight.w600),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: AppTypography.ui(size: 14, color: AppColors.inkSecondary),
        hintStyle: AppTypography.ui(size: 14, color: AppColors.inkSecondary)
            .copyWith(color: AppColors.inkSecondary.withValues(alpha: 0.6)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.red, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.red, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.red, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.red,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: AppTypography.ui(size: 15, weight: FontWeight.w600)
              .copyWith(letterSpacing: 0.4),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.red,
          textStyle: AppTypography.ui(size: 14, weight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: AppTypography.ui(size: 14, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
