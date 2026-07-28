import 'package:cloud_firestore/cloud_firestore.dart';

/// Matches the `users/{uid}` schema in AGENTS.md §5.
/// Role naming: "resident" | "tanod" | "police" — Tanod == Barangay Official,
/// same role, see AGENTS.md §1 naming note.
enum UserRole { resident, tanod, police }

extension UserRoleX on UserRole {
  String get value => name; // "resident" / "tanod" / "police"

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (r) => r.value == value,
      orElse: () => throw ArgumentError('Unknown role: $value'),
    );
  }

  String get displayLabel => switch (this) {
        UserRole.resident => 'Resident',
        UserRole.tanod => 'Barangay Tanod',
        UserRole.police => 'Police Responder',
      };
}

class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.purok,
    this.barangay = 'Camino Nuevo',
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String purok;
  final String barangay;
  final DateTime? createdAt;

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      role: UserRoleX.fromString(data['role'] as String? ?? 'resident'),
      purok: data['purok'] as String? ?? '',
      barangay: data['barangay'] as String? ?? 'Camino Nuevo',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.value,
      'purok': purok,
      'barangay': barangay,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
