import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../models/user_model.dart';
import '../data/auth_repository.dart';

/// Barangay Admin sign-in — deliberately separate from LoginScreen
/// (auth/screens/login_screen.dart) because that screen always offers a
/// "Register" link, and admin accounts are never meant to be self-
/// registered (see AdminRepository.createStaffAccount — only an existing
/// admin can create another one; the very first admin account has to be
/// seeded directly in Firestore/Firebase console).
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
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
      final user = await _authRepository.login(email: _emailController.text.trim(), password: _passwordController.text);
      if (user.role != UserRole.admin) {
        setState(() {
          _error = 'This account is registered as ${user.role.displayLabel}, not Barangay Admin.';
          _loading = false;
        });
        await _authRepository.logout();
        return;
      }
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
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
      appBar: AppBar(title: const Text('Barangay Admin login')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin sign-in', style: AppTypography.display(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text('For monitoring and managing the system. No self-registration — accounts are created by another admin.', style: AppTypography.bodySoft(fontSize: 12.5)),
                  const SizedBox(height: 24),
                  Text('EMAIL', style: AppTypography.mono(fontSize: 10.5, letterSpacing: 0.4)),
                  const SizedBox(height: 4),
                  TextField(controller: _emailController, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  Text('PASSWORD', style: AppTypography.mono(fontSize: 10.5, letterSpacing: 0.4)),
                  const SizedBox(height: 4),
                  TextField(controller: _passwordController, obscureText: true),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: AppTypography.mono(fontSize: 11, color: AppColors.urgent)),
                  ],
                  const SizedBox(height: 20),
                  AppButton(label: _loading ? 'Signing in...' : 'Log in', onPressed: _loading ? null : _submit),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
