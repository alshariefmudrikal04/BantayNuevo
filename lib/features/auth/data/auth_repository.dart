import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_model.dart';

/// Wraps Firebase Auth + the users/{uid} Firestore doc. Screens should never
/// touch FirebaseAuth/Firestore directly — go through here, per AGENTS.md §8
/// (repositories return typed models, never raw Firebase objects, to the UI).
class AuthRepository {
  AuthRepository({
    fb_auth.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? fb_auth.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final fb_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  /// Emits the current [UserModel] (with role) whenever auth state changes,
  /// or null when signed out. This is what core/router/app_router.dart
  /// listens to for role-based routing.
  Stream<UserModel?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((fbUser) async {
      if (fbUser == null) return null;
      return _fetchUserModel(fbUser.uid);
    });
  }

  Future<UserModel?> _fetchUserModel(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc.data()!, uid);
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String phone,
    required String purok,
    required String password,
    required UserRole role,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

    final user = UserModel(
      uid: uid,
      name: name,
      email: email,
      phone: phone,
      role: role,
      purok: purok,
    );

    await _users.doc(uid).set(user.toFirestore());
    return user;
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = await _fetchUserModel(credential.user!.uid);
    if (user == null) {
      throw StateError(
        'Signed in but no matching users/{uid} document found — '
        'this account was never fully registered.',
      );
    }
    return user;
  }

  Future<void> logout() => _auth.signOut();
}
