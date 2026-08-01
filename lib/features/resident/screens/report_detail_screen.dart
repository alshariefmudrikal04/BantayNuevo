import 'package:flutter/material.dart';
import '../../../models/report_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/list_item_tile.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../data/report_repository.dart';
import 'evidence_vault_screen.dart';

class ReportDetailScreen extends StatelessWidget {
  ReportDetailScreen({super.key, required this.reportId});

  final String reportId;
  final _reportRepository = ReportRepository();

  AppStatus _toAppStatus(ReportStatus s) => switch (s) {
        ReportStatus.pending => AppStatus.pending,
        ReportStatus.inProgress => AppStatus.progress,
        ReportStatus.resolved => AppStatus.resolved,
      };

  String _formatDate(DateTime? date) {
    if (date == null) return 'just now';
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Report detail')),
      body: StreamBuilder<ReportModel>(
        stream: _reportRepository.streamReport(reportId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Report not found.'));
          }
          final report = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.type, style: AppTypography.display(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      '${report.id} · Filed ${_formatDate(report.createdAt)}',
                      style: AppTypography.mono(fontSize: 10.5),
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<String?>(
                      future: report.assignedTanodId != null
                          ? _reportRepository.fetchUserName(report.assignedTanodId!)
                          : Future.value(null),
                      builder: (context, tanodSnapshot) {
                        final tanodName = tanodSnapshot.data;
                        return Text(
                          tanodName != null ? 'Assigned to $tanodName' : 'Not yet assigned to a Tanod',
                          style: AppTypography.mono(fontSize: 10.5),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SectionTitle('Description'),
              AppCard(
                child: Text(
                  report.description.isEmpty ? 'No description provided.' : report.description,
                  style: AppTypography.body(fontSize: 12.5),
                ),
              ),

              const SectionTitle('Status'),
              AppCard(
                child: ListItemTile(
                  title: 'Current status',
                  trailing: StatusBadge(status: _toAppStatus(report.status)),
                  isLast: true,
                ),
              ),

              const SectionTitle('Evidence'),
              AppButton(
                label: '🔒 View evidence vault',
                variant: AppButtonVariant.outline,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => EvidenceVaultScreen(reportId: reportId)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
