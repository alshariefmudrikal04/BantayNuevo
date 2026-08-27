import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../../models/sos_alert_model.dart';

/// Plays a distinct alarm sound on the tanod side depending on which
/// emergency type a resident picked when sending SOS (sos_screen.dart's
/// type-selection step). See assets/sounds/README.md — the actual .mp3
/// files aren't bundled, you need to supply real audio and drop it in
/// that folder with the exact filenames listed there.
///
/// This only plays while a tanod's app is actually open and running (the
/// SOS list screen is what triggers it, on noticing a new alert in the
/// stream) — there's no OS-level background notification sound involved,
/// since that needs Cloud Functions + FCM push, which this project isn't
/// running on Blaze for right now. See tanod_sos_screen.dart for where
/// this gets called.
class AlarmSoundService {
  AlarmSoundService._();

  static final _player = AudioPlayer();

  static String _assetFor(EmergencyType type) => switch (type) {
        EmergencyType.physicalViolence => 'sounds/physical_violence.mp3',
        EmergencyType.domesticViolence => 'sounds/domestic_violence.mp3',
        EmergencyType.threats => 'sounds/threats.mp3',
        EmergencyType.minorAbuse => 'sounds/minor_abuse.mp3',
        EmergencyType.other => 'sounds/other.mp3',
      };

  /// Fails silently (just logs in debug mode) rather than throwing — a
  /// missing or corrupt sound file should never crash the app or block a
  /// tanod from actually seeing/responding to the alert itself, which
  /// matters far more than the sound cue does.
  static Future<void> play(EmergencyType type) async {
    try {
      await _player.stop(); // don't stack overlapping alarms if several alerts land in quick succession
      await _player.play(AssetSource(_assetFor(type)));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AlarmSoundService: could not play sound for ${type.value} — $e');
      }
    }
  }
}
