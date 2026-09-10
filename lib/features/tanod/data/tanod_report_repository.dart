import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/report_model.dart';
import '../../../core/services/cloudinary_uploader.dart';
import '../../resident/data/notification_repository.dart';

/// Tanod-side report handling — sees ALL residents' reports (unlike the
/// resident-side ReportRepository, which filters to just their own).
class TanodReportRepository {
  TanodReportRepository({FirebaseFirestore? firestore, NotificationRepository? notificationRepository})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _notificationRepository = notificationRepository ?? NotificationRepository();

  final FirebaseFirestore _firestore;
  final NotificationRepository _notificationRepository;

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

  /// Notifies the resident only when the new status is "resolved" — the
  /// case being closed is a key moment worth a notification; toggling
  /// between pending/in-progress isn't (that's already visible live on
  /// the resident's own Report Detail screen). residentId/tanodName are
  /// optional so this can still be called without them if a caller ever
  /// doesn't have them handy — it just skips the notification in that case.
  Future<void> updateStatus(
    String reportId,
    ReportStatus status, {
    String? residentId,
    String? tanodName,
  }) async {
    await _reports.doc(reportId).update({
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (status == ReportStatus.resolved && residentId != null) {
      await _notificationRepository.create(
        recipientId: residentId,
        message: '${tanodName ?? 'A tanod'} marked your report as resolved.',
        relatedReportId: reportId,
      );
    }
  }

  /// tanodName isn't part of the reports schema (only assignedTanodId is,
  /// per AGENTS.md §5) — kept as a param for API symmetry with
  /// tanod_sos_repository.dart's acceptAlert, but only the id is written.
  /// Display screens look the name up via fetchUserName when needed.
  /// residentId is optional the same way as updateStatus above — only
  /// used to send the "you've been assigned a tanod" notification.
  Future<void> assignToTanod(
    String reportId,
    String tanodId,
    String tanodName, {
    String? residentId,
  }) async {
    await _reports.doc(reportId).update({
      'assignedTanodId': tanodId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (residentId != null) {
      await _notificationRepository.create(
        recipientId: residentId,
        message: '$tanodName was assigned to your report.',
        relatedReportId: reportId,
      );
    }
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

  /// Adds one entry to the report's case log — a tanod documenting a site
  /// visit, a general update, or (once the report is being marked
  /// resolved) what was actually agreed/settled. Any attached files are
  /// uploaded first (same Cloudinary flow as everything else in this
  /// app), then the whole entry — note text + resulting evidence URLs —
  /// is appended in one array write, same append-only pattern as
  /// appendAccessLog above: nothing here ever overwrites a past entry,
  /// so the case log stays a genuine chronological record.
  ///
  /// [when] is set client-side (Timestamp.now()) rather than
  /// FieldValue.serverTimestamp() — Firestore doesn't support server
  /// timestamps inside array elements written via arrayUnion, only on
  /// top-level/nested map fields set directly.
  Future<void> addCaseUpdate({
    required String reportId,
    required String authorName,
    required String authorRole,
    required String note,
    List<({String type, Uint8List bytes, String name})> evidence = const [],
    String? residentId,
  }) async {
    final uploaded = <EvidenceFile>[];
    for (final item in evidence) {
      final url = await CloudinaryUploader.uploadBytes(item.bytes, filename: item.name);
      uploaded.add(EvidenceFile(type: item.type, url: url, name: item.name, uploadedAt: DateTime.now()));
    }

    final update = CaseUpdate(authorName: authorName, authorRole: authorRole, note: note, evidenceFiles: uploaded, when: DateTime.now());

    await _reports.doc(reportId).update({
      'caseUpdates': FieldValue.arrayUnion([update.toMap()]),
    });

    if (residentId != null) {
      await _notificationRepository.create(
        recipientId: residentId,
        message: '$authorName ($authorRole) added an update to your report.',
        relatedReportId: reportId,
      );
    }
  }
}
