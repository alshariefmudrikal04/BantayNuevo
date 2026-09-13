import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/user_model.dart';
import '../../../models/sos_alert_model.dart';
import '../../../core/theme/lux_theme.dart';
import '../../../core/widgets/live_map.dart';
import '../data/police_repository.dart';

/// Mirrors TanodAlertDetailScreen, minus the "Accept" step — a police
/// officer only ever sees an alert here once already assigned. Reskinned
/// to match the resident side's look.
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
      SnackBar(content: Text(message), backgroundColor: isError ? LuxColors.red : LuxColors.black),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxColors.bg,
      appBar: AppBar(
        backgroundColor: LuxColors.bg,
        elevation: 0,
        title: Text('SOS ALERT', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.ink)),
      ),
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SOS FROM ${residentName.toUpperCase()}', style: LuxType.hero(fontSize: 22)),
                    const SizedBox(height: 4),
                    Text(alert.emergencyType.label, style: LuxType.eyebrow(fontSize: 10.5, color: LuxColors.red)),
                    const SizedBox(height: 14),
                    if (isClosed)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
                        child: Text('This alert was marked resolved.', style: LuxType.body(fontSize: 12, color: LuxColors.inkSoft)),
                      )
                    else
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: LiveMap(
                            selfLat: _myPosition?.latitude ?? alert.lat ?? 0,
                            selfLng: _myPosition?.longitude ?? alert.lng ?? 0,
                            selfLabel: 'You',
                            otherLat: alert.lat,
                            otherLng: alert.lng,
                            otherLabel: residentName,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    if (!isClosed && !hasArrived) ...[
                      _LuxButton(label: _arriving ? 'UPDATING...' : "I'VE ARRIVED", filled: true, onTap: _arriving ? null : () => _arrived(alert.residentId)),
                      const SizedBox(height: 8),
                      _LuxButton(label: 'MARK RESOLVED', filled: false, onTap: () => _resolve(alert.residentId)),
                    ],
                    if (!isClosed && hasArrived) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, size: 16, color: LuxColors.success),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('You marked yourself as arrived. $residentName has been notified.', style: LuxType.body(fontSize: 11.5, color: LuxColors.inkSoft)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _LuxButton(label: 'MARK RESOLVED', filled: true, onTap: () => _resolve(alert.residentId)),
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

class _LuxButton extends StatelessWidget {
  const _LuxButton({required this.label, required this.filled, required this.onTap});

  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? LuxColors.red : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: filled ? null : Border.all(color: LuxColors.divider)),
          child: Text(label, style: LuxType.eyebrow(fontSize: 12, color: filled ? Colors.white : LuxColors.ink, letterSpacing: 0.6)),
        ),
      ),
    );
  }
}
