import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/sos_alert_model.dart';
import '../../../models/report_model.dart';
import '../../resident/data/notification_repository.dart';

/// Police-side data access. Unlike TanodSosRepository/TanodReportRepository
/// — which show every open alert/report for any tanod to self-assign —
/// police only ever see what's already assigned TO them specifically
/// (responderId / assignedTanodId == their own uid). That assignment
/// currently always comes from a Barangay Admin (see
/// AdminRepository.assignSosResponder / assignReportResponder); there's no
/// self-serve "open pool" for police the way tanod has one, since nothing
/// in the app yet auto-routes an alert's escalationTarget to 'pnp' — see
/// SosAlertModel's doc comment on that field. If/when auto-escalation to
/// police gets built, a streamEscalatedOpenAlerts() using that field would
/// slot in here the same way TanodSosRepository.streamOpenAlerts does.
class PoliceRepository {
  PoliceRepository({FirebaseFirestore? firestore, NotificationRepository? notificationRepository})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _notificationRepository = notificationRepository ?? NotificationRepository();

  final FirebaseFirestore _firestore;
  final NotificationRepository _notificationRepository;

  CollectionReference<Map<String, dynamic>> get _alerts => _firestore.collection('sos_alerts');
  CollectionReference<Map<String, dynamic>> get _reports => _firestore.collection('reports');
  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  // ---------------------------------------------------------------------
  // SOS alerts assigned to this police officer
  // ---------------------------------------------------------------------

  /// Sorted client-side rather than via Firestore's own orderBy — a
  /// .where() + .orderBy() on different fields needs a composite index
  /// (an extra manual step in the Firebase console), and a single police
  /// officer's own alert list is small enough that sorting the already-
  /// fetched results in Dart is simpler and needs zero extra setup.
  Stream<List<SosAlertModel>> streamMyAlerts(String policeUid) {
    return _alerts.where('responderId', isEqualTo: policeUid).snapshots().map((snap) {
      final alerts = snap.docs.map((d) => SosAlertModel.fromFirestore(d.data(), d.id)).toList();
      alerts.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return alerts;
    });
  }

  Stream<SosAlertModel> streamAlert(String alertId) {
    return _alerts.doc(alertId).snapshots().map((d) => SosAlertModel.fromFirestore(d.data()!, d.id));
  }

  /// Called repeatedly while responding, same as TanodSosRepository's
  /// version, so the resident's live-tracking view follows a police
  /// responder approaching exactly the same way it follows a tanod.
  Future<void> updateMyLocation(String alertId, double lat, double lng) {
    return _alerts.doc(alertId).update({
      'responderLocation': {'lat': lat, 'lng': lng},
    });
  }

  Future<void> markArrived({
    required String alertId,
    required String residentId,
    required String policeName,
  }) async {
    await _alerts.doc(alertId).update({'status': 'arrived'});
    await _notificationRepository.create(
      recipientId: residentId,
      message: '$policeName has arrived at your location.',
      relatedAlertId: alertId,
    );
  }

  Future<void> markResolved({
    required String alertId,
    required String residentId,
    required String policeName,
  }) async {
    await _alerts.doc(alertId).update({'status': 'closed'});
    await _notificationRepository.create(
      recipientId: residentId,
      message: '$policeName marked your SOS alert as resolved.',
      relatedAlertId: alertId,
    );
  }

  // ---------------------------------------------------------------------
  // Incident reports assigned to this police officer
  // ---------------------------------------------------------------------

  Stream<List<ReportModel>> streamMyReports(String policeUid) {
    return _reports
        .where('assignedTanodId', isEqualTo: policeUid) // generic responder-id field, see AdminRepository's doc comment on it
        .snapshots()
        .map((snap) {
      final reports = snap.docs.map((d) => ReportModel.fromFirestore(d.data(), d.id)).toList();
      reports.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return reports;
    });
  }

  Stream<ReportModel> streamReport(String reportId) {
    return _reports.doc(reportId).snapshots().map((d) => ReportModel.fromFirestore(d.data()!, d.id));
  }

  Future<void> updateStatus(
    String reportId,
    ReportStatus status, {
    String? residentId,
    String? policeName,
  }) async {
    await _reports.doc(reportId).update({
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (status == ReportStatus.resolved && residentId != null) {
      await _notificationRepository.create(
        recipientId: residentId,
        message: '${policeName ?? 'A police responder'} marked your report as resolved.',
        relatedReportId: reportId,
      );
    }
  }

  Future<String?> fetchUserName(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['name'] as String?;
  }

  /// Same append-only chain-of-custody log tanod writes to — police
  /// viewing evidence is just as much an access event worth recording.
  Future<void> appendAccessLog(String reportId, String who) {
    return _reports.doc(reportId).update({
      'accessLog': FieldValue.arrayUnion([
        {'who': who, 'when': Timestamp.now()},
      ]),
    });
  }
}
