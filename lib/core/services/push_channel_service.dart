import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../models/sos_alert_model.dart';

/// Creates the Android notification channels that make a background/closed
/// -app SOS push actually vibrate and sound like an emergency, not just a
/// generic "ding".
///
/// Why this has to exist at all: AlarmSoundService already plays a
/// distinct sound + vibration per EmergencyType, but ONLY while a tanod's
/// app is open — it reacts to a live Firestore stream, so it can't run
/// when the app is closed. Making an alert vibrate/sound while the app is
/// closed has to happen through the OS notification system instead (via
/// the FCM push in firebase/functions/index.js's onSosCreated), and on
/// Android 8+ that system has one hard rule: a notification channel's
/// sound and vibration pattern are locked in the moment the channel is
/// first created on the device, and can NEVER be changed remotely by a
/// later push — only the *choice of which channel to use* travels with
/// the push (see the channelId sent from onSosCreated). So each possible
/// sound has to have its own pre-made channel sitting on the device
/// before any push arrives, which is what this does at app startup.
///
/// One channel per EmergencyType (so each has its own bundled sound),
/// all sharing the same vibration pattern AlarmSoundService already uses
/// in the foreground ([0, 800, 400, 800, 400, 800] — three long pulses),
/// so a closed-app alert feels the same as an open-app one. Plus one
/// plain channel for non-SOS incident reports.
///
/// Sound files: Android notification-channel sounds must be bundled
/// native resources, NOT the Cloudinary URLs / assets/sounds/*.mp3 files
/// AlarmSoundService can stream — the OS plays these itself, it can't
/// fetch a URL first. Drop matching files into
/// android/app/src/main/res/raw/ — see the README there for exact names.
/// A channel still gets created without the file present, it just falls
/// back to the OS default sound until you add it (Android silently
/// ignores an unresolvable sound resource rather than crashing).
class PushChannelService {
  PushChannelService._();

  static const _vibrationPattern = [0, 800, 400, 800, 400, 800];

  static const _reportsChannelId = 'reports';

  static String channelIdFor(EmergencyType type) => 'sos_${type.value}';

  /// Call once, early in main() before runApp — see main.dart. Safe to
  /// call every app launch; creating a channel that already exists with
  /// identical settings is a no-op on Android.
  static Future<void> setup() async {
    final plugin = FlutterLocalNotificationsPlugin();
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return; // no-op on iOS/web/desktop — APNs handles its own sound

    for (final type in EmergencyType.values) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          channelIdFor(type),
          'SOS Alert — ${type.label}',
          description: 'Emergency alerts for "${type.label}" — plays even when the app is closed.',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(type.value),
          enableVibration: true,
          vibrationPattern: Int64List.fromList(_vibrationPattern),
        ),
      );
    }

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _reportsChannelId,
        'New incident reports',
        description: 'Non-emergency report notifications.',
        importance: Importance.high,
      ),
    );
  }
}
