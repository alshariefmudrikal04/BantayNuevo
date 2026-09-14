import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';
import '../../models/sos_alert_model.dart';
import 'push_channel_service.dart';

/// Keeps tanod alerting alive with the app closed, WITHOUT Cloud Functions
/// or FCM push (this project deliberately isn't on the Blaze plan — see
/// the conversation this was built from). Instead, this runs the app's own
/// SOS listener inside an Android foreground service: a persistent
/// "monitoring for alerts" notification keeps Android from killing the
/// process, and the moment a new active alert shows up, it fires a local
/// notification through one of PushChannelService's pre-made channels —
/// same sound + vibration an FCM push would have given, just triggered by
/// this device's own listener instead of a server.
///
/// Mirrors TanodHomeScreen._checkForNewAlerts' dedup logic exactly (skip
/// whatever's already sitting there on first snapshot, only alarm on
/// alerts that show up afterwards) so a restart of this service doesn't
/// replay every existing active alert as if it were new.
///
/// Tanod-only for now: police doesn't have an open alert pool to monitor
/// yet (see police_repository.dart's own doc comment on escalationTarget/
/// 'pnp' auto-routing not existing yet) — wire this up for police too
/// once that lands, the same way TanodHomeScreen does today.
///
/// Trade-offs vs. a real server push, worth knowing:
/// - Android can still kill this under aggressive battery optimization on
///   some phones (Xiaomi/Huawei/Oppo especially) — ask tanods to exempt
///   the app from battery optimization in their phone's settings.
/// - Doesn't survive the phone being fully powered off.
/// - Slightly more battery drain than no background process at all,
///   though a single idle Firestore listener is fairly light.
class BackgroundAlertService {
  BackgroundAlertService._();

  static const _notificationId = 888;
  static const _channelId = 'tanod_monitoring';

  /// Call once at app startup (main.dart) — creates the plain low-key
  /// channel the foreground service's own persistent "monitoring" tray
  /// notification needs to exist BEFORE the service can start (Android
  /// throws and crashes the app if a foreground service points at a
  /// notification channel that hasn't been created yet — this is that
  /// creation step). Doesn't start listening for alerts yet; that only
  /// happens once a tanod is actually logged in — see [start].
  static Future<void> initialize() async {
    // flutter_background_service has no web implementation — calling it
    // there throws before runApp() ever renders, which is why this was
    // showing a blank white page on Chrome. "Keep running after the
    // browser tab is closed" isn't something a website can do anyway, so
    // this feature is Android/iOS-app-only by design.
    if (kIsWeb || !Platform.isAndroid) return;

    final notifications = FlutterLocalNotificationsPlugin();
    await notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'Background monitoring',
            description: 'Persistent notification while monitoring for SOS alerts in the background.',
            importance: Importance.low,
          ),
        );

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'Bantay Nuevo',
        initialNotificationContent: 'Monitoring for SOS alerts…',
        foregroundServiceNotificationId: _notificationId,
      ),
      // iOS background execution is far more restricted by Apple than
      // Android's foreground-service model — this is Android-only for
      // now. On iOS, alerts still work fine while the app is open or
      // freshly backgrounded, just not once fully swiped away.
      iosConfiguration: IosConfiguration(autoStart: false),
    );
  }

  /// Call right after a tanod logs in (TanodHomeScreen.initState). Safe
  /// to call if it's already running — flutter_background_service no-ops
  /// a second startService() call.
  static Future<void> start() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
  }

  /// Call on logout — otherwise the service keeps listening (and
  /// alarming!) for whichever account was last signed in on this device,
  /// even after they've logged out of the app itself.
  static Future<void> stop() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stop');
    }
  }

  /// Runs in its own isolate — separate from the main app's Dart
  /// isolate/widget tree entirely, hence re-initializing Firebase and
  /// local notifications from scratch here.
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Bantay Nuevo',
        content: 'Monitoring for SOS alerts…',
      );
    }

    var initialLoadDone = false;
    final seenAlertIds = <String>{};

    final subscription = FirebaseFirestore.instance
        .collection('sos_alerts')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) async {
      final alerts = snapshot.docs.map((d) => SosAlertModel.fromFirestore(d.data(), d.id)).toList();

      if (!initialLoadDone) {
        seenAlertIds.addAll(alerts.map((a) => a.id));
        initialLoadDone = true;
        return;
      }

      for (final alert in alerts) {
        final isNew = seenAlertIds.add(alert.id);
        if (isNew && alert.status == SosStatus.active) {
          await notifications.show(
            alert.id.hashCode,
            'SOS Alert — ${alert.emergencyType.label}',
            'A resident triggered an SOS — respond now.',
            NotificationDetails(
              android: AndroidNotificationDetails(
                PushChannelService.channelIdFor(alert.emergencyType),
                'SOS Alert — ${alert.emergencyType.label}',
                importance: Importance.max,
                priority: Priority.max,
                fullScreenIntent: true,
              ),
            ),
          );
        }
      }
    });

    service.on('stop').listen((event) {
      subscription.cancel();
      service.stopSelf();
    });
  }
}