import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../../models/user_model.dart';
import '../../../models/report_model.dart';
import '../../../core/theme/lux_theme.dart';
import '../../../core/widgets/live_map.dart';
import '../../../core/widgets/photo_viewer_screen.dart';
import '../data/police_repository.dart';

/// Mirrors TanodReportReviewScreen — status updates are always available
/// here (no "assign to me" gate). Reskinned to match the resident side's
/// look, with the status section rebuilt as a proper stepper (see
/// _StatusStepper) instead of 3 identical buttons, so pending/in-progress/
/// resolved actually read as different stages of one progression rather
/// than a flat multiple-choice.
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
      SnackBar(content: Text(message), backgroundColor: isError ? LuxColors.red : LuxColors.black),
    );
  }

  Future<void> _setStatus(ReportModel report, ReportStatus status) async {
    setState(() => _updatingStatus = true);
    try {
      await _repository.updateStatus(widget.reportId, status, residentId: report.residentId, policeName: widget.user.name);
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
      backgroundColor: LuxColors.bg,
      appBar: AppBar(
        backgroundColor: LuxColors.bg,
        elevation: 0,
        title: Text('REPORT REVIEW', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.ink)),
      ),
      body: StreamBuilder<ReportModel>(
        stream: _reportStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) return Center(child: Text('Report not found.', style: LuxType.body(fontSize: 13)));
          final report = snapshot.data!;
          _logAccessOnce();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(report.type, style: LuxType.hero(fontSize: 22)),
              const SizedBox(height: 4),
              FutureBuilder<String?>(
                future: _userNameFuture(report.residentId),
                builder: (context, nameSnap) => Text(
                  'Filed by ${nameSnap.data ?? 'Resident'} · ${_formatDate(report.createdAt)}',
                  style: LuxType.eyebrow(fontSize: 9.5, color: LuxColors.inkSoft, letterSpacing: 0.2),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: LuxColors.surfaceMuted, borderRadius: BorderRadius.circular(20)),
                child: Text('ESCALATED TO POLICE', style: LuxType.eyebrow(fontSize: 9, color: LuxColors.red, letterSpacing: 0.4)),
              ),
              const SizedBox(height: 20),

              Text('STATUS', style: LuxType.eyebrow(fontSize: 10.5)),
              const SizedBox(height: 10),
              _StatusStepper(current: report.status, enabled: !_updatingStatus, onSelect: (s) => _setStatus(report, s)),
              const SizedBox(height: 24),

              Text('DESCRIPTION', style: LuxType.eyebrow(fontSize: 10.5)),
              const SizedBox(height: 8),
              _Section(child: Text(report.description, style: LuxType.body(fontSize: 12.5))),
              const SizedBox(height: 20),

              Text('LOCATION', style: LuxType.eyebrow(fontSize: 10.5)),
              const SizedBox(height: 8),
              if (report.lat != null && report.lng != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(height: 160, child: LiveMap(selfLat: report.lat!, selfLng: report.lng!, selfLabel: report.locationAddress ?? 'Incident location')),
                )
              else
                _Section(child: Text('No location attached to this report.', style: LuxType.body(fontSize: 12, color: LuxColors.inkSoft))),
              if (report.locationAddress != null) ...[
                const SizedBox(height: 6),
                Text(report.locationAddress!, style: LuxType.body(fontSize: 11, color: LuxColors.inkSoft)),
              ],
              const SizedBox(height: 24),

              Text('CASE LOG', style: LuxType.eyebrow(fontSize: 10.5)),
              const SizedBox(height: 4),
              Text('Document site visits, progress updates, and — once resolved — what was actually agreed.', style: LuxType.body(fontSize: 11, color: LuxColors.inkSoft)),
              const SizedBox(height: 10),
              if (report.caseUpdates.isEmpty)
                Text('No updates logged yet.', style: LuxType.body(fontSize: 12, color: LuxColors.inkSoft))
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
                                    Expanded(child: Text(file.name, style: LuxType.eyebrow(fontSize: 10, color: LuxColors.red, letterSpacing: 0.2), overflow: TextOverflow.ellipsis)),
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
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _openAddUpdateSheet(report),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: LuxColors.divider)),
                    child: Text('＋ ADD UPDATE', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.ink, letterSpacing: 0.5)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text('EVIDENCE', style: LuxType.eyebrow(fontSize: 10.5)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: LuxColors.black, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline, size: 16, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Files are encrypted and locked to this case. You can view them, but they can't be downloaded "
                        "or deleted — this preserves the evidence chain for court/legal purposes. Your name and the "
                        "time you opened this were just logged below.",
                        style: LuxType.body(fontSize: 11, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (report.evidenceFiles.isEmpty)
                Text('No evidence uploaded for this report yet.', style: LuxType.body(fontSize: 12, color: LuxColors.inkSoft))
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
                            decoration: i == report.evidenceFiles.length - 1 ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.divider))),
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
                                      Text('${report.evidenceFiles[i].type} · uploaded ${_formatDate(report.evidenceFiles[i].uploadedAt)}', style: LuxType.eyebrow(fontSize: 9, color: LuxColors.inkSoft, letterSpacing: 0.2)),
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
              const SizedBox(height: 24),

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
                          decoration: i == report.accessLog.length - 1 ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.divider))),
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

