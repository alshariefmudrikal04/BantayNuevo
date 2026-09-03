import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/verification_pending_screen.dart';
import '../../features/resident/screens/resident_shell_screen.dart';
import '../../features/tanod/screens/tanod_home_screen.dart';
import '../../features/admin/screens/admin_home_screen.dart';
import '../widgets/coming_soon_screen.dart';

/// Root auth/role gate. Listens to AuthRepository.authStateChanges and shows:
/// - LoginScreen when signed out — a single form, no role picker; whoever
///   signs in gets routed by the switch below based on their account's
///   actual role in Firestore, not a role they picked beforehand.
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
          return const LoginScreen();
        }

        return switch (user.role) {
          // A resident whose ID + face photos haven't been approved by an
          // admin yet (or were rejected) never reaches the real resident
          // app — see VerificationStatus on UserModel and the admin-side
          // Verifications queue (AdminVerificationsSection).
          UserRole.resident when user.verificationStatus != VerificationStatus.approved =>
            VerificationPendingScreen(user: user, onLogout: authRepository.logout),
          UserRole.resident => ResidentShellScreen(user: user),
          // TODO(Prompt 9+): replace with the full TanodDashboardScreen
          // (report review, etc.) once its UI reference is provided —
          // for now this is SOS response only.
          UserRole.tanod => TanodHomeScreen(user: user),
          // TODO(Prompt 9+): replace with the real PoliceDashboardScreen.
          UserRole.police => ComingSoonScreen(
              roleLabel: 'Police',
              onLogout: authRepository.logout,
            ),
          // Prompt 14 — Barangay Admin PC/web dashboard.
          UserRole.admin => AdminHomeScreen(user: user),
        };
      },
    );
  }
}
