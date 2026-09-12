import 'package:flutter/material.dart';
import '../../../core/theme/lux_theme.dart';
import '../data/auth_repository.dart';
import 'register_screen.dart';
import 'forgot_account_screen.dart';

/// The app's single sign-in screen — no role picker, no "which login are
/// you" branching. Whoever's account this is (resident, tanod, police, or
/// admin) gets routed to the right home screen automatically by AuthGate
/// (core/router/app_router.dart), which reads the role straight off their
/// Firestore user doc the moment they're signed in. This replaced an
/// earlier role_select_screen.dart that asked the person to pick a role
/// card before even seeing a login form — redundant once every account
/// already knows its own role server-side.
///
/// Reskinned to the same "luxury minimal" design used on
/// resident_home_screen.dart (LuxColors/LuxType — see lux_theme.dart) so
/// the very first screen someone sees matches the rest of the resident
/// experience instead of the old navy/sage palette. Copy was trimmed to
/// just what's needed to act — no "Sign in to continue." filler line, and
/// the tanod/police/admin explainer shrunk to a single short caption
/// instead of a full sentence.
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
  bool _obscurePassword = true;
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
        _error = AuthRepository.friendlyError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: LuxColors.red, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('BANTAY NUEVO', style: LuxType.eyebrow(fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text('Welcome back', style: LuxType.hero(fontSize: 34)),
                  const SizedBox(height: 28),
                  _LuxField(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _LuxField(
                    label: 'Password',
                    controller: _passwordController,
                    obscure: _obscurePassword,
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
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ForgotAccountScreen()),
                      ),
                      child: Text('Forgot account?', style: LuxType.eyebrow(fontSize: 10.5, color: LuxColors.red, letterSpacing: 0.2)),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: LuxType.body(fontSize: 12, color: LuxColors.red)),
                  ],
                  const SizedBox(height: 22),
                  _LuxButton(
                    label: _loading ? 'Signing in...' : 'Log in',
                    loading: _loading,
                    onTap: _loading ? null : _submit,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: LuxType.body(fontSize: 12.5, color: LuxColors.inkSoft),
                          children: [
                            const TextSpan(text: 'No account yet? '),
                            TextSpan(text: 'Register', style: LuxType.body(fontSize: 12.5, color: LuxColors.red, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Tanod, police, and admin accounts are issued by an admin.',
                      textAlign: TextAlign.center,
                      style: LuxType.eyebrow(fontSize: 9.5, color: LuxColors.inkSoft, letterSpacing: 0.2),
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

/// Card-style input matching the row treatment used across
/// resident_home_screen.dart (white surface, hairline divider border,
/// rounded corners) instead of the old underline-style TextField.
class _LuxField extends StatelessWidget {
  const _LuxField({
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

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
            obscureText: obscure,
            keyboardType: keyboardType,
            style: LuxType.body(fontSize: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              suffixIcon: suffixIcon,
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-width black CTA button, matching the weight/shape language of
/// resident_home_screen.dart's _SosBanner and _ServiceRow (solid fill,
/// 14-16px radius, InkWell ripple) rather than the old ElevatedButton
/// default styling.
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
