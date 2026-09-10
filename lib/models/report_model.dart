import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportStatus { pending, inProgress, resolved }

extension ReportStatusX on ReportStatus {
  String get value => switch (this) {
        ReportStatus.pending => 'pending',
        ReportStatus.inProgress => 'in_progress',
        ReportStatus.resolved => 'resolved',
      };

  static ReportStatus fromString(String value) => switch (value) {
        'in_progress' => ReportStatus.inProgress,
        'resolved' => ReportStatus.resolved,
        _ => ReportStatus.pending,
      };

  String get displayLabel => switch (this) {
        ReportStatus.pending => 'Pending',
        ReportStatus.inProgress => 'In progress',
        ReportStatus.resolved => 'Resolved',
      };
}

class EvidenceFile {
  const EvidenceFile({required this.type, required this.url, required this.name, this.uploadedAt});

  final String type; // "photo" | "video" | "audio" | "document"
  final String url;
  final String name;
  final DateTime? uploadedAt;

  factory EvidenceFile.fromMap(Map<String, dynamic> map) => EvidenceFile(
        type: map['type'] as String? ?? 'document',
        url: map['url'] as String? ?? '',
        name: map['name'] as String? ?? '',
        uploadedAt: (map['uploadedAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'type': type,
        'url': url,
        'name': name,
        'uploadedAt': uploadedAt != null ? Timestamp.fromDate(uploadedAt!) : FieldValue.serverTimestamp(),
      };
}

class AccessLogEntry {
  const AccessLogEntry({required this.who, this.when});

  final String who;
  final DateTime? when;

  factory AccessLogEntry.fromMap(Map<String, dynamic> map) => AccessLogEntry(
        who: map['who'] as String? ?? 'Unknown',
        when: (map['when'] as Timestamp?)?.toDate(),
      );
}

/// One entry in a report's progress/case log — a tanod or police responder
/// documenting a visit, a status change, or (once resolved) what was
/// actually agreed/settled. Separate from AccessLogEntry (which just
/// records "someone opened this") and from the resident's own
/// evidenceFiles (submitted once, at filing) — this is the ongoing,
/// responder-authored narrative of what happened AFTER the report came
/// in, which can include its own attached evidence (e.g. a photo taken
/// during a site visit, or a scanned settlement/agreement document).
class CaseUpdate {
  const CaseUpdate({
    required this.authorName,
    required this.authorRole,
    required this.note,
    this.evidenceFiles = const [],
    this.when,
  });

  final String authorName;
  final String authorRole; // "Tanod" | "Police" | "Admin"
  final String note;
  final List<EvidenceFile> evidenceFiles;
  final DateTime? when;

  factory CaseUpdate.fromMap(Map<String, dynamic> map) => CaseUpdate(
        authorName: map['authorName'] as String? ?? 'Unknown',
        authorRole: map['authorRole'] as String? ?? '',
        note: map['note'] as String? ?? '',
        evidenceFiles: ((map['evidenceFiles'] as List?) ?? [])
            .map((e) => EvidenceFile.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        when: (map['when'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'authorName': authorName,
        'authorRole': authorRole,
        'note': note,
        'evidenceFiles': evidenceFiles.map((e) => e.toMap()).toList(),
        'when': Timestamp.now(), // set client-side, not serverTimestamp — see TanodReportRepository.addCaseUpdate's doc comment on why
      };
}

/// Matches the `reports/{reportId}` schema in AGENTS.md §5.
class ReportModel {
  const ReportModel({
    required this.id,
    required this.residentId,
    required this.type,
    required this.description,
    required this.status,
    this.locationAddress,
    this.lat,
    this.lng,
    this.evidenceFiles = const [],
    this.accessLog = const [],
    this.caseUpdates = const [],
    this.assignedTanodId,
    this.createdAt,
  });

  final String id;
  final String residentId;
  final String type;
  final String description;
  final ReportStatus status;
  final String? locationAddress;
  final double? lat;
  final double? lng;
  final List<EvidenceFile> evidenceFiles;
  final List<AccessLogEntry> accessLog;
  final List<CaseUpdate> caseUpdates;
  final String? assignedTanodId;
  final DateTime? createdAt;

  factory ReportModel.fromFirestore(Map<String, dynamic> data, String id) {
    final location = data['location'] as Map<String, dynamic>?;
    return ReportModel(
      id: id,
      residentId: data['residentId'] as String? ?? '',
      type: data['type'] as String? ?? 'Other',
      description: data['description'] as String? ?? '',
      status: ReportStatusX.fromString(data['status'] as String? ?? 'pending'),
      locationAddress: location?['address'] as String?,
      lat: (location?['lat'] as num?)?.toDouble(),
      lng: (location?['lng'] as num?)?.toDouble(),
      evidenceFiles: ((data['evidenceFiles'] as List?) ?? [])
          .map((e) => EvidenceFile.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      accessLog: ((data['accessLog'] as List?) ?? [])
          .map((e) => AccessLogEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      caseUpdates: ((data['caseUpdates'] as List?) ?? [])
          .map((e) => CaseUpdate.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      assignedTanodId: data['assignedTanodId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
