import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

/// Root widget. AuthGate handles the real auth flow (role_select →
/// login/register → role-based home). No app-wide lock here on purpose —
/// SOS has to be reachable instantly in an emergency, so PIN/biometric
/// protection is scoped narrowly to Reports & Evidence instead. See
/// core/widgets/sensitive_content_gate.dart, applied directly on
/// my_reports_screen.dart, report_detail_screen.dart, and
/// evidence_vault_screen.dart.
class BantayNuevoApp extends StatelessWidget {
  const BantayNuevoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bantay Nuevo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
