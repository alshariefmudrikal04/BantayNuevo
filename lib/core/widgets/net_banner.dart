import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Online/offline indicator banner, shown on the SOS screen (Prompt 4).
/// Online: Tanod/police get an in-app push, emergency contacts get an SMS.
/// Offline: the app sends SMS directly from the resident's own SIM, since
/// Firestore is unreachable — see AGENTS.md §5 (sos_alerts.deliveryMethod).
class NetBanner extends StatelessWidget {
  const NetBanner({super.key, required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.teal : AppColors.amber;
    final bg = isOnline ? AppColors.tealLight : AppColors.amberLight;
    final label = isOnline
        ? 'Online — Tanod/police notified in-app, contacts get SMS'
        : 'Offline — sending SMS directly from your phone';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: bg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.mono(fontSize: 10, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
