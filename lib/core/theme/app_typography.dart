import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Design tokens — typography.
///
/// Three type roles per AGENTS.md §4:
/// - Display / headings  → Space Grotesk (weight 600-700)
/// - Body / UI text      → IBM Plex Sans (weight 400-500)
/// - Labels / eyebrow /
///   timestamps / mono
///   UI chrome            → IBM Plex Mono
class AppTypography {
  AppTypography._();

  static TextStyle display({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    Color color = AppColors.navyDeep,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: -0.2,
      );

  static TextStyle body({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.ink,
  }) =>
      GoogleFonts.ibmPlexSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  static TextStyle bodySoft({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w400,
  }) =>
      GoogleFonts.ibmPlexSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: AppColors.inkSoft,
      );

  /// Uppercase field labels, eyebrow text, status-bar-style chrome, timestamps.
  static TextStyle mono({
    double fontSize = 10.5,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.inkSoft,
    double letterSpacing = 0.4,
  }) =>
      GoogleFonts.ibmPlexMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );
}
