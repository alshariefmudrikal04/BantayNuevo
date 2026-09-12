import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../data/auth_repository.dart';

/// Resident sign-up — the only self-registration path left in the app
/// (tanod/police/admin accounts are created by an existing admin; see
/// AdminUsersSection). Requires an ID photo + a live face photo, both
/// reviewed by a Barangay Admin before the account can actually be used —
/// see VerificationStatus on UserModel and VerificationPendingScreen,
/// which is what a newly-registered resident lands on right after this.
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
      // Previously, backing out mid-upload could leave a Firebase Auth
      // account created with no matching Firestore user doc (registration
      // creates the Auth account first, then uploads two photos, then
      // writes Firestore last) — AuthRepository.register now rolls that
      // orphaned account back on failure, but the safest fix is simply not
      // letting the resident navigate away mid-submit in the first place,
      // since a slow connection could otherwise make it look "stuck" and
      // invite exactly that back-out.
      canPop: !_loading,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please wait for this to finish.')),
        );
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: const Text('Resident sign-up')),
        body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create your account', style: AppTypography.display(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                'A barangay admin verifies every new resident before the account can be used — this keeps SOS access limited to actual residents of the barangay.',
                style: AppTypography.bodySoft(fontSize: 12.5),
              ),
              const SizedBox(height: 24),
              _Field(label: 'Full name', controller: _nameController),
              const SizedBox(height: 12),
              _Field(label: 'Email', controller: _emailController, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _Field(
                label: 'Phone number',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                hint: '09171234567',
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
              ),
              const SizedBox(height: 12),
              _Field(label: 'Purok', controller: _purokController),
              const SizedBox(height: 12),
              _Field(label: 'Password', controller: _passwordController, obscure: true),
              const SizedBox(height: 20),
              Text('IDENTITY VERIFICATION', style: AppTypography.mono(fontSize: 10.5, letterSpacing: 0.4)),
              const SizedBox(height: 8),
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
                const SizedBox(height: 12),
                Text(_error!, style: AppTypography.mono(fontSize: 11, color: AppColors.urgent)),
              ],
              const SizedBox(height: 20),
              AppButton(
                label: _loading ? 'Creating account...' : 'Submit for verification',
                onPressed: _loading ? null : _submit,
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.label, required this.subtitle, required this.bytes, required this.onTap});

  final String label;
  final String subtitle;
  final Uint8List? bytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bytes != null ? AppColors.teal : AppColors.line),
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
                decoration: BoxDecoration(color: AppColors.line.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.add_a_photo_outlined, size: 18, color: AppColors.inkSoft),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(bytes != null ? 'Selected — tap to retake' : subtitle, style: AppTypography.bodySoft(fontSize: 10.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.inputFormatters,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTypography.mono(fontSize: 10.5, letterSpacing: 0.4)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