/// A real 3-stage progress stepper instead of 3 identical buttons — each
/// stage gets its own icon and framing, not just a different color:
///   PENDING     — outline circle, clock icon, "Not yet started"
///   IN PROGRESS — solid black circle, in-motion icon, "Being handled"
///   RESOLVED    — solid green circle, check icon, "Closed"
/// Stages before the current one show filled/checked (completed); the
/// current stage is bold/highlighted; stages after are dim/outlined
/// (not yet reached). Any stage remains tappable — police can move a
/// report backward (e.g. accidentally marked resolved) as well as forward.
class _StatusStepper extends StatelessWidget {
  const _StatusStepper({required this.current, required this.enabled, required this.onSelect});

  final ReportStatus current;
  final bool enabled;
  final ValueChanged<ReportStatus> onSelect;

  static const _stages = [
    (ReportStatus.pending, Icons.schedule, 'PENDING', 'Not yet started'),
    (ReportStatus.inProgress, Icons.directions_run, 'IN PROGRESS', 'Being handled'),
    (ReportStatus.resolved, Icons.check_circle, 'RESOLVED', 'Closed'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _stages.indexWhere((s) => s.$1 == current);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _stages.length; i++) ...[
          Expanded(
            child: _StepperNode(
              icon: _stages[i].$2,
              label: _stages[i].$3,
              description: _stages[i].$4,
              isCompleted: i < currentIndex,
              isCurrent: i == currentIndex,
              onTap: enabled ? () => onSelect(_stages[i].$1) : null,
            ),
          ),
          if (i != _stages.length - 1)
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Container(width: 16, height: 2, color: i < currentIndex ? LuxColors.black : LuxColors.divider),
            ),
        ],
      ],
    );
  }
}

class _StepperNode extends StatelessWidget {
  const _StepperNode({
    required this.icon,
    required this.label,
    required this.description,
    required this.isCompleted,
    required this.isCurrent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool isCompleted;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDone = isCompleted || isCurrent;
    final Color fill = isCurrent
        ? (label == 'RESOLVED' ? LuxColors.success : LuxColors.black)
        : (isCompleted ? LuxColors.black : Colors.transparent);
    final Color fg = isDone ? Colors.white : LuxColors.inkSoft;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                border: isDone ? null : Border.all(color: LuxColors.divider, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 15, color: fg),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: LuxType.eyebrow(fontSize: 8.5, color: isCurrent ? LuxColors.ink : LuxColors.inkSoft, letterSpacing: 0.2)),
            if (isCurrent) ...[
              const SizedBox(height: 2),
              Text(description, textAlign: TextAlign.center, style: LuxType.body(fontSize: 9, color: LuxColors.inkSoft)),
            ],
          ],
        ),
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
        decoration: const BoxDecoration(color: LuxColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.isResolved ? 'DOCUMENT THE RESOLUTION' : 'ADD A CASE UPDATE', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.ink)),
              const SizedBox(height: 6),
              Text(
                widget.isResolved
                    ? 'What was agreed? How was this settled? Attach any signed agreement or supporting evidence.'
                    : 'What happened? e.g. site visit notes, who you spoke with, next steps.',
                style: LuxType.body(fontSize: 11.5, color: LuxColors.inkSoft),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: LuxColors.divider)),
                child: TextField(
                  controller: _noteController,
                  maxLines: 4,
                  autofocus: true,
                  style: LuxType.body(fontSize: 13),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                    hintText: widget.isResolved ? 'e.g. Both parties agreed to...' : 'e.g. Visited the location at 3pm, spoke with...',
                    hintStyle: LuxType.body(fontSize: 12, color: LuxColors.inkSoft),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _PickButton(label: 'Photo', onTap: _pickPhoto)),
                  const SizedBox(width: 8),
                  Expanded(child: _PickButton(label: 'Document', onTap: _pickDocument)),
                  const SizedBox(width: 8),
                  Expanded(child: _PickButton(label: 'Audio', onTap: _pickAudio)),
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
                          color: LuxColors.inkSoft,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_evidence[i].name, style: LuxType.body(fontSize: 11.5), overflow: TextOverflow.ellipsis)),
                        IconButton(icon: const Icon(Icons.close, size: 16, color: LuxColors.inkSoft), onPressed: () => setState(() => _evidence.removeAt(i))),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Material(
                color: LuxColors.red,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _submitting ? null : _submit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    alignment: Alignment.center,
                    child: Text(_submitting ? 'ADDING...' : 'ADD UPDATE', style: LuxType.eyebrow(fontSize: 11.5, color: Colors.white, letterSpacing: 0.5)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('CANCEL', style: LuxType.eyebrow(fontSize: 10.5, color: LuxColors.inkSoft))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: LuxColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: LuxColors.divider)),
          alignment: Alignment.center,
          child: Text('＋ $label', style: LuxType.eyebrow(fontSize: 9.5, letterSpacing: 0.2)),
        ),
      ),
    );
  }
}
