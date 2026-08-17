import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Temporary placeholder shown by the router for roles whose real home
/// screen hasn't been built yet. Tanod and Police use this until their
/// prompts run; Resident uses this only until Prompt 2 replaces it in
/// app_router.dart with the real resident_home_screen.dart.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.roleLabel, required this.onLogout});

  final String roleLabel;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg, 
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$roleLabel dashboard', style: AppTypography.display(fontSize: 20)),
              const SizedBox(height: 6),
              Text('— coming soon', style: AppTypography.mono(fontSize: 12)),
              const SizedBox(height: 20),
              TextButton(onPressed: onLogout, child: const Text('Log out')),
            ],
          ),
        ),
      ),
    );
  }
}
