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

  /// All non-closed, non-expired alerts, newest first. Single-field
  /// orderBy needs no composite index. Also does the "lazy expire" write:
  /// any tanod's app that notices a stale 'active' alert flips it to
  /// 'expired' — fire-and-forget, doesn't block this stream. The security
  /// rule only permits that exact transition, and only once the alert has
  /// genuinely aged past sosAlertValidityMinutes server-side, so this is
  /// safe for any tanod device to do, not just whichever one happens to
  /// be watching first. The .where() below also excludes stale-but-not-
  /// yet-persisted alerts immediately, so the UI never has to wait for
  /// that write to round-trip before hiding them.
  Stream<List<SosAlertModel>> streamOpenAlerts() {
    return _alerts.orderBy('createdAt', descending: true).limit(50).snapshots().map((snap) {
      final alerts = snap.docs.map((d) => SosAlertModel.fromFirestore(d.data(), d.id)).toList();

      for (final alert in alerts) {
        if (alert.status == SosStatus.active && alert.isExpired) {
          _alerts.doc(alert.id).update({'status': 'expired'}).catchError((_) {
            // Another client may have already flipped it, or a transient
            // network issue — either way nothing to surface here, the
            // filter below hides it from this UI regardless.
            return null;
          });
        }
      }

      return alerts
          .where((a) => a.status != SosStatus.closed && a.status != SosStatus.expired && !a.isExpired)
          .toList();
    });
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
    // Defense in depth — firestore.rules is the real enforcement (a
    // modified client can't bypass it), but checking here first means a
    // tanod who taps Accept on something that expired moments ago gets a
    // clear, friendly message instead of a raw permission-denied
    // exception surfacing from Firestore.
    final snap = await _alerts.doc(alertId).get();
    if (!snap.exists) {
      throw Exception('This alert no longer exists.');
    }
    final current = SosAlertModel.fromFirestore(snap.data()!, snap.id);
    if (current.status != SosStatus.active || current.isExpired) {
      throw Exception('This alert has expired and can no longer be accepted.');
    }

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
