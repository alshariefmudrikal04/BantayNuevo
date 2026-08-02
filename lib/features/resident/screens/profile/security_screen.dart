import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/toggle_row.dart';
import '../../../../core/widgets/section_title.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  static const _storage = FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  bool _pinOnOpen = false;
  bool _biometric = false;
  bool _autoLock = false;
  bool _biometricAvailable = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pin = await _storage.read(key: 'security_pin_on_open');
    final bio = await _storage.read(key: 'security_biometric');
    final auto = await _storage.read(key: 'security_auto_lock');

    var biometricAvailable = false;
    try {
      biometricAvailable = await _localAuth.canCheckBiometrics && await _localAuth.isDeviceSupported();
    } catch (_) {
      biometricAvailable = false;
    }

    if (!mounted) return;
    setState(() {
      _pinOnOpen = pin == 'true';
      _biometric = bio == 'true';
      _autoLock = auto == 'true';
      _biometricAvailable = biometricAvailable;
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) => _storage.write(key: key, value: value.toString());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('App lock & security')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const SectionTitle('App lock', topPadding: 0),
                AppCard(
                  child: Column(
                    children: [
                      ToggleRow(
                        label: 'Require PIN on open',
                        description: 'Protects the app if your phone is unlocked',
                        value: _pinOnOpen,
                        onChanged: (v) {
                          setState(() => _pinOnOpen = v);
                          _set('security_pin_on_open', v);
                        },
                      ),
                      ToggleRow(
                        label: 'Biometric unlock',
                        description: _biometricAvailable
                            ? 'Fingerprint / face unlock'
                            : 'Not available on this device',
                        value: _biometric,
                        onChanged: _biometricAvailable
                            ? (v) {
                                setState(() => _biometric = v);
                                _set('security_biometric', v);
                              }
                            : (_) {},
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SectionTitle('Session'),
                AppCard(
                  child: ToggleRow(
                    label: 'Auto-lock after 1 min idle',
                    description: 'Re-locks app in background',
                    value: _autoLock,
                    onChanged: (v) {
                      setState(() => _autoLock = v);
                      _set('security_auto_lock', v);
                    },
                    isLast: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'These settings are stored securely on this device only — they don\'t sync across devices.',
                  style: AppTypography.bodySoft(fontSize: 10.5),
                ),
              ],
            ),
    );
  }
}
