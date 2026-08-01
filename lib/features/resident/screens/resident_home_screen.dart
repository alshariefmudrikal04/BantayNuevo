import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/report_model.dart';
import '../../../models/notification_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/list_item_tile.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/feature_stub_screen.dart';
import '../../../core/services/fcm_service.dart';
import 'report_form_screen.dart';
import 'sos_screen.dart';
import 'my_reports_screen.dart';
import 'report_detail_screen.dart';
import 'notifications_screen.dart';
import '../data/report_repository.dart';
import '../data/notification_repository.dart';
import '../../auth/data/auth_repository.dart';

class ResidentHomeScreen extends StatefulWidget {
  const ResidentHomeScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends State<ResidentHomeScreen> {
  final _reportRepository = ReportRepository();
  final _notificationRepository = NotificationRepository();
  final _authRepository = AuthRepository();

  @override
  void initState() {
    super.initState();
    // Registers this device's FCM token so onSosCreated/onReportCreated
    // (Prompt 4.5) can actually push to it — free on Spark, no Blaze needed.
    FcmService.registerToken(widget.user.uid);
  }

  AppStatus _toAppStatus(ReportStatus s) => switch (s) {
        ReportStatus.pending => AppStatus.pending,
        ReportStatus.inProgress => AppStatus.progress,
        ReportStatus.resolved => AppStatus.resolved,
      };

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
          StreamBuilder<List<NotificationModel>>(
            stream: _notificationRepository.streamForUser(user.uid),
            builder: (context, snapshot) {
              final unread = (snapshot.data ?? []).where((n) => !n.read).length;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none, size: 22),
                    tooltip: 'Notifications',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => NotificationsScreen(user: user)),
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: AppColors.urgent, shape: BoxShape.circle),
                      ),
                    ),
                ],
              );
            },
          ),
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
                      Text('${user.barangay} resident · Purok ${user.purok}', style: AppTypography.bodySoft(fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SectionTitle('Quick actions', topPadding: 4),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Open SOS',
                  variant: AppButtonVariant.filled,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SosScreen(user: user)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'File a report',
                  variant: AppButtonVariant.outline,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ReportFormScreen(user: user)),
                  ),
                ),
              ),
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionTitle('Recent activity', topPadding: 4),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MyReportsScreen(user: user)),
                ),
                child: const Text('See all'),
              ),
            ],
          ),
          StreamBuilder<List<ReportModel>>(
            stream: _reportRepository.streamRecentReports(user.uid, limit: 2),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final reports = snapshot.data ?? [];
              if (reports.isEmpty) {
                return AppCard(
                  child: Text(
                    'No reports yet. Filed reports will show up here.',
                    style: AppTypography.bodySoft(fontSize: 12),
                  ),
                );
              }
              return AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Column(
                  children: [
                    for (int i = 0; i < reports.length; i++)
                      ListItemTile(
                        title: reports[i].type,
                        subtitle: reports[i].id,
                        trailing: StatusBadge(status: _toAppStatus(reports[i].status)),
                        isLast: i == reports.length - 1,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ReportDetailScreen(reportId: reports[i].id)),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          const SectionTitle('Quick access'),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Hotlines',
                  variant: AppButtonVariant.ghost,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FeatureStubScreen(title: 'Resources')),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Evidence vault',
                  variant: AppButtonVariant.ghost,
                  // Vault is per-report, so route through My Reports to pick
                  // which case's evidence to view rather than guessing one.
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => MyReportsScreen(user: user)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
