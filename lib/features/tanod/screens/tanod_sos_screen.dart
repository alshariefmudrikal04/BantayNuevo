import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/sos_alert_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/services/alarm_sound_service.dart';
import '../data/tanod_sos_repository.dart';
import '../../auth/data/auth_repository.dart';
import 'tanod_alert_detail_screen.dart';

class TanodSosScreen extends StatefulWidget {
  const TanodSosScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<TanodSosScreen> createState() => _TanodSosScreenState();
}

class _TanodSosScreenState extends State<TanodSosScreen> {
  final _repository = TanodSosRepository();
  final _authRepository = AuthRepository();

  // asBroadcastStream() — this stream now needs two independent listeners:
  // the StreamBuilder driving the UI, and _alarmSubscription below watching
  // for brand-new alerts to play a sound for. A plain Firestore stream is
  // single-subscription only and would throw on the second listen().
  late final Stream<List<SosAlertModel>> _alertsStream = _repository.streamOpenAlerts().asBroadcastStream();

  // Tracks which alert IDs this screen has already seen, so the alarm only
  // fires for GENUINELY NEW alerts — not on every stream tick (which also
  // fires on routine things like a responder's live location updating
  // every ~6s). The first emission just records what's already there
  // without alarming, so opening this screen with existing alerts doesn't
  // blast a sound for all of them at once.
  final Set<String> _seenAlertIds = {};
  bool _initialLoadDone = false;
  StreamSubscription<List<SosAlertModel>>? _alarmSubscription;

  // Cached per residentId so the list doesn't re-fetch a name on every
  // stream tick (which happens every ~6s from live location updates) —
  // same "cache the async work" fix as the earlier flash-bug cleanup.
  final Map<String, Future<String?>> _nameFutures = {};
  Future<String?> _residentNameFuture(String residentId) {
    return _nameFutures.putIfAbsent(residentId, () => _repository.fetchUserName(residentId));
  }

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
      }
    }
  }

  String _relativeTime(DateTime? date) {
    if (date == null) return 'just now';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours} hr ago';
  }

  /// Minutes left before this alert expires and can no longer be accepted
  /// — shown next to still-active alerts so tanod can see urgency at a
  /// glance. Purely a display hint; the real cutoff is enforced server-side
  /// (firestore.rules), this just mirrors it.
  int _minutesRemaining(DateTime? createdAt) {
    if (createdAt == null) return sosAlertValidityMinutes;
    final elapsed = DateTime.now().difference(createdAt);
    final remaining = const Duration(minutes: sosAlertValidityMinutes) - elapsed;
    return remaining.isNegative ? 0 : remaining.inMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Active SOS alerts'),
        actions: [
          IconButton(icon: const Icon(Icons.logout, size: 20), onPressed: _authRepository.logout),
        ],
      ),
      body: StreamBuilder<List<SosAlertModel>>(
        stream: _alertsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppCard(
                child: Text(
                  'Could not load alerts.\n\n${snapshot.error}',
                  style: const TextStyle(color: AppColors.urgent, fontSize: 11),
                ),
              ),
            );
          }
          final alerts = snapshot.data ?? [];
          if (alerts.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppCard(child: Text('No active SOS alerts right now.', style: AppTypography.bodySoft(fontSize: 12))),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              for (final alert in alerts)
                InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TanodAlertDetailScreen(alertId: alert.id, user: widget.user)),
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
                                future: _residentNameFuture(alert.residentId),
                                builder: (context, nameSnap) => Text(
                                  nameSnap.data ?? 'Resident',
                                  style: AppTypography.body(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                alert.status == SosStatus.active
                                    ? '${alert.emergencyType.label} · ${_relativeTime(alert.createdAt)} · '
                                        'expires in ${_minutesRemaining(alert.createdAt)}m'
                                    : '${alert.responderName ?? "A responder"} is handling this',
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
          );
        },
      ),
    );
  }
}
