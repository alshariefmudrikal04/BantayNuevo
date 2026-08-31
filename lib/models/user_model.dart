import 'package:cloud_firestore/cloud_firestore.dart';

/// Matches the `users/{uid}` schema in AGENTS.md §5.
/// Role naming: "resident" | "tanod" | "police" | "admin" — Tanod ==
/// Barangay Official, same role, see AGENTS.md §1 naming note. "admin" is
/// the Barangay Admin PC/web dashboard role (Prompt 14) — deliberately not
/// selectable from role_select_screen.dart's public registration flow;
/// accounts are created by another admin (see AdminRepository.createStaffAccount)
/// or seeded directly in Firestore/Firebase console for the very first one.
enum UserRole { resident, tanod, police, admin }

extension UserRoleX on UserRole {
  String get value => name; // "resident" / "tanod" / "police" / "admin"

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
        UserRole.admin => 'Barangay Admin',
      };
}

/// A resident's identity-verification state (tanod/police/admin accounts,
/// created by an admin via AdminRepository.createStaffAccount, are always
/// `approved` — the act of an admin creating the account IS the vetting).
/// Residents self-register (register_screen.dart) with an ID photo + a
/// face photo and start at `pending` until an admin reviews both in the
/// dashboard's Verifications queue (AdminVerificationDetailScreen).
enum VerificationStatus { pending, approved, rejected }

extension VerificationStatusX on VerificationStatus {
  String get value => name;

  static VerificationStatus fromString(String value) {
    return VerificationStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => VerificationStatus.approved, // legacy accounts predating this feature
    );
  }
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
    this.active = true,
    this.verificationStatus = VerificationStatus.approved,
    this.idPhotoUrl,
    this.facePhotoUrl,
    this.rejectionReason,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String purok;
  final String barangay;

  /// Soft-disable flag, set by an admin (AdminUsersScreen). There's no
  /// Cloud Function wired up to actually disable the underlying Firebase
  /// Auth account (that needs the Admin SDK, same constraint noted on the
  /// PIN-recovery Cloud Function elsewhere in this project) — so this is
  /// enforced client-side: AuthGate signs an inactive user straight back
  /// out the moment their doc streams in with active == false. Good
  /// enough for a barangay-scale deployment; a real Cloud Function to
  /// disable the Auth account too is a known follow-up.
  final bool active;

  /// See VerificationStatus doc comment above. Only meaningfully varies
  /// for residents — defaults to `approved` for every other role.
  final VerificationStatus verificationStatus;
  final String? idPhotoUrl;
  final String? facePhotoUrl;

  /// Set by an admin when rejecting (AdminRepository.rejectVerification) —
  /// shown back to the resident on their pending/rejected screen and
  /// included in the notification email.
  final String? rejectionReason;

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
      active: data['active'] as bool? ?? true,
      verificationStatus: VerificationStatusX.fromString(data['verificationStatus'] as String? ?? 'approved'),
      idPhotoUrl: data['idPhotoUrl'] as String?,
      facePhotoUrl: data['facePhotoUrl'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
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
      'active': active,
      'verificationStatus': verificationStatus.value,
      if (idPhotoUrl != null) 'idPhotoUrl': idPhotoUrl,
      if (facePhotoUrl != null) 'facePhotoUrl': facePhotoUrl,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
