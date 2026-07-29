import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Circular SOS panic button — radial red gradient with a soft halo ring,
/// per AGENTS.md §4 shape spec (150px diameter, 8px halo).
class PanicButton extends StatelessWidget {
  const PanicButton({super.key, required this.onPressed, this.busy = false});

  final VoidCallback? onPressed;
  final bool busy;

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
                        Text('PANIC', style: AppTypography.display(fontSize: 20, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text('HOLD TO SEND', style: AppTypography.mono(fontSize: 9, color: Colors.white.withOpacity(0.9))),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
