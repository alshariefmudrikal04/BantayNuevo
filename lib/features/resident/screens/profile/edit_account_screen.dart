import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';

import '../../../../core/theme/lux_theme.dart';
import '../../../../models/user_model.dart';
import '../../../auth/data/auth_repository.dart';

/// One place to change the account-level credentials that live on
/// Firebase Auth + users/{uid} — email, phone, password — and, at the
/// bottom, the destructive "delete account" action. Split out from
/// ProfileScreen (which only has quick links to sections like this one)
/// and from SecurityScreen (which is about the local PIN/biometric lock,
/// not the underlying account itself).
///
/// Every save (and the delete flow) asks for the CURRENT password once,
/// via [_currentPasswordController] — Firebase requires a recent sign-in
/// before it'll allow an email/password change or an account deletion, so
/// this collects it up front rather than the resident hitting a cryptic
/// "requires-recent-login" error after filling everything else in.
class EditAccountScreen extends StatefulWidget {
  const EditAccountScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  final _authRepository = AuthRepository();
  final _formKey = GlobalKey<FormState>();

  late final _emailController = TextEditingController(text: widget.user.email);
  late final _phoneController = TextEditingController(text: widget.user.phone);
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _currentPasswordController = TextEditingController();

  bool _changePassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? LuxColors.red : LuxColors.ink),
    );
  }

  bool get _emailChanged => _emailController.text.trim() != widget.user.email;
  bool get _phoneChanged => _phoneController.text.trim() != widget.user.phone;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final nothingToDo = !_emailChanged && !_phoneChanged && !_changePassword;
    if (nothingToDo) {
      _showSnack('Nothing to save yet.');
      return;
    }

    setState(() => _busy = true);
    try {
      await _authRepository.updateAccount(
        currentPassword: _currentPasswordController.text,
        newEmail: _emailChanged ? _emailController.text.trim() : null,
        newPhone: _phoneChanged ? _phoneController.text.trim() : null,
        newPassword: _changePassword ? _newPasswordController.text : null,
      );
      if (!mounted) return;

      if (_emailChanged) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Check your new inbox'),
            content: Text(
              'We sent a confirmation link to ${_emailController.text.trim()}. '
              'Your email won\'t switch over for logging in until you click it.',
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it'))],
          ),
        );
      } else {
        _showSnack('Account updated.');
      }
      if (mounted) Navigator.of(context).pop();
    } on fb_auth.FirebaseAuthException catch (e) {
      _showSnack(AuthRepository.friendlyError(e), isError: true);
    } catch (e) {
      _showSnack('Could not save changes: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (password == null || password.isEmpty) return;

    setState(() => _busy = true);
    try {
      await _authRepository.deleteAccount(currentPassword: password);
      // No navigation needed here — deleting the Firebase Auth user fires
      // authStateChanges() -> AuthGate swaps straight back to LoginScreen
      // on its own, same as a normal logout.
    } on fb_auth.FirebaseAuthException catch (e) {
      _showSnack(AuthRepository.friendlyError(e), isError: true);
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      _showSnack('Could not delete account: $e', isError: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxColors.bg,
      appBar: AppBar(
        backgroundColor: LuxColors.bg,
        elevation: 0,
        title: Text('EDIT ACCOUNT', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.ink)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('LOGIN DETAILS', style: LuxType.eyebrow(fontSize: 10.5)),
            const SizedBox(height: 10),
            _FieldGroup(
              children: [
                _LabeledField(
                  label: 'Email',
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _decoration('you@gmail.com'),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                ),
                _LabeledField(
                  label: 'Phone number',
                  isLast: true,
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: _decoration('09XX XXX XXXX'),
                    validator: (v) => (v == null || v.trim().length < 7) ? 'Enter a valid phone number' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Text('PASSWORD', style: LuxType.eyebrow(fontSize: 10.5)),
            const SizedBox(height: 10),
            _FieldGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Change password', style: LuxType.heading(fontSize: 13.5)),
                            const SizedBox(height: 2),
                            Text('Set a new password for signing in', style: LuxType.body(fontSize: 11, color: LuxColors.inkSoft)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _changePassword,
                        activeThumbColor: LuxColors.red,
                        onChanged: (v) => setState(() => _changePassword = v),
                      ),
                    ],
                  ),
                ),
                if (_changePassword) ...[
                  const Divider(height: 1, color: LuxColors.divider),
                  _LabeledField(
                    label: 'New password',
                    child: TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      decoration: _decoration('At least 6 characters', obscureToggle: () => setState(() => _obscureNew = !_obscureNew), obscured: _obscureNew),
                      validator: (v) {
                        if (!_changePassword) return null;
                        if (v == null || v.length < 6) return 'At least 6 characters';
                        return null;
                      },
                    ),
                  ),
                  _LabeledField(
                    label: 'Confirm new password',
                    isLast: true,
                    child: TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureNew,
                      decoration: _decoration('Re-enter new password'),
                      validator: (v) {
                        if (!_changePassword) return null;
                        if (v != _newPasswordController.text) return 'Passwords don\'t match';
                        return null;
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            Text('CONFIRM WITH CURRENT PASSWORD', style: LuxType.eyebrow(fontSize: 10.5)),
            const SizedBox(height: 10),
            _FieldGroup(
              children: [
                _LabeledField(
                  label: 'Current password',
                  isLast: true,
                  child: TextFormField(
                    controller: _currentPasswordController,
                    obscureText: _obscureCurrent,
                    decoration: _decoration(
                      'Required to save changes',
                      obscureToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      obscured: _obscureCurrent,
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password to confirm' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Needed so we can verify it\'s really you before changing anything on your account.',
              style: LuxType.body(fontSize: 10.5, color: LuxColors.inkSoft),
            ),
            const SizedBox(height: 24),

            Material(
              color: LuxColors.ink,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _busy ? null : _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  alignment: Alignment.center,
                  child: _busy
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('SAVE CHANGES', style: LuxType.eyebrow(fontSize: 11.5, color: Colors.white, letterSpacing: 0.8)),
                ),
              ),
            ),

            const SizedBox(height: 40),
            Text('DANGER ZONE', style: LuxType.eyebrow(fontSize: 10.5, color: LuxColors.red)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: LuxColors.redSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.red.withOpacity(0.25))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delete account', style: LuxType.heading(fontSize: 14, color: LuxColors.redDark)),
                  const SizedBox(height: 4),
                  Text(
                    'Permanently removes your login and profile. This cannot be undone.',
                    style: LuxType.body(fontSize: 11.5, color: LuxColors.ink),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _busy ? null : _confirmDelete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: LuxColors.red)),
                        child: Text('DELETE MY ACCOUNT', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.red, letterSpacing: 0.6)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint, {VoidCallback? obscureToggle, bool obscured = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: LuxType.body(fontSize: 13, color: LuxColors.inkSoft),
      border: InputBorder.none,
      isDense: true,
      suffixIcon: obscureToggle == null
          ? null
          : IconButton(
              icon: Icon(obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: LuxColors.inkSoft),
              onPressed: obscureToggle,
            ),
    );
  }
}

class _FieldGroup extends StatelessWidget {
  const _FieldGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child, this.isLast = false});

  final String label;
  final Widget child;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: isLast ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.divider))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: LuxType.eyebrow(fontSize: 9.5, letterSpacing: 0.5)),
          child,
        ],
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This permanently deletes your login and profile. Enter your password to confirm.'),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Current password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text('Delete', style: TextStyle(color: LuxColors.red)),
        ),
      ],
    );
  }
}
