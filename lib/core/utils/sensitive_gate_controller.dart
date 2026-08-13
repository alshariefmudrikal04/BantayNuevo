import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tracks whether the resident has already unlocked Reports/Evidence
/// during this app session, shared across every SensitiveContentGate
/// instance — so navigating My Reports → Report Detail → Evidence Vault
/// only prompts once, not three times in a row.
///
/// This intentionally does NOT gate the whole app (see app.dart) — an SOS
/// press has to work instantly in an emergency, so only the report/evidence
/// screens specifically ask for PIN/biometric, per the actual threat this
/// protects against: someone who took the resident's unlocked phone
/// specifically to see what was reported about them, not casual app use.
class SensitiveGateController with WidgetsBindingObserver {
  SensitiveGateController._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final SensitiveGateController instance = SensitiveGateController._internal();
  static const _storage = FlutterSecureStorage();

  DateTime? _unlockedAt;
  DateTime? _pausedAt;

  void markUnlocked() => _unlockedAt = DateTime.now();

  /// True if a prior unlock still counts. If "Auto-lock after 1 min idle"
  /// is off, an unlock lasts for the rest of the app session once granted
  /// — same semantics the old whole-app lock used, just scoped smaller now.
  Future<bool> isUnlocked() async {
    if (_unlockedAt == null) return false;
    final autoLock = await _storage.read(key: 'security_auto_lock') == 'true';
    if (!autoLock) return true;
    // With auto-lock on, a background gap of a minute or more (handled in
    // didChangeAppLifecycleState below) already would have cleared
    // _unlockedAt, so reaching here means either no gap occurred or it was
    // under a minute — still counts as unlocked.
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (pausedAt == null) return;

    _storage.read(key: 'security_auto_lock').then((value) {
      if (value != 'true') return; // auto-lock off — unlock persists regardless of idle time
      final idleFor = DateTime.now().difference(pausedAt);
      if (idleFor >= const Duration(minutes: 1)) {
        _unlockedAt = null;
      }
    });
  }
}
