import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../data/auth_repository.dart';
import 'register_screen.dart';

/// The app's single sign-in screen — no role picker, no "which login are
/// you" branching. Whoever's account this is (resident, tanod, police, or
/// admin) gets routed to the right home screen automatically by AuthGate
/// (core/router/app_router.dart), which reads the role straight off their
/// Firestore user doc the moment they're signed in. This replaced an
/// earlier role_select_screen.dart that asked the person to pick a role
/// card before even seeing a login form — redundant once every account
/// already knows its own role server-side.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authRepository = AuthRepository();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authRepository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Nothing else to do here — AuthGate is already listening to
      // authStateChanges in the background and will swap itself to the
      // right home screen for whatever role this account turns out to be
      // the instant Firestore confirms it. LoginScreen IS that root
      // screen now (see app_router.dart), so there's no route to pop
      // back to — just let the StreamBuilder above take over.
    } catch (e) {
      setState(() {
        _error = 'Could not sign in: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('Bantay Nuevo', style: AppTypography.mono(fontSize: 11, letterSpacing: 0.4)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Welcome back', style: AppTypography.display(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text('Sign in to continue.', style: AppTypography.bodySoft(fontSize: 12.5)),
                  const SizedBox(height: 24),
                  _Field(label: 'Email', controller: _emailController, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _Field(label: 'Password', controller: _passwordController, obscure: true),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: AppTypography.mono(fontSize: 11, color: AppColors.urgent)),
                  ],
                  const SizedBox(height: 20),
                  AppButton(
                    label: _loading ? 'Signing in...' : 'Log in',
                    onPressed: _loading ? null : _submit,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                      child: const Text('No account yet? Register as a resident'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Tanod, police, and admin accounts are created by a barangay admin.',
                      textAlign: TextAlign.center,
                      style: AppTypography.mono(fontSize: 10.5, color: AppColors.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
