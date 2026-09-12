import 'package:flutter/material.dart';
import '../../../core/theme/lux_theme.dart';
import '../../../core/widgets/lux_field.dart';
import '../../../core/widgets/lux_button.dart';
import '../data/auth_repository.dart';

/// "Forgot account?" — enter the email you registered with, get a
/// password-reset link. A plain FirebaseAuth SDK call
/// (AuthRepository.sendPasswordResetEmail) — no Cloud Function, no Blaze
/// plan needed.
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
        // matched an account, so an error here is almost always a
        // malformed address or no connection — never "that email doesn't
        // exist," which would leak account existence.
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
                        : 'Enter the email you registered with and we\'ll send a link to reset your password.',
                    style: LuxType.body(fontSize: 12.5, color: LuxColors.inkSoft),
                  ),
                  const SizedBox(height: 24),
                  if (!_sent) ...[
                    LuxField(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: LuxType.body(fontSize: 12, color: LuxColors.red)),
                    ],
                    const SizedBox(height: 20),
                    LuxButton(
                      label: _loading ? 'Sending...' : 'Send reset link',
                      loading: _loading,
                      onTap: _loading ? null : _sendResetEmail,
                    ),
                  ] else ...[
                    GestureDetector(
                      onTap: _loading ? null : _sendResetEmail,
                      child: Text('Resend email', style: LuxType.eyebrow(fontSize: 10, color: LuxColors.red)),
                    ),
                    const SizedBox(height: 20),
                    LuxButton(
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
