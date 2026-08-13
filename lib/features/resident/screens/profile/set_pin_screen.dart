import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/pin_hash.dart';
import '../../../../core/widgets/pin_keypad.dart';

/// Pushed from security_screen.dart the first time someone turns on
/// "Require PIN on open" (or taps "Change PIN" afterward). Returns `true`
/// via Navigator.pop if a PIN was successfully set, so the caller knows
/// whether to actually flip the toggle on — cancelling or backing out
/// leaves the previous PIN (if any) untouched.
class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  static const _storage = FlutterSecureStorage();
  static const _pinLength = 4;

  String? _firstEntry;
  String _entered = '';
  String? _error;

  bool get _isConfirmStage => _firstEntry != null;

  void _onDigit(String digit) {
    if (_entered.length >= _pinLength) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length == _pinLength) {
      _handleComplete();
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _handleComplete() async {
    if (!_isConfirmStage) {
      // First pass done — move to confirmation, don't save yet.
      setState(() {
        _firstEntry = _entered;
        _entered = '';
      });
      return;
    }
    if (_entered == _firstEntry) {
      final salt = generatePinSalt();
      final hash = hashPin(_entered, salt);
      await _storage.write(key: 'security_pin_salt', value: salt);
      await _storage.write(key: 'security_pin_hash', value: hash);
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = "PINs didn't match — start over";
        _firstEntry = null;
        _entered = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(_isConfirmStage ? 'Confirm your PIN' : 'Set a PIN')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              _isConfirmStage ? 'Enter it again to confirm' : 'Choose a 4-digit PIN to protect the app',
              style: AppTypography.body(fontSize: 13, color: AppColors.inkSoft),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
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
              const SizedBox(height: 12),
              Text(_error!, style: AppTypography.mono(fontSize: 11, color: AppColors.urgent)),
            ],
            const Spacer(),
            PinKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

