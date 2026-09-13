import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/lux_theme.dart';
import '../../../core/widgets/lux_field.dart';
import '../../../core/widgets/lux_button.dart';
import '../data/auth_repository.dart';

/// Resident sign-up — the only self-registration path left in the app
/// (tanod/police/admin accounts are created by an existing admin; see
/// AdminUsersSection). Requires an ID photo + a live face photo, both
/// reviewed by a Barangay Admin before the account can actually be used —
/// see VerificationStatus on UserModel and VerificationPendingScreen,
/// which is what a newly-registered resident lands on right after this.
///
/// Matches login_screen.dart's actual component vocabulary (LuxField,
/// LuxButton, the eyebrow+hero greeting) rather than the separate old
/// AppColors/AppTypography/AppButton this screen used to run on — that
/// mismatch was the biggest visual tell that this page wasn't designed
/// alongside the rest of the app, just generated on its own.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Philippine mobile numbers: 11 digits, always starting with 09 in local
  // format (e.g. 09171234567). Enforced here — rather than left free-form —
  // because this exact number is what receives the approve/reject SMS from
  // AdminRepository once a Barangay Admin reviews the account, so an
  // invalid or mistyped one silently breaks that notification.
  static final RegExp _phRegex = RegExp(r'^09\d{9}$');

  // A reasonably strict but standard email shape check. Same reasoning as
  // the phone regex: this address is where the approve/reject email
  // actually goes (AdminRepository._sendVerificationEmail), so it's worth
  // catching an obviously-malformed one before it ever reaches Firebase Auth.
  static final RegExp _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[A-Za-z]{2,}$');

  final _authRepository = AuthRepository();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _purokController = TextEditingController();
  final _passwordController = TextEditingController();
  Uint8List? _idPhotoBytes;
  String? _idPhotoName;
  Uint8List? _facePhotoBytes;
  String? _facePhotoName;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _purokController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _captureId() async {
    // Gallery, not camera — residents often already have a scan/photo of
    // their ID saved, and re-photographing a physical card by hand tends
    // to come out worse than a document scan they already have.
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    // Bytes, not a dart:io File+path — see CloudinaryUploader's doc
    // comment for why a File-based approach breaks on Flutter Web.
    // XFile.readAsBytes() works identically on every platform.
    final bytes = await file.readAsBytes();
    if (mounted) setState(() {
      _idPhotoBytes = bytes;
      _idPhotoName = file.name;
    });
  }

  Future<void> _captureFace() async {
    // Camera, front-facing — this needs to be a live selfie taken right
    // now, not a photo-of-a-photo, so gallery isn't offered here at all.
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() {
      _facePhotoBytes = bytes;
      _facePhotoName = file.name;
    });
  }

  Future<void> _submit() async {
    final idBytes = _idPhotoBytes;
    final faceBytes = _facePhotoBytes;
    if (idBytes == null || faceBytes == null) {
      setState(() => _error = 'Both your ID photo and a face photo are required.');
      return;
    }
    final email = _emailController.text.trim();
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address — this is where your approval notice goes.');
      return;
    }
    final phone = _phoneController.text.trim();
    if (!_phRegex.hasMatch(phone)) {
      setState(() => _error = 'Enter a valid 11-digit mobile number, e.g. 09171234567 — this is where your approval SMS goes.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authRepository.register(
        name: _nameController.text.trim(),
        email: email,
        phone: phone,
        purok: _purokController.text.trim(),
        password: _passwordController.text,
        idPhotoBytes: idBytes,
        idPhotoFilename: _idPhotoName ?? 'id_photo.jpg',
        facePhotoBytes: faceBytes,
        facePhotoFilename: _facePhotoName ?? 'face_photo.jpg',
      );
      if (!mounted) return;
      // Explicit confirmation before handing back to AuthGate — previously
      // this popped straight to VerificationPendingScreen with no moment
      // of "yes, that went through," which read as the app just quietly
      // doing something (or nothing) after a long submit.
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: LuxColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Account submitted', style: LuxType.heading(fontSize: 16)),
          content: Text(
            'A barangay admin will review your ID and photo. You\'ll get a text and email once your '
            'account is approved or rejected.',
            style: LuxType.body(fontSize: 13, color: LuxColors.inkSoft),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Got it', style: LuxType.heading(fontSize: 13, color: LuxColors.red)),
            ),
          ],
        ),
      );
      // AuthGate (core/router/app_router.dart) already picked up the new
      // signed-in user in the background — but RegisterScreen was pushed
      // on top of it, so we need to pop back to root ourselves for that
      // updated screen (VerificationPendingScreen, since this account
      // starts at `pending`) to actually become visible.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() {
        _error = AuthRepository.friendlyError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Blocks the back gesture/button while a submission is in flight.
      // Backing out mid-upload used to be able to leave a Firebase Auth
      // account created with no matching Firestore user doc (registration
      // creates the Auth account first, then uploads two photos, then
      // writes Firestore last) — AuthRepository.register now rolls that
      // orphaned account back on failure, but the safest fix is simply not
      // letting the resident navigate away mid-submit in the first place.
      canPop: !_loading,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please wait for this to finish.')),
        );
      },
      child: Scaffold(
        backgroundColor: LuxColors.bg,
        appBar: AppBar(
          backgroundColor: LuxColors.bg,
          elevation: 0,
          foregroundColor: LuxColors.black,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SIGN UP', style: LuxType.eyebrow(fontSize: 11)),
                const SizedBox(height: 2),
                Text('Create your account', style: LuxType.hero(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  'A barangay admin verifies every new resident before the account can be used.',
                  style: LuxType.body(fontSize: 12.5, color: LuxColors.inkSoft),
                ),
                const SizedBox(height: 24),
                LuxField(label: 'Full name', controller: _nameController),
                const SizedBox(height: 12),
                LuxField(label: 'Email', controller: _emailController, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                LuxField(
                  label: 'Phone number',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  hintText: '09171234567',
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                ),
                const SizedBox(height: 12),
                LuxField(label: 'Purok', controller: _purokController),
                const SizedBox(height: 12),
                LuxField(
                  label: 'Password',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 19,
                      color: LuxColors.inkSoft,
                    ),
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 22),
                Text('IDENTITY VERIFICATION', style: LuxType.eyebrow(fontSize: 10.5)),
                const SizedBox(height: 10),
                _PhotoPicker(
                  label: 'Valid ID',
                  subtitle: 'A photo or scan of any government or barangay-issued ID',
                  bytes: _idPhotoBytes,
                  onTap: _captureId,
                ),
                const SizedBox(height: 10),
                _PhotoPicker(
                  label: 'Face photo',
                  subtitle: 'A live selfie, taken now, for the admin to match against your ID',
                  bytes: _facePhotoBytes,
                  onTap: _captureFace,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: LuxType.body(fontSize: 12, color: LuxColors.red)),
                ],
                const SizedBox(height: 22),
                LuxButton(
                  label: _loading ? 'Creating account...' : 'Submit for verification',
                  loading: _loading,
                  onTap: _loading ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Same white-surface / rounded-14 / hairline-border shape as LuxField and
/// resident_home_screen.dart's own cards — the photo-picker row sits in
/// that same family instead of the separate teal-accented panel style it
/// used to have on the old palette.
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.label, required this.subtitle, required this.bytes, required this.onTap});

  final String label;
  final String subtitle;
  final Uint8List? bytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LuxColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: bytes != null ? LuxColors.success : LuxColors.divider),
          ),
          child: Row(
            children: [
              if (bytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  // Image.memory, not Image.file — a dart:io File-based
                  // preview silently fails on Flutter Web (no real
                  // filesystem there); raw bytes render identically on
                  // every platform.
                  child: Image.memory(bytes!, width: 46, height: 46, fit: BoxFit.cover),
                )
              else
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(color: LuxColors.surfaceMuted, shape: BoxShape.circle),
                  child: const Icon(Icons.add_a_photo_outlined, size: 18, color: LuxColors.inkSoft),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: LuxType.heading(fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(
                      bytes != null ? 'Selected — tap to retake' : subtitle,
                      style: LuxType.body(fontSize: 10.5, color: LuxColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
