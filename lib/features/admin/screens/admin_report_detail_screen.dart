import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/live_map.dart';
import '../../../core/widgets/photo_viewer_screen.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/report_model.dart';
import '../../../models/user_model.dart';
import '../data/admin_repository.dart';

/// Admin's view of a single incident report — unlike tanod_report_review_screen,
/// an admin can always reassign or change status (not gated on "am I the
/// assigned tanod"), since overseeing/reassigning is the whole point of
/// this dashboard.
class AdminReportDetailScreen extends StatefulWidget {
  const AdminReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  State<AdminReportDetailScreen> createState() => _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<AdminReportDetailScreen> {
  final _repository = AdminRepository();
  late final Stream<ReportModel> _reportStream = _repository.streamReport(widget.reportId);

  final Map<String, Future<String?>> _nameFutures = {};
  Future<String?> _nameFor(String uid) => _nameFutures.putIfAbsent(uid, () => _repository.fetchUserName(uid));

  bool _busy = false;

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

  Future<void> _openFile(EvidenceFile file) async {
    if (file.url.isEmpty) return _showSnack("This file doesn't have a valid link.", isError: true);
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
    setState(() => _busy = true);
    try {
      await _repository.updateReportStatus(widget.reportId, status, residentId: report.residentId);
    } catch (e) {
      _showSnack('Could not update status: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assignResponder(ReportModel report) async {
    final result = await showDialog<({UserModel user, UserRole role})>(
      context: context,
      builder: (_) => _ResponderPickerDialog(repository: _repository),
    );
    if (result == null) return;

    setState(() => _busy = true);
    try {
      await _repository.assignReportResponder(
        widget.reportId,
        responderId: result.user.uid,
        responderName: result.user.name,
        responderRole: result.role,
        residentId: report.residentId,
      );
    } catch (e) {
      _showSnack('Could not assign: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Incident report')),
      body: StreamBuilder<ReportModel>(
        stream: _reportStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final report = snapshot.data!;

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
                future: _nameFor(report.residentId),
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
                  child: LiveMap(selfLat: report.lat!, selfLng: report.lng!, selfLabel: report.locationAddress ?? 'Incident location'),
                )
              else
                AppCard(child: Text('No location attached to this report.', style: AppTypography.bodySoft(fontSize: 12))),

              const SectionTitle('Assignment'),
              if (report.assignedTanodId != null)
                FutureBuilder<String?>(
                  future: _nameFor(report.assignedTanodId!),
                  builder: (context, nameSnap) => AppCard(
                    child: Row(
                      children: [
                        Expanded(child: Text('Assigned to ${nameSnap.data ?? 'a responder'}', style: AppTypography.body(fontSize: 12.5))),
                        TextButton(onPressed: _busy ? null : () => _assignResponder(report), child: const Text('Reassign')),
                      ],
                    ),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _assignResponder(report),
                  icon: const Icon(Icons.person_add_alt, size: 16),
                  label: const Text('Assign a tanod or police responder'),
                ),

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
                        enabled: !_busy,
                        onTap: () => _setStatus(report, status),
                      ),
                    ),
                    if (status != ReportStatus.values.last) const SizedBox(width: 8),
                  ],
                ],
              ),

              const SectionTitle('Evidence'),
              if (report.evidenceFiles.isEmpty)
                Text('No evidence uploaded for this report yet.', style: AppTypography.bodySoft(fontSize: 12))
              else
                for (final file in report.evidenceFiles)
                  InkWell(
                    onTap: () => _openFile(file),
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

/// Modal for picking any tanod/police account to assign — the admin-only
/// counterpart to tanod_report_review_screen's "assign to me" button, which
/// only ever assigns the currently signed-in tanod.
class _ResponderPickerDialog extends StatelessWidget {
  const _ResponderPickerDialog({required this.repository});

  final AdminRepository repository;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign a responder'),
      content: SizedBox(
        width: 360,
        height: 400,
        child: StreamBuilder<List<UserModel>>(
          stream: repository.streamAllUsers(),
          builder: (context, snapshot) {
            final responders = (snapshot.data ?? [])
                .where((u) => (u.role == UserRole.tanod || u.role == UserRole.police) && u.active)
                .toList();
            if (responders.isEmpty) {
              return const Center(child: Text('No active tanod or police accounts yet.'));
            }
            return ListView(
              children: [
                for (final responder in responders)
                  ListTile(
                    leading: CircleAvatar(child: Text(responder.name.isNotEmpty ? responder.name[0].toUpperCase() : '?')),
                    title: Text(responder.name),
                    subtitle: Text(responder.role.displayLabel),
                    onTap: () => Navigator.of(context).pop((user: responder, role: responder.role)),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
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
