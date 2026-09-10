import 'package:flutter/material.dart';
import '../../../models/notification_model.dart';
import '../../../core/theme/lux_theme.dart';
import '../data/notification_repository.dart';
import 'report_detail_screen.dart';
import 'sos_screen.dart';
import '../../../models/user_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notificationRepository = NotificationRepository();
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
        MaterialPageRoute(builder: (_) => ReportDetailScreen(reportId: n.relatedReportId!)),
      );
    } else if (n.relatedAlertId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SosScreen(user: widget.user)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxColors.bg,
      appBar: AppBar(
        backgroundColor: LuxColors.bg,
        elevation: 0,
        title: Text('NOTIFICATIONS', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.ink)),
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
                child: Text(
                  "No notifications yet. You'll see updates here once a tanod responds to a report or SOS.",
                  style: LuxType.body(fontSize: 12, color: LuxColors.inkSoft),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (int i = 0; i < notifications.length; i++)
                      InkWell(
                        onTap: () => _handleTap(context, notifications[i]),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: i == notifications.length - 1
                              ? null
                              : const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.divider))),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(notifications[i].message, style: LuxType.body(fontSize: 12.5)),
                                    const SizedBox(height: 3),
                                    Text(
                                      _relativeTime(notifications[i].createdAt),
                                      style: LuxType.eyebrow(fontSize: 9, color: LuxColors.inkSoft, letterSpacing: 0.3),
                                    ),
                                  ],
                                ),
                              ),
                              if (!notifications[i].read)
                                Container(
                                  width: 7,
                                  height: 7,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: const BoxDecoration(color: LuxColors.red, shape: BoxShape.circle),
                                ),
                            ],
                          ),
                        ),
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
