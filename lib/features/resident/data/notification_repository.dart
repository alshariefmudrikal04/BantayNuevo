import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/notification_model.dart';

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
}
