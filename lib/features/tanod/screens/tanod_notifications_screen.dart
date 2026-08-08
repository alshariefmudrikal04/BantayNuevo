import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/notification_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/list_item_tile.dart';
import '../../resident/data/notification_repository.dart';
import 'tanod_report_review_screen.dart';
import 'tanod_alert_detail_screen.dart';

/// Same pattern as the resident's notifications_screen.dart +
/// NotificationRepository — that repository already streams by
/// recipientId, which works for a tanod uid just as well as a resident
/// uid (AGENTS.md §5's notifications schema isn't role-specific).
class TanodNotificationsScreen extends StatefulWidget {
  const TanodNotificationsScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<TanodNotificationsScreen> createState() => _TanodNotificationsScreenState();
}

class _TanodNotificationsScreenState extends State<TanodNotificationsScreen> {
  final _notificationRepository = NotificationRepository();

  // Cached once here, not recreated in build() — the earlier "don't
  // recreate the stream every rebuild" bugfix (AGENTS.md §8) applies to
  // this screen too.
  late final Stream<List<NotificationModel>> _notificationsStream =
      _notificationRepository.streamForUser(widget.user.uid);

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
        MaterialPageRoute(
          builder: (_) => TanodReportReviewScreen(reportId: n.relatedReportId!, user: widget.user),
        ),
      );
    } else if (n.relatedAlertId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TanodAlertDetailScreen(alertId: n.relatedAlertId!, user: widget.user),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationsStream,
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
                  "No notifications yet. You'll see updates here when a resident files a report or sends an SOS.",
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
