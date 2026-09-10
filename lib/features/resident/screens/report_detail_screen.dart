import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/report_model.dart';
import '../../../core/theme/lux_theme.dart';
import '../data/report_repository.dart';
import 'evidence_vault_screen.dart';
import '../../../core/widgets/sensitive_content_gate.dart';
import '../../../core/widgets/photo_viewer_screen.dart';

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

  String _formatDate(DateTime? date) {
    if (date == null) return 'just now';
    return '${date.month}/${date.day}/${date.year}';
  }

  IconData _iconFor(String type) => switch (type) {
        'photo' => Icons.image_outlined,
        'video' => Icons.videocam_outlined,
        'audio' => Icons.mic_none_outlined,
        _ => Icons.description_outlined,
      };

  /// Case-update attachments aren't part of report.evidenceFiles (the
  /// resident's own original submission) — they live in a separate array
  /// per update, so they're not shown in EvidenceVaultScreen. Opened
  /// directly here instead, same photo-viewer-or-external-launch pattern
  /// as everywhere else evidence gets viewed in this app.
  Future<void> _openFile(BuildContext context, EvidenceFile file) async {
    if (file.url.isEmpty) return;
    if (file.type == 'photo') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhotoViewerScreen(url: file.url, title: file.name)));
      return;
    }
    final uri = Uri.parse(file.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SensitiveContentGate(
      child: Scaffold(
        backgroundColor: LuxColors.bg,
        appBar: AppBar(
          backgroundColor: LuxColors.bg,
          elevation: 0,
          title: Text('REPORT DETAIL', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.ink)),
        ),
        body: StreamBuilder<ReportModel>(
          stream: _reportStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData) {
              return Center(child: Text('Report not found.', style: LuxType.body(fontSize: 13)));
            }
            final report = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _Section(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(report.type, style: LuxType.heading(fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('${report.id} · Filed ${_formatDate(report.createdAt)}', style: LuxType.eyebrow(fontSize: 9, color: LuxColors.inkSoft, letterSpacing: 0.3)),
                            const SizedBox(height: 4),
                            _TanodNameLabel(reportRepository: _reportRepository, assignedTanodId: report.assignedTanodId),
                          ],
                        ),
                      ),
                      LuxStatusPill(status: report.status.value),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Text('DESCRIPTION', style: LuxType.eyebrow(fontSize: 10.5)),
                const SizedBox(height: 8),
                _Section(
                  child: Text(
                    report.description.isEmpty ? 'No description provided.' : report.description,
                    style: LuxType.body(fontSize: 12.5),
                  ),
                ),
                const SizedBox(height: 20),

                Text('EVIDENCE', style: LuxType.eyebrow(fontSize: 10.5)),
                const SizedBox(height: 8),
                Material(
                  color: LuxColors.red,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => EvidenceVaultScreen(reportId: widget.reportId)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline, size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          Text('VIEW EVIDENCE VAULT', style: LuxType.eyebrow(fontSize: 11, color: Colors.white, letterSpacing: 0.6)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text('UPDATES FROM RESPONDERS', style: LuxType.eyebrow(fontSize: 10.5)),
                const SizedBox(height: 8),
                if (report.caseUpdates.isEmpty)
                  _Section(
                    child: Text(
                      'No updates yet. Once a tanod or police responder acts on your report, progress notes '
                      'and — if resolved — what was agreed will show up here.',
                      style: LuxType.body(fontSize: 12, color: LuxColors.inkSoft),
                    ),
                  )
                else
                  for (final update in report.caseUpdates.reversed) ...[
                    _Section(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('${update.authorName} · ${update.authorRole}', style: LuxType.heading(fontSize: 13))),
                              Text(_formatDate(update.when), style: LuxType.eyebrow(fontSize: 9, color: LuxColors.inkSoft)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(update.note, style: LuxType.body(fontSize: 12.5)),
                          if (update.evidenceFiles.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            for (final file in update.evidenceFiles)
                              InkWell(
                                onTap: () => _openFile(context, file),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    children: [
                                      Icon(_iconFor(file.type), size: 14, color: LuxColors.red),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(file.name, style: LuxType.eyebrow(fontSize: 10, color: LuxColors.red, letterSpacing: 0.2), overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
      child: child,
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
          style: LuxType.eyebrow(fontSize: 9, color: LuxColors.inkSoft, letterSpacing: 0.2),
        );
      },
    );
  }
}
