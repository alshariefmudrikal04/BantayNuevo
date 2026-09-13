import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_model.dart';
import '../../../core/services/cloudinary_uploader.dart';

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

  /// Turns a raw exception (usually a [fb_auth.FirebaseAuthException]) into
  /// something a resident can actually act on, instead of the screens
  /// showing "Could not sign in: [firebase_auth/wrong-password] ..." verbatim.
  /// Shared by login, register, and account-recovery screens so the tone
  /// stays consistent everywhere an auth call can fail.
  static String friendlyError(Object error) {
    if (error is fb_auth.FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That email address doesn\'t look right.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'user-disabled':
          return 'This account has been disabled. Contact your barangay admin.';
        case 'too-many-requests':
          return 'Too many attempts. Wait a moment and try again.';
        case 'email-already-in-use':
          return 'That email already has an account. Try logging in, or use '
              '"Forgot account?" to reset the password instead.';
        case 'weak-password':
          return 'Choose a password with at least 6 characters.';
        case 'network-request-failed':
          return 'No internet connection. Check your network and try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  /// Emits the current [UserModel] (with role) whenever auth state changes,
  /// or null when signed out. This is what core/router/app_router.dart
  /// listens to for role-based routing.
  ///
  /// This used to do a one-time `_users.doc(uid).get()` inside asyncMap,
  /// which caused the "stuck after registering" bug: Firebase's own
  /// authStateChanges() fires the instant createUserWithEmailAndPassword
  /// succeeds — before register() has uploaded the two photos and written
  /// users/{uid} — so that one-time get() caught the account mid-registration,
  /// found no doc yet, and returned null. Since authStateChanges() only
  /// fires again on an actual sign-in/out transition (never just because a
  /// Firestore doc later appears), AuthGate was left stuck rendering
  /// LoginScreen underneath RegisterScreen for the rest of the session — so
  /// when RegisterScreen finished and popped back to the root, it revealed
  /// LoginScreen instead of VerificationPendingScreen, even though
  /// registration itself had actually succeeded. The resident then had to
  /// log back in manually, which read as "registration got stuck."
  ///
  /// Using `.snapshots()` (a live listener) instead of `.get()` fixes this
  /// at the root: the moment register() finishes writing users/{uid}, this
  /// listener fires again on its own with the real data, and AuthGate
  /// rebuilds itself to the correct screen without RegisterScreen needing
  /// to do anything beyond popping back to the root.
  Stream<UserModel?> get authStateChanges {
    return _auth.authStateChanges().asyncExpand((fbUser) {
      if (fbUser == null) return Stream<UserModel?>.value(null);
      return _users.doc(fbUser.uid).snapshots().asyncMap((doc) async {
        if (!doc.exists) return null;
        final user = UserModel.fromFirestore(doc.data()!, fbUser.uid);
        // Soft-disable check (see UserModel.active) — an admin deactivating
        // someone doesn't touch the underlying Firebase Auth account, so we
        // enforce it here instead: sign them straight back out.
        if (!user.active) {
          await _auth.signOut();
          return null;
        }
        return user;
      });
    });
  }

  /// Residents are the only self-registering role now — tanod/police/admin
  /// accounts are created by an existing admin (AdminRepository.createStaffAccount),
  /// which is itself the vetting step for those roles. A resident instead
  /// proves who they are with an ID photo + a live face photo, uploaded to
  /// Cloudinary (same unsigned-preset flow as evidence files — see
  /// CloudinaryUploader), and starts out `pending` until a Barangay Admin
  /// reviews both in the dashboard's Verifications queue.
  ///
  /// Takes raw bytes + filenames rather than dart:io Files — see
  /// CloudinaryUploader's doc comment for why that matters wherever this
  /// runs in a browser (register_screen.dart reads XFile.readAsBytes()
  /// before calling this, which works on every platform).
  Future<UserModel> register({
    required String name,
    required String email,
    required String phone,
    required String purok,
    required String password,
    required Uint8List idPhotoBytes,
    required String idPhotoFilename,
    required Uint8List facePhotoBytes,
    required String facePhotoFilename,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

    try {
      // Both photos upload in parallel rather than one-after-the-other —
      // this was the main source of the long wait between tapping submit
      // and actually landing on VerificationPendingScreen, since two
      // sequential multipart uploads on a mobile connection easily doubled
      // the real wait versus doing them at the same time.
      final uploads = await Future.wait([
        CloudinaryUploader.uploadBytes(idPhotoBytes, filename: idPhotoFilename),
        CloudinaryUploader.uploadBytes(facePhotoBytes, filename: facePhotoFilename),
      ]);
      final idPhotoUrl = uploads[0];
      final facePhotoUrl = uploads[1];

      final user = UserModel(
        uid: uid,
        name: name,
        email: email,
        phone: phone,
        role: UserRole.resident,
        purok: purok,
        verificationStatus: VerificationStatus.pending,
        idPhotoUrl: idPhotoUrl,
        facePhotoUrl: facePhotoUrl,
      );

      await _users.doc(uid).set(user.toFirestore());
      return user;
    } catch (e) {
      // Roll back the Auth account we just created if anything after it
      // fails — an upload timing out, the resident backing out of the
      // screen mid-upload (which throws when this future's context is
      // gone), or a Firestore write error. Without this, the Auth account
      // exists with no matching users/{uid} doc, and every future signup
      // attempt with that same email permanently fails with
      // "email-already-in-use" — the exact bug where a resident goes back
      // and retries, only to be told their email is already taken, with no
      // way to recover it themselves.
      try {
        await credential.user!.delete();
      } catch (_) {
        // Deleting can itself fail (e.g. a stale session needing
        // re-authentication) — not fatal to surface here. Worst case an
        // admin has to remove the orphaned Auth record by hand; the
        // original error below is still what reaches the resident.
      }
      rethrow;
    }
  }

  /// Signs in and returns as soon as Firebase Auth confirms the
  /// credentials — it deliberately does NOT also do its own Firestore
  /// read of users/{uid} afterwards. That used to be here (a one-time
  /// `.get()` right after signInWithEmailAndPassword, mirroring the same
  /// pattern that caused the "stuck after registering" bug described
  /// above), and it caused login to hang indefinitely: a one-time get()
  /// issued the instant sign-in succeeds can stall before the new
  /// session is fully propagated, so the button's spinner would run
  /// forever even though the sign-in itself had already gone through.
  ///
  /// AuthGate's `authStateChanges` (above) already does the equivalent
  /// check with a live `.snapshots()` listener and safely falls back to
  /// LoginScreen if users/{uid} doesn't exist, so re-checking it here
  /// was both redundant and the actual source of the hang.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Nothing else to do — AuthGate's live listener takes it from here.
  }

  Future<void> logout() => _auth.signOut();

  /// "Forgot account?" — Firebase's own built-in reset-email flow
  /// (`sendPasswordResetEmail`), entirely client-side. No Cloud Function
  /// and no Blaze plan involved: this is a stock FirebaseAuth SDK call, so
  /// it works today on the free Spark plan. Firebase always resolves this
  /// the same way whether or not the email matches an account, so — same
  /// as the phone-based version this replaced — it can't be used to probe
  /// which addresses are registered.
  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  // ---------------------------------------------------------------------
  // Account settings — edit email / phone / password, delete account.
  //
  // Email and password are Firebase Auth credentials, so both require a
  // recent sign-in before Firebase will let them change (the
  // 'requires-recent-login' error otherwise) — [_reauthenticate] does that
  // with the password the resident just typed on the Edit Account screen,
  // so every save (and the delete flow) goes through it first rather than
  // surfacing that raw Firebase error.
  // ---------------------------------------------------------------------

  Future<void> _reauthenticate(String currentPassword) async {
    final fbUser = _auth.currentUser;
    if (fbUser == null || fbUser.email == null) {
      throw StateError('Not signed in.');
    }
    final credential = fb_auth.EmailAuthProvider.credential(
      email: fbUser.email!,
      password: currentPassword,
    );
    await fbUser.reauthenticateWithCredential(credential);
  }

  /// Updates phone (and, optionally, email/password) for the signed-in
  /// account in one call, so the Edit Account screen only asks for the
  /// current password once no matter how many fields actually changed.
  ///
  /// [newEmail]/[newPassword] are only applied when non-null — pass null
  /// for whichever the resident left unchanged. Phone lives purely in the
  /// Firestore users/{uid} doc (there's no Firebase Phone Auth involved in
  /// this app — see UserModel doc comment), so it's always written
  /// alongside whatever Auth changes were requested.
  ///
  /// Email changes go through [fb_auth.User.verifyBeforeUpdateEmail]
  /// rather than the older updateEmail() call: current Firebase projects
  /// reject updateEmail with 'operation-not-allowed' under email
  /// enumeration protection, while verifyBeforeUpdateEmail (send a
  /// confirmation link to the NEW address, only swap once it's clicked)
  /// works everywhere and is the officially recommended replacement. The
  /// Firestore email field is updated immediately either way so the app's
  /// own UI reflects it right away; the resident still needs to click the
  /// link in their new inbox before that new address can actually be used
  /// to log in — the confirmation dialog in edit_account_screen.dart says
  /// so.
  Future<void> updateAccount({
    required String currentPassword,
    String? newEmail,
    String? newPhone,
    String? newPassword,
  }) async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) throw StateError('Not signed in.');

    await _reauthenticate(currentPassword);

    var emailVerificationSent = false;
    if (newEmail != null && newEmail != fbUser.email) {
      await fbUser.verifyBeforeUpdateEmail(newEmail);
      emailVerificationSent = true;
    }

    if (newPassword != null && newPassword.isNotEmpty) {
      await fbUser.updatePassword(newPassword);
    }

    final firestoreUpdates = <String, dynamic>{
      if (newPhone != null) 'phone': newPhone,
      // Kept in sync for display right away — see doc comment above on why
      // the Auth side doesn't flip until the confirmation link is clicked.
      if (newEmail != null) 'email': newEmail,
    };
    if (firestoreUpdates.isNotEmpty) {
      await _users.doc(fbUser.uid).update(firestoreUpdates);
    }

    return;
  }

  /// Same reauthentication requirement as above — deleting a Firebase Auth
  /// account also needs a recent sign-in. The Firestore users/{uid} doc is
  /// removed first: if that succeeds but the Auth deletion below then
  /// somehow fails, the resident is left signed in with no profile doc
  /// (AuthGate treats that as "not registered", which is a safer failure
  /// mode than the reverse order — an Auth account deleted but a Firestore
  /// doc left behind that still shows up in admin's user list for someone
  /// who can no longer log in).
  ///
  /// This does not delete the resident's uploaded reports/evidence or ID
  /// photos (Cloudinary + the reports/sos_alerts collections) — those stay
  /// for the barangay's own record-keeping, same as a paper case file
  /// wouldn't be shredded because the person who filed it moved away. A
  /// real deployment may want to blank the ID/face photos specifically;
  /// out of scope for now.
  Future<void> deleteAccount({required String currentPassword}) async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) throw StateError('Not signed in.');

    await _reauthenticate(currentPassword);
    await _users.doc(fbUser.uid).delete();
    await fbUser.delete();
  }
}
