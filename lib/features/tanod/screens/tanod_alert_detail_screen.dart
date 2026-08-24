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
import '../data/tanod_sos_repository.dart';

class TanodAlertDetailScreen extends StatefulWidget {
  const TanodAlertDetailScreen({super.key, required this.alertId, required this.user});

  final String alertId;
  final UserModel user;

  @override
  State<TanodAlertDetailScreen> createState() => _TanodAlertDetailScreenState();
}

class _TanodAlertDetailScreenState extends State<TanodAlertDetailScreen> {
  final _repository = TanodSosRepository();
  late final Stream<SosAlertModel> _alertStream = _repository.streamAlert(widget.alertId);
  late final Map<String, Future<String?>> _nameFutures = {};

  Position? _myPosition;
  Timer? _locationTimer;
  bool _accepting = false;
  bool _arriving = false;

  Future<String?> _residentNameFuture(String residentId) {
    return _nameFutures.putIfAbsent(residentId, () => _repository.fetchUserName(residentId));
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<Position?> _captureLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      return null;
    }
  }

  Future<void> _accept(String residentId) async {
    setState(() => _accepting = true);
    final position = await _captureLocation();
    if (position == null) {
      _showSnack('Could not get your location — check permissions and try again.', isError: true);
      setState(() => _accepting = false);
      return;
    }
    try {
      await _repository.acceptAlert(
        alertId: widget.alertId,
        residentId: residentId,
        tanodId: widget.user.uid,
        tanodName: widget.user.name,
        lat: position.latitude,
        lng: position.longitude,
      );
      setState(() {
        _myPosition = position;
        _accepting = false;
      });
      _startLocationUpdates();
    } catch (e) {
      _showSnack('Could not accept: $e', isError: true);
      setState(() => _accepting = false);
    }
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      final position = await _captureLocation();
      if (position == null) return;
      if (mounted) setState(() => _myPosition = position);
      try {
        await _repository.updateMyLocation(widget.alertId, position.latitude, position.longitude);
      } catch (_) {
        // Transient hiccup — next tick retries.
      }
    });
  }

  /// Distinct from resolving — this is the tanod telling the resident
  /// "I'm physically here", a safety milestone worth surfacing on its own
  /// (see TanodSosRepository.markArrived).
  Future<void> _arrived(String residentId) async {
    setState(() => _arriving = true);
    try {
      await _repository.markArrived(
        alertId: widget.alertId,
        residentId: residentId,
        tanodName: widget.user.name,
      );
    } catch (e) {
      _showSnack('Could not update: $e', isError: true);
    } finally {
      if (mounted) setState(() => _arriving = false);
    }
  }

  Future<void> _resolve(String residentId) async {
    _locationTimer?.cancel();
    await _repository.markResolved(
      alertId: widget.alertId,
      residentId: residentId,
      tanodName: widget.user.name,
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? AppColors.urgent : AppColors.navyDeep),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('SOS alert')),
      body: StreamBuilder<SosAlertModel>(
        stream: _alertStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final alert = snapshot.data!;
          final iAccepted = alert.responderId == widget.user.uid;
          final someoneElseAccepted = alert.responderId != null && !iAccepted;
          final hasArrived = alert.status == SosStatus.arrived;
          final isExpired = alert.status == SosStatus.expired || alert.isExpired;

          return FutureBuilder<String?>(
            future: _residentNameFuture(alert.residentId),
            builder: (context, nameSnap) {
              final residentName = nameSnap.data ?? 'Resident';

              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SOS from $residentName', style: AppTypography.display(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      alert.escalationTarget == 'pnp' ? 'Escalated directly to PNP' : 'Standard SOS alert',
                      style: AppTypography.mono(fontSize: 10.5),
                    ),
                    const SizedBox(height: 10),
                    if (someoneElseAccepted)
                      AppCard(
                        child: Text(
                          '${alert.responderName ?? "Another responder"} is already handling this alert.',
                          style: AppTypography.bodySoft(fontSize: 12),
                        ),
                      )
                    else if (isExpired)
                      AppCard(
                        child: Row(
                          children: [
                            const Icon(Icons.timer_off_outlined, size: 18, color: AppColors.inkSoft),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This alert expired without a response and can no longer be accepted. '
                                'It was only valid for $sosAlertValidityMinutes minutes after being sent.',
                                style: AppTypography.bodySoft(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Expanded(
                        child: LiveMap(
                          selfLat: (iAccepted ? _myPosition?.latitude : null) ?? alert.lat ?? 0,
                          selfLng: (iAccepted ? _myPosition?.longitude : null) ?? alert.lng ?? 0,
                          selfLabel: iAccepted ? 'You' : residentName,
                          otherLat: iAccepted ? alert.lat : null,
                          otherLng: iAccepted ? alert.lng : null,
                          otherLabel: iAccepted ? residentName : null,
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (!someoneElseAccepted && !iAccepted && !isExpired)
                      AppButton(
                        label: _accepting ? 'Accepting...' : 'Accept — respond to this SOS',
                        onPressed: _accepting ? null : () => _accept(alert.residentId),
                      ),
                    if (iAccepted && !hasArrived) ...[
                      AppButton(
                        label: _arriving ? 'Updating...' : "I've arrived at the location",
                        onPressed: _arriving ? null : () => _arrived(alert.residentId),
                      ),
                      const SizedBox(height: 8),
                      AppButton(
                        label: 'Mark resolved',
                        variant: AppButtonVariant.ghost,
                        onPressed: () => _resolve(alert.residentId),
                      ),
                    ],
                    if (iAccepted && hasArrived) ...[
                      AppCard(
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, size: 16, color: AppColors.resolvedFg),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You marked yourself as arrived. $residentName has been notified.',
                                style: AppTypography.bodySoft(fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppButton(label: 'Mark resolved', onPressed: () => _resolve(alert.residentId)),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
