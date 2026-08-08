import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/report_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/list_item_tile.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/tanod_report_repository.dart';
import 'tanod_report_review_screen.dart';

class TanodDashboardScreen extends StatefulWidget {
  const TanodDashboardScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<TanodDashboardScreen> createState() => _TanodDashboardScreenState();
}

class _TanodDashboardScreenState extends State<TanodDashboardScreen> {
  final _repository = TanodReportRepository();
  late final Stream<List<ReportModel>> _reportsStream = _repository.streamAllReports();

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
      appBar: AppBar(title: const Text('Incident reports')),
      body: StreamBuilder<List<ReportModel>>(
        stream: _reportsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppCard(
                child: Text(
                  'Could not load reports.\n\n${snapshot.error}',
                  style: const TextStyle(color: AppColors.urgent, fontSize: 11),
                ),
              ),
            );
          }

          final reports = snapshot.data ?? [];
          final pending = reports.where((r) => r.status == ReportStatus.pending).length;
          final inProgress = reports.where((r) => r.status == ReportStatus.inProgress).length;
          final resolved = reports.where((r) => r.status == ReportStatus.resolved).length;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                children: [
                  Expanded(child: _CountCard(label: 'Pending', count: pending, color: AppColors.amber)),
                  const SizedBox(width: 8),
                  Expanded(child: _CountCard(label: 'In progress', count: inProgress, color: AppColors.teal)),
                  const SizedBox(width: 8),
                  Expanded(child: _CountCard(label: 'Resolved', count: resolved, color: AppColors.resolvedFg)),
                ],
              ),
              const SectionTitle('All reports'),
              if (reports.isEmpty)
                AppCard(child: Text('No reports filed yet.', style: AppTypography.bodySoft(fontSize: 12)))
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  child: Column(
                    children: [
                      for (int i = 0; i < reports.length; i++)
                        ListItemTile(
                          title: reports[i].type,
                          subtitle: '${reports[i].id} · ${_formatDate(reports[i].createdAt)}',
                          trailing: StatusBadge(status: _toAppStatus(reports[i].status)),
                          isLast: i == reports.length - 1,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TanodReportReviewScreen(reportId: reports[i].id, user: widget.user),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.mono(fontSize: 9.5)),
          const SizedBox(height: 4),
          Text('$count', style: AppTypography.display(fontSize: 20, color: color)),
        ],
      ),
    );
  }
}
