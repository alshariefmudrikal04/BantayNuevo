import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/section_title.dart';
import '../../../../core/widgets/list_item_tile.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Privacy & data')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Data Privacy Act compliance', style: AppTypography.display(fontSize: 14)),
                const SizedBox(height: 6),
                Text(
                  'Your reports and evidence are classified as sensitive personal information under '
                  'RA 10173 and are encrypted and access-limited accordingly.',
                  style: AppTypography.bodySoft(fontSize: 11.5),
                ),
              ],
            ),
          ),

          const SectionTitle('Retention'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Column(
              children: const [
                ListItemTile(
                  title: 'Evidence retention period',
                  trailing: Text('Until case closed + 1 year', style: TextStyle(fontSize: 10.5)),
                ),
                ListItemTile(
                  title: 'Who can access your case',
                  trailing: Text('Assigned Tanod + escalated PNP only', style: TextStyle(fontSize: 10.5)),
                  isLast: true,
                ),
              ],
            ),
          ),

          const SectionTitle('Your data rights'),
          AppButton(
            label: 'Request a copy of my data',
            variant: AppButtonVariant.outline,
            onPressed: () => _showSnack(
              context,
              "Request noted. We'll email you a copy within the timeframe required by RA 10173.",
            ),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Request account deletion',
            variant: AppButtonVariant.ghost,
            onPressed: () => _showSnack(
              context,
              'Request noted. A barangay official will follow up to confirm before deletion.',
            ),
          ),
        ],
      ),
    );
  }
}
