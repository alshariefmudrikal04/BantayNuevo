import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/sos_alert_model.dart';

/// Talks to the `sos_alerts` collection. Per thesis scope, there is only
/// one path: write the alert doc, and the onSosCreated Cloud Function
/// (firebase/functions/index.js) handles everything downstream — pushing
/// to tanod, texting every saved emergency contact via PhilSMS with the
/// resident's location, and a backup SMS ping to tanod. Nothing here talks
/// to PhilSMS directly; that only happens server-side.
///
/// Also handles the live-tracking piece: streaming the resident's own
/// location while the alert is active, and watching for a responder's
/// location once tanod accepts.
class SosRepository {
  SosRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _alerts => _firestore.collection('sos_alerts');

  /// Writes the alert doc. The onSosCreated Cloud Function picks this up
  /// and handles push-notifying tanod plus texting emergency contacts via
  /// PhilSMS — nothing else to do client-side. Returns the new alert's id,
  /// needed for the live-tracking view.
  ///
  /// createdAt uses Timestamp.now() rather than FieldValue.serverTimestamp()
  /// — the tanod's streamOpenAlerts() orders by createdAt, and a
  /// server-timestamp write shows up locally as null for a moment before
  /// the server round-trip resolves, which makes brand-new alerts briefly
  /// disappear from the active list right after creation. Not acceptable
  /// for something this time-critical.
  Future<String> createOnlineAlert({
    required String residentId,
    required String escalationTarget, // always "tanod" — see sos_screen.dart
    required EmergencyType emergencyType,
    required double lat,
    required double lng,
  }) async {
    final docRef = await _alerts.add({
      'residentId': residentId,
      'escalationTarget': escalationTarget,
      'emergencyType': emergencyType.value,
      'location': {'lat': lat, 'lng': lng},
      'responderId': null,
      'responderName': null,
      'responderLocation': null,
      'deliveryMethod': 'app',
      'contactsNotified': <String>[],
      'status': 'active',
      'createdAt': Timestamp.now(),
    });
    return docRef.id;
  }

  /// Looks up whether this resident already has a non-closed alert —
  /// called from SosScreen.initState() so reopening the SOS screen (after
  /// backing out with the device back button, switching apps and getting
  /// killed by the OS, etc.) resumes live tracking instead of always
  /// resetting to the panic button. Firestore is the source of truth here
  /// on purpose: the alert's real status doesn't live in this screen's
  /// local state, so anything that can dispose that state (navigation,
  /// process death) shouldn't be able to silently "lose" an active SOS.
  Future<SosAlertModel?> fetchActiveAlert(String residentId) async {
    final snap = await _alerts
        .where('residentId', isEqualTo: residentId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final alert = SosAlertModel.fromFirestore(snap.docs.first.data(), snap.docs.first.id);
    return alert.status == SosStatus.closed ? null : alert;
  }

  /// Live stream of one alert — the resident's live-tracking view watches
  /// this for status changes and the responder's location once accepted.
  /// Also performs the same lazy-expire write TanodSosRepository.
  /// streamOpenAlerts() does — either side noticing a stale 'active' alert
  /// can persist 'expired', not just a tanod's device. The security rule
  /// permits this exact transition from either role, and only once the
  /// alert has genuinely aged out server-side.
  Stream<SosAlertModel> streamAlert(String alertId) {
    return _alerts.doc(alertId).snapshots().map((d) {
      final alert = SosAlertModel.fromFirestore(d.data()!, d.id);
      if (alert.status == SosStatus.active && alert.isExpired) {
        _alerts.doc(alertId).update({'status': 'expired'}).catchError((_) => null);
      }
      return alert;
    });
  }

  /// Called repeatedly (every few seconds) while the SOS screen is open and
  /// the alert is still active — keeps the resident's location current so a
  /// responding tanod can actually follow them, not just see where they
  /// were the moment they pressed the button.
  Future<void> updateMyLocation(String alertId, double lat, double lng) {
    return _alerts.doc(alertId).update({'location': {'lat': lat, 'lng': lng}});
  }

  /// Resident-initiated — marks the alert closed (e.g. "I'm safe now" /
  /// false alarm), stopping the live-tracking loop on both ends.
  Future<void> markResolved(String alertId) {
    return _alerts.doc(alertId).update({'status': 'closed'});
  }

  /// Records which emergency contacts were successfully texted for this
  /// alert — same bookkeeping onSosCreated does server-side
  /// (`contactsNotified` in the Cloud Function), kept here too now that
  /// sos_screen.dart sends the SMS itself client-side (see
  /// PhilSmsService / philsms_config.dart's doc comments for why).
  Future<void> markContactsNotified(String alertId, List<String> contactIds) {
    return _alerts.doc(alertId).update({'contactsNotified': contactIds});
  }
}
