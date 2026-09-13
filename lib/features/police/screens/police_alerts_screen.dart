import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/sos_alert_model.dart';
import '../../../core/theme/lux_theme.dart';
import '../data/police_repository.dart';
import 'police_alert_detail_screen.dart';

/// Every SOS alert currently assigned to this police officer. Reskinned
/// to match the resident side's look.
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
      backgroundColor: LuxColors.bg,
      appBar: AppBar(
        backgroundColor: LuxColors.bg,
        elevation: 0,
        title: Text('ASSIGNED SOS ALERTS', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.ink)),
      ),
      body: StreamBuilder<List<SosAlertModel>>(
        stream: _alertsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final alerts = snapshot.data ?? [];
          if (alerts.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
                child: Text(
                  'No SOS alerts assigned to you yet. A barangay admin assigns these from the dashboard.',
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
                    for (int i = 0; i < alerts.length; i++)
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => PoliceAlertDetailScreen(alertId: alerts[i].id, user: widget.user)),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: i == alerts.length - 1
                              ? null
                              : const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.divider))),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: alerts[i].status == SosStatus.closed ? LuxColors.surfaceMuted : LuxColors.red,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                  color: alerts[i].status == SosStatus.closed ? LuxColors.inkSoft : Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FutureBuilder<String?>(
                                      future: _residentNameFuture(alerts[i].residentId),
                                      builder: (context, nameSnap) => Text(nameSnap.data ?? 'Resident', style: LuxType.heading(fontSize: 13.5)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${alerts[i].emergencyType.label} · ${alerts[i].status.value} · ${_relativeTime(alerts[i].createdAt)}',
                                      style: LuxType.eyebrow(fontSize: 9, color: LuxColors.inkSoft, letterSpacing: 0.2),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, size: 18, color: LuxColors.inkSoft),
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
