import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Generic placeholder for feature screens that haven't been built yet
/// (report form → Prompt 3, SOS → Prompt 4, evidence vault → Prompt 5,
/// resources → Prompt 8). Pushed via normal Navigator.push, so the built-in
/// back button just works — unlike ComingSoonScreen, which is used only for
/// the top-level role dashboards under AuthGate.
class FeatureStubScreen extends StatelessWidget {
  const FeatureStubScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text('$title — coming soon', style: AppTypography.mono(fontSize: 12)),
      ),
    );
  }
}
