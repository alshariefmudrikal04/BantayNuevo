import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../../models/user_model.dart';
import '../../../models/report_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/live_map.dart';
import '../../../core/widgets/photo_viewer_screen.dart';
import '../data/tanod_report_repository.dart';
import '../services/report_pdf_generator.dart';

class TanodReportReviewScreen extends StatefulWidget {
  const TanodReportReviewScreen({super.key, required this.reportId, required this.user});

  final String reportId;
  final UserModel user;

  @override
  State<TanodReportReviewScreen> createState() => _TanodReportReviewScreenState();
}

class _TanodReportReviewScreenState extends State<TanodReportReviewScreen> {
  final _repository = TanodReportRepository();

  // Created once, same "don't recreate the stream in build()" fix used
  // everywhere else in this repo (AGENTS.md §8 bugfix note).
  //
  // asBroadcastStream() — this now needs two independent listeners: the
  // main StreamBuilder driving the body, and the small one below driving
  // the app bar's "Generate report" button (which needs to know the
  // latest report to hand off, without re-triggering a stream listen —
  // a plain Firestore snapshots() stream is single-subscription only and
  // would throw on a second listen()). Same fix tanod_sos_screen.dart
  // uses for its own two-listener situation.
  late final Stream<ReportModel> _reportStream = _repository.streamReport(widget.reportId).asBroadcastStream();

  // Cached per uid (works for both residentId and assignedTanodId lookups),
  // same pattern as tanod_sos_screen.dart — avoids refetching a name on
  // every stream tick.
  final Map<String, Future<String?>> _nameFutures = {};
  Future<String?> _userNameFuture(String uid) {
    return _nameFutures.putIfAbsent(uid, () => _repository.fetchUserName(uid));
  }

  bool _assigning = false;
  bool _updatingStatus = false;
  bool _generatingPdf = false;

  // Evidence access is logged once per screen visit, not once per stream
  // tick — guarded so re-renders from the report's own status/assignment
  // changes don't spam the accessLog.
  bool _loggedAccess = false;

