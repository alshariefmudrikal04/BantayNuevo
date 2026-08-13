import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/toggle_row.dart';
import '../../../../core/widgets/section_title.dart';
import '../../../../core/widgets/list_item_tile.dart';
import 'set_pin_screen.dart';

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
  bool _hasPin = false;
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
    final pinHash = await _storage.read(key: 'security_pin_hash');

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
      _hasPin = pinHash != null;
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) => _storage.write(key: key, value: value.toString());

  /// Pushes SetPinScreen and returns whether a PIN now exists — used both
  /// when first turning on "Require PIN on open" and for the standalone
  /// "Change PIN" row below.
  Future<bool> _promptSetPin() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SetPinScreen()),
    );
    if (created == true && mounted) setState(() => _hasPin = true);
    return created == true;
  }

  Future<void> _onPinOnOpenChanged(bool value) async {
    if (value && !_hasPin) {
      // Turning this on for the first time needs an actual PIN to check
      // against — send them to create one first, and only flip the toggle
      // if they actually finish that flow. Backing out leaves it off.
      final created = await _promptSetPin();
      if (!created) return;
    }
    setState(() => _pinOnOpen = value);
    _set('security_pin_on_open', value);
  }

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
                const SectionTitle('Reports & Evidence lock', topPadding: 0),
                AppCard(
                  child: Column(
                    children: [
                      ToggleRow(
                        label: 'Require PIN to view Reports & Evidence',
                        description: "Protects your report history if someone else has your phone",
                        value: _pinOnOpen,
                        onChanged: _onPinOnOpenChanged,
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
                    label: 'Re-lock after 1 min idle',
                    description: 'Re-checks PIN if you leave and come back',
                    value: _autoLock,
                    onChanged: (v) {
                      setState(() => _autoLock = v);
                      _set('security_auto_lock', v);
                    },
                    isLast: true,
                  ),
                ),
                if (_hasPin) ...[
                  const SectionTitle('PIN'),
                  AppCard(
                    child: ListItemTile(
                      title: 'Change PIN',
                      subtitle: 'Set a new 4-digit PIN',
                      showChevron: true,
                      isLast: true,
                      onTap: () => _promptSetPin(),
                    ),
                  ),
                ],
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
