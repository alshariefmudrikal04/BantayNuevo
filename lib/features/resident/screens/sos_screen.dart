import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/user_model.dart';
import '../../../models/sos_alert_model.dart';
import '../../../models/emergency_contact_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/live_map.dart';
import '../data/sos_repository.dart';
import '../data/emergency_contact_repository.dart';
import '../../../core/utils/geofence.dart';

/// Per the thesis design: residents never choose tanod vs. police directly
/// — every SOS always routes to tanod first (escalationTarget is always
/// "tanod"). Requesting police involvement is tanod's own call to make
/// after reviewing the alert, not something exposed here.
///
/// Also per the thesis scope: there is no offline/on-device SMS fallback.
/// SOS is always: write the alert to Firestore -> onSosCreated Cloud
/// Function -> PhilSMS texts every saved emergency contact with the
/// resident's location and a distress message, same call also used as a
/// backup ping to tanod.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key, required this.user, this.autoStart = false});

  final UserModel user;

  /// True when opened from a "this IS the SOS action" entry point (bottom
  /// nav's SOS button, Home's big panic circle, the "Not urgent? /
  /// Emergency instead" link in the report form). Historically this
  /// skipped straight into the countdown; now that picking an emergency
  /// type is a required first step (it's what selects the alarm sound on
  /// the tanod side), there's no longer a screen left to skip past — this
  /// flag is kept for API compatibility with existing call sites but no
  /// longer changes behavior. Either way, an already-active alert always
  /// takes priority — see _resumeActiveAlertIfAny().
  final bool autoStart;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final _sosRepository = SosRepository();
  final _emergencyContactRepository = EmergencyContactRepository();
  bool _busy = false;

  // Set once an alert is created — switches the screen into the
  // live-tracking view. Null means "no active alert, show the panic button".
  String? _activeAlertId;
  Stream<SosAlertModel>? _alertStream;
  Position? _lastKnownPosition;
  Timer? _locationTimer;

  // Countdown state — pressing the panic button does NOT send anything
  // immediately. It starts a 10-second window the resident can cancel out
  // of (e.g. an accidental press). Nothing is written to Firestore, no SMS
  // is sent, and no location is captured or shown until the countdown
  // actually completes — see _sendDistressNow().
  bool _countingDown = false;
  int _secondsLeft = _countdownSeconds;
  Timer? _countdownTimer;
  static const _countdownSeconds = 10;

  // Which emergency type the resident picked on the type-selection screen
  // — required before any countdown can start now, since it's what
  // determines which alarm sound plays on the tanod side (see
  // core/services/alarm_sound_service.dart). Null only while that screen
  // is still showing, before a choice has been made.
  EmergencyType? _selectedType;

  // Shown as avatars around the countdown ring — just for reassurance that
  // "yes, these are the people who'll be texted", not used for anything
  // functional here (the actual texting happens server-side).
  List<EmergencyContactModel> _contacts = [];

  @override
  void initState() {
    super.initState();
    _emergencyContactRepository.streamForResident(widget.user.uid).first.then((contacts) {
      if (mounted) setState(() => _contacts = contacts);
    });
    _resumeActiveAlertIfAny();
  }

  /// Checks Firestore for an alert this resident already has open, rather
  /// than assuming "no active alert" just because this particular screen
  /// instance is fresh. An already-active alert always resumes straight
  /// into live tracking, skipping type-selection entirely (the type was
  /// already picked whenever that alert was originally created).
  Future<void> _resumeActiveAlertIfAny() async {
    final alert = await _sosRepository.fetchActiveAlert(widget.user.uid);
    if (!mounted || alert == null) return;
    setState(() {
      _activeAlertId = alert.id;
      _alertStream = _sosRepository.streamAlert(alert.id);
    });
    _startLiveLocationUpdates(alert.id);
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<Position?> _captureLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('GPS took too long to respond'),
      );
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Called when the resident taps a specific emergency type — records
  /// the choice and starts the 10s countdown in one tap, doesn't send
  /// anything yet.
  void _selectTypeAndStartCountdown(EmergencyType type) {
    if (_countingDown || _busy || _activeAlertId != null) return;
    setState(() {
      _selectedType = type;
      _countingDown = true;
      _secondsLeft = _countdownSeconds;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _countingDown = false;
          _secondsLeft = _countdownSeconds;
        });
        _sendDistressNow();
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _countingDown = false;
      _secondsLeft = _countdownSeconds;
      _selectedType = null;
    });
    _showSnack('SOS cancelled — nothing was sent.');
  }

  /// The real send — only ever reached once the 10-second countdown runs
  /// out without being cancelled.
  Future<void> _sendDistressNow() async {
    setState(() => _busy = true);
    final position = await _captureLocation();

    if (position == null) {
      _showSnack('Could not get your location — check location permissions and try again.', isError: true);
      setState(() => _busy = false);
      return;
    }

    final geofence = checkBarangayBoundary(position.latitude, position.longitude);
    if (!geofence.withinBoundary) {
      _showSnack("You appear to be outside Barangay Camino Nuevo's coverage area — sending anyway.");
    }

    try {
      final alertId = await _sosRepository
          .createOnlineAlert(
            residentId: widget.user.uid,
            escalationTarget: 'tanod',
            emergencyType: _selectedType ?? EmergencyType.other,
            lat: position.latitude,
            lng: position.longitude,
          )
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw TimeoutException('Could not reach the server'),
          );

      setState(() {
        _activeAlertId = alertId;
        _alertStream = _sosRepository.streamAlert(alertId);
        _lastKnownPosition = position;
      });
      _startLiveLocationUpdates(alertId);
      _showSnack('Distress signal sent — Tanod and your emergency contacts are being notified.');
    } on TimeoutException {
      _showSnack(
        'Could not send SOS — no internet connection. Connect to WiFi or mobile data and try again.',
        isError: true,
      );
    } catch (e) {
      _showSnack('Could not send SOS: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startLiveLocationUpdates(String alertId) {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      final position = await _captureLocation();
      if (position == null) return;
      if (mounted) setState(() => _lastKnownPosition = position);
      try {
        await _sosRepository.updateMyLocation(alertId, position.latitude, position.longitude);
      } catch (_) {
        // Transient network hiccup — next tick will retry, nothing to show the user.
      }
    });
  }

  /// Dismisses the current alert view and returns to the panic button.
  /// Skips the Firestore write entirely if the alert already expired —
  /// firestore.rules treats 'expired' as a fully terminal status (no
  /// further transitions, matching "EXPIRED → CANNOT BE ACCEPTED"), so
  /// attempting markResolved() on one would just fail with a permission
  /// error. There's nothing to update server-side in that case anyway —
  /// this is purely resetting local state so the resident can try again.
  Future<void> _markResolved({required bool alreadyExpired}) async {
    _locationTimer?.cancel();
    if (_activeAlertId != null && !alreadyExpired) {
      await _sosRepository.markResolved(_activeAlertId!);
    }
    if (!mounted) return;
    setState(() {
      _activeAlertId = null;
      _alertStream = null;
      _lastKnownPosition = null;
      _selectedType = null;
    });
    _showSnack(alreadyExpired ? 'You can send a new SOS if you still need help.' : 'Marked resolved.');
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? AppColors.urgent : AppColors.navyDeep),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _activeAlertId == null && !_countingDown,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_countingDown) {
          _showSnack('Sending in $_secondsLeft s — tap "I am safe" below to stop it.');
        } else {
          _showSnack("Your SOS is still active. Tap \"I'm safe now\" below to cancel it.");
        }
      },
      child: Scaffold(
        backgroundColor: _countingDown ? AppColors.urgent : AppColors.bg,
        appBar: _countingDown
            ? null
            : AppBar(title: const Text('Emergency SOS')),
        body: SafeArea(
          child: _activeAlertId != null
              ? _buildTrackingView(context)
              : _countingDown
                  ? _buildCountdownView(context)
                  : _buildTypeSelectionView(context),
        ),
      ),
    );
  }

  /// Required first step now — picking a type both selects it AND starts
  /// the 10s countdown in one tap (no separate confirm button), so this
  /// doesn't add meaningful friction versus the old single panic button.
  /// The type chosen here is what determines which alarm sound plays on
  /// the tanod side — see core/services/alarm_sound_service.dart.
  Widget _buildTypeSelectionView(BuildContext context) {
    final types = [
      (EmergencyType.physicalViolence, Icons.front_hand, AppColors.urgent, AppColors.urgentLight),
      (EmergencyType.domesticViolence, Icons.home, AppColors.urgent, AppColors.urgentLight),
      (EmergencyType.threats, Icons.warning_amber_rounded, AppColors.amber, AppColors.amberLight),
      (EmergencyType.minorAbuse, Icons.child_care, AppColors.lock, AppColors.lockLight),
      (EmergencyType.other, Icons.error_outline, AppColors.navy, AppColors.tealLight),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What kind of emergency is this?',
            style: AppTypography.display(fontSize: 17),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Tapping one starts a 10-second countdown before Tanod is alerted — plenty of time to cancel '
            'if it was an accident.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySoft(fontSize: 12),
          ),
          const SizedBox(height: 20),
          for (final (type, icon, color, bg) in types)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _selectTypeAndStartCountdown(type),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          child: Icon(icon, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(type.label, style: AppTypography.display(fontSize: 14.5, color: AppColors.ink)),
                        ),
                        Icon(Icons.chevron_right, color: color),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          AppCard(
            child: Text(
              'Once sent, your emergency contacts are texted automatically with your location — add them under '
              "Profile → Emergency contacts if you haven't yet, since they don't use the app.",
              style: AppTypography.bodySoft(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  /// Full-bleed red "Emergency Calling" style screen — the countdown ring,
  /// a pulsing broadcast icon, up to 4 emergency-contact avatars scattered
  /// around it, and a white pill "I AM SAFE" button that cancels. Nothing
  /// is sent or shown location-wise until this actually reaches zero.
  Widget _buildCountdownView(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: Center(
                    child: Text(
                      '$_secondsLeft',
                      style: AppTypography.display(fontSize: 44, color: AppColors.urgent),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Emergency Calling...',
                  style: AppTypography.display(fontSize: 22, color: Colors.white),
                ),
                if (_selectedType != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _selectedType!.label,
                    style: AppTypography.mono(fontSize: 11, color: Colors.white.withOpacity(0.85)),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Tanod and your emergency contacts will be notified in $_secondsLeft seconds. '
                  'Tap "I am safe" below to stop this.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(fontSize: 12.5, color: Colors.white.withOpacity(0.85)),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  height: 190,
                  width: 260,
                  child: _ContactBroadcastRing(contacts: _contacts),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _cancelCountdown,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.urgent,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: Text('I AM SAFE', style: AppTypography.display(fontSize: 14, color: AppColors.urgent)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingView(BuildContext context) {
    return StreamBuilder<SosAlertModel>(
      stream: _alertStream,
      builder: (context, snapshot) {
        final alert = snapshot.data;
        final selfLat = _lastKnownPosition?.latitude ?? alert?.lat;
        final selfLng = _lastKnownPosition?.longitude ?? alert?.lng;

        if (selfLat == null || selfLng == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final status = alert?.status ?? SosStatus.active;
        final isExpired = status == SosStatus.expired || alert?.isExpired == true;
        final statusText = isExpired
            ? 'No one responded in time — this alert has expired'
            : switch (status) {
                SosStatus.active => 'Waiting for a responder...',
                SosStatus.responded => '${alert?.responderName ?? 'A responder'} is on the way',
                SosStatus.arrived => '${alert?.responderName ?? 'A responder'} has arrived',
                SosStatus.closed => 'Marked resolved',
                SosStatus.expired => 'No one responded in time — this alert has expired',
              };
        final statusColor = isExpired
            ? AppColors.urgent
            : switch (status) {
                SosStatus.active => AppColors.amber,
                SosStatus.responded => AppColors.teal,
                SosStatus.arrived => AppColors.resolvedFg,
                SosStatus.closed => AppColors.resolvedFg,
                SosStatus.expired => AppColors.urgent,
              };

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(statusText, style: AppTypography.display(fontSize: 14, color: statusColor))),
                ],
              ),
              if (alert != null) ...[
                const SizedBox(height: 2),
                Text(alert.emergencyType.label, style: AppTypography.mono(fontSize: 10.5, color: AppColors.inkSoft)),
              ],
              const SizedBox(height: 10),
              Expanded(
                child: LiveMap(
                  selfLat: selfLat,
                  selfLng: selfLng,
                  selfLabel: 'You',
                  otherLat: alert?.responderLat,
                  otherLng: alert?.responderLng,
                  otherLabel: alert?.responderName,
                  showBoundary: true,
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: isExpired ? 'Send a new SOS' : "I'm safe now — mark resolved",
                variant: AppButtonVariant.ghost,
                onPressed: () => _markResolved(alreadyExpired: isExpired),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pulsing center icon with up to 4 emergency-contact avatars scattered
/// around it in fixed corner-ish positions, matching the reference layout
/// (broadcast icon in the middle, contacts orbiting it). Purely decorative
/// reassurance during the countdown — no functional role.
class _ContactBroadcastRing extends StatefulWidget {
  const _ContactBroadcastRing({required this.contacts});

  final List<EmergencyContactModel> contacts;

  @override
  State<_ContactBroadcastRing> createState() => _ContactBroadcastRingState();
}

class _ContactBroadcastRingState extends State<_ContactBroadcastRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _avatar(EmergencyContactModel contact) {
    final initial = contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?';
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
      ),
      child: Center(
        child: Text(initial, style: AppTypography.display(fontSize: 16, color: AppColors.urgent)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fixed corner slots, same arrangement style as the reference image —
    // top-left, top-right, bottom-left, bottom-right around the center.
    const positions = [
      Alignment(-0.85, -0.75),
      Alignment(0.85, -0.75),
      Alignment(-0.85, 0.75),
      Alignment(0.85, 0.75),
    ];

    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing broadcast rings behind the center icon.
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            return Container(
              width: 60 + (t * 40),
              height: 60 + (t * 40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity((1 - t) * 0.35),
              ),
            );
          },
        ),
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          child: const Icon(Icons.sensors, color: AppColors.urgent, size: 26),
        ),
        for (int i = 0; i < widget.contacts.length && i < 4; i++)
          Align(alignment: positions[i], child: _avatar(widget.contacts[i])),
      ],
    );
  }
}
