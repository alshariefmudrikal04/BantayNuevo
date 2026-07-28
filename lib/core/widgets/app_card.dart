import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Shared card container — 1px `line` border, panel background, 10-12px
/// radius, per AGENTS.md §4. Used for profile summary, report summary,
/// SOS "nearby responders", etc.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(13),
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 11),
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: AppSpacing.cardRadius,
        border: Border.all(color: AppColors.line, width: AppSpacing.hairline),
      ),
      child: child,
    );
  }
}
