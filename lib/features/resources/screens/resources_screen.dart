import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/hotlines_data.dart';
import 'guide_detail_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  Future<void> _dial(BuildContext context, String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: digits);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the dialer on this device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Resources')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SectionTitle('Emergency hotlines', topPadding: 0),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Column(
              children: [
                for (int i = 0; i < kHotlines.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: i == kHotlines.length - 1
                          ? null
                          : const Border(bottom: BorderSide(color: AppColors.line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(kHotlines[i].name, style: AppTypography.body(fontSize: 12, fontWeight: FontWeight.w500)),
                              Text(kHotlines[i].description, style: AppTypography.mono(fontSize: 10)),
                            ],
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(7),
                          onTap: () => _dial(context, kHotlines[i].phone),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.tealLight,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              kHotlines[i].phone,
                              style: AppTypography.mono(fontSize: 11.5, color: AppColors.navy),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SectionTitle('Safety guides'),
          for (final guide in kSafetyGuides)
            InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => GuideDetailScreen(guide: guide)),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: AppColors.amberLight, borderRadius: BorderRadius.circular(9)),
                      alignment: Alignment.center,
                      child: Icon(guide.icon, size: 18, color: AppColors.amber),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(guide.title, style: AppTypography.body(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          Text(guide.subtitle, style: AppTypography.mono(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
