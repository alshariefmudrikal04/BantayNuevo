import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/report_model.dart';
import '../../../core/theme/lux_theme.dart';
import '../../../core/widgets/sensitive_content_gate.dart';
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'just now';
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SensitiveContentGate(
      child: Scaffold(
        backgroundColor: LuxColors.bg,
        appBar: AppBar(
          backgroundColor: LuxColors.bg,
          elevation: 0,
          title: Text('MY REPORTS', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.ink)),
        ),
        body: StreamBuilder<List<ReportModel>>(
          stream: _reportsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: _EmptyCard(text: 'Could not load your reports.\n\n${snapshot.error}', isError: true),
              );
            }
            final reports = snapshot.data ?? [];
            if (reports.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: _EmptyCard(text: "You haven't filed any reports yet."),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (int i = 0; i < reports.length; i++)
                        InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ReportDetailScreen(reportId: reports[i].id)),
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
                                        style: LuxType.eyebrow(fontSize: 9, color: LuxColors.inkSoft, letterSpacing: 0.3),
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
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
      child: Text(text, style: LuxType.body(fontSize: 12, color: isError ? LuxColors.red : LuxColors.inkSoft)),
    );
  }
}
