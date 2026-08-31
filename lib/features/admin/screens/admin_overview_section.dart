import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../models/report_model.dart';
import '../../../models/sos_alert_model.dart';
import '../../../models/user_model.dart';
import '../data/admin_repository.dart';
import 'admin_home_screen.dart';

/// Landing section of the dashboard — at-a-glance counts across active
/// SOS, pending reports, and staff, each linking straight into the
/// relevant section. This is intentionally light: the actual live
/// incident map / full monitoring view is a later phase (see
/// AdminHomeScreen's doc comment).
class AdminOverviewSection extends StatelessWidget {
  const AdminOverviewSection({super.key, required this.onNavigate});

  final void Function(AdminSection) onNavigate;

  @override
  Widget build(BuildContext context) {
    final repository = AdminRepository();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: StreamBuilder<List<SosAlertModel>>(
        stream: repository.streamAllSosAlerts(),
        builder: (context, sosSnap) {
          return StreamBuilder<List<ReportModel>>(
            stream: repository.streamAllReports(),
            builder: (context, reportSnap) {
              return StreamBuilder<List<UserModel>>(
                stream: repository.streamAllUsers(),
                builder: (context, userSnap) {
                  return StreamBuilder<List<UserModel>>(
                    stream: repository.streamPendingVerifications(),
                    builder: (context, verificationSnap) {
                  final alerts = sosSnap.data ?? [];
                  final reports = reportSnap.data ?? [];
                  final users = userSnap.data ?? [];
                  final pendingVerifications = verificationSnap.data?.length ?? 0;

                  final activeAlerts = alerts.where((a) => a.status == SosStatus.active).length;
                  final respondingAlerts = alerts.where((a) => a.status == SosStatus.responded).length;
                  final pendingReports = reports.where((r) => r.status == ReportStatus.pending).length;
                  final tanodCount = users.where((u) => u.role == UserRole.tanod).length;
                  final policeCount = users.where((u) => u.role == UserRole.police).length;
                  final residentCount = users.where((u) => u.role == UserRole.resident).length;

                  return ListView(
                    children: [
                      Text('System overview', style: AppTypography.display(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text('Barangay Camino Nuevo · live counts', style: AppTypography.bodySoft(fontSize: 12.5)),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _StatCard(
                            label: 'Active SOS',
                            value: '$activeAlerts',
                            color: activeAlerts > 0 ? AppColors.urgent : AppColors.teal,
                            onTap: () => onNavigate(AdminSection.incidents),
                          ),
                          _StatCard(
                            label: 'Being responded to',
                            value: '$respondingAlerts',
                            color: AppColors.amber,
                            onTap: () => onNavigate(AdminSection.incidents),
                          ),
                          _StatCard(
                            label: 'Pending reports',
                            value: '$pendingReports',
                            color: pendingReports > 0 ? AppColors.amber : AppColors.teal,
                            onTap: () => onNavigate(AdminSection.incidents),
                          ),
                          _StatCard(
                            label: 'Tanod',
                            value: '$tanodCount',
                            color: AppColors.teal,
                            onTap: () => onNavigate(AdminSection.responders),
                          ),
                          _StatCard(
                            label: 'Police',
                            value: '$policeCount',
                            color: AppColors.teal,
                            onTap: () => onNavigate(AdminSection.responders),
                          ),
                          _StatCard(
                            label: 'Residents',
                            value: '$residentCount',
                            color: AppColors.navy,
                            onTap: () => onNavigate(AdminSection.users),
                          ),
                          _StatCard(
                            label: 'Pending verifications',
                            value: '$pendingVerifications',
                            color: pendingVerifications > 0 ? AppColors.amber : AppColors.teal,
                            onTap: () => onNavigate(AdminSection.verifications),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (activeAlerts > 0)
                        AppCard(
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.urgent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '$activeAlerts SOS alert${activeAlerts == 1 ? '' : 's'} waiting for a responder.',
                                  style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              TextButton(
                                onPressed: () => onNavigate(AdminSection.incidents),
                                child: const Text('Assign now'),
                              ),
                            ],
                          ),
                        ),
                      if (pendingVerifications > 0) ...[
                        const SizedBox(height: 12),
                        AppCard(
                          child: Row(
                            children: [
                              const Icon(Icons.fact_check_outlined, color: AppColors.amber),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '$pendingVerifications resident${pendingVerifications == 1 ? '' : 's'} waiting on ID verification.',
                                  style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              TextButton(
                                onPressed: () => onNavigate(AdminSection.verifications),
                                child: const Text('Review now'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color, required this.onTap});

  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppSpacing.cardRadius,
      onTap: onTap,
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: AppSpacing.cardRadius,
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTypography.display(fontSize: 28, color: color)),
            const SizedBox(height: 4),
            Text(label, style: AppTypography.bodySoft(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
