import 'package:flutter/material.dart';
import '../../../../models/user_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/section_title.dart';
import '../../../../core/widgets/list_item_tile.dart';
import '../../../../core/widgets/toggle_row.dart';
import '../../../auth/data/auth_repository.dart';
import 'emergency_contacts_screen.dart';
import 'security_screen.dart';
import 'privacy_screen.dart';
import '../my_reports_screen.dart';
import '../../../resources/screens/resources_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authRepository = AuthRepository();
  bool _pushEnabled = true;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.tealLight,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: AppTypography.display(fontSize: 16, color: AppColors.teal),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: AppTypography.display(fontSize: 15)),
                      Text('Purok ${user.purok} · ${user.email}', style: AppTypography.bodySoft(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SectionTitle('Account'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Column(
              children: [
                ListItemTile(
                  title: 'Emergency contacts',
                  subtitle: 'Notified alongside Tanod on every SOS',
                  showChevron: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => EmergencyContactsScreen(user: user)),
                  ),
                ),
                ListItemTile(
                  title: 'My reports',
                  showChevron: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => MyReportsScreen(user: user)),
                  ),
                ),
                ListItemTile(
                  title: 'Evidence vault',
                  subtitle: 'Pick a report to view its evidence',
                  showChevron: true,
                  isLast: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => MyReportsScreen(user: user)),
                  ),
                ),
              ],
            ),
          ),

          const SectionTitle('Security & privacy'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Column(
              children: [
                ListItemTile(
                  title: 'App lock & security',
                  subtitle: 'PIN, biometric, session timeout',
                  showChevron: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SecurityScreen()),
                  ),
                ),
                ListItemTile(
                  title: 'Privacy & data',
                  subtitle: 'Retention policy, data requests',
                  showChevron: true,
                  isLast: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                  ),
                ),
              ],
            ),
          ),

          const SectionTitle('Support'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: ListItemTile(
              title: 'Hotlines & safety guides',
              subtitle: 'Emergency numbers and resources',
              showChevron: true,
              isLast: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ResourcesScreen()),
              ),
            ),
          ),

          const SectionTitle('Preferences'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: ToggleRow(
              label: 'Push notifications',
              description: 'Alerts on report status changes',
              value: _pushEnabled,
              onChanged: (v) => setState(() => _pushEnabled = v),
              isLast: true,
            ),
          ),

          const SizedBox(height: 16),
          AppButton(
            label: 'Log out',
            variant: AppButtonVariant.ghost,
            onPressed: _authRepository.logout,
          ),
        ],
      ),
    );
  }
}