  void _logAccessOnce() {
    if (_loggedAccess) return;
    _loggedAccess = true;
    _repository.appendAccessLog(widget.reportId, widget.user.name);
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

  /// Same viewing behavior as the resident's own evidence_vault_screen.dart
  /// — photos open in-app zoomable, everything else hands off to whatever
  /// app the device has for that file type. Still strictly view-only,
  /// nothing here downloads or deletes anything (AGENTS.md §8).
  Future<void> _openFile(BuildContext context, EvidenceFile file) async {
    if (file.url.isEmpty) {
      _showSnack("This file doesn't have a valid link.", isError: true);
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

  Future<void> _assignToMe(String residentId) async {
    setState(() => _assigning = true);
    try {
      await _repository.assignToTanod(
        widget.reportId,
        widget.user.uid,
        widget.user.name,
        residentId: residentId,
      );
    } catch (e) {
      _showSnack('Could not assign: $e', isError: true);
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  /// If the report is unassigned, assigning + setting status happens in
  /// the same tap (per Prompt 11's "your call on UX, keep it simple").
  Future<void> _setStatus(ReportModel report, ReportStatus status) async {
    setState(() => _updatingStatus = true);
    try {
      if (report.assignedTanodId == null) {
        await _repository.assignToTanod(
          widget.reportId,
          widget.user.uid,
          widget.user.name,
          residentId: report.residentId,
        );
      }
      await _repository.updateStatus(
        widget.reportId,
        status,
        residentId: report.residentId,
        tanodName: widget.user.name,
      );
    } catch (e) {
      _showSnack('Could not update status: $e', isError: true);
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  /// "Generate Reports" — thesis §3.2.1's Barangay Official functional
  /// requirement, previously unimplemented anywhere in the app. Builds a
  /// case-summary PDF (see ReportPdfGenerator's doc comment on exactly
  /// what it does and doesn't include) and hands it straight to the OS
  /// print/share/save-as-PDF sheet via `printing` — no file path or
  /// storage-permission handling needed on our end.
  Future<void> _generateReport(ReportModel report) async {
    setState(() => _generatingPdf = true);
    try {
      final residentName = await _userNameFuture(report.residentId) ?? 'Resident';
      final assignedName = report.assignedTanodId != null ? await _userNameFuture(report.assignedTanodId!) : null;
      final pdf = await ReportPdfGenerator.generate(
        report: report,
        residentName: residentName,
        assignedResponderName: assignedName,
        generatedByName: widget.user.name,
      );
      await Printing.layoutPdf(onLayout: (_) => pdf.save(), name: 'Incident Report - ${report.id}.pdf');
    } catch (e) {
      _showSnack('Could not generate report: $e', isError: true);
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  /// Opens the note+evidence composer for the report's case log — see
  /// _AddCaseUpdateSheet and CaseUpdate's doc comment on report_model.dart
  /// for what this is for (site-visit notes, general progress updates,
  /// and — once marking a report resolved — documenting what was actually
  /// agreed/settled).
  Future<void> _openAddUpdateSheet(ReportModel report) async {
    final result = await showModalBottomSheet<_CaseUpdateDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddCaseUpdateSheet(isResolved: report.status == ReportStatus.resolved),
    );
    if (result == null || result.note.trim().isEmpty) return;

    setState(() => _updatingStatus = true); // reuse the same "something's saving" flag for the button state
    try {
      await _repository.addCaseUpdate(
        reportId: widget.reportId,
        authorName: widget.user.name,
        authorRole: 'Tanod',
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
      appBar: AppBar(
        title: const Text('Report review'),
        actions: [
          StreamBuilder<ReportModel>(
            stream: _reportStream,
            builder: (context, snapshot) {
              final report = snapshot.data;
              return IconButton(
                icon: _generatingPdf
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Generate report',
                onPressed: _generatingPdf || report == null ? null : () => _generateReport(report),
              );
            },
          ),
        ],
      ),
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
          final iAmAssigned = report.assignedTanodId == widget.user.uid;
          final assignedToSomeoneElse = report.assignedTanodId != null && !iAmAssigned;
          final canUpdateStatus = report.assignedTanodId == null || iAmAssigned;

          // Fires once the report has actually loaded, i.e. once evidence
          // is genuinely visible on screen.
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
              const SizedBox(height: 14),

              const SectionTitle('Description'),
              AppCard(child: Text(report.description, style: AppTypography.body(fontSize: 12.5))),

              const SectionTitle('Location'),
              if (report.lat != null && report.lng != null)
                SizedBox(
                  height: 180,
                  child: LiveMap(
                    selfLat: report.lat!,
                    selfLng: report.lng!,
                    selfLabel: report.locationAddress ?? 'Incident location',
                  ),
                )
              else
                AppCard(child: Text('No location attached to this report.', style: AppTypography.bodySoft(fontSize: 12))),
              if (report.locationAddress != null) ...[
                const SizedBox(height: 6),
                Text(report.locationAddress!, style: AppTypography.bodySoft(fontSize: 11)),
              ],

              const SectionTitle('Assignment'),
              if (assignedToSomeoneElse)
                FutureBuilder<String?>(
                  future: _userNameFuture(report.assignedTanodId!),
                  builder: (context, nameSnap) => AppCard(
                    child: Text('Assigned to ${nameSnap.data ?? 'another tanod'}', style: AppTypography.body(fontSize: 12.5)),
                  ),
                )
              else if (iAmAssigned)
                AppCard(child: Text('Assigned to ${widget.user.name} (you)', style: AppTypography.body(fontSize: 12.5)))
              else
                AppButton(
                  label: _assigning ? 'Assigning...' : 'Assign to me',
                  onPressed: _assigning ? null : () => _assignToMe(report.residentId),
                ),

              const SectionTitle('Status'),
              Row(
                children: [
                  Expanded(
                    child: _StatusChoiceButton(
                      label: 'Pending',
                      selected: report.status == ReportStatus.pending,
                      color: AppColors.amber,
                      enabled: canUpdateStatus && !_updatingStatus,
                      onTap: () => _setStatus(report, ReportStatus.pending),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusChoiceButton(
                      label: 'In progress',
                      selected: report.status == ReportStatus.inProgress,
                      color: AppColors.teal,
                      enabled: canUpdateStatus && !_updatingStatus,
                      onTap: () => _setStatus(report, ReportStatus.inProgress),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusChoiceButton(
                      label: 'Resolved',
                      selected: report.status == ReportStatus.resolved,
                      color: AppColors.resolvedFg,
                      enabled: canUpdateStatus && !_updatingStatus,
                      onTap: () => _setStatus(report, ReportStatus.resolved),
                    ),
                  ),
                ],
              ),
              if (!canUpdateStatus) ...[
                const SizedBox(height: 6),
                Text(
                  'Only the assigned tanod can change this report\'s status.',
                  style: AppTypography.mono(fontSize: 10, color: AppColors.inkSoft),
                ),
              ],

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
              AppButton(
                label: '＋ Add update',
                variant: AppButtonVariant.outline,
                onPressed: canUpdateStatus ? () => _openAddUpdateSheet(report) : null,
              ),
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
                        "downloaded or deleted from the app — this preserves the evidence chain for the resident "
                        "and police. Your name and the time you opened this were just logged below.",
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
    );
  }
}

/// What _AddCaseUpdateSheet hands back on submit.
class _CaseUpdateDraft {
  const _CaseUpdateDraft({required this.note, required this.evidence});
  final String note;
  final List<({String type, Uint8List bytes, String name})> evidence;
}

/// Note + optional evidence composer for a case-log entry. Hint text
/// adapts to whether the report is currently marked resolved, per the
/// request this was built for: "if in progress... upload evidence and
/// info... same thing when resolved, what were the agreements" — same
/// composer either way, just different framing of what to write.
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
          style: AppTypography.mono(
            fontSize: 10,
            color: enabled ? (selected ? color : AppColors.inkSoft) : AppColors.line,
          ),
        ),
      ),
    );
  }
}
