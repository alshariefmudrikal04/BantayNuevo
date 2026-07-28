import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Label + description + switch row, used on the Security and Profile
/// preference screens (PIN, biometric, push notifications, etc.).
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    this.isLast = false,
  });

  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.body(fontSize: 12.5, fontWeight: FontWeight.w500)),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(description!, style: AppTypography.mono(fontSize: 10.5)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.panel,
            activeTrackColor: AppColors.teal,
            inactiveTrackColor: AppColors.line,
          ),
        ],
      ),
    );
  }
}
