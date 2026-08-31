import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../models/user_model.dart';
import '../data/admin_repository.dart';

/// User Management — every account in the system, filterable by role,
/// with activate/deactivate and role-change controls, plus creating new
/// Tanod/Police/Admin accounts directly (see AdminRepository.createStaffAccount
/// for why that needs a throwaway secondary FirebaseApp under the hood).
///
/// "Approve/verify responder accounts" from the original brief is covered
/// by activate/deactivate here — residents self-register already, but a
/// newly-created tanod/police account created THROUGH this screen is the
/// verification step: nobody becomes a responder without an admin
/// deliberately creating that account.
class AdminUsersSection extends StatefulWidget {
  const AdminUsersSection({super.key, required this.currentAdminUid});

  final String currentAdminUid;

  @override
  State<AdminUsersSection> createState() => _AdminUsersSectionState();
}

class _AdminUsersSectionState extends State<AdminUsersSection> {
  final _repository = AdminRepository();
  UserRole? _roleFilter;

  Future<void> _toggleActive(UserModel user) async {
    if (user.uid == widget.currentAdminUid) {
      _showSnack("You can't deactivate your own account.", isError: true);
      return;
    }
    try {
      await _repository.setUserActive(user.uid, !user.active);
    } catch (e) {
      _showSnack('Could not update: $e', isError: true);
    }
  }

  Future<void> _changeRole(UserModel user) async {
    if (user.uid == widget.currentAdminUid) {
      _showSnack("You can't change your own role here.", isError: true);
      return;
    }
    final newRole = await showDialog<UserRole>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Change role for ${user.name}'),
        children: [
          for (final role in UserRole.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(role),
              child: Text(role.displayLabel),
            ),
        ],
      ),
    );
    if (newRole == null || newRole == user.role) return;
    try {
      await _repository.setUserRole(user.uid, newRole);
    } catch (e) {
      _showSnack('Could not update role: $e', isError: true);
    }
  }

  Future<void> _createStaffAccount() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateStaffDialog(repository: _repository),
    );
    if (created == true) _showSnack('Account created.');
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? AppColors.urgent : AppColors.navyDeep),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: _repository.streamAllUsers(),
      builder: (context, snapshot) {
        var users = snapshot.data ?? [];
        if (_roleFilter != null) users = users.where((u) => u.role == _roleFilter).toList();

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('All accounts', style: AppTypography.display(fontSize: 18))),
                  OutlinedButton.icon(
                    onPressed: _createStaffAccount,
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const Text('Create tanod / police account'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _roleChip(null, 'All'),
                  for (final role in UserRole.values) _roleChip(role, role.displayLabel),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    for (final user in users)
                      AppCard(
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.tealLight,
                              child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.teal)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.name, style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text('${user.role.displayLabel} · ${user.email}', style: AppTypography.mono(fontSize: 10)),
                                ],
                              ),
                            ),
                            TextButton(onPressed: () => _changeRole(user), child: const Text('Change role')),
                            const SizedBox(width: 4),
                            Switch(
                              value: user.active,
                              activeThumbColor: AppColors.teal,
                              onChanged: (_) => _toggleActive(user),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _roleChip(UserRole? role, String label) {
    final selected = _roleFilter == role;
    return ChoiceChip(
      label: Text(label, style: AppTypography.mono(fontSize: 10.5, color: selected ? Colors.white : AppColors.inkSoft)),
      selected: selected,
      onSelected: (_) => setState(() => _roleFilter = role),
      selectedColor: AppColors.navy,
      backgroundColor: AppColors.panel,
      side: BorderSide(color: selected ? AppColors.navy : AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.pillRadius),
    );
  }
}

class _CreateStaffDialog extends StatefulWidget {
  const _CreateStaffDialog({required this.repository});

  final AdminRepository repository;

  @override
  State<_CreateStaffDialog> createState() => _CreateStaffDialogState();
}

class _CreateStaffDialogState extends State<_CreateStaffDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _purok = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.tanod;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _purok.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _password.text.length < 6) {
      setState(() => _error = 'Name, email, and a password of at least 6 characters are required.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.createStaffAccount(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        purok: _purok.text.trim(),
        password: _password.text,
        role: _role,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'Could not create account: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create a staff account'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<UserRole>(
                value: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [UserRole.tanod, UserRole.police, UserRole.admin]
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.displayLabel)))
                    .toList(),
                onChanged: (r) => setState(() => _role = r ?? UserRole.tanod),
              ),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
              TextField(controller: _purok, decoration: const InputDecoration(labelText: 'Purok')),
              TextField(controller: _password, decoration: const InputDecoration(labelText: 'Temporary password'), obscureText: true),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: AppTypography.mono(fontSize: 11, color: AppColors.urgent)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        SizedBox(
          width: 140,
          child: AppButton(label: _loading ? 'Creating...' : 'Create', onPressed: _loading ? null : _submit, fullWidth: false),
        ),
      ],
    );
  }
}
