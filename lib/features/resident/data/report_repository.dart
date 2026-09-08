import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/report_model.dart';
import '../../../core/services/cloudinary_uploader.dart';

/// A locally-picked evidence file, before it's uploaded. Holds raw bytes
/// rather than a dart:io File — image_picker's XFile.readAsBytes() works
/// identically on every platform including Flutter Web, whereas a real
/// File object only works on native (see CloudinaryUploader's doc comment
/// for the exact web failure this avoids).
class PickedEvidence {
  const PickedEvidence({required this.type, required this.bytes, required this.name});

  final String type; // "photo" | "video"
  final Uint8List bytes;
  final String name;
}

/// Talks to the `reports` Firestore collection. Started here in Prompt 2
/// with just the read needed for Home's "recent activity" list — Prompt 3
/// adds createReport() with evidence upload on top of this same class.
class ReportRepository {
  ReportRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reports => _firestore.collection('reports');

  /// Live stream of a resident's most recent reports, newest first.
  ///
  /// Sorted/limited client-side rather than via Firestore's own
  /// orderBy+limit — a .where() + .orderBy() on different fields needs a
  /// composite index (an easy-to-forget manual step in the Firebase
  /// console; until it's created, this just silently fails with a
  /// precondition error). A resident's own report count is always small
  /// enough that fetching all of them and sorting/limiting in Dart avoids
  /// that setup step entirely.
  Stream<List<ReportModel>> streamRecentReports(String residentId, {int limit = 2}) {
    return _reports.where('residentId', isEqualTo: residentId).snapshots().map((snap) {
      final reports = snap.docs.map((d) => ReportModel.fromFirestore(d.data(), d.id)).toList();
      reports.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return reports.take(limit).toList();
    });
  }

  /// Live stream of ALL of a resident's reports — used by my_reports_screen.dart (Prompt 5).
  /// Same client-side sort as streamRecentReports above, same reasoning.
  Stream<List<ReportModel>> streamAllReports(String residentId) {
    return _reports.where('residentId', isEqualTo: residentId).snapshots().map((snap) {
      final reports = snap.docs.map((d) => ReportModel.fromFirestore(d.data(), d.id)).toList();
      reports.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return reports;
    });
  }

  /// Live stream of a single report — used by report_detail_screen.dart and
  /// evidence_vault_screen.dart (Prompt 5), so status/access-log updates from
  /// a tanod show up in real time without a manual refresh.
  Stream<ReportModel> streamReport(String reportId) {
    return _reports.doc(reportId).snapshots().map((d) => ReportModel.fromFirestore(d.data()!, d.id));
  }

  /// Looks up a user's display name by uid — used by report_detail_screen.dart
  /// to show the assigned tanod's name instead of just their id.
  Future<String?> fetchUserName(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['name'] as String?;
  }

  /// Creates a new report doc (status defaults to "pending") and uploads any
  /// attached evidence to Cloudinary first — TEMPORARY demo-purposes swap-in
  /// for Firebase Storage, which is blocked on the Blaze plan. See
  /// core/config/cloudinary_config.dart for how to switch back later.
  /// Storing the resulting URLs in evidenceFiles — per AGENTS.md §5.
  /// Returns the new report's id.
  Future<String> createReport({
    required String residentId,
    required String type,
    required String description,
    required List<PickedEvidence> evidence,
    double? lat,
    double? lng,
    String? locationAddress,
  }) async {
    final docRef = _reports.doc();

    final uploaded = <Map<String, dynamic>>[];
    for (final item in evidence) {
      final url = await _uploadToCloudinary(item);
      uploaded.add(EvidenceFile(
        type: item.type,
        url: url,
        name: item.name,
        uploadedAt: DateTime.now(),
      ).toMap());
    }

    await docRef.set({
      'residentId': residentId,
      'type': type,
      'description': description,
      'status': 'pending',
      'location': {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (locationAddress != null) 'address': locationAddress,
      },
      'evidenceFiles': uploaded,
      'accessLog': <Map<String, dynamic>>[],
      // createdAt uses Timestamp.now(), not FieldValue.serverTimestamp() —
      // streamAllReports/streamRecentReports (here and on the tanod side)
      // order by createdAt, and a server-timestamp write resolves to null
      // locally until the round-trip completes, which makes a just-submitted
      // report briefly vanish from both the resident's and tanod's lists.
      'createdAt': Timestamp.now(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Uploads one evidence file's bytes via the shared CloudinaryUploader.
  Future<String> _uploadToCloudinary(PickedEvidence item) {
    return CloudinaryUploader.uploadBytes(item.bytes, filename: item.name);
  }
}
