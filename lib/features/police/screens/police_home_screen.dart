import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/sos_alert_model.dart';
import '../../../models/report_model.dart';
import '../../../models/notification_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../data/police_repository.dart';
import '../../resident/data/notification_repository.dart';
import '../../auth/data/auth_repository.dart';
import 'police_alerts_screen.dart';
import 'police_reports_screen.dart';
import 'police_notifications_screen.dart';

/// Police landing screen — mirrors TanodHomeScreen's layout exactly
/// (SOS card + reports card + notification bell), but every count here is
/// scoped to "assigned to me" rather than "everything open" — see
/// PoliceRepository's doc comment for why.
class PoliceHomeScreen extends StatefulWidget {
  const PoliceHomeScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<PoliceHomeScreen> createState() => _PoliceHomeScreenState();
}

class _PoliceHomeScreenState extends State<PoliceHomeScreen> {
  final _repository = PoliceRepository();
  final _notificationRepository = NotificationRepository();
  final _authRepository = AuthRepository();
  late final Stream<List<SosAlertModel>> _alertsStream = _repository.streamMyAlerts(widget.user.uid);
  late final Stream<List<ReportModel>> _reportsStream = _repository.streamMyReports(widget.user.uid);
  late final Stream<List<NotificationModel>> _notificationsStream =
      _notificationRepository.streamForUser(widget.user.uid);

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text('Bantay Nuevo'),
          ],
        ),
        actions: [
          StreamBuilder<List<NotificationModel>>(
            stream: _notificationsStream,
            builder: (context, snapshot) {
              final unread = (snapshot.data ?? []).where((n) => !n.read).length;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none, size: 22),
                    tooltip: 'Notifications',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PoliceNotificationsScreen(user: user)),
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: AppColors.urgent, shape: BoxShape.circle),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Log out',
            onPressed: _authRepository.logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.tealLight,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: AppTypography.display(fontSize: 15, color: AppColors.teal),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hi, ${user.name}', style: AppTypography.display(fontSize: 16)),
                      Text('Police Responder · ${user.barangay}', style: AppTypography.bodySoft(fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          StreamBuilder<List<SosAlertModel>>(
            stream: _alertsStream,
            builder: (context, snapshot) {
              final alerts = snapshot.data ?? [];
              final active = alerts.where((a) => a.status == SosStatus.responded || a.status == SosStatus.arrived).length;

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PoliceAlertsScreen(user: user)),
                ),
                child: AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: active > 0 ? AppColors.urgentLight : AppColors.tealLight,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: active > 0 ? AppColors.urgent : AppColors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Assigned SOS alerts', style: AppTypography.display(fontSize: 14)),
                            Text(
                              active > 0 ? '$active you\'re currently handling' : 'Nothing assigned to you right now',
                              style: AppTypography.bodySoft(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.inkSoft),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 10),
          StreamBuilder<List<ReportModel>>(
            stream: _reportsStream,
            builder: (context, snapshot) {
              final reports = snapshot.data ?? [];
              final pendingCount = reports.where((r) => r.status != ReportStatus.resolved).length;

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PoliceReportsScreen(user: user)),
                ),
                child: AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: pendingCount > 0 ? AppColors.amberLight : AppColors.tealLight,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.assignment_outlined,
                          color: pendingCount > 0 ? AppColors.amber : AppColors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Assigned reports', style: AppTypography.display(fontSize: 14)),
                            Text(
                              '${reports.length} total${pendingCount > 0 ? ' · $pendingCount open' : ''}',
                              style: AppTypography.bodySoft(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.inkSoft),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
