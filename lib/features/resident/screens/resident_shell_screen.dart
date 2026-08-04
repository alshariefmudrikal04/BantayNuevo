import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import 'resident_home_screen.dart';
import 'report_form_screen.dart';
import 'sos_screen.dart';
import 'profile/profile_screen.dart';
import '../../resources/screens/resources_screen.dart';

/// Wraps the resident's 4 browsable sections (Home, Report, Resources,
/// Profile) in a persistent bottom tab bar, matching the original HTML
/// mockup's navigation. SOS is the 5th nav item but is NOT a tab body — it's
/// always a full-screen push, so tapping it doesn't change which tab is
/// selected underneath, and returning from it lands back where you were.
class ResidentShellScreen extends StatefulWidget {
  const ResidentShellScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<ResidentShellScreen> createState() => _ResidentShellScreenState();
}

class _ResidentShellScreenState extends State<ResidentShellScreen> {
  int _tabIndex = 0;

  late final List<Widget> _tabs = [
    ResidentHomeScreen(user: widget.user),
    ReportFormScreen(user: widget.user),
    const ResourcesScreen(),
    ProfileScreen(user: widget.user),
  ];

  static const _navItems = [
    AppBottomNavItem(icon: Icons.home_outlined, label: 'Home'),
    AppBottomNavItem(icon: Icons.edit_outlined, label: 'Report'),
    AppBottomNavItem(icon: Icons.warning_amber_outlined, label: 'SOS', isDanger: true),
    AppBottomNavItem(icon: Icons.support_agent_outlined, label: 'Resources'),
    AppBottomNavItem(icon: Icons.person_outline, label: 'Profile'),
  ];

  // Nav bar has 5 items (SOS in the middle), but _tabs only has 4 bodies —
  // these convert between the two index spaces.
  int get _navBarIndex => _tabIndex < 2 ? _tabIndex : _tabIndex + 1;

  void _onNavTap(int navIndex) {
    if (navIndex == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SosScreen(user: widget.user)),
      );
      return;
    }
    final tabIndex = navIndex < 2 ? navIndex : navIndex - 1;
    setState(() => _tabIndex = tabIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: _tabs),
      bottomNavigationBar: AppBottomNav(
        items: _navItems,
        currentIndex: _navBarIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
