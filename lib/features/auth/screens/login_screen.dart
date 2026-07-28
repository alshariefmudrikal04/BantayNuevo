import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../data/auth_repository.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.role});

  final UserRole role;

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
      final user = await _authRepository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (user.role != widget.role) {
        // Signed in fine, but this account's real role (from Firestore)
        // doesn't match the tab they picked on role_select_screen.
        setState(() {
          _error =
              'This account is registered as ${user.role.displayLabel}, not ${widget.role.displayLabel}.';
          _loading = false;
        });
        await _authRepository.logout();
        return;
      }
      // AuthGate (core/router/app_router.dart) already picked up the signed-in
      // user in the background — but LoginScreen was pushed on top of it, so
      // we need to pop back to root ourselves for that to become visible.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
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
      appBar: AppBar(title: Text('${widget.role.displayLabel} login')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back', style: AppTypography.display(fontSize: 22)),
              const SizedBox(height: 4),
              Text('Sign in to continue as ${widget.role.displayLabel}.', style: AppTypography.bodySoft(fontSize: 12.5)),
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
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RegisterScreen(role: widget.role)),
                  ),
                  child: const Text('No account yet? Register'),
                ),
              ),
            ],
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