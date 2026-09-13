import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/report_model.dart';
import '../../../core/theme/lux_theme.dart';
import '../data/police_repository.dart';
import 'police_report_review_screen.dart';

/// Every incident report assigned to this police officer, with
/// pending/in-progress/resolved count cards. Reskinned to match the
/// resident side's look.
class PoliceReportsScreen extends StatefulWidget {
  const PoliceReportsScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<PoliceReportsScreen> createState() => _PoliceReportsScreenState();
}

class _PoliceReportsScreenState extends State<PoliceReportsScreen> {
  final _repository = PoliceRepository();
  late final Stream<List<ReportModel>> _reportsStream = _repository.streamMyReports(widget.user.uid);

  String _formatDate(DateTime? date) {
    if (date == null) return 'just now';
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxColors.bg,
      appBar: AppBar(
        backgroundColor: LuxColors.bg,
        elevation: 0,
        title: Text('ASSIGNED REPORTS', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.ink)),
      ),
      body: StreamBuilder<List<ReportModel>>(
        stream: _reportsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data ?? [];
          final pending = reports.where((r) => r.status == ReportStatus.pending).length;
          final inProgress = reports.where((r) => r.status == ReportStatus.inProgress).length;
          final resolved = reports.where((r) => r.status == ReportStatus.resolved).length;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(child: _CountCard(label: 'PENDING', count: pending, color: LuxColors.amber)),
                  const SizedBox(width: 8),
                  Expanded(child: _CountCard(label: 'IN PROGRESS', count: inProgress, color: LuxColors.black)),
                  const SizedBox(width: 8),
                  Expanded(child: _CountCard(label: 'RESOLVED', count: resolved, color: LuxColors.success)),
                ],
              ),
              const SizedBox(height: 24),
              Text('ASSIGNED TO YOU', style: LuxType.eyebrow(fontSize: 10.5)),
              const SizedBox(height: 8),
              if (reports.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
                  child: Text('No reports assigned to you yet.', style: LuxType.body(fontSize: 12, color: LuxColors.inkSoft)),
                )
              else
                Container(
                  decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (int i = 0; i < reports.length; i++)
                        InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => PoliceReportReviewScreen(reportId: reports[i].id, user: widget.user)),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: i == reports.length - 1
                                ? null
                                : const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.divider))),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(reports[i].type, style: LuxType.heading(fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${reports[i].id} · ${_formatDate(reports[i].createdAt)}',
                                        style: LuxType.eyebrow(fontSize: 9, color: LuxColors.inkSoft, letterSpacing: 0.2),
                                      ),
                                    ],
                                  ),
                                ),
                                LuxStatusPill(status: reports[i].status.value),
                              ],
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: LuxType.eyebrow(fontSize: 8.5)),
          const SizedBox(height: 4),
          Text('$count', style: LuxType.hero(fontSize: 22, color: color)),
        ],
      ),
    );
  }
}
