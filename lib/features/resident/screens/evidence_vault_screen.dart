import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/report_model.dart';
import '../../../core/theme/lux_theme.dart';
import '../data/report_repository.dart';
import '../../../core/widgets/sensitive_content_gate.dart';
import '../../../core/widgets/photo_viewer_screen.dart';

/// View-only by design (AGENTS.md §8) — this screen must never gain a
/// delete or download action, that's what preserves the evidence chain of
/// custody described in the thesis.
class EvidenceVaultScreen extends StatefulWidget {
  const EvidenceVaultScreen({super.key, required this.reportId});

  final String reportId;

  @override
  State<EvidenceVaultScreen> createState() => _EvidenceVaultScreenState();
}

class _EvidenceVaultScreenState extends State<EvidenceVaultScreen> {
  final _reportRepository = ReportRepository();

  // Created ONCE here instead of inline in build() — same fix as
  // report_detail_screen.dart. A fresh stream on every rebuild (e.g. every
  // time you navigate back to this screen) reset StreamBuilder to "waiting"
  // each time, which is why the file was flashing and disappearing.
  late final Stream<ReportModel> _reportStream = _reportRepository.streamReport(widget.reportId);

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.month}/${date.day}/${date.year}';
  }

  IconData _iconFor(String type) => switch (type) {
        'photo' => Icons.image_outlined,
        'video' => Icons.videocam_outlined,
        'audio' => Icons.mic_none_outlined,
        _ => Icons.description_outlined,
      };

  /// Photos open in an in-app zoomable viewer (photo_viewer_screen.dart).
  /// Video/audio/documents hand off to whatever app the device already has
  /// for that file type (browser, video player, etc.) via the file's own
  /// URL — deliberately not building a custom in-app video/audio player,
  /// since that needs a whole extra package + native setup this project
  /// doesn't need the risk of right now. Either way this is strictly
  /// viewing — nothing here ever downloads or deletes the file itself, so
  /// the chain-of-custody guarantee in the banner above still holds.
  Future<void> _openFile(BuildContext context, EvidenceFile file) async {
    if (file.url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This file doesn't have a valid link."), backgroundColor: LuxColors.red),
      );
      return;
    }
    if (file.type == 'photo') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PhotoViewerScreen(url: file.url, title: file.name)),
      );
      return;
    }
    final uri = Uri.parse(file.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this file.'), backgroundColor: LuxColors.red),
      );
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
          title: Text('EVIDENCE VAULT', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.ink)),
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
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: LuxColors.black, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_outline, size: 16, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Files are encrypted and locked to this case. You can view them, but they can't be "
                          "downloaded or deleted — this preserves the evidence chain for tanod and police.",
                          style: LuxType.body(fontSize: 11, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Text('FILES — ${report.id}', style: LuxType.eyebrow(fontSize: 10.5)),
                const SizedBox(height: 8),
                if (report.evidenceFiles.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
                    child: Text('No evidence uploaded for this report yet.', style: LuxType.body(fontSize: 12, color: LuxColors.inkSoft)),
                  )
                else
                  Container(
                    decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (int i = 0; i < report.evidenceFiles.length; i++)
                          InkWell(
                            onTap: () => _openFile(context, report.evidenceFiles[i]),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: i == report.evidenceFiles.length - 1
                                  ? null
                                  : const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.divider))),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: const BoxDecoration(color: LuxColors.surfaceMuted, shape: BoxShape.circle),
                                    child: Icon(_iconFor(report.evidenceFiles[i].type), size: 18, color: LuxColors.red),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(report.evidenceFiles[i].name, style: LuxType.heading(fontSize: 13), overflow: TextOverflow.ellipsis),
                                        Text(
                                          '${report.evidenceFiles[i].type} · uploaded ${_formatDate(report.evidenceFiles[i].uploadedAt)}',
                                          style: LuxType.eyebrow(fontSize: 9, color: LuxColors.inkSoft, letterSpacing: 0.2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, size: 18, color: LuxColors.inkSoft),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                Text('ACCESS LOG', style: LuxType.eyebrow(fontSize: 10.5)),
                const SizedBox(height: 8),
                if (report.accessLog.isEmpty)
                  Text('No one has viewed this evidence yet.', style: LuxType.body(fontSize: 12, color: LuxColors.inkSoft))
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
                    child: Column(
                      children: [
                        for (int i = 0; i < report.accessLog.length; i++)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: i == report.accessLog.length - 1
                                ? null
                                : const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.divider))),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(report.accessLog[i].who, style: LuxType.body(fontSize: 11.5))),
                                Text(_formatDate(report.accessLog[i].when), style: LuxType.eyebrow(fontSize: 9, color: LuxColors.inkSoft)),
                              ],
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
