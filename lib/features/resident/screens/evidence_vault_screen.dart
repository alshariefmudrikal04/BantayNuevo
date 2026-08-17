import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/report_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/section_title.dart';
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
        const SnackBar(content: Text("This file doesn't have a valid link."), backgroundColor: AppColors.urgent),
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
        const SnackBar(content: Text('Could not open this file.'), backgroundColor: AppColors.urgent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SensitiveContentGate(
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: const Text('Evidence vault')),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lockLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD9CFEC)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline, size: 16, color: AppColors.lock),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Files are encrypted and locked to this case. You can view them, but they can't be "
                        "downloaded or deleted from the app — this preserves the evidence chain for tanod and police.",
                        style: AppTypography.bodySoft(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),

              SectionTitle('Files — ${report.id}'),
              if (report.evidenceFiles.isEmpty)
                Text(
                  'No evidence uploaded for this report yet.',
                  style: AppTypography.bodySoft(fontSize: 12),
                )
              else
                for (final file in report.evidenceFiles)
                  InkWell(
                    onTap: () => _openFile(context, file),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration:
                                BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(8)),
                            child: Icon(_iconFor(file.type), size: 18, color: AppColors.teal),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(file.name, style: AppTypography.body(fontSize: 12), overflow: TextOverflow.ellipsis),
                                Text(
                                  '${file.type} · uploaded ${_formatDate(file.uploadedAt)}',
                                  style: AppTypography.mono(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 18, color: AppColors.inkSoft),
                        ],
                      ),
                    ),
                  ),

              const SectionTitle('Access log'),
              if (report.accessLog.isEmpty)
                Text('No one has viewed this evidence yet.', style: AppTypography.bodySoft(fontSize: 12))
              else
                for (final entry in report.accessLog)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(entry.who, style: AppTypography.bodySoft(fontSize: 11))),
                        Text(_formatDate(entry.when), style: AppTypography.mono(fontSize: 10)),
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
