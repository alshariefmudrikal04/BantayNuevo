import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/sos_alert_model.dart';
import '../../resident/data/notification_repository.dart';

/// Tanod-side SOS handling — accept an alert, mark arrived, stream live
/// location updates both ways, mark resolved. Each of those three actions
/// is a "key moment" that also writes a notification for the resident
/// (AGENTS.md §5 notifications schema) — see NotificationRepository.create.
class TanodSosRepository {
  TanodSosRepository({FirebaseFirestore? firestore, NotificationRepository? notificationRepository})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _notificationRepository = notificationRepository ?? NotificationRepository();

  final FirebaseFirestore _firestore;
  final NotificationRepository _notificationRepository;

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
    required String residentId,
    required String tanodId,
    required String tanodName,
    required double lat,
    required double lng,
  }) async {
    await _alerts.doc(alertId).update({
      'responderId': tanodId,
      'responderName': tanodName,
      'responderLocation': {'lat': lat, 'lng': lng},
      'status': 'responded',
    });
    await _notificationRepository.create(
      recipientId: residentId,
      message: '$tanodName accepted your SOS and is on the way.',
      relatedAlertId: alertId,
    );
  }

  /// Called repeatedly while this tanod is actively responding, so the
  /// resident's live-tracking view can actually follow them approaching.
  Future<void> updateMyLocation(String alertId, double lat, double lng) {
    return _alerts.doc(alertId).update({
      'responderLocation': {'lat': lat, 'lng': lng},
    });
  }

  /// Distinct from "resolved" — this is the tanod physically reaching the
  /// resident's location, a meaningful safety milestone on its own that
  /// the resident should be told about right away, even before the case
  /// is actually closed out.
  Future<void> markArrived({
    required String alertId,
    required String residentId,
    required String tanodName,
  }) async {
    await _alerts.doc(alertId).update({'status': 'arrived'});
    await _notificationRepository.create(
      recipientId: residentId,
      message: '$tanodName has arrived at your location.',
      relatedAlertId: alertId,
    );
  }

  Future<void> markResolved({
    required String alertId,
    required String residentId,
    required String tanodName,
  }) async {
    await _alerts.doc(alertId).update({'status': 'closed'});
    await _notificationRepository.create(
      recipientId: residentId,
      message: '$tanodName marked your SOS alert as resolved.',
      relatedAlertId: alertId,
    );
  }

  Future<String?> fetchUserName(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['name'] as String?;
  }
}
