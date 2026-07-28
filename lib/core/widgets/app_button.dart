import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant { filled, outline, ghost }

/// Shared button component — three variants matching the reference UI's
/// .btn-navy / .btn-outline / .btn-ghost classes. Every screen should use
/// this instead of hand-rolling one-off buttons (AGENTS.md §4/§8).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.fullWidth = true,
    this.leadingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool fullWidth;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: 16),
          const SizedBox(width: 6),
        ],
        Text(label),
      ],
    );

    final Widget button = switch (variant) {
      AppButtonVariant.filled => ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const RoundedRectangleBorder(borderRadius: AppSpacing.buttonRadius),
            padding: const EdgeInsets.symmetric(vertical: 12),
            textStyle: AppTypography.body(fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
          child: child,
        ),
      AppButtonVariant.outline => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.navy,
            side: const BorderSide(color: AppColors.navy),
            shape: const RoundedRectangleBorder(borderRadius: AppSpacing.buttonRadius),
            padding: const EdgeInsets.symmetric(vertical: 12),
            textStyle: AppTypography.body(fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
          child: child,
        ),
      AppButtonVariant.ghost => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.bg,
            foregroundColor: AppColors.inkSoft,
            side: const BorderSide(color: AppColors.line),
            shape: const RoundedRectangleBorder(borderRadius: AppSpacing.buttonRadius),
            padding: const EdgeInsets.symmetric(vertical: 12),
            textStyle: AppTypography.body(fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
          child: child,
        ),
    };

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
