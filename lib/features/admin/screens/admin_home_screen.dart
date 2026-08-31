import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/user_model.dart';
import '../../auth/data/auth_repository.dart';
import 'admin_overview_section.dart';
import 'admin_incidents_section.dart';
import 'admin_responders_section.dart';
import 'admin_users_section.dart';
import 'admin_verifications_section.dart';
import 'admin_alarm_sounds_section.dart';

/// Root shell for the Barangay Admin dashboard (Prompt 14) — a persistent
/// sidebar (NavigationRail) + top bar, built to be opened maximized on a
/// PC rather than a phone-sized screen, per AGENTS.md's Prompt 14 note.
/// Still runs fine on a phone (NavigationRail collapses to icons-only,
/// Flutter is the same app either way), but this is where a Barangay
/// Admin is expected to actually live day-to-day: monitoring, assigning
/// responders, and managing accounts from a desk, not a phone.
///
/// Records/incident-history export and the full live incident map are
/// intentionally not built yet — this first pass covers Incident
/// Management, Responder Management, User Management, and the org-wide
/// Alarm Sounds control that replaced the earlier per-tanod picker.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _authRepository = AuthRepository();
  AdminSection _section = AdminSection.overview;

  static const _destinations = [
    (AdminSection.overview, Icons.dashboard_outlined, 'Overview'),
    (AdminSection.incidents, Icons.report_gmailerrorred_outlined, 'Incidents'),
    (AdminSection.responders, Icons.groups_outlined, 'Responders'),
    (AdminSection.users, Icons.manage_accounts_outlined, 'Users'),
    (AdminSection.verifications, Icons.fact_check_outlined, 'Verifications'),
    (AdminSection.alarmSounds, Icons.volume_up_outlined, 'Alarm Sounds'),
  ];

  String get _title => switch (_section) {
        AdminSection.overview => 'Overview',
        AdminSection.incidents => 'Incident Management',
        AdminSection.responders => 'Responder Management',
        AdminSection.users => 'User Management',
        AdminSection.verifications => 'Resident Verifications',
        AdminSection.alarmSounds => 'Alarm Sounds',
      };

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _destinations.indexWhere((d) => d.$1 == _section);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('Bantay Nuevo — $_title'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('${widget.user.name} · Admin', style: AppTypography.bodySoft(fontSize: 12)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Log out',
            onPressed: _authRepository.logout,
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) => setState(() => _section = _destinations[i].$1),
            labelType: NavigationRailLabelType.all,
            backgroundColor: AppColors.panel,
            useIndicator: true,
            indicatorColor: AppColors.tealLight,
            selectedIconTheme: const IconThemeData(color: AppColors.teal),
            selectedLabelTextStyle: AppTypography.body(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.teal),
            unselectedLabelTextStyle: AppTypography.bodySoft(fontSize: 11),
            destinations: [
              for (final d in _destinations) NavigationRailDestination(icon: Icon(d.$2), label: Text(d.$3)),
            ],
          ),
          const VerticalDivider(width: 1, color: AppColors.line),
          Expanded(
            child: switch (_section) {
              AdminSection.overview => AdminOverviewSection(onNavigate: (s) => setState(() => _section = s)),
              AdminSection.incidents => const AdminIncidentsSection(),
              AdminSection.responders => const AdminRespondersSection(),
              AdminSection.users => AdminUsersSection(currentAdminUid: widget.user.uid),
              AdminSection.verifications => const AdminVerificationsSection(),
              AdminSection.alarmSounds => const AdminAlarmSoundsSection(),
            },
          ),
        ],
      ),
    );
  }
}

/// Which sidebar section is showing — public so AdminOverviewSection's
/// quick-links can request a switch without this shell needing to expose
/// anything more than this enum + the callback signature below.
enum AdminSection { overview, incidents, responders, users, verifications, alarmSounds }
