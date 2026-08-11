import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/user_model.dart';
import '../../../models/sos_alert_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/net_banner.dart';
import '../../../core/widgets/live_map.dart';
import '../data/sos_repository.dart';
import '../widgets/panic_button.dart';
import '../widgets/escalate_row.dart';
import '../../../core/utils/geofence.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final _sosRepository = SosRepository();
  bool _online = true;
  bool _busy = false;

  // Set once an online alert is created — switches the screen into the
  // live-tracking view. Null means "no active alert, show the panic button".
  String? _activeAlertId;
  Stream<SosAlertModel>? _alertStream;
  Position? _lastKnownPosition;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) setState(() => _online = !results.contains(ConnectivityResult.none));
    });
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
    // Resumes sending this resident's own live location too — otherwise a
    // resumed alert would show correctly but silently stop updating where
    // the resident actually is.
    _startLiveLocationUpdates(alert.id);
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _online = !results.contains(ConnectivityResult.none));
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

  Future<void> _trigger(String escalationTarget) async {
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
    // being chased. Tanod/police still see the exact coordinates and can
    // judge for themselves whether to respond. Contrast with the report
    // form, which does hard-block (see report_form_screen.dart) — that's a
    // non-urgent submission where waiting until back in-barangay is fine.
    final geofence = checkBarangayBoundary(position.latitude, position.longitude);
    if (!geofence.withinBoundary) {
      _showSnack("You appear to be outside Barangay Camino Nuevo's coverage area — sending anyway.");
    }

    try {
      if (_online) {
        final alertId = await _sosRepository
            .createOnlineAlert(
              residentId: widget.user.uid,
              escalationTarget: escalationTarget,
              lat: position.latitude,
              lng: position.longitude,
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException('Could not reach Firestore'),
            );

        setState(() {
          _activeAlertId = alertId;
          _alertStream = _sosRepository.streamAlert(alertId);
          _lastKnownPosition = position;
        });
        _startLiveLocationUpdates(alertId);
        _showSnack('SOS sent — Tanod is being notified.');
      } else {
        await _sendOfflineSms(escalationTarget: escalationTarget, position: position);
        await _sosRepository.logOfflineAlertAttempt(
          residentId: widget.user.uid,
          escalationTarget: escalationTarget,
          lat: position.latitude,
          lng: position.longitude,
        );
      }
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

  Future<void> _sendOfflineSms({required String escalationTarget, required Position position}) async {
    final numbers = <String>{
      ...await _sosRepository.fetchPhoneNumbersForRole('tanod'),
      if (escalationTarget == 'pnp') ...await _sosRepository.fetchPhoneNumbersForRole('police'),
    };

    if (numbers.isEmpty) {
      _showSnack('No responder numbers on file — could not prepare the SMS.', isError: true);
      return;
    }

    final message = '[EMERGENCY - Bantay Nuevo] ${widget.user.name} needs help. '
        'Location: https://maps.google.com/?q=${position.latitude},${position.longitude}';

    final uri = Uri(scheme: 'sms', path: numbers.join(','), queryParameters: {'body': message});

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      _showSnack('SMS ready — confirm send in your messaging app.');
    } else {
      _showSnack('Could not open your SMS app.', isError: true);
    }
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
      // Only intercept back navigation while an alert is actually active —
      // otherwise this would block the normal back button on the panic-
      // button view for no reason. Prevents someone from thinking they
      // cancelled their SOS by backing out of the screen, when the alert
      // (and the resident's live location updates) are actually still
      // running per fetchActiveAlert's resume logic above.
      canPop: _activeAlertId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showSnack("Your SOS is still active. Tap \"I'm safe now\" below to cancel it.");
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: const Text('Emergency SOS')),
        body: SafeArea(
          child: Column(
            children: [
              if (_activeAlertId == null) NetBanner(isOnline: _online),
              Expanded(
                child: _activeAlertId != null
                    ? _buildTrackingView(context)
                    : _buildPanicView(context),
              ),
            ],
          ),
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
            _online
                ? 'Live GPS shared with Tanod/police in-app. Emergency contact texting arrives once that\'s wired up.'
                : 'No internet detected — pressing below opens a pre-filled text to your Tanod (and police, if escalated).',
            textAlign: TextAlign.center,
            style: AppTypography.bodySoft(fontSize: 12),
          ),
          const SizedBox(height: 20),
          PanicButton(busy: _busy, onPressed: () => _trigger('auto')),
          const SizedBox(height: 8),
          Text('Defaults to nearest Tanod · officials notified', style: AppTypography.mono(fontSize: 10)),
          const SectionTitle('Or escalate directly'),
          EscalateRow(
            onTanod: _busy ? () {} : () => _trigger('tanod'),
            onPolice: _busy ? () {} : () => _trigger('pnp'),
          ),
          const SizedBox(height: 4),
          AppCard(
            child: Text(
              'Your emergency contacts are texted on every SOS once Profile → Emergency contacts is set up (Prompt 7) — they don\'t use the app, so SMS is the only way to reach them.',
              style: AppTypography.bodySoft(fontSize: 11),
            ),
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
