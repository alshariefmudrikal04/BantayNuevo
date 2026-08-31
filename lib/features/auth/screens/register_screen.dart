import 'dart:io';

import 'package:flutter/material.dart';
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
  final _authRepository = AuthRepository();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _purokController = TextEditingController();
  final _passwordController = TextEditingController();
  File? _idPhoto;
  File? _facePhoto;
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
    if (file != null) setState(() => _idPhoto = File(file.path));
  }

  Future<void> _captureFace() async {
    // Camera, front-facing — this needs to be a live selfie taken right
    // now, not a photo-of-a-photo, so gallery isn't offered here at all.
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
    );
    if (file != null) setState(() => _facePhoto = File(file.path));
  }

  Future<void> _submit() async {
    if (_idPhoto == null || _facePhoto == null) {
      setState(() => _error = 'Both your ID photo and a face photo are required.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authRepository.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        purok: _purokController.text.trim(),
        password: _passwordController.text,
        idPhoto: _idPhoto!,
        facePhoto: _facePhoto!,
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
        _error = 'Could not create account: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              _Field(label: 'Phone number', controller: _phoneController, keyboardType: TextInputType.phone),
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
                file: _idPhoto,
                onTap: _captureId,
              ),
              const SizedBox(height: 10),
              _PhotoPicker(
                label: 'Face photo',
                subtitle: 'A live selfie, taken now, for the admin to match against your ID',
                file: _facePhoto,
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
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.label, required this.subtitle, required this.file, required this.onTap});

  final String label;
  final String subtitle;
  final File? file;
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
          border: Border.all(color: file != null ? AppColors.teal : AppColors.line),
        ),
        child: Row(
          children: [
            if (file != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(file!, width: 46, height: 46, fit: BoxFit.cover),
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
                  Text(file != null ? 'Selected — tap to retake' : subtitle, style: AppTypography.bodySoft(fontSize: 10.5)),
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
  const _Field({required this.label, required this.controller, this.obscure = false, this.keyboardType});

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;

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
        ),
      ],
    );
  }
}
