import 'package:flutter/material.dart';

/// Design tokens — colors.
///
/// These values are locked to AGENTS.md §4 (extracted from the approved
/// resident UI reference). Do not introduce new colors outside this palette
/// anywhere in the app — every screen composes from these tokens.
class AppColors {
  AppColors._();

  static const bg = Color(0xFFEEF1EC);
  static const panel = Color(0xFFFFFFFF);
  static const ink = Color(0xFF142B27);
  static const inkSoft = Color(0xFF4C6660);
  static const line = Color(0xFFD7DFD9);

  /// Primary action color — buttons, active nav state, headers.
  static const navy = Color(0xFF16324F);
  /// Deep headers / display text.
  static const navyDeep = Color(0xFF0D2136);
  /// Brand accent + "in progress" status.
  static const teal = Color(0xFF1F6E63);
  static const tealLight = Color(0xFFE4F0EC);

  /// SOS / danger / "pending" contrast state.
  static const urgent = Color(0xFFC9432E);
  static const urgentLight = Color(0xFFFBE7E2);

  /// "Pending" status color.
  static const amber = Color(0xFFB8791B);
  static const amberLight = Color(0xFFFBF0DD);

  /// "Resolved" status color.
  static const resolvedFg = Color(0xFF3E7A2A);
  static const resolvedBg = Color(0xFFE4EEE0);

  /// Evidence vault / security — "locked" status color.
  static const lock = Color(0xFF5B4B8A);
  static const lockLight = Color(0xFFECE7F5);
}
