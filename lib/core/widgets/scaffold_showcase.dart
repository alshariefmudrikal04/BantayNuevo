import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';
import 'status_badge.dart';
import 'app_card.dart';
import 'section_title.dart';
import 'list_item_tile.dart';
import 'toggle_row.dart';
import 'net_banner.dart';

/// Debug-only screen from Prompt 0, kept for reference. Was briefly wired as
/// the app's home screen to visually confirm the theme + shared widgets
/// before Prompt 1 (auth) replaced app.dart's home with AuthGate. Not used
/// anywhere in the real navigation flow — safe to delete once you no longer
/// need to spot-check the design system.
class _ScaffoldShowcase extends StatefulWidget {
  const _ScaffoldShowcase();

  @override
  State<_ScaffoldShowcase> createState() => _ScaffoldShowcaseState();
}

class _ScaffoldShowcaseState extends State<_ScaffoldShowcase> {
  bool _toggleOn = true;
  bool _online = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bantay Nuevo — scaffold check')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          NetBanner(isOnline: _online),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Toggle online/offline', onPressed: () => setState(() => _online = !_online)),
          const SectionTitle('Buttons'),
          AppButton(label: 'Filled button', onPressed: () {}),
          const SizedBox(height: AppSpacing.sm),
          AppButton(label: 'Outline button', variant: AppButtonVariant.outline, onPressed: () {}),
          const SizedBox(height: AppSpacing.sm),
          AppButton(label: 'Ghost button', variant: AppButtonVariant.ghost, onPressed: () {}),
          const SectionTitle('Status badges'),
          const Wrap(
            spacing: 8,
            children: [
              StatusBadge(status: AppStatus.pending),
              StatusBadge(status: AppStatus.progress),
              StatusBadge(status: AppStatus.resolved),
              StatusBadge(status: AppStatus.locked),
            ],
          ),
          const SectionTitle('Card + list items'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListItemTile(
                  title: 'Slight physical injury report',
                  subtitle: 'BCN-2026-0143',
                  trailing: const StatusBadge(status: AppStatus.progress),
                ),
                ListItemTile(
                  title: 'Noise / threat complaint',
                  subtitle: 'BCN-2026-0139',
                  trailing: const StatusBadge(status: AppStatus.resolved),
                  isLast: true,
                ),
              ],
            ),
          ),
          const SectionTitle('Toggle row'),
          AppCard(
            child: ToggleRow(
              label: 'Push notifications',
              description: 'Alerts on report status changes',
              value: _toggleOn,
              onChanged: (v) => setState(() => _toggleOn = v),
              isLast: true,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Color palette: ',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppColors.navy,
              AppColors.teal,
              AppColors.urgent,
              AppColors.amber,
              AppColors.resolvedFg,
              AppColors.lock,
            ]
                .map((c) => Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
