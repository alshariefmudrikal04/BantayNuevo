import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../../models/user_model.dart';
import '../../../models/report_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/live_map.dart';
import '../../../core/widgets/photo_viewer_screen.dart';
import '../data/police_repository.dart';

/// Mirrors TanodReportReviewScreen. Simpler than the tanod version in one
/// respect — since PoliceReportsScreen only ever lists reports already
/// assigned to this officer (see PoliceRepository), there's no "assign to
/// me" step here; status updates are always available.
class PoliceReportReviewScreen extends StatefulWidget {
  const PoliceReportReviewScreen({super.key, required this.reportId, required this.user});

  final String reportId;
  final UserModel user;

  @override
  State<PoliceReportReviewScreen> createState() => _PoliceReportReviewScreenState();
}

class _PoliceReportReviewScreenState extends State<PoliceReportReviewScreen> {
  final _repository = PoliceRepository();
  late final Stream<ReportModel> _reportStream = _repository.streamReport(widget.reportId);

  final Map<String, Future<String?>> _nameFutures = {};
  Future<String?> _userNameFuture(String uid) {
    return _nameFutures.putIfAbsent(uid, () => _repository.fetchUserName(uid));
  }

  bool _updatingStatus = false;
  bool _loggedAccess = false;

  void _logAccessOnce() {
    if (_loggedAccess) return;
    _loggedAccess = true;
    _repository.appendAccessLog(widget.reportId, '${widget.user.name} (Police)');
  }

  AppStatus _toAppStatus(ReportStatus s) => switch (s) {
        ReportStatus.pending => AppStatus.pending,
        ReportStatus.inProgress => AppStatus.progress,
        ReportStatus.resolved => AppStatus.resolved,
      };

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

