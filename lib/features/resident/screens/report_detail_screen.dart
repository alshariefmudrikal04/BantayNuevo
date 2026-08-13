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
import '../../../core/widgets/sensitive_content_gate.dart';

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final _reportRepository = ReportRepository();

  // Created ONCE here instead of inline in build() — creating a fresh stream
  // on every rebuild (e.g. every time you navigate back to this screen)
  // resets StreamBuilder to "waiting" each time, which is why content was
  // flashing and disappearing. Caching it fixes that.
  late final Stream<ReportModel> _reportStream = _reportRepository.streamReport(widget.reportId);

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
    return SensitiveContentGate(
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: const Text('Report detail')),
      body: StreamBuilder<ReportModel>(
        stream: _reportStream,
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
                    _TanodNameLabel(
                      reportRepository: _reportRepository,
                      assignedTanodId: report.assignedTanodId,
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
                  MaterialPageRoute(builder: (_) => EvidenceVaultScreen(reportId: widget.reportId)),
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}

/// Split out as its own StatefulWidget so the tanod-name lookup (a Future,
/// same "recreated on every rebuild" trap as the stream above) only runs
/// once per assignedTanodId, not once per parent rebuild.
class _TanodNameLabel extends StatefulWidget {
  const _TanodNameLabel({required this.reportRepository, required this.assignedTanodId});

  final ReportRepository reportRepository;
  final String? assignedTanodId;

  @override
  State<_TanodNameLabel> createState() => _TanodNameLabelState();
}

class _TanodNameLabelState extends State<_TanodNameLabel> {
  late final Future<String?> _tanodNameFuture = widget.assignedTanodId != null
      ? widget.reportRepository.fetchUserName(widget.assignedTanodId!)
      : Future.value(null);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _tanodNameFuture,
      builder: (context, snapshot) {
        final tanodName = snapshot.data;
        return Text(
          tanodName != null ? 'Assigned to $tanodName' : 'Not yet assigned to a Tanod',
          style: AppTypography.mono(fontSize: 10.5),
        );
      },
    );
  }
}
