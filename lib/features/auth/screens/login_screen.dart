import 'package:flutter/material.dart';
import '../../../core/theme/lux_theme.dart';
import '../../../core/widgets/lux_field.dart';
import '../../../core/widgets/lux_button.dart';
import '../data/auth_repository.dart';
import 'register_screen.dart';
import 'forgot_account_screen.dart';

/// The app's single sign-in screen — no role picker, no "which login are
/// you" branching. Whoever's account this is (resident, tanod, police, or
/// admin) gets routed to the right home screen automatically by AuthGate
/// (core/router/app_router.dart), which reads the role straight off their
/// Firestore user doc the moment they're signed in.
///
/// Matches resident_home_screen.dart's actual component vocabulary rather
/// than a generic auth-page skin: the eyebrow+hero greeting pattern is the
/// same one used there ("WELCOME BACK," / firstName), and the input fields
/// reuse the exact rounded/bordered surface treatment that shows up in
/// every card on that screen (LuxField, in core/widgets) — not a separate
/// "form input" look invented just for this page. No logo lockup or
/// wordmark sits above the greeting: resident_home_screen doesn't have one
/// either, and it wasn't earning its place here — it labeled nothing.
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
      // Nothing else to do here — AuthGate is already listening in the
      // background and swaps itself to the right home screen the instant
      // it sees this account signed in. LoginScreen IS the root screen
      // (app_router.dart), so there's no route to pop back to.
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
                  const SizedBox(height: 12),
                  Text('LOG IN', style: LuxType.eyebrow(fontSize: 11)),
                  const SizedBox(height: 2),
                  Text('Bantay Nuevo', style: LuxType.hero(fontSize: 36)),
                  const SizedBox(height: 28),
                  LuxField(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
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
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: LuxType.body(fontSize: 12, color: LuxColors.red)),
                  ],
                  const SizedBox(height: 18),
                  LuxButton(
                    label: _loading ? 'Signing in...' : 'Log in',
                    loading: _loading,
                    onTap: _loading ? null : _submit,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        ),
                        child: Text('Register', style: LuxType.eyebrow(fontSize: 10.5, color: LuxColors.ink)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ForgotAccountScreen()),
                        ),
                        child: Text('Forgot account?', style: LuxType.eyebrow(fontSize: 10.5, color: LuxColors.red)),
                      ),
                    ],
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
