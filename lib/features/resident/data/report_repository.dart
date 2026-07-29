import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../models/report_model.dart';

/// A locally-picked evidence file, before it's uploaded. Kept decoupled from
/// image_picker's XFile so this repository doesn't depend on UI-layer types.
class PickedEvidence {
  const PickedEvidence({required this.type, required this.file, required this.name});

  final String type; // "photo" | "video"
  final File file;
  final String name;
}

/// Talks to the `reports` Firestore collection. Started here in Prompt 2
/// with just the read needed for Home's "recent activity" list — Prompt 3
/// adds createReport() with evidence upload on top of this same class.
class ReportRepository {
  ReportRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _reports => _firestore.collection('reports');

  /// Live stream of a resident's most recent reports, newest first.
  Stream<List<ReportModel>> streamRecentReports(String residentId, {int limit = 2}) {
    return _reports
        .where('residentId', isEqualTo: residentId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ReportModel.fromFirestore(d.data(), d.id)).toList());
  }

  /// Live stream of ALL of a resident's reports — used by my_reports_screen.dart (Prompt 5).
  Stream<List<ReportModel>> streamAllReports(String residentId) {
    return _reports
        .where('residentId', isEqualTo: residentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ReportModel.fromFirestore(d.data(), d.id)).toList());
  }

  /// Creates a new report doc (status defaults to "pending") and uploads any
  /// attached evidence to Storage under reports/{reportId}/evidence/ first,
  /// storing the resulting download URLs in evidenceFiles — per AGENTS.md §5.
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
      final ref = _storage.ref('reports/${docRef.id}/evidence/${item.name}');
      await ref.putFile(item.file);
      final url = await ref.getDownloadURL();
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
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }
}
