import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/sos_alert_model.dart';

/// Tanod-side SOS handling — accept an alert, stream live location updates
/// both ways, mark resolved. This is the first slice of Prompt 9 (Tanod):
/// scoped to SOS response only, the full dashboard/report review comes later.
class TanodSosRepository {
  TanodSosRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _alerts => _firestore.collection('sos_alerts');
  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  /// All non-closed alerts, newest first. Single-field orderBy needs no
  /// composite index — "active vs. already responded" is filtered
  /// client-side here rather than adding a where() clause that would.
  Stream<List<SosAlertModel>> streamOpenAlerts() {
    return _alerts.orderBy('createdAt', descending: true).limit(50).snapshots().map(
          (snap) => snap.docs
              .map((d) => SosAlertModel.fromFirestore(d.data(), d.id))
              .where((a) => a.status != SosStatus.closed)
              .toList(),
        );
  }

  Stream<SosAlertModel> streamAlert(String alertId) {
    return _alerts.doc(alertId).snapshots().map((d) => SosAlertModel.fromFirestore(d.data()!, d.id));
  }

  Future<void> acceptAlert({
    required String alertId,
    required String tanodId,
    required String tanodName,
    required double lat,
    required double lng,
  }) {
    return _alerts.doc(alertId).update({
      'responderId': tanodId,
      'responderName': tanodName,
      'responderLocation': {'lat': lat, 'lng': lng},
      'status': 'responded',
    });
  }

  /// Called repeatedly while this tanod is actively responding, so the
  /// resident's live-tracking view can actually follow them approaching.
  Future<void> updateMyLocation(String alertId, double lat, double lng) {
    return _alerts.doc(alertId).update({
      'responderLocation': {'lat': lat, 'lng': lng},
    });
  }

  Future<void> markResolved(String alertId) {
    return _alerts.doc(alertId).update({'status': 'closed'});
  }

  Future<String?> fetchUserName(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['name'] as String?;
  }
}
