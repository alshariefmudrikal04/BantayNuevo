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
import '../data/police_repository.dart';

/// Mirrors TanodAlertDetailScreen, minus the "Accept" step — a police
/// officer only ever sees an alert here once already assigned (see
/// PoliceRepository's doc comment), so every alert reaching this screen
/// is already theirs to handle. Live location sharing, "arrived", and
/// "resolved" all work identically to the tanod version.
class PoliceAlertDetailScreen extends StatefulWidget {
  const PoliceAlertDetailScreen({super.key, required this.alertId, required this.user});

  final String alertId;
  final UserModel user;

  @override
  State<PoliceAlertDetailScreen> createState() => _PoliceAlertDetailScreenState();
}

class _PoliceAlertDetailScreenState extends State<PoliceAlertDetailScreen> {
  final _repository = PoliceRepository();
  late final Stream<SosAlertModel> _alertStream = _repository.streamAlert(widget.alertId);
  final Map<String, Future<String?>> _nameFutures = {};

  Position? _myPosition;
  Timer? _locationTimer;
  bool _arriving = false;

  Future<String?> _residentNameFuture(String residentId) {
    return _nameFutures.putIfAbsent(residentId, () => _repository.fetchUserName(residentId));
  }

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
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

  Future<void> _arrived(String residentId) async {
    setState(() => _arriving = true);
    try {
      await _repository.markArrived(alertId: widget.alertId, residentId: residentId, policeName: widget.user.name);
    } catch (e) {
      _showSnack('Could not update: $e', isError: true);
    } finally {
      if (mounted) setState(() => _arriving = false);
    }
  }

  Future<void> _resolve(String residentId) async {
    _locationTimer?.cancel();
    await _repository.markResolved(alertId: widget.alertId, residentId: residentId, policeName: widget.user.name);
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
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final alert = snapshot.data!;
          final hasArrived = alert.status == SosStatus.arrived;
          final isClosed = alert.status == SosStatus.closed;

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
                    Text(alert.emergencyType.label, style: AppTypography.mono(fontSize: 10.5, color: AppColors.urgent)),
                    const SizedBox(height: 10),
                    if (isClosed)
                      AppCard(child: Text('This alert was marked resolved.', style: AppTypography.bodySoft(fontSize: 12)))
                    else
                      Expanded(
                        child: LiveMap(
                          selfLat: _myPosition?.latitude ?? alert.lat ?? 0,
                          selfLng: _myPosition?.longitude ?? alert.lng ?? 0,
                          selfLabel: 'You',
                          otherLat: alert.lat,
                          otherLng: alert.lng,
                          otherLabel: residentName,
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (!isClosed && !hasArrived) ...[
                      AppButton(
                        label: _arriving ? 'Updating...' : "I've arrived at the location",
                        onPressed: _arriving ? null : () => _arrived(alert.residentId),
                      ),
                      const SizedBox(height: 8),
                      AppButton(label: 'Mark resolved', variant: AppButtonVariant.ghost, onPressed: () => _resolve(alert.residentId)),
                    ],
                    if (!isClosed && hasArrived) ...[
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
                      const SizedBox(height: 8),
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
