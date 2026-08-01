import 'package:cloud_firestore/cloud_firestore.dart';

/// Matches the `notifications/{notificationId}` schema in AGENTS.md §5.
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.recipientId,
    required this.message,
    required this.read,
    this.relatedReportId,
    this.relatedAlertId,
    this.createdAt,
  });

  final String id;
  final String recipientId;
  final String message;
  final bool read;
  final String? relatedReportId;
  final String? relatedAlertId;
  final DateTime? createdAt;

  factory NotificationModel.fromFirestore(Map<String, dynamic> data, String id) => NotificationModel(
        id: id,
        recipientId: data['recipientId'] as String? ?? '',
        message: data['message'] as String? ?? '',
        read: data['read'] as bool? ?? false,
        relatedReportId: data['relatedReportId'] as String?,
        relatedAlertId: data['relatedAlertId'] as String?,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      );
}
