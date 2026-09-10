import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/theme/lux_theme.dart';
import '../../data/pin_security_repository.dart';
import 'set_pin_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  static const _storage = FlutterSecureStorage();
  final _pinSecurityRepository = PinSecurityRepository();
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
    // pinOnOpen/hasPin come from the account (Firestore, cached locally) —
    // see PinSecurityRepository's doc comment for why. Biometric/auto-lock
    // stay purely local, device-specific settings.
    final pinSettings = await _pinSecurityRepository.load();
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
      _pinOnOpen = pinSettings.pinOnOpen;
      _biometric = bio == 'true';
      _autoLock = auto == 'true';
      _biometricAvailable = biometricAvailable;
      _hasPin = pinSettings.hasPin;
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
    if (!mounted) return;
    setState(() => _pinOnOpen = value);
    await _pinSecurityRepository.setPinOnOpen(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxColors.bg,
      appBar: AppBar(
        backgroundColor: LuxColors.bg,
        elevation: 0,
        title: Text('APP LOCK & SECURITY', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.ink)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('REPORTS & EVIDENCE LOCK', style: LuxType.eyebrow(fontSize: 10.5)),
                const SizedBox(height: 8),
                _Group(
                  children: [
                    _ToggleTile(
                      label: 'Require PIN to view Reports & Evidence',
                      description: 'Protects your report history if someone else has your phone',
                      value: _pinOnOpen,
                      onChanged: _onPinOnOpenChanged,
                    ),
                    _ToggleTile(
                      label: 'Biometric unlock',
                      description: _biometricAvailable ? 'Fingerprint / face unlock' : 'Not available on this device',
                      value: _biometric,
                      isLast: true,
                      onChanged: _biometricAvailable
                          ? (v) {
                              setState(() => _biometric = v);
                              _set('security_biometric', v);
                            }
                          : (_) {},
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text('SESSION', style: LuxType.eyebrow(fontSize: 10.5)),
                const SizedBox(height: 8),
                _Group(
                  children: [
                    _ToggleTile(
                      label: 'Re-lock after 1 min idle',
                      description: 'Re-checks PIN if you leave and come back',
                      value: _autoLock,
                      isLast: true,
                      onChanged: (v) {
                        setState(() => _autoLock = v);
                        _set('security_auto_lock', v);
                      },
                    ),
                  ],
                ),

                if (_hasPin) ...[
                  const SizedBox(height: 24),
                  Text('PIN', style: LuxType.eyebrow(fontSize: 10.5)),
                  const SizedBox(height: 8),
                  _Group(
                    children: [
                      InkWell(
                        onTap: () => _promptSetPin(),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Change PIN', style: LuxType.heading(fontSize: 13.5)),
                                    const SizedBox(height: 2),
                                    Text('Set a new 4-digit PIN', style: LuxType.body(fontSize: 11, color: LuxColors.inkSoft)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, size: 18, color: LuxColors.inkSoft),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                Text(
                  'Your PIN and this toggle apply to your account everywhere — logging in on another '
                  'device enforces the same PIN. Biometric and re-lock timing are set per device.',
                  style: LuxType.body(fontSize: 10.5, color: LuxColors.inkSoft),
                ),
              ],
            ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({required this.label, required this.description, required this.value, required this.onChanged, this.isLast = false});

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: isLast ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.divider))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: LuxType.heading(fontSize: 13)),
                const SizedBox(height: 2),
                Text(description, style: LuxType.body(fontSize: 10.5, color: LuxColors.inkSoft)),
              ],
            ),
          ),
          Switch(value: value, activeThumbColor: LuxColors.red, onChanged: onChanged),
        ],
      ),
    );
  }
}
