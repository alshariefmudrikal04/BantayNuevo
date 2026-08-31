import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import 'login_screen.dart';
import 'admin_login_screen.dart';

/// First screen of the auth flow — "I am a...". Selecting a role takes you
/// to login_screen.dart for that role; the actual source of truth for a
/// user's role is always the Firestore users/{uid} doc (set at registration),
/// this selection is just which login/register form to show.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('BANTAY NUEVO', style: AppTypography.mono(fontSize: 11, letterSpacing: 1)),
                ],
              ),
              const SizedBox(height: 10),
              Text('Who are you signing in as?', style: AppTypography.display(fontSize: 24)),
              const SizedBox(height: 6),
              Text(
                'Barangay Camino Nuevo violence response system',
                style: AppTypography.bodySoft(fontSize: 13),
              ),
              const SizedBox(height: 32),
              _RoleCard(
                role: UserRole.resident,
                title: 'Resident',
                desc: 'Report incidents, send SOS, track your cases',
                onTap: () => _goToLogin(context, UserRole.resident),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                role: UserRole.tanod,
                title: 'Barangay Tanod',
                desc: 'Monitor reports, coordinate response',
                onTap: () => _goToLogin(context, UserRole.tanod),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                role: UserRole.police,
                title: 'Police Responder',
                desc: 'Respond to escalated emergency alerts',
                onTap: () => _goToLogin(context, UserRole.police),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                  ),
                  child: Text('Barangay Admin sign-in', style: AppTypography.mono(fontSize: 11, color: AppColors.inkSoft)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToLogin(BuildContext context, UserRole role) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LoginScreen(role: role)),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.title, required this.desc, required this.onTap});

  final UserRole role;
  final String title;
  final String desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.cardRadius,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: AppSpacing.cardRadius,
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.display(fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(desc, style: AppTypography.bodySoft(fontSize: 11.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}
