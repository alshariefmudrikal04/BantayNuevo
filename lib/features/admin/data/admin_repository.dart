import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart';

import '../../../core/services/cloudinary_uploader.dart';
import '../../../models/report_model.dart';
import '../../../models/sos_alert_model.dart';
import '../../../models/user_model.dart';
import '../../resident/data/notification_repository.dart';

/// Data layer for the Barangay Admin dashboard (Prompt 14). Unlike the
/// resident/tanod repositories, admin genuinely needs full-collection
/// visibility across users, reports, and sos_alerts — that's the whole
/// point of an oversight dashboard — so every stream here is unscoped.
///
/// NOTE on firestore.rules: everything this class touches already sits
/// under the existing `request.auth != null` rules (see firestore.rules'
/// documented "known separate follow-up" for full RBAC), EXCEPT the
/// `config/alarm_sounds` doc, which now has a real isAdmin()-gated rule
/// since it's the one new piece of global, everyone-affecting state this
/// dashboard introduces.
class AdminRepository {
  AdminRepository({FirebaseFirestore? firestore, NotificationRepository? notificationRepository})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _notificationRepository = notificationRepository ?? NotificationRepository();

  final FirebaseFirestore _firestore;
  final NotificationRepository _notificationRepository;

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _reports => _firestore.collection('reports');
  CollectionReference<Map<String, dynamic>> get _alerts => _firestore.collection('sos_alerts');
  DocumentReference<Map<String, dynamic>> get _alarmSoundsDoc => _firestore.collection('config').doc('alarm_sounds');

  // ---------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------

