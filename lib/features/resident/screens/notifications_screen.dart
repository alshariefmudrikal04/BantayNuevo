import 'package:flutter/material.dart';
import '../../../models/notification_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/list_item_tile.dart';
import '../data/notification_repository.dart';
import 'report_detail_screen.dart';
import 'sos_screen.dart';
import '../../../models/user_model.dart';

class NotificationsScreen extends StatelessWidget {
  NotificationsScreen({super.key, required this.user});

  final UserModel user;
  final _notificationRepository = NotificationRepository();

  String _relativeTime(DateTime? date) {
    if (date == null) return 'just now';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${date.month}/${date.day}/${date.year}';
  }

  Future<void> _handleTap(BuildContext context, NotificationModel n) async {
    if (!n.read) {
      await _notificationRepository.markAsRead(n.id);
    }
    if (!context.mounted) return;
    if (n.relatedReportId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReportDetailScreen(reportId: n.relatedReportId!)),
      );
    } else if (n.relatedAlertId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SosScreen(user: user)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationRepository.streamForUser(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppCard(
                child: Text(
                  "No notifications yet. You'll see updates here once a tanod responds to a report or SOS.",
                  style: AppTypography.bodySoft(fontSize: 12),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Column(
                  children: [
                    for (int i = 0; i < notifications.length; i++)
                      ListItemTile(
                        title: notifications[i].message,
                        subtitle: _relativeTime(notifications[i].createdAt),
                        trailing: notifications[i].read
                            ? null
                            : Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.only(left: 4),
                                decoration: const BoxDecoration(color: AppColors.urgent, shape: BoxShape.circle),
                              ),
                        isLast: i == notifications.length - 1,
                        onTap: () => _handleTap(context, notifications[i]),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
