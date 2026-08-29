import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static TextStyle display({
    double size = 34,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.ink,
    double letterSpacing = -0.5,
    double? height,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    return GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
    );
  }

  static TextStyle ui({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.ink,
    double letterSpacing = 0,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextTheme textTheme() {
    return TextTheme(
      displayLarge: display(size: 40, weight: FontWeight.w700),
      displayMedium: display(size: 32, weight: FontWeight.w700),
      displaySmall: display(size: 28, weight: FontWeight.w600),
      headlineMedium: display(size: 24, weight: FontWeight.w600),
      titleLarge: display(size: 20, weight: FontWeight.w600),
      titleMedium: ui(size: 16, weight: FontWeight.w600),
      titleSmall: ui(size: 14, weight: FontWeight.w600),
      bodyLarge: ui(size: 16, color: AppColors.ink),
      bodyMedium: ui(size: 14, color: AppColors.inkSecondary, height: 1.4),
      bodySmall: ui(size: 12, color: AppColors.inkSecondary),
      labelLarge: ui(size: 14, weight: FontWeight.w600),
      labelMedium: ui(size: 12, weight: FontWeight.w600),
    );
  }
}
