import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

/// Root widget. As of Prompt 1, this now shows the real auth flow via
/// AuthGate (core/router/app_router.dart) instead of the Prompt 0 widget
/// showcase — role_select → login/register → role-based home.
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
