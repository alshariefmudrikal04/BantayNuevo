import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// New design system, replacing the soft sage/navy palette in app_colors.dart
/// + app_typography.dart — a bold, high-contrast black/white/red "luxury
/// minimal" look (reference: dribbble.com/shots/27499918). Full rollout plan
/// is resident first, then tanod/police/admin migrate to this same file in
/// later passes — see the app-wide decision in chat. Kept as a SEPARATE file
/// rather than editing AppColors/AppTypography directly, specifically so
/// tanod/police/admin (built around the old palette) don't visually break
/// the moment this lands; once every role is migrated, AppColors/AppTypography
/// can be deleted and everything can just import this file instead.
class LuxColors {
  LuxColors._();

  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);

  /// Screen background for the light (non-SOS-trigger) screens — warm off-
  /// white rather than clinical pure white, for the "luxury" half of
  /// "luxury minimal".
  static const bg = Color(0xFFF7F7F5);

  /// Ink on light backgrounds.
  static const ink = Color(0xFF111111);
  static const inkSoft = Color(0xFF6E6E6E);
  static const divider = Color(0xFFE7E7E4);

  /// Card/list-row surface on light backgrounds.
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF0F0EE);

  /// The one accent color in this entire palette — used deliberately
  /// sparingly (the SOS button, the "active" banner, a few icons) so it
  /// keeps its urgency instead of becoming wallpaper.
  static const red = Color(0xFFEE3A2E);
  static const redDark = Color(0xFFC42B21);
  static const redSoft = Color(0xFFFBE2E0);

  static const success = Color(0xFF2E7D4F);
  static const amber = Color(0xFFB8791B);
}

/// Three type roles, same structure as the old AppTypography for an easy
/// mechanical migration later, but bolder throughout:
/// - hero()    → Archivo Black — the giant, single-weight display font for
///               "SOS", "WELCOME BACK, ALEX"-style headlines. Deliberately
///               a different family from heading(), not just a heavier
///               weight of it — Archivo Black IS a distinct 900-weight-only
///               face, which is what gives the reference its poster-like
///               impact that a merely-bold Space Grotesk doesn't reach.
/// - heading() → Space Grotesk 700 — section titles, button labels.
/// - body()    → IBM Plex Sans — same as before, just re-homed here.
/// - eyebrow() → IBM Plex Mono, uppercase, tracked — "HOW CAN WE HELP?"-
///               style small labels above a section.
class LuxType {
  LuxType._();

  static TextStyle hero({double fontSize = 40, Color color = LuxColors.ink, double letterSpacing = -0.5}) =>
      GoogleFonts.archivoBlack(fontSize: fontSize, color: color, letterSpacing: letterSpacing, height: 1.0);

  static TextStyle heading({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w700,
    Color color = LuxColors.ink,
  }) =>
      GoogleFonts.spaceGrotesk(fontSize: fontSize, fontWeight: fontWeight, color: color, letterSpacing: -0.2);

  static TextStyle body({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    Color color = LuxColors.ink,
  }) =>
      GoogleFonts.ibmPlexSans(fontSize: fontSize, fontWeight: fontWeight, color: color);

  static TextStyle eyebrow({
    double fontSize = 10.5,
    Color color = LuxColors.inkSoft,
    double letterSpacing = 1.1,
    FontWeight fontWeight = FontWeight.w600,
  }) =>
      GoogleFonts.ibmPlexMono(fontSize: fontSize, fontWeight: fontWeight, color: color, letterSpacing: letterSpacing);
}
