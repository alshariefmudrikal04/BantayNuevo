import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/notification_model.dart';

/// Shared by resident AND tanod/police screens (recipientId isn't
/// role-specific — see AGENTS.md §5). Historically this only streamed
/// notifications; `create()` is what actually writes them now, since
/// nothing in the app wrote to this collection before — the bell/list
/// screens existed but always showed empty.
class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications => _firestore.collection('notifications');

  /// Live stream of a user's notifications, newest first — works for any
  /// role, not just resident, since recipientId can be a tanod/police uid too.
  Stream<List<NotificationModel>> streamForUser(String uid) {
    return _notifications
        .where('recipientId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => NotificationModel.fromFirestore(d.data(), d.id)).toList());
  }

  Future<void> markAsRead(String notificationId) {
    return _notifications.doc(notificationId).update({'read': true});
  }

  /// Writes a notification doc directly from the client at a "key moment"
  /// (assigned / arrived / resolved) rather than on every field change —
  /// keeps the resident's bell meaningful instead of spammy. Done
  /// client-side rather than via a Cloud Function trigger so it works
  /// without the Blaze plan (same reasoning as the offline-SMS path).
  ///
  /// Uses Timestamp.now() rather than FieldValue.serverTimestamp() on
  /// purpose: the latter resolves to null in the optimistic local write
  /// Firestore shows before the server round-trip completes, and since
  /// streamForUser() orders by this field, a null value gets excluded
  /// from the ordered result — the notification flashes in, then
  /// disappears until the server confirms the real timestamp a moment
  /// later. A client timestamp has no such gap. Trade-off: relies on the
  /// device clock being roughly correct, which is fine for "which came
  /// first" ordering at this granularity.
  Future<void> create({
    required String recipientId,
    required String message,
    String? relatedReportId,
    String? relatedAlertId,
  }) {
    return _notifications.add({
      'recipientId': recipientId,
      'message': message,
      'read': false,
      if (relatedReportId != null) 'relatedReportId': relatedReportId,
      if (relatedAlertId != null) 'relatedAlertId': relatedAlertId,
      'createdAt': Timestamp.now(),
    });
  }
}
