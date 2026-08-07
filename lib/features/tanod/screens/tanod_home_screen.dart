import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/sos_alert_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../data/tanod_sos_repository.dart';
import '../../auth/data/auth_repository.dart';
import 'tanod_sos_screen.dart';

/// Temporary Tanod landing screen — SOS response only, built as the first
/// slice of Prompt 9. The full dashboard (report review, report status
/// updates, etc.) replaces this once its UI reference is provided.
class TanodHomeScreen extends StatefulWidget {
  const TanodHomeScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<TanodHomeScreen> createState() => _TanodHomeScreenState();
}

class _TanodHomeScreenState extends State<TanodHomeScreen> {
  final _repository = TanodSosRepository();
  final _authRepository = AuthRepository();
  late final Stream<List<SosAlertModel>> _alertsStream = _repository.streamOpenAlerts();

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text('Bantay Nuevo'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Log out',
            onPressed: _authRepository.logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.tealLight,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: AppTypography.display(fontSize: 15, color: AppColors.teal),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hi, ${user.name}', style: AppTypography.display(fontSize: 16)),
                      Text('Tanod · ${user.barangay}', style: AppTypography.bodySoft(fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          StreamBuilder<List<SosAlertModel>>(
            stream: _alertsStream,
            builder: (context, snapshot) {
              final alerts = snapshot.data ?? [];
              final activeCount = alerts.where((a) => a.status == SosStatus.active).length;
              final respondingCount = alerts.where((a) => a.status == SosStatus.responded).length;

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TanodSosScreen(user: user)),
                ),
                child: AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: activeCount > 0 ? AppColors.urgentLight : AppColors.tealLight,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: activeCount > 0 ? AppColors.urgent : AppColors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SOS alerts', style: AppTypography.display(fontSize: 14)),
                            Text(
                              activeCount > 0
                                  ? '$activeCount waiting · $respondingCount being responded to'
                                  : respondingCount > 0
                                      ? '$respondingCount being responded to'
                                      : 'No active alerts right now',
                              style: AppTypography.bodySoft(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.inkSoft),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),
          AppCard(
            child: Text(
              'This is a temporary Tanod screen — SOS response only, so you can test the live-tracking flow. '
              'The full dashboard (incident report review, status updates, etc.) comes later in Prompt 9.',
              style: AppTypography.bodySoft(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}