import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Registers this device's FCM token to users/{uid}.fcmToken so the
/// onSosCreated / onReportCreated Cloud Functions (Prompt 4.5) can actually
/// push to it — closing the gap noted in firebase/functions/index.js where
/// push silently no-oped because no screen ever saved a token.
///
/// Free on the Spark plan — does NOT require Blaze, unlike Storage.
class FcmService {
  FcmService._();

  /// Call once after a user signs in (see resident_home_screen.dart initState).
  /// Fails silently and logs in debug mode only — a device without a token
  /// just won't get push, SMS backup in the Cloud Function still covers it.
  static Future<void> registerToken(String uid) async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token != null) {
        await _saveToken(uid, token);
      }

      // Tokens can rotate — keep it current for the life of the app session.
      messaging.onTokenRefresh.listen((newToken) => _saveToken(uid, newToken));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FcmService.registerToken failed (non-fatal): $e');
      }
    }
  }

  static Future<void> _saveToken(String uid, String token) {
    return FirebaseFirestore.instance.collection('users').doc(uid).update({'fcmToken': token});
  }
}
