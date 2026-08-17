import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import 'resident_home_screen.dart';
import 'sos_screen.dart';
import 'profile/profile_screen.dart';

/// Wraps the resident's browsable sections in a persistent bottom nav —
/// just Home and Settings (Profile) as actual tab bodies. SOS is the 2nd
/// nav slot but is NOT a tab body — it's always a full-screen push, so
/// tapping it doesn't change which tab is selected underneath, and
/// returning from it lands back where you were.
///
/// Report and Resources are deliberately NOT separate tabs: Report already
/// has its own card on Home right next to "Share my location", and
/// Resources now lives inside Settings (see profile_screen.dart) instead
/// of taking up a whole nav slot for something opened rarely.
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
    ProfileScreen(user: widget.user),
  ];

  static const _navItems = [
    AppBottomNavItem(icon: Icons.home_outlined, label: 'Home'),
    AppBottomNavItem(icon: Icons.shield_outlined, label: 'SOS', isDanger: true, isRaised: true),
    AppBottomNavItem(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  // Nav bar has 3 items (SOS in the middle), but _tabs only has 2 bodies —
  // these convert between the two index spaces.
  int get _navBarIndex => _tabIndex == 0 ? 0 : 2;

  void _onNavTap(int navIndex) {
    if (navIndex == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SosScreen(user: widget.user, autoStart: true)),
      );
      return;
    }
    setState(() => _tabIndex = navIndex == 0 ? 0 : 1);
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