  Future<void> _openFile(BuildContext context, EvidenceFile file) async {
    if (file.url.isEmpty) {
      _showSnack("This file doesn't have a valid link.", isError: true);
      return;
    }
    if (file.type == 'photo') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhotoViewerScreen(url: file.url, title: file.name)));
      return;
    }
    final uri = Uri.parse(file.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Could not open this file.', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? AppColors.urgent : AppColors.navyDeep),
    );
  }

  Future<void> _setStatus(ReportModel report, ReportStatus status) async {
    setState(() => _updatingStatus = true);
    try {
      await _repository.updateStatus(
        widget.reportId,
        status,
        residentId: report.residentId,
        policeName: widget.user.name,
      );
    } catch (e) {
      _showSnack('Could not update status: $e', isError: true);
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _openAddUpdateSheet(ReportModel report) async {
    final result = await showModalBottomSheet<_CaseUpdateDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddCaseUpdateSheet(isResolved: report.status == ReportStatus.resolved),
    );
    if (result == null || result.note.trim().isEmpty) return;

    setState(() => _updatingStatus = true);
    try {
      await _repository.addCaseUpdate(
        reportId: widget.reportId,
        authorName: widget.user.name,
        authorRole: 'Police',
        note: result.note.trim(),
        evidence: result.evidence,
        residentId: report.residentId,
      );
    } catch (e) {
      _showSnack('Could not add update: $e', isError: true);
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Report review')),
      body: StreamBuilder<ReportModel>(
        stream: _reportStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) return const Center(child: Text('Report not found.'));
          final report = snapshot.data!;
          _logAccessOnce();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(report.type, style: AppTypography.display(fontSize: 16))),
                  StatusBadge(status: _toAppStatus(report.status)),
                ],
              ),
              const SizedBox(height: 4),
              FutureBuilder<String?>(
                future: _userNameFuture(report.residentId),
                builder: (context, nameSnap) => Text(
                  'Filed by ${nameSnap.data ?? 'Resident'} · ${_formatDate(report.createdAt)}',
                  style: AppTypography.mono(fontSize: 10.5),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(20)),
                child: Text('Escalated to Police', style: AppTypography.mono(fontSize: 9.5, color: AppColors.teal)),
              ),
              const SizedBox(height: 14),

              const SectionTitle('Description'),
              AppCard(child: Text(report.description, style: AppTypography.body(fontSize: 12.5))),

              const SectionTitle('Location'),
              if (report.lat != null && report.lng != null)
                SizedBox(
                  height: 180,
                  child: LiveMap(selfLat: report.lat!, selfLng: report.lng!, selfLabel: report.locationAddress ?? 'Incident location'),
                )
              else
                AppCard(child: Text('No location attached to this report.', style: AppTypography.bodySoft(fontSize: 12))),
              if (report.locationAddress != null) ...[
                const SizedBox(height: 6),
                Text(report.locationAddress!, style: AppTypography.bodySoft(fontSize: 11)),
              ],

              const SectionTitle('Status'),
              Row(
                children: [
                  for (final status in ReportStatus.values) ...[
                    Expanded(
                      child: _StatusChoiceButton(
                        label: status.displayLabel,
                        selected: report.status == status,
                        color: status == ReportStatus.resolved
                            ? AppColors.resolvedFg
                            : status == ReportStatus.inProgress
                                ? AppColors.teal
                                : AppColors.amber,
                        enabled: !_updatingStatus,
                        onTap: () => _setStatus(report, status),
                      ),
                    ),
                    if (status != ReportStatus.values.last) const SizedBox(width: 8),
                  ],
                ],
              ),

              const SectionTitle('Case log'),
              Text(
                'Document site visits, progress updates, and — once resolved — what was actually agreed.',
                style: AppTypography.bodySoft(fontSize: 11),
              ),
              const SizedBox(height: 8),
              if (report.caseUpdates.isEmpty)
                Text('No updates logged yet.', style: AppTypography.bodySoft(fontSize: 12))
              else
                for (final update in report.caseUpdates.reversed)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${update.authorName} · ${update.authorRole}',
                                style: AppTypography.body(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(_formatDate(update.when), style: AppTypography.mono(fontSize: 9.5, color: AppColors.inkSoft)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(update.note, style: AppTypography.body(fontSize: 12.5)),
                        if (update.evidenceFiles.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          for (final file in update.evidenceFiles)
                            InkWell(
                              onTap: () => _openFile(context, file),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Icon(_iconFor(file.type), size: 14, color: AppColors.teal),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(file.name, style: AppTypography.mono(fontSize: 10.5, color: AppColors.teal), overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
              const SizedBox(height: 4),
              AppButton(label: '＋ Add update', variant: AppButtonVariant.outline, onPressed: () => _openAddUpdateSheet(report)),
              const SizedBox(height: 8),

              const SectionTitle('Evidence'),
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
                        "downloaded or deleted from the app — this preserves the evidence chain for court/legal "
                        "purposes. Your name and the time you opened this were just logged below.",
                        style: AppTypography.bodySoft(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (report.evidenceFiles.isEmpty)
                Text('No evidence uploaded for this report yet.', style: AppTypography.bodySoft(fontSize: 12))
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
                            decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(8)),
                            child: Icon(_iconFor(file.type), size: 18, color: AppColors.teal),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(file.name, style: AppTypography.body(fontSize: 12), overflow: TextOverflow.ellipsis),
                                Text('${file.type} · uploaded ${_formatDate(file.uploadedAt)}', style: AppTypography.mono(fontSize: 10)),
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
    );
  }
}

/// What _AddCaseUpdateSheet hands back on submit.
class _CaseUpdateDraft {
  const _CaseUpdateDraft({required this.note, required this.evidence});
  final String note;
  final List<({String type, Uint8List bytes, String name})> evidence;
}

/// Mirrors the tanod version of this same composer — see
/// tanod_report_review_screen.dart's copy for the full doc comment.
class _AddCaseUpdateSheet extends StatefulWidget {
  const _AddCaseUpdateSheet({required this.isResolved});

  final bool isResolved;

  @override
  State<_AddCaseUpdateSheet> createState() => _AddCaseUpdateSheetState();
}

class _AddCaseUpdateSheetState extends State<_AddCaseUpdateSheet> {
  final _noteController = TextEditingController();
  final List<({String type, Uint8List bytes, String name})> _evidence = [];
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _evidence.add((type: 'photo', bytes: bytes, name: file.name)));
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx'], withData: true);
    final picked = result?.files.single;
    final bytes = picked?.bytes;
    if (picked == null || bytes == null) return;
    if (mounted) setState(() => _evidence.add((type: 'document', bytes: bytes, name: picked.name)));
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio, withData: true);
    final picked = result?.files.single;
    final bytes = picked?.bytes;
    if (picked == null || bytes == null) return;
    if (mounted) setState(() => _evidence.add((type: 'audio', bytes: bytes, name: picked.name)));
  }

  void _submit() {
    if (_noteController.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    Navigator.of(context).pop(_CaseUpdateDraft(note: _noteController.text, evidence: _evidence));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.isResolved ? 'Document the resolution' : 'Add a case update',
                style: AppTypography.display(fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isResolved
                    ? 'What was agreed? How was this settled? Attach any signed agreement or supporting evidence.'
                    : 'What happened? e.g. site visit notes, who you spoke with, next steps.',
                style: AppTypography.bodySoft(fontSize: 11.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.isResolved ? 'e.g. Both parties agreed to...' : 'e.g. Visited the location at 3pm, spoke with...',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: AppButton(label: '＋ Photo', variant: AppButtonVariant.outline, onPressed: _pickPhoto)),
                  const SizedBox(width: 8),
                  Expanded(child: AppButton(label: '＋ Document', variant: AppButtonVariant.outline, onPressed: _pickDocument)),
                  const SizedBox(width: 8),
                  Expanded(child: AppButton(label: '＋ Audio', variant: AppButtonVariant.outline, onPressed: _pickAudio)),
                ],
              ),
              if (_evidence.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (int i = 0; i < _evidence.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          switch (_evidence[i].type) {
                            'photo' => Icons.image_outlined,
                            'audio' => Icons.mic_none_outlined,
                            _ => Icons.description_outlined,
                          },
                          size: 16,
                          color: AppColors.inkSoft,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_evidence[i].name, style: AppTypography.body(fontSize: 11.5), overflow: TextOverflow.ellipsis)),
                        IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _evidence.removeAt(i))),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              AppButton(label: _submitting ? 'Adding...' : 'Add update', onPressed: _submitting ? null : _submit),
              const SizedBox(height: 8),
              AppButton(label: 'Cancel', variant: AppButtonVariant.ghost, onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChoiceButton extends StatelessWidget {
  const _StatusChoiceButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : AppColors.panel,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? color : AppColors.line),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.mono(fontSize: 10, color: enabled ? (selected ? color : AppColors.inkSoft) : AppColors.line),
        ),
      ),
    );
  }
}
