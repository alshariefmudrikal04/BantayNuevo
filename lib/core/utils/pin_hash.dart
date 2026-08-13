import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Hashes a PIN with a per-install random salt before it ever touches
/// storage — even though flutter_secure_storage is already encrypted at
/// rest (Android Keystore / iOS Keychain), this means the actual 4-digit
/// PIN itself is never persisted anywhere, only proof that a matching
/// digit sequence was entered.
String hashPin(String pin, String salt) {
  final bytes = utf8.encode('$salt:$pin');
  return sha256.convert(bytes).toString();
}

/// One random salt generated at PIN-creation time and stored alongside
/// the hash — see set_pin_screen.dart.
String generatePinSalt() {
  final random = Random.secure();
  return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
