import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/report_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/list_item_tile.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/report_repository.dart';
import 'report_detail_screen.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final _reportRepository = ReportRepository();
  late final Stream<List<ReportModel>> _reportsStream = _reportRepository.streamAllReports(widget.user.uid);

  AppStatus _toAppStatus(ReportStatus s) => switch (s) {
        ReportStatus.pending => AppStatus.pending,
        ReportStatus.inProgress => AppStatus.progress,
        ReportStatus.resolved => AppStatus.resolved,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('My reports')),
      body: StreamBuilder<List<ReportModel>>(
        stream: _reportsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data ?? [];
          if (reports.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppCard(
                child: const Text("You haven't filed any reports yet."),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
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
                          MaterialPageRoute(builder: (_) => ReportDetailScreen(reportId: reports[i].id)),
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'just now';
    return '${date.month}/${date.day}/${date.year}';
  }
}
