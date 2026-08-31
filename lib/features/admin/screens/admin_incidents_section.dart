import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/report_model.dart';
import '../../../models/sos_alert_model.dart';
import '../data/admin_repository.dart';
import 'admin_report_detail_screen.dart';
import 'admin_sos_detail_screen.dart';

/// Incident Management section — two tabs (Reports, SOS Alerts), each
/// filterable by status/type, each row opening a full detail screen where
/// an admin can view evidence, change status, and assign a responder.
class AdminIncidentsSection extends StatefulWidget {
  const AdminIncidentsSection({super.key});

  @override
  State<AdminIncidentsSection> createState() => _AdminIncidentsSectionState();
}

class _AdminIncidentsSectionState extends State<AdminIncidentsSection> with SingleTickerProviderStateMixin {
  final _repository = AdminRepository();
  late final TabController _tabController = TabController(length: 2, vsync: this);

  ReportStatus? _reportStatusFilter;
  SosStatus? _sosStatusFilter;
  EmergencyType? _typeFilter;

  final Map<String, Future<String?>> _nameFutures = {};
  Future<String?> _nameFor(String uid) => _nameFutures.putIfAbsent(uid, () => _repository.fetchUserName(uid));

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: AppColors.panel,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.teal,
            unselectedLabelColor: AppColors.inkSoft,
            indicatorColor: AppColors.teal,
            labelStyle: AppTypography.body(fontSize: 12.5, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Incident Reports'),
              Tab(text: 'SOS Alerts'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_reportsTab(), _sosTab()],
          ),
        ),
      ],
    );
  }

  Widget _reportsTab() {
    return StreamBuilder<List<ReportModel>>(
      stream: _repository.streamAllReports(),
      builder: (context, snapshot) {
        var reports = snapshot.data ?? [];
        if (_reportStatusFilter != null) {
          reports = reports.where((r) => r.status == _reportStatusFilter).toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  _filterChip('All', _reportStatusFilter == null, () => setState(() => _reportStatusFilter = null)),
                  for (final s in ReportStatus.values)
                    _filterChip(
                      s.displayLabel,
                      _reportStatusFilter == s,
                      () => setState(() => _reportStatusFilter = s),
                    ),
                ],
              ),
            ),
            Expanded(
              child: reports.isEmpty
                  ? Center(child: Text('No reports match this filter.', style: AppTypography.bodySoft(fontSize: 12)))
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        for (final report in reports)
                          InkWell(
                            borderRadius: BorderRadius.circular(11),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => AdminReportDetailScreen(reportId: report.id)),
                            ),
                            child: AppCard(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(report.type, style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        FutureBuilder<String?>(
                                          future: _nameFor(report.residentId),
                                          builder: (context, nameSnap) => Text(
                                            'Filed by ${nameSnap.data ?? 'Resident'}',
                                            style: AppTypography.mono(fontSize: 10),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusBadge(status: _toAppStatus(report.status)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right, size: 18, color: AppColors.inkSoft),
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
    );
  }

  Widget _sosTab() {
    return StreamBuilder<List<SosAlertModel>>(
      stream: _repository.streamAllSosAlerts(),
      builder: (context, snapshot) {
        var alerts = snapshot.data ?? [];
        if (_sosStatusFilter != null) {
          alerts = alerts.where((a) => a.status == _sosStatusFilter).toList();
        }
        if (_typeFilter != null) {
          alerts = alerts.where((a) => a.emergencyType == _typeFilter).toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      _filterChip('All statuses', _sosStatusFilter == null, () => setState(() => _sosStatusFilter = null)),
                      for (final s in SosStatus.values)
                        _filterChip(
                          s.value,
                          _sosStatusFilter == s,
                          () => setState(() => _sosStatusFilter = s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _filterChip('All types', _typeFilter == null, () => setState(() => _typeFilter = null)),
                      for (final t in EmergencyType.values)
                        _filterChip(t.label, _typeFilter == t, () => setState(() => _typeFilter = t)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: alerts.isEmpty
                  ? Center(child: Text('No SOS alerts match this filter.', style: AppTypography.bodySoft(fontSize: 12)))
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        for (final alert in alerts)
                          InkWell(
                            borderRadius: BorderRadius.circular(11),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => AdminSosDetailScreen(alertId: alert.id)),
                            ),
                            child: AppCard(
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: alert.status == SosStatus.active ? AppColors.urgentLight : AppColors.tealLight,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.warning_amber_rounded,
                                      size: 18,
                                      color: alert.status == SosStatus.active ? AppColors.urgent : AppColors.teal,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        FutureBuilder<String?>(
                                          future: _nameFor(alert.residentId),
                                          builder: (context, nameSnap) => Text(
                                            nameSnap.data ?? 'Resident',
                                            style: AppTypography.body(fontSize: 12.5, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        Text(
                                          '${alert.emergencyType.label} · ${alert.status.value}'
                                          '${alert.responderName != null ? ' · ${alert.responderName}' : ''}',
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
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  AppStatus _toAppStatus(ReportStatus s) => switch (s) {
        ReportStatus.pending => AppStatus.pending,
        ReportStatus.inProgress => AppStatus.progress,
        ReportStatus.resolved => AppStatus.resolved,
      };

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label, style: AppTypography.mono(fontSize: 10.5, color: selected ? Colors.white : AppColors.inkSoft)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.navy,
      backgroundColor: AppColors.panel,
      side: BorderSide(color: selected ? AppColors.navy : AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.pillRadius),
    );
  }
}
