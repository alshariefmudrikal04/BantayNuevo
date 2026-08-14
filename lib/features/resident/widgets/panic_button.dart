import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Circular SOS button — radial red gradient with a soft halo ring, per
/// AGENTS.md §4 shape spec (150px diameter, 8px halo). Reused in two
/// places with different meanings, distinguished by label/icon:
///   - sos_screen.dart: PANIC / HOLD TO SEND — tapping this directly
///     triggers _trigger(), sends the real alert immediately.
///   - resident_home_screen.dart: SOS / TAP TO SEND — tapping this just
///     navigates into SosScreen, it does NOT send anything itself. A big
///     always-visible red circle on the home screen that fires instantly
///     on any accidental tap would be a real false-alarm risk, so Home's
///     version is an entry point, not a trigger.
class PanicButton extends StatelessWidget {
  const PanicButton({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.label = 'PANIC',
    this.sublabel = 'HOLD TO SEND',
    this.icon,
  });

  final VoidCallback? onPressed;
  final bool busy;
  final String label;
  final String sublabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.panicButtonDiameter,
      height: AppSpacing.panicButtonDiameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.urgentLight,
            spreadRadius: AppSpacing.panicButtonHaloWidth,
          ),
        ],
      ),
      child: Material(
        shape: const CircleBorder(),
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? null : onPressed,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.4),
                colors: [Color(0xFFE05B44), AppColors.urgent],
                stops: [0.0, 0.7],
              ),
            ),
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 26),
                          const SizedBox(height: 4),
                        ],
                        Text(label, style: AppTypography.display(fontSize: 20, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(sublabel, style: AppTypography.mono(fontSize: 9, color: Colors.white.withOpacity(0.9))),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
