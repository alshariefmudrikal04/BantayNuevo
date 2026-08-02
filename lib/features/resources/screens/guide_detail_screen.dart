import 'package:flutter/material.dart';
import '../data/hotlines_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';

class GuideDetailScreen extends StatelessWidget {
  const GuideDetailScreen({super.key, required this.guide});

  final SafetyGuide guide;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Safety guide')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Row(
              children: [
                Icon(guide.icon, size: 24, color: AppColors.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(guide.title, style: AppTypography.display(fontSize: 15)),
                      Text(guide.subtitle, style: AppTypography.bodySoft(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Text(
            'General guidance — outside the core violence-response scope, offered as supplementary support.',
            style: AppTypography.mono(fontSize: 10, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < guide.steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: AppTypography.mono(fontSize: 11, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(guide.steps[i], style: AppTypography.bodySoft(fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
