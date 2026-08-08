import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/report_model.dart';

/// Tanod-side report handling — sees ALL residents' reports (unlike the
/// resident-side ReportRepository, which filters to just their own).
class TanodReportRepository {
  TanodReportRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reports => _firestore.collection('reports');
  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  Stream<List<ReportModel>> streamAllReports() {
    return _reports
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ReportModel.fromFirestore(d.data(), d.id)).toList());
  }

  Stream<ReportModel> streamReport(String reportId) {
    return _reports.doc(reportId).snapshots().map((d) => ReportModel.fromFirestore(d.data()!, d.id));
  }

  Future<void> updateStatus(String reportId, ReportStatus status) {
    return _reports.doc(reportId).update({
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// tanodName isn't part of the reports schema (only assignedTanodId is,
  /// per AGENTS.md §5) — kept as a param for API symmetry with
  /// tanod_sos_repository.dart's acceptAlert, but only the id is written.
  /// Display screens look the name up via fetchUserName when needed.
  Future<void> assignToTanod(String reportId, String tanodId, String tanodName) {
    return _reports.doc(reportId).update({
      'assignedTanodId': tanodId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> fetchUserName(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['name'] as String?;
  }

  /// Append-only write to `accessLog` (AGENTS.md §8 — never overwrite or
  /// delete existing entries, this is what preserves the chain-of-custody
  /// trail once a tanod opens a report's evidence).
  Future<void> appendAccessLog(String reportId, String who) {
    return _reports.doc(reportId).update({
      'accessLog': FieldValue.arrayUnion([
        {'who': who, 'when': Timestamp.now()},
      ]),
    });
  }
}