  Stream<List<UserModel>> streamAllUsers() {
    return _users
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => UserModel.fromFirestore(d.data(), d.id)).toList());
  }

  Future<void> setUserActive(String uid, bool active) {
    return _users.doc(uid).update({'active': active});
  }

  Future<void> setUserRole(String uid, UserRole role) {
    return _users.doc(uid).update({'role': role.value});
  }

  /// Creates a brand-new tanod/police/admin account without signing the
  /// current admin out of their own session.
  ///
  /// The naive approach — calling FirebaseAuth.instance.createUserWith...
  /// on the SAME app instance the admin is signed in on — would sign the
  /// admin OUT and into the newly-created account instead (a well-known
  /// Firebase Auth SDK quirk: create-user also signs in as that user on
  /// whichever FirebaseAuth instance you call it on). The fix is to spin
  /// up a second, throwaway FirebaseApp just for this one call, create
  /// the user there, then immediately tear that second app down — the
  /// admin's own FirebaseAuth.instance session is never touched.
  Future<void> createStaffAccount({
    required String name,
    required String email,
    required String phone,
    required String purok,
    required String password,
    required UserRole role,
  }) async {
    final secondaryApp = await Firebase.initializeApp(
      name: 'admin_create_user_${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    try {
      final secondaryAuth = fb_auth.FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;

      // Written via the admin's own (primary) Firestore instance — Firestore
      // isn't tied to which FirebaseApp/Auth session created the doc, only
      // to which project it's in, so this doesn't need the secondary app.
      await _users.doc(uid).set(
            UserModel(uid: uid, name: name, email: email, phone: phone, role: role, purok: purok).toFirestore(),
          );

      await secondaryAuth.signOut();
    } finally {
      await secondaryApp.delete();
    }
  }

  // ---------------------------------------------------------------------
  // Resident identity verification
  // ---------------------------------------------------------------------

  Stream<List<UserModel>> streamPendingVerifications() {
    return _users
        .where('role', isEqualTo: UserRole.resident.value)
        .where('verificationStatus', isEqualTo: VerificationStatus.pending.value)
        .snapshots()
        .map((snap) => snap.docs.map((d) => UserModel.fromFirestore(d.data(), d.id)).toList());
  }

  Future<void> approveVerification(UserModel resident) async {
    await _users.doc(resident.uid).update({
      'verificationStatus': VerificationStatus.approved.value,
      'rejectionReason': FieldValue.delete(),
    });
    await _sendVerificationEmail(
      resident,
      subject: 'Your Bantay Nuevo account is verified',
      body:
          'Hi ${resident.name},\n\nYour resident account has been verified by a barangay admin. '
          'You can now log in and use the app, including SOS.\n\n— Barangay Camino Nuevo',
    );
  }

  Future<void> rejectVerification(UserModel resident, String reason) async {
    await _users.doc(resident.uid).update({
      'verificationStatus': VerificationStatus.rejected.value,
      'rejectionReason': reason,
    });
    await _sendVerificationEmail(
      resident,
      subject: 'Your Bantay Nuevo account could not be verified',
      body:
          'Hi ${resident.name},\n\nA barangay admin reviewed your ID and photo and could not verify '
          'your account.\n\nReason: $reason\n\nIf you believe this is a mistake, please visit the '
          'barangay hall in person.\n\n— Barangay Camino Nuevo',
    );
  }

  /// Writes a doc to the `mail` collection, the trigger document format
  /// expected by Firebase's official "Trigger Email from Firestore"
  /// extension. That extension (installed + configured with your own SMTP
  /// provider from the Firebase console — a one-time manual setup step,
  /// same category as the Cloudinary swap-in elsewhere in this project)
  /// is what actually sends the email; this call by itself does nothing
  /// without it installed.
  Future<void> _sendVerificationEmail(UserModel resident, {required String subject, required String body}) {
    return _firestore.collection('mail').add({
      'to': [resident.email],
      'message': {'subject': subject, 'text': body},
    });
  }

  // ---------------------------------------------------------------------
  // Incident reports
  // ---------------------------------------------------------------------

  Stream<List<ReportModel>> streamAllReports() {
    return _reports
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ReportModel.fromFirestore(d.data(), d.id)).toList());
  }

  Stream<ReportModel> streamReport(String reportId) {
    return _reports.doc(reportId).snapshots().map((d) => ReportModel.fromFirestore(d.data()!, d.id));
  }

  Future<void> updateReportStatus(String reportId, ReportStatus status, {String? residentId}) async {
    await _reports.doc(reportId).update({
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (status == ReportStatus.resolved && residentId != null) {
      await _notificationRepository.create(
        recipientId: residentId,
        message: 'A barangay admin marked your report as resolved.',
        relatedReportId: reportId,
      );
    }
  }

  /// responderId can be a tanod OR a police account — the reports schema
  /// only ever stored a single assignedTanodId (naming predates this
  /// dashboard), reused here generically rather than adding a parallel
  /// assignedPoliceId field for what's functionally the same "who's
  /// handling this" relationship.
  Future<void> assignReportResponder(
    String reportId, {
    required String responderId,
    required String responderName,
    required UserRole responderRole,
    String? residentId,
  }) async {
    await _reports.doc(reportId).update({
      'assignedTanodId': responderId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (residentId != null) {
      await _notificationRepository.create(
        recipientId: residentId,
        message: '${responderRole.displayLabel} $responderName was assigned to your report.',
        relatedReportId: reportId,
      );
    }
  }

  // ---------------------------------------------------------------------
  // SOS alerts
  // ---------------------------------------------------------------------

  /// Unlike TanodSosRepository.streamOpenAlerts (which hides closed/expired
  /// alerts — a tanod only cares about what's actionable right now), admin
  /// oversight wants the full picture including history, so nothing here
  /// is filtered out.
  Stream<List<SosAlertModel>> streamAllSosAlerts() {
    return _alerts
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SosAlertModel.fromFirestore(d.data(), d.id)).toList());
  }

  Stream<SosAlertModel> streamSosAlert(String alertId) {
    return _alerts.doc(alertId).snapshots().map((d) => SosAlertModel.fromFirestore(d.data()!, d.id));
  }

  /// Admin-initiated assignment — distinct from TanodSosRepository.acceptAlert
  /// (which requires the tanod's own live GPS position to accept for
  /// themselves). Here the admin is assigning someone else, so there's no
  /// responder location to capture yet — it starts null and fills in once
  /// that responder's own app starts sending live location updates.
  Future<void> assignSosResponder({
    required String alertId,
    required String residentId,
    required String responderId,
    required String responderName,
  }) async {
    final snap = await _alerts.doc(alertId).get();
    if (!snap.exists) throw Exception('This alert no longer exists.');
    final current = SosAlertModel.fromFirestore(snap.data()!, snap.id);
    if (current.status != SosStatus.active) {
      throw Exception('This alert is no longer active (already ${current.status.value}).');
    }

    await _alerts.doc(alertId).update({
      'responderId': responderId,
      'responderName': responderName,
      'status': 'responded',
    });
    await _notificationRepository.create(
      recipientId: residentId,
      message: '$responderName was assigned to your SOS alert.',
      relatedAlertId: alertId,
    );
  }

  Future<void> closeSosAlert(String alertId) {
    return _alerts.doc(alertId).update({'status': 'closed'});
  }

  Future<String?> fetchUserName(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['name'] as String?;
  }

  // ---------------------------------------------------------------------
  // Org-wide alarm sounds (replaces the earlier per-tanod local picker —
  // this dashboard is now the single source of truth for what sound
  // plays, org-wide, per emergency type). See core/services/alarm_sound_service.dart.
  // ---------------------------------------------------------------------

  /// Emits a map of emergencyType.value -> Cloudinary URL. A type missing
  /// from the map means "use the bundled default asset" (see
  /// AlarmSoundService).
  Stream<Map<String, String>> streamAlarmSoundConfig() {
    return _alarmSoundsDoc.snapshots().map((doc) {
      final data = doc.data() ?? {};
      return data.map((key, value) => MapEntry(key, value as String));
    });
  }

  /// Uploads [file] to Cloudinary (same unsigned-preset approach as
  /// evidence uploads — see ReportRepository._uploadToCloudinary) and
  /// records the resulting URL as the org-wide sound for [emergencyTypeValue].
  Future<void> uploadAlarmSound(String emergencyTypeValue, File file) async {
    final url = await CloudinaryUploader.upload(file);
    await _alarmSoundsDoc.set({emergencyTypeValue: url}, SetOptions(merge: true));
  }

  Future<void> resetAlarmSoundToDefault(String emergencyTypeValue) {
    return _alarmSoundsDoc.update({emergencyTypeValue: FieldValue.delete()});
  }
}
