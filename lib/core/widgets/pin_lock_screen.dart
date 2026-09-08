import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../utils/pin_hash.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/resident/data/pin_security_repository.dart';
import 'pin_keypad.dart';

/// Full-screen, opaque lock shown by AppLockGate whenever the resident has
/// "Require PIN on open" and/or "Biometric unlock" turned on
/// (security_screen.dart). Tries biometric automatically if enabled, and
/// always offers the PIN pad as a fallback if a PIN is on file.
class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key, required this.onUnlocked, required this.biometricEnabled});

  final VoidCallback onUnlocked;
  final bool biometricEnabled;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final _pinSecurityRepository = PinSecurityRepository();
  static const _pinLength = 4;
  final _localAuth = LocalAuthentication();

  String _entered = '';
  String? _error;
  bool _hasPin = false;
  String? _hash;
  String? _salt;
  bool _checkingPin = true;
  bool _biometricAttempted = false;

  @override
  void initState() {
    super.initState();
    _checkPinExists();
    if (widget.biometricEnabled) {
      // Post-frame so the lock screen is actually visible before the OS
      // biometric prompt pops over it, rather than racing the build.
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  Future<void> _checkPinExists() async {
    // Checks this device's local cache first, and if this account was
    // never unlocked here before, pulls the PIN down from Firestore
    // instead (see PinSecurityRepository) — this is what makes a PIN set
    // on one device actually apply the first time you log in on another.
    final settings = await _pinSecurityRepository.load();
    if (!mounted) return;
    setState(() {
      _hasPin = settings.hasPin;
      _hash = settings.hash;
      _salt = settings.salt;
      _checkingPin = false;
    });
  }

  Future<void> _tryBiometric() async {
    if (_biometricAttempted) return;
    _biometricAttempted = true;
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Unlock Bantay Nuevo',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (ok) widget.onUnlocked();
    } catch (_) {
      // Device error, no biometrics enrolled, etc. — the PIN pad (if a PIN
      // is set) or the retry button below still gets them in.
    }
  }

  Future<void> _onDigit(String digit) async {
    if (_entered.length >= _pinLength) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length == _pinLength) {
      await _submitPin();
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _submitPin() async {
    final salt = _salt;
    final storedHash = _hash;
    if (salt == null || storedHash == null) {
      // Shouldn't happen if _hasPin gated the UI correctly, but fail open
      // rather than trap someone behind a PIN pad with nothing to check
      // against.
      widget.onUnlocked();
      return;
    }
    if (hashPin(_entered, salt) == storedHash) {
      widget.onUnlocked();
    } else {
      setState(() {
        _error = 'Incorrect PIN';
        _entered = '';
      });
    }
  }

  /// Recovery path for "I forgot my PIN" or "biometrics won't work on this
  /// device anymore" — turns app-lock off entirely and signs out. This is
  /// safe specifically because the PIN is a local convenience layer on top
  /// of an already-unlocked phone, not the app's real security boundary
  /// (that's Firebase Auth + Firestore rules) — someone who can tap this
  /// already has physical access to the unlocked device. The alternative,
  /// no escape hatch at all, risks permanently locking a resident out of
  /// reporting or SOS, which is worse.
  ///
  /// Clears the PIN via PinSecurityRepository — i.e. account-wide, not
  /// just this device — since the PIN is now an account-level setting
  /// (see that repository's doc comment). Leaving it set on the account
  /// while wiping only this device's cache would just mean it comes back
  /// the next time this device (or any other) syncs it from Firestore.
  Future<void> _forgotPin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Can't unlock?"),
        content: const Text(
          "This turns off app lock and signs you out. You'll need to log back in, and can set a new PIN "
          'afterward from Profile → App lock & security.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out', style: TextStyle(color: AppColors.urgent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _pinSecurityRepository.clearPin();
    await AuthRepository().logout();
    widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.lock_outline, size: 40, color: AppColors.navy),
              const SizedBox(height: 12),
              Text('Bantay Nuevo is locked', style: AppTypography.display(fontSize: 18)),
              const SizedBox(height: 6),
              Text(
                _hasPin ? 'Enter your PIN to continue' : 'Verify to continue',
                style: AppTypography.body(fontSize: 13, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 24),
              if (_checkingPin)
                const CircularProgressIndicator()
              else ...[
                if (_hasPin) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pinLength, (i) {
                      final filled = i < _entered.length;
                      return Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? AppColors.navy : Colors.transparent,
                          border: Border.all(color: AppColors.navy, width: 1.5),
                        ),
                      );
                    }),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: AppTypography.mono(fontSize: 11, color: AppColors.urgent)),
                  ],
                  const Spacer(),
                  PinKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
                ] else ...[
                  const Spacer(),
                  if (widget.biometricEnabled)
                    TextButton.icon(
                      onPressed: () {
                        _biometricAttempted = false;
                        _tryBiometric();
                      },
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Try again'),
                    ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _forgotPin,
                  child: Text(
                    "Can't unlock?",
                    style: AppTypography.mono(fontSize: 10.5, color: AppColors.inkSoft),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
