import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/user_model.dart';
import '../../../models/sos_alert_model.dart';
import '../../../models/report_model.dart';
import '../../../models/notification_model.dart';
import '../../../core/theme/lux_theme.dart';
import '../../../core/widgets/live_map.dart';
import '../../../core/services/alarm_sound_service.dart';
import '../data/tanod_sos_repository.dart';
import '../data/tanod_report_repository.dart';
import '../../resident/data/notification_repository.dart';
import '../../auth/data/auth_repository.dart';
import 'tanod_sos_screen.dart';
import 'tanod_dashboard_screen.dart';
import 'tanod_notifications_screen.dart';
import 'tanod_alert_detail_screen.dart';
import 'tanod_report_review_screen.dart';

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

  late final Stream<List<SosAlertModel>> _alertsStream = _repository.streamOpenAlerts().asBroadcastStream();
  late final Stream<List<ReportModel>> _reportsStream = _reportRepository.streamAllReports();
  late final Stream<List<NotificationModel>> _notificationsStream =
      _notificationRepository.streamForUser(widget.user.uid);

  final Set<String> _seenAlertIds = {};
  bool _initialLoadDone = false;
  StreamSubscription<List<SosAlertModel>>? _alarmSubscription;

  SosAlertModel? _distressAlert;

  Position? _currentPosition;
  DateTime? _positionUpdatedAt;
  bool _locatingSelf = true;

  @override
  void initState() {
    super.initState();
    _alarmSubscription = _alertsStream.listen(_checkForNewAlerts);
    _loadCurrentLocation();
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

  Future<void> _loadCurrentLocation() async {
    setState(() => _locatingSelf = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _locatingSelf = false);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locatingSelf = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _positionUpdatedAt = DateTime.now();
        _locatingSelf = false;
      });
    } catch (_) {
      if (mounted) setState(() => _locatingSelf = false);
    }
  }

  String _relativeTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes} min ago';
    return 'Updated ${diff.inHours} hr ago';
  }

  String _formatReportDate(DateTime? date) {
    if (date == null) return 'Just now';
    return 'Filed ${date.month}/${date.day}/${date.year}';
  }

  ({String label, Color color}) _statusMeta(ReportStatus s) => switch (s) {
        ReportStatus.pending => (label: 'PENDING', color: LuxColors.amber),
        ReportStatus.inProgress => (label: 'IN PROGRESS', color: LuxColors.black),
        ReportStatus.resolved => (label: 'RESOLVED', color: LuxColors.success),
      };

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final firstName = user.name.trim().isEmpty ? 'TANOD' : user.name.trim().split(' ').first.toUpperCase();

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
                        decoration: const BoxDecoration(color: LuxColors.red, shape: BoxShape.circle),
                      ),
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ON DUTY,', style: LuxType.eyebrow(fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(firstName, style: LuxType.hero(fontSize: 36)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: LuxColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: LuxColors.success, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('PATROLLING', style: LuxType.eyebrow(fontSize: 9, color: LuxColors.success, letterSpacing: 0.4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Tanod · ${user.barangay}${user.purok.isNotEmpty ? ', Purok ${user.purok}' : ''}',
              style: LuxType.body(fontSize: 12, color: LuxColors.inkSoft)),
          const SizedBox(height: 22),

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
            const SizedBox(height: 22),
          ],

          Text('PRIORITY', style: LuxType.eyebrow(fontSize: 10.5)),
          const SizedBox(height: 10),
          StreamBuilder<List<SosAlertModel>>(
            stream: _alertsStream,
            builder: (context, snapshot) {
              final alerts = snapshot.data ?? [];
              final activeCount = alerts.where((a) => a.status == SosStatus.active).length;
              final respondingCount = alerts.where((a) => a.status == SosStatus.responded).length;
              final urgent = activeCount > 0;

              return _SosCard(
                urgent: urgent,
                subtitle: urgent
                    ? '$activeCount waiting · $respondingCount being responded to'
                    : respondingCount > 0
                        ? '$respondingCount being responded to'
                        : 'No active alerts right now',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TanodSosScreen(user: user)),
                ),
              );
            },
          ),
          const SizedBox(height: 26),

          Text('QUICK ACTIONS', style: LuxType.eyebrow(fontSize: 10.5)),
          const SizedBox(height: 10),
          StreamBuilder<List<ReportModel>>(
            stream: _reportsStream,
            builder: (context, snapshot) {
              final reports = snapshot.data ?? [];
              final pendingCount = reports.where((r) => r.status == ReportStatus.pending).length;
              return _ServiceRow(
                icon: Icons.assignment_outlined,
                title: 'Incident Reports',
                subtitle: pendingCount > 0
                    ? '$pendingCount pending review · ${reports.length} total'
                    : '${reports.length} total, none pending',
                isLast: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TanodDashboardScreen(user: user)),
                ),
              );
            },
          ),
          const SizedBox(height: 26),

          Text('PATROL AREA', style: LuxType.eyebrow(fontSize: 10.5)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: LuxColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LuxColors.divider),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 140,
                  child: _locatingSelf
                      ? const ColoredBox(color: LuxColors.surfaceMuted, child: Center(child: CircularProgressIndicator()))
                      : _currentPosition == null
                          ? ColoredBox(
                              color: LuxColors.surfaceMuted,
                              child: Center(child: Text('Location unavailable', style: LuxType.body(fontSize: 12, color: LuxColors.inkSoft))),
                            )
                          : LiveMap(
                              selfLat: _currentPosition!.latitude,
                              selfLng: _currentPosition!.longitude,
                              selfLabel: 'You',
                              showBoundary: true,
                            ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 18, color: LuxColors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${user.barangay} boundary', style: LuxType.heading(fontSize: 14)),
                            if (_positionUpdatedAt != null)
                              Text(_relativeTime(_positionUpdatedAt), style: LuxType.eyebrow(fontSize: 9, color: LuxColors.inkSoft, letterSpacing: 0.3)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18, color: LuxColors.ink),
                        tooltip: 'Refresh location',
                        onPressed: _locatingSelf ? null : _loadCurrentLocation,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RECENT REPORTS', style: LuxType.eyebrow(fontSize: 10.5)),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TanodDashboardScreen(user: user)),
                ),
                child: Text('SEE ALL', style: LuxType.eyebrow(fontSize: 10.5, color: LuxColors.red)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<ReportModel>>(
            stream: _reportsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final reports = (snapshot.data ?? []).take(3).toList();
              if (reports.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
                  child: Text('No reports yet. Resident reports will show up here.', style: LuxType.body(fontSize: 12, color: LuxColors.inkSoft)),
                );
              }
              return Container(
                decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (int i = 0; i < reports.length; i++)
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => TanodReportReviewScreen(reportId: reports[i].id, user: user)),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: i == reports.length - 1
                              ? null
                              : const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.divider))),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(reports[i].type, style: LuxType.heading(fontSize: 13.5)),
                                    const SizedBox(height: 2),
                                    Text(_formatReportDate(reports[i].createdAt), style: LuxType.eyebrow(fontSize: 9, color: LuxColors.inkSoft, letterSpacing: 0.3)),
                                  ],
                                ),
                              ),
                              _StatusPill(meta: _statusMeta(reports[i].status)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

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
      color: LuxColors.red,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'NEW SOS — RESPOND NOW',
                      style: LuxType.eyebrow(fontSize: 10.5, color: Colors.white),
                    ),
                  ),
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
                  style: LuxType.hero(fontSize: 22, color: Colors.white),
                ),
              ),
              const SizedBox(height: 2),
              Text(alert.emergencyType.label, style: LuxType.body(fontSize: 13, color: Colors.white.withOpacity(0.9))),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onView,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: LuxColors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: Text('VIEW & RESPOND', style: LuxType.heading(fontSize: 13, color: LuxColors.red)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosCard extends StatelessWidget {
  const _SosCard({required this.urgent, required this.subtitle, required this.onTap});

  final bool urgent;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: urgent ? LuxColors.red : LuxColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: urgent ? null : BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: LuxColors.divider)),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: urgent ? Colors.white.withOpacity(0.18) : LuxColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: urgent ? Colors.white : LuxColors.red,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SOS Alerts', style: LuxType.heading(fontSize: 15, color: urgent ? Colors.white : LuxColors.ink)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: LuxType.body(fontSize: 11.5, color: urgent ? Colors.white70 : LuxColors.inkSoft)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: urgent ? Colors.white : LuxColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Material(
        color: LuxColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: LuxColors.divider)),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: LuxColors.surfaceMuted, shape: BoxShape.circle),
                  child: Icon(icon, size: 19, color: LuxColors.red),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: LuxType.heading(fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: LuxType.body(fontSize: 11, color: LuxColors.inkSoft)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: LuxColors.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.meta});

  final ({String label, Color color}) meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: meta.color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(meta.label, style: LuxType.eyebrow(fontSize: 9, color: meta.color, letterSpacing: 0.4)),
    );
  }
}