import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum AppStatus { pending, progress, resolved, locked }

/// Pill-shaped status badge, mono font, color-coded per AGENTS.md §4.
/// Used on report list items, report detail, and the evidence vault.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.customLabel});

  final AppStatus status;
  final String? customLabel;

  ({Color fg, Color bg, String label}) get _spec => switch (status) {
        AppStatus.pending => (fg: AppColors.amber, bg: AppColors.amberLight, label: 'Pending'),
        AppStatus.progress => (fg: AppColors.teal, bg: AppColors.tealLight, label: 'In progress'),
        AppStatus.resolved => (fg: AppColors.resolvedFg, bg: AppColors.resolvedBg, label: 'Resolved'),
        AppStatus.locked => (fg: AppColors.lock, bg: AppColors.lockLight, label: 'Locked'),
      };

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: spec.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        customLabel ?? spec.label,
        style: AppTypography.mono(fontSize: 9.5, color: spec.fg, letterSpacing: 0),
      ),
    );
  }
}
