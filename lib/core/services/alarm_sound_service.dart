import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/sos_alert_model.dart';

/// Plays a distinct alarm sound on the tanod side depending on which
/// emergency type a resident picked when sending SOS (sos_screen.dart's
/// type-selection step).
///
/// Sound source, checked in this order:
/// 1. The org-wide sound set by a Barangay Admin (AdminAlarmSoundsScreen,
///    Prompt 14) — stored as a Cloudinary URL in the `config/alarm_sounds`
///    Firestore doc, one field per emergency type. This is intentionally
///    the SAME sound for every tanod's phone (the admin's call — a
///    per-tanod local picker was considered and dropped in favor of a
///    single, consistent, admin-controlled set everyone hears).
/// 2. The bundled default asset — see assets/sounds/README.md. Not
///    included in the repo; falls back to silence (logged in debug mode)
///    if neither an admin-set sound nor the default asset is present.
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

  /// Cached org-wide config, refreshed by a live Firestore listener so
  /// playback never needs to await a network round-trip at alert time —
  /// by the time an SOS actually lands, this is almost certainly already
  /// populated. Starts listening on first use and keeps listening for the
  /// lifetime of the app.
  static Map<String, String> _remoteUrls = {};
  static bool _listening = false;

  static void _ensureListening() {
    if (_listening) return;
    _listening = true;
    FirebaseFirestore.instance.collection('config').doc('alarm_sounds').snapshots().listen(
      (doc) {
        final data = doc.data() ?? {};
        _remoteUrls = data.map((key, value) => MapEntry(key, value as String));
      },
      onError: (e) {
        if (kDebugMode) debugPrint('AlarmSoundService: could not listen for config — $e');
      },
    );
  }

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
    _ensureListening();
    try {
      await _player.stop(); // don't stack overlapping alarms if several alerts land in quick succession
      final remoteUrl = _remoteUrls[type.value];
      if (remoteUrl != null) {
        await _player.play(UrlSource(remoteUrl));
      } else {
        await _player.play(AssetSource(_assetFor(type)));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AlarmSoundService: could not play sound for ${type.value} — $e');
      }
    }
  }
}
