import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/sos_alert_model.dart';
import '../../../models/report_model.dart';
import '../../../models/notification_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/services/alarm_sound_service.dart';
import '../data/tanod_sos_repository.dart';
import '../data/tanod_report_repository.dart';
import '../../resident/data/notification_repository.dart';
import '../../auth/data/auth_repository.dart';
import 'tanod_sos_screen.dart';
import 'tanod_dashboard_screen.dart';
import 'tanod_notifications_screen.dart';
import 'tanod_alert_detail_screen.dart';

/// Tanod landing screen — SOS alerts card + incident reports card, each
/// with a live count, plus the notifications bell. Built up across
/// Prompts 9–12.
///
/// This is also where the alarm sound + distress banner actually live now
/// (moved from tanod_sos_screen.dart — see that file's own comment on why):
/// Home is the one screen that stays alive the whole time a tanod has the
/// app open (SOS list, report review, etc. are all pushed ON TOP of it via
/// Navigator, never replacing it), so it's the only reliable place to
/// detect "a brand new SOS just came in" regardless of which screen the
/// tanod happens to be looking at.
class TanodHomeScreen extends StatefulWidget {
  const TanodHomeScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<TanodHomeScreen> createState() => _TanodHomeScreenState();
}

class _TanodHomeScreenState extends State<TanodHomeScreen> {
  final _repository = TanodSosRepository();
  final _reportRepository = TanodReportRepository();
  final _notificationRepository = NotificationRepository();
  final _authRepository = AuthRepository();

  // asBroadcastStream() — this now needs two independent listeners: the
  // StreamBuilder driving the SOS count card below, and _alarmSubscription
  // watching for brand-new alerts to sound/vibrate/banner for. A plain
  // Firestore stream is single-subscription only and would throw on the
  // second listen().
  late final Stream<List<SosAlertModel>> _alertsStream = _repository.streamOpenAlerts().asBroadcastStream();
  late final Stream<List<ReportModel>> _reportsStream = _reportRepository.streamAllReports();
  late final Stream<List<NotificationModel>> _notificationsStream =
      _notificationRepository.streamForUser(widget.user.uid);

  // Tracks which alert IDs this session has already seen, so the alarm
  // only fires for GENUINELY NEW alerts — not on every stream tick (which
  // also fires on routine things like a responder's live location updating
  // every ~6s). The first emission just records what's already there
  // without alarming, so opening the app with existing alerts doesn't
  // blast a sound for all of them at once.
  final Set<String> _seenAlertIds = {};
  bool _initialLoadDone = false;
  StreamSubscription<List<SosAlertModel>>? _alarmSubscription;

  // The most recent not-yet-dismissed new alert — drives the full-width
  // red distress banner at the top of Home. Deliberately separate from
  // "alerts I haven't accepted yet" (there could be several of those) —
  // this is specifically "the one that JUST came in", the thing a tanod
  // should see and react to first.
  SosAlertModel? _distressAlert;

  @override
  void initState() {
    super.initState();
    _alarmSubscription = _alertsStream.listen(_checkForNewAlerts);
  }

  @override
  void dispose() {
    _alarmSubscription?.cancel();
    super.dispose();
  }

  void _checkForNewAlerts(List<SosAlertModel> alerts) {
    if (!_initialLoadDone) {
      _seenAlertIds.addAll(alerts.map((a) => a.id));
      _initialLoadDone = true;
      return;
    }
    for (final alert in alerts) {
      if (_seenAlertIds.add(alert.id) && alert.status == SosStatus.active) {
        AlarmSoundService.play(alert.emergencyType);
        if (mounted) setState(() => _distressAlert = alert);
      }
    }
  }

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
                      MaterialPageRoute(builder: (_) => TanodNotificationsScreen(user: user)),
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
          if (_distressAlert != null) ...[
            _DistressBanner(
              alert: _distressAlert!,
              repository: _repository,
              onView: () {
                final alert = _distressAlert!;
                setState(() => _distressAlert = null);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TanodAlertDetailScreen(alertId: alert.id, user: user)),
                );
              },
              onDismiss: () => setState(() => _distressAlert = null),
            ),
            const SizedBox(height: 16),
          ],
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
                      Text('Tanod · ${user.barangay}', style: AppTypography.bodySoft(fontSize: 11.5)),
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
              final activeCount = alerts.where((a) => a.status == SosStatus.active).length;
              final respondingCount = alerts.where((a) => a.status == SosStatus.responded).length;

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TanodSosScreen(user: user)),
                ),
                child: AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: activeCount > 0 ? AppColors.urgentLight : AppColors.tealLight,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: activeCount > 0 ? AppColors.urgent : AppColors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SOS alerts', style: AppTypography.display(fontSize: 14)),
                            Text(
                              activeCount > 0
                                  ? '$activeCount waiting · $respondingCount being responded to'
                                  : respondingCount > 0
                                      ? '$respondingCount being responded to'
                                      : 'No active alerts right now',
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
              final pendingCount = reports.where((r) => r.status == ReportStatus.pending).length;

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TanodDashboardScreen(user: user)),
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
                            Text('Incident reports', style: AppTypography.display(fontSize: 14)),
                            Text(
                              pendingCount > 0
                                  ? '$pendingCount pending review · ${reports.length} total'
                                  : '${reports.length} total, none pending',
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

/// "Distress UI" — a hard-to-miss, full-width red banner that takes over
/// the top of Home the instant a brand-new SOS comes in, regardless of
/// which screen the tanod was previously looking at (Home is always
/// underneath). This is deliberately the loudest thing on the screen —
/// pulsing isn't used since a color/motion effect can still be missed;
/// pairing this with the sound+vibration from AlarmSoundService (see
/// _checkForNewAlerts above) covers sight, sound, and touch at once.
class _DistressBanner extends StatelessWidget {
  const _DistressBanner({
    required this.alert,
    required this.repository,
    required this.onView,
    required this.onDismiss,
  });

  final SosAlertModel alert;
  final TanodSosRepository repository;
  final VoidCallback onView;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.urgent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'NEW SOS — RESPOND NOW',
                    style: AppTypography.mono(fontSize: 11, color: Colors.white, letterSpacing: 0.6),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                    tooltip: 'Dismiss',
                    onPressed: onDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FutureBuilder<String?>(
                future: repository.fetchUserName(alert.residentId),
                builder: (context, snap) => Text(
                  snap.data ?? 'Resident',
                  style: AppTypography.display(fontSize: 20, color: Colors.white),
                ),
              ),
              const SizedBox(height: 2),
              Text(alert.emergencyType.label, style: AppTypography.body(fontSize: 13, color: Colors.white.withOpacity(0.9))),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onView,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.urgent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('VIEW & RESPOND', style: AppTypography.display(fontSize: 13, color: AppColors.urgent)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
