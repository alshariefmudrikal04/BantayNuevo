import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/sos_alert_model.dart';

/// Talks to the `sos_alerts` collection and looks up responder phone numbers
/// by role — used for both the online (Firestore write, Cloud Function
/// notifies everyone) and offline (on-device SMS) paths in sos_screen.dart.
/// Also handles the live-tracking piece: streaming the resident's own
/// location while the alert is active, and watching for a responder's
/// location once a tanod/police accepts.
///
/// Emergency contact lookup (fetchEmergencyContactNumbers below) mirrors
/// what the online path's onSosCreated Cloud Function already does via
/// PhilSMS — this is what lets the offline SMS path reach the same
/// numbers when there's no internet at all to trigger that function.
class SosRepository {
  SosRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _alerts => _firestore.collection('sos_alerts');
  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  /// ONLINE path: just write the alert doc. The onSosCreated Cloud Function
  /// (Prompt 4.5) picks this up and handles push-notifying tanod/police plus
  /// texting emergency contacts — nothing else to do client-side.
  /// Returns the new alert's id, needed for the live-tracking view.
  /// createdAt uses Timestamp.now() rather than FieldValue.serverTimestamp()
  /// — the tanod's streamOpenAlerts() orders by createdAt, and a
  /// server-timestamp write shows up locally as null for a moment before
  /// the server round-trip resolves, which makes brand-new alerts briefly
  /// disappear from the active list right after creation. Not acceptable
  /// for something this time-critical.
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
      'createdAt': Timestamp.now(),
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
        'createdAt': Timestamp.now(),
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

  /// This resident's saved emergency contact numbers — the same numbers
  /// the online path's onSosCreated Cloud Function already texts via
  /// Semaphore. Used here so the offline on-device SMS path (sos_screen.dart)
  /// reaches them too, since AGENTS.md §2 treats this as their ONLY channel
  /// regardless of whether the resident has internet at the moment.
  Future<List<String>> fetchEmergencyContactNumbers(String residentId) async {
    final snap = await _firestore.collection('emergency_contacts').where('residentId', isEqualTo: residentId).get();
    return snap.docs
        .map((d) => d.data()['phone'] as String? ?? '')
        .where((phone) => phone.isNotEmpty)
        .toList();
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
