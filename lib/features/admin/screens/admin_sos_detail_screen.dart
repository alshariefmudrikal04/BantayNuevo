import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/live_map.dart';
import '../../../models/sos_alert_model.dart';
import '../../../models/user_model.dart';
import '../data/admin_repository.dart';

/// Admin's view of a single SOS alert — read-only on the map side (an
/// admin isn't a responder walking toward the resident, so there's no
/// "my own live position" the way tanod_alert_detail_screen.dart has),
/// but can assign any tanod/police account or close the alert outright.
class AdminSosDetailScreen extends StatefulWidget {
  const AdminSosDetailScreen({super.key, required this.alertId});

  final String alertId;

  @override
  State<AdminSosDetailScreen> createState() => _AdminSosDetailScreenState();
}

class _AdminSosDetailScreenState extends State<AdminSosDetailScreen> {
  final _repository = AdminRepository();
  late final Stream<SosAlertModel> _alertStream = _repository.streamSosAlert(widget.alertId);

  final Map<String, Future<String?>> _nameFutures = {};
  Future<String?> _nameFor(String uid) => _nameFutures.putIfAbsent(uid, () => _repository.fetchUserName(uid));

  bool _busy = false;

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? AppColors.urgent : AppColors.navyDeep),
    );
  }

  Future<void> _assign(SosAlertModel alert) async {
    final result = await showDialog<UserModel>(
      context: context,
      builder: (_) => _ResponderPickerDialog(repository: _repository),
    );
    if (result == null) return;

    setState(() => _busy = true);
    try {
      await _repository.assignSosResponder(
        alertId: widget.alertId,
        residentId: alert.residentId,
        responderId: result.uid,
        responderName: result.name,
      );
    } catch (e) {
      _showSnack('Could not assign: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    setState(() => _busy = true);
    try {
      await _repository.closeSosAlert(widget.alertId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showSnack('Could not close: $e', isError: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('SOS alert')),
      body: StreamBuilder<SosAlertModel>(
        stream: _alertStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final alert = snapshot.data!;
          final canAssign = alert.status == SosStatus.active;
          final canClose = alert.status != SosStatus.closed;

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<String?>(
                  future: _nameFor(alert.residentId),
                  builder: (context, nameSnap) => Text('SOS from ${nameSnap.data ?? 'Resident'}', style: AppTypography.display(fontSize: 16)),
                ),
                const SizedBox(height: 4),
                Text('${alert.emergencyType.label} · ${alert.status.value}', style: AppTypography.mono(fontSize: 10.5, color: AppColors.urgent)),
                const SizedBox(height: 10),
                if (alert.responderName != null)
                  AppCard(child: Text('Responder: ${alert.responderName}', style: AppTypography.bodySoft(fontSize: 12)))
                else
                  AppCard(child: Text('No responder assigned yet.', style: AppTypography.bodySoft(fontSize: 12))),
                const SizedBox(height: 10),
                if (alert.lat != null && alert.lng != null)
                  Expanded(
                    child: LiveMap(
                      selfLat: alert.lat!,
                      selfLng: alert.lng!,
                      selfLabel: 'Resident',
                      otherLat: alert.responderLat,
                      otherLng: alert.responderLng,
                      otherLabel: alert.hasResponderLocation ? alert.responderName : null,
                    ),
                  )
                else
                  Expanded(child: Center(child: Text('No location on this alert.', style: AppTypography.bodySoft(fontSize: 12)))),
                const SizedBox(height: 12),
                if (canAssign)
                  AppButton(
                    label: _busy ? 'Assigning...' : 'Assign a tanod or police responder',
                    onPressed: _busy ? null : () => _assign(alert),
                  ),
                if (canClose) ...[
                  const SizedBox(height: 8),
                  AppButton(label: 'Close this alert', variant: AppButtonVariant.ghost, onPressed: _busy ? null : _close),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ResponderPickerDialog extends StatelessWidget {
  const _ResponderPickerDialog({required this.repository});

  final AdminRepository repository;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign a responder'),
      content: SizedBox(
        width: 360,
        height: 400,
        child: StreamBuilder<List<UserModel>>(
          stream: repository.streamAllUsers(),
          builder: (context, snapshot) {
            final responders = (snapshot.data ?? [])
                .where((u) => (u.role == UserRole.tanod || u.role == UserRole.police) && u.active)
                .toList();
            if (responders.isEmpty) {
              return const Center(child: Text('No active tanod or police accounts yet.'));
            }
            return ListView(
              children: [
                for (final responder in responders)
                  ListTile(
                    leading: CircleAvatar(child: Text(responder.name.isNotEmpty ? responder.name[0].toUpperCase() : '?')),
                    title: Text(responder.name),
                    subtitle: Text(responder.role.displayLabel),
                    onTap: () => Navigator.of(context).pop(responder),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
    );
  }
}
