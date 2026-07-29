import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/report_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/list_item_tile.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/feature_stub_screen.dart';
import 'report_form_screen.dart';
import 'sos_screen.dart';
import '../data/report_repository.dart';
import '../../auth/data/auth_repository.dart';

class ResidentHomeScreen extends StatelessWidget {
  ResidentHomeScreen({super.key, required this.user});

  final UserModel user;
  final _reportRepository = ReportRepository();
  final _authRepository = AuthRepository();

  AppStatus _toAppStatus(ReportStatus s) => switch (s) {
        ReportStatus.pending => AppStatus.pending,
        ReportStatus.inProgress => AppStatus.progress,
        ReportStatus.resolved => AppStatus.resolved,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text('Bantay Nuevo'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Log out',
            onPressed: _authRepository.logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.tealLight,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: AppTypography.display(fontSize: 15, color: AppColors.teal),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hi, ${user.name}', style: AppTypography.display(fontSize: 16)),
                      Text('${user.barangay} resident · Purok ${user.purok}', style: AppTypography.bodySoft(fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SectionTitle('Quick actions', topPadding: 4),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Open SOS',
                  variant: AppButtonVariant.filled,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SosScreen(user: user)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'File a report',
                  variant: AppButtonVariant.outline,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ReportFormScreen(user: user)),
                  ),
                ),
              ),
            ],
          ),

          const SectionTitle('Recent activity'),
          StreamBuilder<List<ReportModel>>(
            stream: _reportRepository.streamRecentReports(user.uid, limit: 2),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final reports = snapshot.data ?? [];
              if (reports.isEmpty) {
                return AppCard(
                  child: Text(
                    'No reports yet. Filed reports will show up here.',
                    style: AppTypography.bodySoft(fontSize: 12),
                  ),
                );
              }
              return AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Column(
                  children: [
                    for (int i = 0; i < reports.length; i++)
                      ListItemTile(
                        title: reports[i].type,
                        subtitle: reports[i].id,
                        trailing: StatusBadge(status: _toAppStatus(reports[i].status)),
                        isLast: i == reports.length - 1,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FeatureStubScreen(title: 'Report detail')),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          const SectionTitle('Quick access'),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Hotlines',
                  variant: AppButtonVariant.ghost,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FeatureStubScreen(title: 'Resources')),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Evidence vault',
                  variant: AppButtonVariant.ghost,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FeatureStubScreen(title: 'Evidence vault')),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}