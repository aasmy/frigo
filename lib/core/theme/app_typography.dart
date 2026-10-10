import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography for Frigo.
///
/// Inter via google_fonts, tuned for a calm editorial hierarchy: tight tracking
/// on the big titles, comfortable line-height on body copy. If the font can't be
/// fetched on first run, google_fonts falls back to the platform sans-serif and
/// the hierarchy still holds.
class AppTypography {
  const AppTypography._();

  static TextTheme build() {
    TextStyle f(
      double size,
      FontWeight weight, {
      double? height,
      double? spacing,
      Color? color,
    }) {
      return GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        color: color ?? AppColors.textPrimary,
      );
    }

    return TextTheme(
      // Display / large titles
      displaySmall: f(33, FontWeight.w700, height: 1.1, spacing: -0.8),
      headlineLarge: f(28, FontWeight.w700, height: 1.14, spacing: -0.6),
      headlineMedium: f(23, FontWeight.w700, height: 1.2, spacing: -0.4),
      // Section headers
      titleLarge: f(19, FontWeight.w700, height: 1.25, spacing: -0.3),
      titleMedium: f(17, FontWeight.w600, height: 1.3, spacing: -0.2),
      titleSmall: f(15, FontWeight.w600, height: 1.3, spacing: -0.1),
      // Body
      bodyLarge: f(16.5, FontWeight.w400, height: 1.45),
      bodyMedium: f(15, FontWeight.w400, height: 1.5),
      bodySmall: f(13.5, FontWeight.w400, height: 1.45, color: AppColors.textSecondary),
      // Labels / metadata
      labelLarge: f(15, FontWeight.w600, height: 1.2, spacing: 0.1),
      labelMedium: f(13, FontWeight.w500, height: 1.35, color: AppColors.textSecondary),
      labelSmall: f(11.5, FontWeight.w600, height: 1.3, spacing: 0.3, color: AppColors.textTertiary),
    );
  }
}
