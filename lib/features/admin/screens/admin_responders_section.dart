import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../models/sos_alert_model.dart';
import '../../../models/user_model.dart';
import '../data/admin_repository.dart';

/// Responder Management — tanod and police accounts, each shown with
/// whether they're currently tied up on an active/responding SOS alert
/// (cross-referenced live against sos_alerts) or free to be assigned.
/// Actual assignment happens from an incident's own detail screen
/// (AdminReportDetailScreen / AdminSosDetailScreen) — this section is the
/// "who's available right now" overview.
class AdminRespondersSection extends StatelessWidget {
  const AdminRespondersSection({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = AdminRepository();

    return StreamBuilder<List<UserModel>>(
      stream: repository.streamAllUsers(),
      builder: (context, userSnap) {
        return StreamBuilder<List<SosAlertModel>>(
          stream: repository.streamAllSosAlerts(),
          builder: (context, alertSnap) {
            final users = userSnap.data ?? [];
            final alerts = alertSnap.data ?? [];

            final busyIds = alerts
                .where((a) => a.status == SosStatus.responded || a.status == SosStatus.arrived)
                .map((a) => a.responderId)
                .whereType<String>()
                .toSet();

            final tanods = users.where((u) => u.role == UserRole.tanod).toList();
            final police = users.where((u) => u.role == UserRole.police).toList();

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Text('Barangay Tanod', style: AppTypography.display(fontSize: 16)),
                const SizedBox(height: 8),
                if (tanods.isEmpty)
                  Text('No tanod accounts yet.', style: AppTypography.bodySoft(fontSize: 12))
                else
                  for (final u in tanods) _ResponderRow(user: u, busy: busyIds.contains(u.uid)),
                const SizedBox(height: 24),
                Text('Police Responders', style: AppTypography.display(fontSize: 16)),
                const SizedBox(height: 8),
                if (police.isEmpty)
                  Text('No police accounts yet.', style: AppTypography.bodySoft(fontSize: 12))
                else
                  for (final u in police) _ResponderRow(user: u, busy: busyIds.contains(u.uid)),
              ],
            );
          },
        );
      },
    );
  }
}

class _ResponderRow extends StatelessWidget {
  const _ResponderRow({required this.user, required this.busy});

  final UserModel user;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final statusColor = !user.active ? AppColors.inkSoft : (busy ? AppColors.amber : AppColors.teal);
    final statusLabel = !user.active ? 'Deactivated' : (busy ? 'Responding to an alert' : 'Available');

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.tealLight,
            child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.teal)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(user.purok.isNotEmpty ? 'Purok ${user.purok}' : user.email, style: AppTypography.mono(fontSize: 10)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(statusLabel, style: AppTypography.mono(fontSize: 9.5, color: statusColor)),
          ),
        ],
      ),
    );
  }
}
