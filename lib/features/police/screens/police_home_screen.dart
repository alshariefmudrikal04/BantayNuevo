import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/sos_alert_model.dart';
import '../../../models/report_model.dart';
import '../../../models/notification_model.dart';
import '../../../core/theme/lux_theme.dart';
import '../data/police_repository.dart';
import '../../resident/data/notification_repository.dart';
import '../../auth/data/auth_repository.dart';
import 'police_alerts_screen.dart';
import 'police_reports_screen.dart';
import 'police_notifications_screen.dart';

/// Police landing screen — reskinned to match the resident side's
/// "luxury minimal" look (see lux_theme.dart's doc comment on the staged
/// rollout: resident first, then tanod/police/admin). All business logic
/// (streams, counts) is unchanged from before — presentation-only rewrite.
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
      backgroundColor: LuxColors.bg,
      appBar: AppBar(
        backgroundColor: LuxColors.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          StreamBuilder<List<NotificationModel>>(
            stream: _notificationsStream,
            builder: (context, snapshot) {
              final unread = (snapshot.data ?? []).where((n) => !n.read).length;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none, size: 22, color: LuxColors.black),
                    tooltip: 'Notifications',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PoliceNotificationsScreen(user: user)),
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: LuxColors.red, shape: BoxShape.circle)),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20, color: LuxColors.black),
            tooltip: 'Log out',
            onPressed: _authRepository.logout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('WELCOME BACK,', style: LuxType.eyebrow(fontSize: 11)),
          const SizedBox(height: 2),
          Text(user.name.trim().isEmpty ? 'OFFICER' : user.name.trim().split(' ').first.toUpperCase(), style: LuxType.hero(fontSize: 36)),
          const SizedBox(height: 2),
          Text('POLICE RESPONDER · ${user.barangay.toUpperCase()}', style: LuxType.eyebrow(fontSize: 10, color: LuxColors.inkSoft)),
          const SizedBox(height: 24),

          Text('ASSIGNED TO YOU', style: LuxType.eyebrow(fontSize: 10.5)),
          const SizedBox(height: 10),
          StreamBuilder<List<SosAlertModel>>(
            stream: _alertsStream,
            builder: (context, snapshot) {
              final alerts = snapshot.data ?? [];
              final active = alerts.where((a) => a.status == SosStatus.responded || a.status == SosStatus.arrived).length;

              return Material(
                color: active > 0 ? LuxColors.red : LuxColors.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PoliceAlertsScreen(user: user))),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: active > 0 ? null : Border.all(color: LuxColors.divider)),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 28, color: active > 0 ? Colors.white : LuxColors.red),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SOS ALERTS', style: LuxType.eyebrow(fontSize: 10, color: active > 0 ? Colors.white70 : LuxColors.inkSoft)),
                              const SizedBox(height: 2),
                              Text(
                                active > 0 ? '$active active' : 'Nothing assigned',
                                style: LuxType.hero(fontSize: 20, color: active > 0 ? Colors.white : LuxColors.ink),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: active > 0 ? Colors.white : LuxColors.inkSoft),
                      ],
                    ),
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

              return Material(
                color: LuxColors.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PoliceReportsScreen(user: user))),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(color: LuxColors.surfaceMuted, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Icon(Icons.assignment_outlined, size: 19, color: LuxColors.red),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Assigned reports', style: LuxType.heading(fontSize: 14)),
                              Text(
                                '${reports.length} total${pendingCount > 0 ? ' · $pendingCount open' : ''}',
                                style: LuxType.body(fontSize: 11, color: LuxColors.inkSoft),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 18, color: LuxColors.inkSoft),
                      ],
                    ),
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
