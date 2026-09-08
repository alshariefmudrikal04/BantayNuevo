import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// What a device knows about the signed-in account's PIN, either from its
/// own local cache or freshly synced from Firestore. See PinSecurityRepository.
class PinSecuritySettings {
  const PinSecuritySettings({this.hash, this.salt, required this.pinOnOpen});

  final String? hash;
  final String? salt;
  final bool pinOnOpen;

  bool get hasPin => hash != null && salt != null;
}

/// Makes the resident's PIN an account-level setting instead of a
/// per-device one — set it on your phone, and logging into the app on a
/// different device (or after reinstalling) enforces the same PIN and
/// the same "require PIN on open" toggle, rather than each install
/// starting from zero. This is what closes the actual security gap the
/// old device-only version had: someone who reinstalls the app on a
/// stolen phone, or logs into your account on another device, used to
/// bypass app-lock entirely just by virtue of it never having been set
/// up there.
///
/// Firestore (`pin_security/{uid}`) is the source of truth; the device's
/// own flutter_secure_storage is kept as a synced cache purely so PIN
/// checks stay instant and work offline once synced at least once — see
/// firestore.rules, which scopes this collection strictly to
/// `request.auth.uid == uid` (nobody else's account, unlike the broader
/// `users/{uid}` collection's current "any authenticated user" rule).
///
/// Biometric-unlock and auto-lock-after-idle stay device-local on
/// purpose (security_screen.dart) — biometric hardware is inherently
/// per-device, and there's no real security reason to sync an idle-lock
/// timeout.
class PinSecurityRepository {
  PinSecurityRepository({FirebaseFirestore? firestore, fb_auth.FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb_auth.FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final fb_auth.FirebaseAuth _auth;
  static const _storage = FlutterSecureStorage();

  DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('pin_security').doc(uid);
  }

  /// Called from set_pin_screen.dart on a new/changed PIN.
  Future<void> setPin(String hash, String salt) async {
    await _storage.write(key: 'security_pin_hash', value: hash);
    await _storage.write(key: 'security_pin_salt', value: salt);
    await _doc?.set({'pinHash': hash, 'pinSalt': salt}, SetOptions(merge: true));
  }

  /// The "Require PIN to view Reports & Evidence" toggle itself — synced
  /// so turning it on on one device means it's on everywhere, which is
  /// the actual behavior asked for: security settings shouldn't reset
  /// just because you're on a different phone.
  Future<void> setPinOnOpen(bool value) async {
    await _storage.write(key: 'security_pin_on_open', value: value.toString());
    await _doc?.set({'pinOnOpen': value}, SetOptions(merge: true));
  }

  /// "Forgot PIN" (pin_lock_screen.dart) — clears everywhere, not just
  /// this device, since leaving it set on the account but wiped locally
  /// would just recreate the exact device-mismatch problem this whole
  /// repository exists to fix.
  Future<void> clearPin() async {
    await _storage.delete(key: 'security_pin_hash');
    await _storage.delete(key: 'security_pin_salt');
    await _storage.delete(key: 'security_pin_on_open');
    await _doc?.set({
      'pinHash': FieldValue.delete(),
      'pinSalt': FieldValue.delete(),
      'pinOnOpen': false,
    }, SetOptions(merge: true));
  }

  /// Reads local cache first (fast, offline-friendly). Only reaches out
  /// to Firestore if this device has no local PIN cached yet — e.g. the
  /// very first PIN check after logging into this account on a device
  /// that never set one up here before — and caches whatever it finds
  /// locally so every check after this one is instant again, same as the
  /// old fully-local version was.
  Future<PinSecuritySettings> load() async {
    var hash = await _storage.read(key: 'security_pin_hash');
    var salt = await _storage.read(key: 'security_pin_salt');
    var onOpen = await _storage.read(key: 'security_pin_on_open') == 'true';

    if (hash == null) {
      try {
        final snap = await _doc?.get();
        final data = snap?.data();
        if (data != null) {
          hash = data['pinHash'] as String?;
          salt = data['pinSalt'] as String?;
          onOpen = data['pinOnOpen'] as bool? ?? onOpen;
          if (hash != null && salt != null) {
            await _storage.write(key: 'security_pin_hash', value: hash);
            await _storage.write(key: 'security_pin_salt', value: salt);
            await _storage.write(key: 'security_pin_on_open', value: onOpen.toString());
          }
        }
      } catch (_) {
        // Offline on a device that's never synced this account's PIN
        // before — fail open (no PIN found) rather than trap someone
        // behind a lock screen with nothing to check against and no
        // network to fetch it. Once they're back online, the next check
        // syncs normally.
      }
    }
    return PinSecuritySettings(hash: hash, salt: salt, pinOnOpen: onOpen);
  }
}
