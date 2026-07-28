import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../data/auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.role});

  final UserRole role;

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

  Future<void> _submit() async {
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
        role: widget.role, // fixed — set by which role card they tapped on role_select_screen, not user-editable here
      );
      // AuthGate (core/router/app_router.dart) already picked up the new
      // signed-in user in the background — but LoginScreen/RegisterScreen
      // were pushed on top of it, so we need to pop back to root ourselves
      // for that updated screen to actually become visible.
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
      appBar: AppBar(title: Text('${widget.role.displayLabel} registration')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create your account', style: AppTypography.display(fontSize: 22)),
              const SizedBox(height: 4),
              Text('Registering as ${widget.role.displayLabel}.', style: AppTypography.bodySoft(fontSize: 12.5)),
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
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: AppTypography.mono(fontSize: 11, color: AppColors.urgent)),
              ],
              const SizedBox(height: 20),
              AppButton(
                label: _loading ? 'Creating account...' : 'Register',
                onPressed: _loading ? null : _submit,
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