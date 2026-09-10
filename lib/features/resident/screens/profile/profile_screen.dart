import 'package:flutter/material.dart';
import '../../../../models/user_model.dart';
import '../../../../core/theme/lux_theme.dart';
import '../../../auth/data/auth_repository.dart';
import 'emergency_contacts_screen.dart';
import 'security_screen.dart';
import 'privacy_screen.dart';
import '../my_reports_screen.dart';
import '../../../resources/screens/resources_screen.dart';

/// Settings — reskinned to match the resident's new "luxury minimal" look
/// (see lux_theme.dart / resident_home_screen.dart's doc comments on the
/// rollout plan). Same sections and links as before, just restyled;
/// bypasses the shared cross-role widgets (AppCard, ListItemTile,
/// ToggleRow, etc.) the same way Home does, since those are still used
/// by tanod/police/admin on the old palette.
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
      backgroundColor: LuxColors.bg,
      appBar: AppBar(
        backgroundColor: LuxColors.bg,
        elevation: 0,
        title: Text('SETTINGS', style: LuxType.eyebrow(fontSize: 12, color: LuxColors.ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: LuxColors.red,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: LuxType.hero(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: LuxType.heading(fontSize: 16)),
                      const SizedBox(height: 2),
                      Text('Purok ${user.purok} · ${user.email}', style: LuxType.body(fontSize: 11, color: LuxColors.inkSoft)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text('ACCOUNT', style: LuxType.eyebrow(fontSize: 10.5)),
          const SizedBox(height: 10),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.contacts_outlined,
                title: 'Emergency contacts',
                subtitle: 'Notified alongside Tanod on every SOS',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EmergencyContactsScreen(user: user))),
              ),
              _SettingsRow(
                icon: Icons.folder_open,
                title: 'My reports',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MyReportsScreen(user: user))),
              ),
              _SettingsRow(
                icon: Icons.lock_outline,
                title: 'Evidence vault',
                subtitle: 'Pick a report to view its evidence',
                isLast: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MyReportsScreen(user: user))),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text('SECURITY & PRIVACY', style: LuxType.eyebrow(fontSize: 10.5)),
          const SizedBox(height: 10),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.shield_outlined,
                title: 'App lock & security',
                subtitle: 'PIN, biometric, session timeout',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SecurityScreen())),
              ),
              _SettingsRow(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy & data',
                subtitle: 'Retention policy, data requests',
                isLast: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text('SUPPORT', style: LuxType.eyebrow(fontSize: 10.5)),
          const SizedBox(height: 10),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.local_hospital_outlined,
                title: 'Hotlines & safety guides',
                subtitle: 'Emergency numbers and resources',
                isLast: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ResourcesScreen())),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text('PREFERENCES', style: LuxType.eyebrow(fontSize: 10.5)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Push notifications', style: LuxType.heading(fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text('Alerts on report status changes', style: LuxType.body(fontSize: 11, color: LuxColors.inkSoft)),
                    ],
                  ),
                ),
                Switch(value: _pushEnabled, activeThumbColor: LuxColors.red, onChanged: (v) => setState(() => _pushEnabled = v)),
              ],
            ),
          ),

          const SizedBox(height: 28),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _authRepository.logout,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: LuxColors.divider)),
                child: Text('LOG OUT', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.red, letterSpacing: 0.8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

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

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.title, this.subtitle, required this.onTap, this.isLast = false});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: isLast ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.divider))),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: LuxColors.surfaceMuted, shape: BoxShape.circle),
              child: Icon(icon, size: 17, color: LuxColors.red),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: LuxType.heading(fontSize: 13.5)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: LuxType.body(fontSize: 10.5, color: LuxColors.inkSoft)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: LuxColors.inkSoft),
          ],
        ),
      ),
    );
  }
}
