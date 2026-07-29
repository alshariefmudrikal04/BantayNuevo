import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Two side-by-side direct-escalate cards — "Alert Tanod" / "Alert PNP" —
/// per AGENTS.md §4/§6 SOS screen spec.
class EscalateRow extends StatelessWidget {
  const EscalateRow({super.key, required this.onTanod, required this.onPolice});

  final VoidCallback onTanod;
  final VoidCallback onPolice;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _EscalateCard(
            title: 'Alert Tanod',
            desc: 'Minor / ongoing situations',
            color: AppColors.amber,
            borderColor: const Color(0xFFC9AE5A),
            bgColor: const Color(0xFFFBF4DD),
            onTap: onTanod,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _EscalateCard(
            title: 'Alert PNP',
            desc: 'Active danger, needs authority',
            color: AppColors.urgent,
            borderColor: AppColors.urgent,
            bgColor: AppColors.urgentLight,
            onTap: onPolice,
          ),
        ),
      ],
    );
  }
}

class _EscalateCard extends StatelessWidget {
  const _EscalateCard({
    required this.title,
    required this.desc,
    required this.color,
    required this.borderColor,
    required this.bgColor,
    required this.onTap,
  });

  final String title;
  final String desc;
  final Color color;
  final Color borderColor;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.display(fontSize: 12, color: color)),
            const SizedBox(height: 1),
            Text(desc, style: AppTypography.mono(fontSize: 9.5)),
          ],
        ),
      ),
    );
  }
}
