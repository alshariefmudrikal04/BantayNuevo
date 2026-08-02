import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/emergency_contact_model.dart';

/// Talks to the `emergency_contacts` collection — these are the numbers
/// texted on every SOS trigger (Prompt 4's offline path, and Prompt 4.5's
/// onSosCreated Cloud Function for the online path).
class EmergencyContactRepository {
  EmergencyContactRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _contacts => _firestore.collection('emergency_contacts');

  Stream<List<EmergencyContactModel>> streamForResident(String residentId) {
    return _contacts
        .where('residentId', isEqualTo: residentId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => EmergencyContactModel.fromFirestore(d.data(), d.id)).toList());
  }

  Future<void> addContact({
    required String residentId,
    required String name,
    required String relationship,
    required String phone,
  }) {
    return _contacts.add({
      'residentId': residentId,
      'name': name,
      'relationship': relationship,
      'phone': _normalizePhone(phone),
    });
  }

  Future<void> deleteContact(String id) => _contacts.doc(id).delete();

  /// Strips spaces/dashes so numbers stored here are consistently digits-only
  /// (matching the format used elsewhere, e.g. users.phone at registration) —
  /// the SMS paths in sos_screen.dart and the Cloud Function both depend on
  /// this being clean and consistent, not on any particular +63/09 prefix.
  static String _normalizePhone(String raw) => raw.replaceAll(RegExp(r'[^0-9+]'), '');
}
