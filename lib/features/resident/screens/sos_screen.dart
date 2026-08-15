import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/user_model.dart';
import '../../../models/sos_alert_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/live_map.dart';
import '../data/sos_repository.dart';
import '../widgets/panic_button.dart';
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
/// backup ping to tanod. If there's genuinely no internet, the alert
/// can't be created at all — see _sendDistressNow()'s error handling
/// rather than any client-side SMS composer fallback.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final _sosRepository = SosRepository();
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

  @override
  void initState() {
    super.initState();
    _resumeActiveAlertIfAny();
  }

  /// Checks Firestore for an alert this resident already has open, rather
  /// than assuming "no active alert" just because this particular screen
  /// instance is fresh — see fetchActiveAlert's doc comment for why.
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

  /// Tapping the panic button lands here — starts the 10s window, doesn't
  /// send anything yet.
  void _startCountdown() {
    if (_countingDown || _busy) return;
    setState(() {
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
    });
    _showSnack('SOS cancelled — nothing was sent.');
  }

  /// The real send — only ever reached once the 10-second countdown runs
  /// out without being cancelled. This writes the alert doc, which is what
  /// triggers onSosCreated server-side to fan out PhilSMS texts to every
  /// saved emergency contact (with location + a distress message) and a
  /// backup SMS to tanod, on top of the in-app push/live-tracking. There is
  /// no client-side SMS composer fallback — if this write fails (e.g. no
  /// internet), that's surfaced as an error, not silently substituted with
  /// something else.
  Future<void> _sendDistressNow() async {
    setState(() => _busy = true);
    final position = await _captureLocation();

    if (position == null) {
      _showSnack('Could not get your location — check location permissions and try again.', isError: true);
      setState(() => _busy = false);
      return;
    }

    // Warn-only, deliberately never blocking — an actual emergency near the
    // barangay line shouldn't get refused just because GPS drifted a few
    // meters past it, or because someone fled just past the boundary while
    // being chased. Tanod still sees the exact coordinates and can judge
    // for themselves whether to respond.
    final geofence = checkBarangayBoundary(position.latitude, position.longitude);
    if (!geofence.withinBoundary) {
      _showSnack("You appear to be outside Barangay Camino Nuevo's coverage area — sending anyway.");
    }

    try {
      final alertId = await _sosRepository
          .createOnlineAlert(
            residentId: widget.user.uid,
            escalationTarget: 'tanod',
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

  /// Keeps the resident's location current on the alert doc every few
  /// seconds while it's active, so a responding tanod can actually follow
  /// them — not just see where they were the instant they pressed the button.
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

  Future<void> _markResolved() async {
    _locationTimer?.cancel();
    if (_activeAlertId != null) {
      await _sosRepository.markResolved(_activeAlertId!);
    }
    if (!mounted) return;
    setState(() {
      _activeAlertId = null;
      _alertStream = null;
      _lastKnownPosition = null;
    });
    _showSnack('Marked resolved.');
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
      // Blocks back navigation both while an alert is active AND during the
      // countdown itself — otherwise backing out mid-countdown would leave
      // the Timer running invisibly on a screen the resident thinks they
      // left, and it would still send a few seconds later with no
      // indication why.
      canPop: _activeAlertId == null && !_countingDown,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_countingDown) {
          _showSnack('Sending in $_secondsLeft s — tap Cancel below to stop it.');
        } else {
          _showSnack("Your SOS is still active. Tap \"I'm safe now\" below to cancel it.");
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: const Text('Emergency SOS')),
        body: SafeArea(
          child: _activeAlertId != null
              ? _buildTrackingView(context)
              : _countingDown
                  ? _buildCountdownView(context)
                  : _buildPanicView(context),
        ),
      ),
    );
  }

  Widget _buildPanicView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Text(
            'Pressing below starts a 10-second countdown before Tanod is alerted — plenty of time to cancel '
            'if it was an accident.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySoft(fontSize: 12),
          ),
          const SizedBox(height: 20),
          PanicButton(busy: _busy, onPressed: _startCountdown),
          const SizedBox(height: 8),
          Text('Tanod is notified · 10s to cancel', style: AppTypography.mono(fontSize: 10)),
          const SizedBox(height: 16),
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

  /// Shown for the 10s window between tapping the panic button and the
  /// signal actually sending. Deliberately does NOT show a map or any
  /// location — that only appears once _sendDistressNow() actually runs.
  Widget _buildCountdownView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Sending distress signal to Tanod in', style: AppTypography.body(fontSize: 14, color: AppColors.inkSoft)),
          const SizedBox(height: 16),
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.urgentLight,
              border: Border.all(color: AppColors.urgent, width: 3),
            ),
            child: Center(
              child: Text('$_secondsLeft', style: AppTypography.display(fontSize: 48, color: AppColors.urgent)),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: AppButton(label: 'Cancel', variant: AppButtonVariant.outline, onPressed: _cancelCountdown),
          ),
          const SizedBox(height: 10),
          Text(
            'Nothing has been sent yet — your location is not shared until this reaches zero.',
            textAlign: TextAlign.center,
            style: AppTypography.mono(fontSize: 10, color: AppColors.inkSoft),
          ),
        ],
      ),
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
        final statusText = switch (status) {
          SosStatus.active => 'Waiting for a responder...',
          SosStatus.responded => '${alert?.responderName ?? 'A responder'} is on the way',
          SosStatus.arrived => '${alert?.responderName ?? 'A responder'} has arrived',
          SosStatus.closed => 'Marked resolved',
        };
        final statusColor = switch (status) {
          SosStatus.active => AppColors.amber,
          SosStatus.responded => AppColors.teal,
          SosStatus.arrived => AppColors.resolvedFg,
          SosStatus.closed => AppColors.resolvedFg,
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
              AppButton(label: "I'm safe now — mark resolved", variant: AppButtonVariant.ghost, onPressed: _markResolved),
            ],
          ),
        );
      },
    );
  }
}
