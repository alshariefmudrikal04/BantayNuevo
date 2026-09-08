import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/sos_alert_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../data/police_repository.dart';
import 'police_alert_detail_screen.dart';

/// Every SOS alert currently assigned to this police officer — mirrors
/// TanodSosScreen's layout, minus the "self-accept + alarm sound on new
/// alert" logic, since police alerts always arrive already-assigned
/// (there's nothing to accept, and no open pool to alarm about).
class PoliceAlertsScreen extends StatefulWidget {
  const PoliceAlertsScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<PoliceAlertsScreen> createState() => _PoliceAlertsScreenState();
}

class _PoliceAlertsScreenState extends State<PoliceAlertsScreen> {
  final _repository = PoliceRepository();
  late final Stream<List<SosAlertModel>> _alertsStream = _repository.streamMyAlerts(widget.user.uid);

  final Map<String, Future<String?>> _nameFutures = {};
  Future<String?> _residentNameFuture(String residentId) {
    return _nameFutures.putIfAbsent(residentId, () => _repository.fetchUserName(residentId));
  }

  String _relativeTime(DateTime? date) {
    if (date == null) return 'just now';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours} hr ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Assigned SOS alerts')),
      body: StreamBuilder<List<SosAlertModel>>(
        stream: _alertsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final alerts = snapshot.data ?? [];
          if (alerts.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppCard(
                child: Text(
                  'No SOS alerts assigned to you yet. A barangay admin assigns these from the dashboard.',
                  style: AppTypography.bodySoft(fontSize: 12),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              for (final alert in alerts)
                InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PoliceAlertDetailScreen(alertId: alert.id, user: widget.user)),
                  ),
                  child: AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: alert.status == SosStatus.closed ? AppColors.tealLight : AppColors.urgentLight,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: alert.status == SosStatus.closed ? AppColors.teal : AppColors.urgent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FutureBuilder<String?>(
                                future: _residentNameFuture(alert.residentId),
                                builder: (context, nameSnap) => Text(
                                  nameSnap.data ?? 'Resident',
                                  style: AppTypography.body(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                '${alert.emergencyType.label} · ${alert.status.value} · ${_relativeTime(alert.createdAt)}',
                                style: AppTypography.mono(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 18, color: AppColors.inkSoft),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
