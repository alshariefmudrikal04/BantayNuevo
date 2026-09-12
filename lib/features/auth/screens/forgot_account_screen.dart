import 'package:flutter/material.dart';
import '../../../core/theme/lux_theme.dart';
import '../data/auth_repository.dart';

/// "Forgot account?" — one step: enter the email you registered with, and
/// Firebase sends a password-reset link to it (AuthRepository.sendPasswordResetEmail,
/// a plain FirebaseAuth SDK call — no Cloud Function, no Blaze plan needed,
/// works on the free Spark tier). An earlier version of this screen sent a
/// 6-digit SMS code and reset the password in-app, but that required a
/// Cloud Function to call admin.auth().updateUser (the client SDK can't
/// change a different account's password), and Cloud Functions require the
/// Blaze plan. This trades "reset via phone" for "zero extra
/// infrastructure" — worth revisiting if this project ever does move to
/// Blaze.
class ForgotAccountScreen extends StatefulWidget {
  const ForgotAccountScreen({super.key});

  @override
  State<ForgotAccountScreen> createState() => _ForgotAccountScreenState();
}

class _ForgotAccountScreenState extends State<ForgotAccountScreen> {
  final _authRepository = AuthRepository();
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter the email you registered with.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authRepository.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Firebase resolves this the same way whether or not the email
        // matched an account, so any error here is almost always just a
        // malformed address or no connection — never "that email doesn't
        // exist", which would leak account existence.
        _error = AuthRepository.friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxColors.bg,
      appBar: AppBar(
        backgroundColor: LuxColors.bg,
        elevation: 0,
        foregroundColor: LuxColors.black,
        title: Text('Recover account', style: LuxType.heading(fontSize: 16)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sent ? 'Check your email' : 'Forgot your password?',
                    style: LuxType.hero(fontSize: 26),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _sent
                        ? 'If ${_emailController.text.trim()} matches an account, a reset link is on its way. Open it on this device to set a new password.'
                        : 'Enter the email you registered with and we\'ll send you a link to reset your password.',
                    style: LuxType.body(fontSize: 12.5, color: LuxColors.inkSoft),
                  ),
                  const SizedBox(height: 24),
                  if (!_sent) ...[
                    _LuxField(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: LuxType.body(fontSize: 12, color: LuxColors.red)),
                    ],
                    const SizedBox(height: 22),
                    _LuxButton(
                      label: _loading ? 'Sending...' : 'Send reset link',
                      loading: _loading,
                      onTap: _loading ? null : _sendResetEmail,
                    ),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: _loading ? null : _sendResetEmail,
                        child: Text('Resend email', style: LuxType.eyebrow(fontSize: 10, color: LuxColors.red)),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _LuxButton(
                      label: 'Back to log in',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LuxField extends StatelessWidget {
  const _LuxField({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: LuxType.eyebrow(fontSize: 10)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: LuxColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: LuxColors.divider),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: LuxType.body(fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _LuxButton extends StatelessWidget {
  const _LuxButton({required this.label, required this.onTap, this.loading = false});

  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: LuxColors.black,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(label, style: LuxType.heading(fontSize: 14, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}
