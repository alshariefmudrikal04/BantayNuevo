import 'package:flutter/material.dart';
import '../theme/app_typography.dart';

/// Uppercase mono section header used above list groups
/// (e.g. "RECENT ACTIVITY", "MY REPORTS") per the reference UI's .section-title.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.label, {super.key, this.topPadding = 14});

  final String label;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: 7),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.mono(fontSize: 10, letterSpacing: 0.6),
      ),
    );
  }
}
