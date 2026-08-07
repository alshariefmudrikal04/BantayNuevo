import 'package:cloud_firestore/cloud_firestore.dart';

enum SosStatus { active, responded, closed }

extension SosStatusX on SosStatus {
  String get value => switch (this) {
        SosStatus.active => 'active',
        SosStatus.responded => 'responded',
        SosStatus.closed => 'closed',
      };

  static SosStatus fromString(String value) => switch (value) {
        'responded' => SosStatus.responded,
        'closed' => SosStatus.closed,
        _ => SosStatus.active,
      };
}

/// Matches the `sos_alerts/{alertId}` schema in AGENTS.md §5, extended with
/// live-tracking fields: the resident's location keeps updating while the
/// alert is active, and once a tanod/police accepts, their location streams
/// in too via responderLocation.
class SosAlertModel {
  const SosAlertModel({
    required this.id,
    required this.residentId,
    required this.escalationTarget,
    required this.status,
    this.lat,
    this.lng,
    this.responderId,
    this.responderName,
    this.responderLat,
    this.responderLng,
    this.createdAt,
  });

  final String id;
  final String residentId;
  final String escalationTarget; // "auto" | "tanod" | "pnp"
  final SosStatus status;
  final double? lat;
  final double? lng;
  final String? responderId;
  final String? responderName;
  final double? responderLat;
  final double? responderLng;
  final DateTime? createdAt;

  bool get hasResponderLocation => responderLat != null && responderLng != null;

  factory SosAlertModel.fromFirestore(Map<String, dynamic> data, String id) {
    final location = data['location'] as Map<String, dynamic>?;
    final responderLocation = data['responderLocation'] as Map<String, dynamic>?;
    return SosAlertModel(
      id: id,
      residentId: data['residentId'] as String? ?? '',
      escalationTarget: data['escalationTarget'] as String? ?? 'auto',
      status: SosStatusX.fromString(data['status'] as String? ?? 'active'),
      lat: (location?['lat'] as num?)?.toDouble(),
      lng: (location?['lng'] as num?)?.toDouble(),
      responderId: data['responderId'] as String?,
      responderName: data['responderName'] as String?,
      responderLat: (responderLocation?['lat'] as num?)?.toDouble(),
      responderLng: (responderLocation?['lng'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
