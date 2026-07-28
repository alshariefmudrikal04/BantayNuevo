import 'package:flutter/material.dart';

/// Design tokens — spacing & shape, per AGENTS.md §4.
class AppSpacing {
  AppSpacing._();

  // Spacing scale
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;

  // Radii — buttons 9px, cards 10-12px per reference UI
  static const radiusButton = 9.0;
  static const radiusCard = 12.0;
  static const radiusPill = 20.0; // status badges

  static const buttonRadius = BorderRadius.all(Radius.circular(radiusButton));
  static const cardRadius = BorderRadius.all(Radius.circular(radiusCard));
  static const pillRadius = BorderRadius.all(Radius.circular(radiusPill));

  // Borders
  static const hairline = 1.0; // list-item / card dividers, 1px `line` color

  // SOS panic button (AGENTS.md §4 shape spec)
  static const panicButtonDiameter = 150.0;
  static const panicButtonHaloWidth = 8.0;
}
