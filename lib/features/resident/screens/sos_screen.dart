import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/net_banner.dart';
import '../data/sos_repository.dart';
import '../widgets/panic_button.dart';
import '../widgets/escalate_row.dart';

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

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) setState(() => _online = !results.contains(ConnectivityResult.none));
    });
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

    try {
      if (_online) {
        await _sosRepository
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

    final uri = Uri(
      scheme: 'sms',
      path: numbers.join(','),
      queryParameters: {'body': message},
    );

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
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.urgent : AppColors.navyDeep,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Emergency SOS')),
      body: SafeArea(
        child: Column(
          children: [
            NetBanner(isOnline: _online),
            Expanded(
              child: SingleChildScrollView(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your emergency contacts are texted on every SOS once Profile → Emergency contacts is set up (Prompt 7) — they don\'t use the app, so SMS is the only way to reach them.',
                            style: AppTypography.bodySoft(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
