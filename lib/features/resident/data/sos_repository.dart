import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/sos_alert_model.dart';

/// Talks to the `sos_alerts` collection and looks up responder phone numbers
/// by role — used for both the online (Firestore write, Cloud Function
/// notifies everyone) and offline (on-device SMS) paths in sos_screen.dart.
/// Also handles the live-tracking piece: streaming the resident's own
/// location while the alert is active, and watching for a responder's
/// location once a tanod/police accepts.
///
/// Note: emergency_contacts lookup isn't wired in here yet — that collection
/// is built in Prompt 7. Once it exists, add a fetchEmergencyContactNumbers()
/// method here and include those numbers in both the online Cloud Function
/// (Prompt 4.5) and the offline SMS list below.
class SosRepository {
  SosRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _alerts => _firestore.collection('sos_alerts');
  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  /// ONLINE path: just write the alert doc. The onSosCreated Cloud Function
  /// (Prompt 4.5) picks this up and handles push-notifying tanod/police plus
  /// texting emergency contacts — nothing else to do client-side.
  /// Returns the new alert's id, needed for the live-tracking view.
  Future<String> createOnlineAlert({
    required String residentId,
    required String escalationTarget, // "auto" | "tanod" | "pnp"
    required double lat,
    required double lng,
  }) async {
    final docRef = await _alerts.add({
      'residentId': residentId,
      'escalationTarget': escalationTarget,
      'location': {'lat': lat, 'lng': lng},
      'responderId': null,
      'responderName': null,
      'responderLocation': null,
      'deliveryMethod': 'app',
      'contactsNotified': <String>[],
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// OFFLINE path: log what we can for later reference once connectivity
  /// returns (best-effort — this write will simply fail silently if there's
  /// truly no signal at all, which is fine, the SMS already went out
  /// separately via the device's own SIM in sos_screen.dart).
  Future<void> logOfflineAlertAttempt({
    required String residentId,
    required String escalationTarget,
    required double lat,
    required double lng,
  }) async {
    try {
      await _alerts.add({
        'residentId': residentId,
        'escalationTarget': escalationTarget,
        'location': {'lat': lat, 'lng': lng},
        'deliveryMethod': 'sms',
        'contactsNotified': <String>[],
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Expected when truly offline — the SMS itself is what matters here.
    }
  }

  /// Phone numbers for every user with the given role — used to address the
  /// offline SMS. role is "tanod" or "police".
  Future<List<String>> fetchPhoneNumbersForRole(String role) async {
    final snap = await _users.where('role', isEqualTo: role).get();
    return snap.docs
        .map((d) => d.data()['phone'] as String? ?? '')
        .where((phone) => phone.isNotEmpty)
        .toList();
  }

  /// Live stream of one alert — the resident's live-tracking view watches
  /// this for status changes and the responder's location once accepted.
  Stream<SosAlertModel> streamAlert(String alertId) {
    return _alerts.doc(alertId).snapshots().map((d) => SosAlertModel.fromFirestore(d.data()!, d.id));
  }

  /// Called repeatedly (every few seconds) while the SOS screen is open and
  /// the alert is still active — keeps the resident's location current so a
  /// responding tanod/police can actually follow them, not just see where
  /// they were the moment they pressed the button.
  Future<void> updateMyLocation(String alertId, double lat, double lng) {
    return _alerts.doc(alertId).update({'location': {'lat': lat, 'lng': lng}});
  }

  /// Resident-initiated — marks the alert closed (e.g. "I'm safe now" /
  /// false alarm), stopping the live-tracking loop on both ends.
  Future<void> markResolved(String alertId) {
    return _alerts.doc(alertId).update({'status': 'closed'});
  }
}
