import 'package:cloud_firestore/cloud_firestore.dart';

enum SosStatus { active, responded, arrived, closed, expired }

extension SosStatusX on SosStatus {
  String get value => switch (this) {
        SosStatus.active => 'active',
        SosStatus.responded => 'responded',
        SosStatus.arrived => 'arrived',
        SosStatus.closed => 'closed',
        SosStatus.expired => 'expired',
      };

  static SosStatus fromString(String value) => switch (value) {
        'responded' => SosStatus.responded,
        'arrived' => SosStatus.arrived,
        'closed' => SosStatus.closed,
        'expired' => SosStatus.expired,
        _ => SosStatus.active,
      };
}

/// A newly created alert is only acceptable for this long — enforced for
/// real in firestore.rules (server clock, not client-trusted), this
/// constant is just for client-side display/filtering so the UI matches
/// what the backend will actually allow.
const sosAlertValidityMinutes = 5;

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

  /// True once this alert has aged past its acceptance window while still
  /// sitting at 'active' — i.e. it should be treated as expired even if
  /// nothing has persisted that to Firestore yet (see
  /// TanodSosRepository.streamOpenAlerts for the lazy-write that actually
  /// does). Purely a client-side read of the clock for filtering/display;
  /// the real enforcement against acceptance lives in firestore.rules.
  bool get isExpired {
    if (status != SosStatus.active) return false;
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt!) >= const Duration(minutes: sosAlertValidityMinutes);
  }

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
