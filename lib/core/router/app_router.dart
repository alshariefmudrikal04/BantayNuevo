import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/screens/role_select_screen.dart';
import '../widgets/coming_soon_screen.dart';

/// Root auth/role gate. Listens to AuthRepository.authStateChanges and shows:
/// - RoleSelectScreen when signed out
/// - the correct role's home screen when signed in
///
/// This is the single place that decides "which screen is home" per role —
/// when Prompt 2 builds the real resident_home_screen.dart, only the
/// `resident` branch below needs to change, nothing else in the auth flow.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepository = AuthRepository();

    return StreamBuilder<UserModel?>(
      stream: authRepository.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;
        if (user == null) {
          return const RoleSelectScreen();
        }

        return switch (user.role) {
          // TODO(Prompt 2): replace with the real ResidentHomeScreen once built.
          UserRole.resident => ComingSoonScreen(
              roleLabel: 'Resident',
              onLogout: authRepository.logout,
            ),
          // TODO(Prompt 9+): replace with the real TanodDashboardScreen once
          // its UI reference is provided.
          UserRole.tanod => ComingSoonScreen(
              roleLabel: 'Tanod',
              onLogout: authRepository.logout,
            ),
          // TODO(Prompt 9+): replace with the real PoliceDashboardScreen.
          UserRole.police => ComingSoonScreen(
              roleLabel: 'Police',
              onLogout: authRepository.logout,
            ),
        };
      },
    );
  }
}
