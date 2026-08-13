import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'pin_lock_screen.dart';
import '../utils/sensitive_gate_controller.dart';
import '../theme/app_colors.dart';

/// Wraps My Reports, Report Detail, and Evidence Vault specifically — NOT
/// the whole app (see sensitive_gate_controller.dart for why). If the
/// resident never turned on PIN/biometric in Profile → App lock & security,
/// this is a no-op and just shows [child] directly — opting in is required,
/// nothing is force-locked for residents who haven't set it up.
class SensitiveContentGate extends StatefulWidget {
  const SensitiveContentGate({super.key, required this.child});

  final Widget child;

  @override
  State<SensitiveContentGate> createState() => _SensitiveContentGateState();
}

class _SensitiveContentGateState extends State<SensitiveContentGate> {
  static const _storage = FlutterSecureStorage();

  bool _checking = true;
  bool _locked = false;
  bool _configured = false;
  bool _biometric = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (await SensitiveGateController.instance.isUnlocked()) {
      if (!mounted) return;
      setState(() {
        _locked = false;
        _checking = false;
      });
      return;
    }
    final pin = await _storage.read(key: 'security_pin_on_open');
    final bio = await _storage.read(key: 'security_biometric');
    final hash = await _storage.read(key: 'security_pin_hash');
    // Only lock if the resident actually opted in AND has a PIN on file to
    // check against — otherwise there's nothing configured to enforce.
    final configured = (pin == 'true' || bio == 'true') && hash != null;
    if (!mounted) return;
    setState(() {
      _configured = configured;
      _biometric = bio == 'true';
      _locked = configured;
      _checking = false;
    });
  }

  void _handleUnlocked() {
    SensitiveGateController.instance.markUnlocked();
    setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(backgroundColor: AppColors.bg, body: Center(child: CircularProgressIndicator()));
    }
    if (_locked && _configured) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: PinLockScreen(onUnlocked: _handleUnlocked, biometricEnabled: _biometric),
      );
    }
    return widget.child;
  }
}
