import 'package:flutter/material.dart';
import '../../../core/theme/lux_theme.dart';
import '../../../core/theme/app_spacing.dart';

/// Circular SOS button — solid red fill, bold white label, per the new
/// "luxury minimal" reference (dribbble.com/shots/27499918): a plain flat
/// circle reads more confident/urgent than the old soft radial-gradient +
/// halo look. Reused in two places with different meanings, distinguished
/// by label/icon:
///   - sos_screen.dart: SOS / TAP FOR EMERGENCY — tapping this directly
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
    this.label = 'SOS',
    this.sublabel = 'TAP FOR EMERGENCY',
    this.icon,
  });

  final VoidCallback? onPressed;
  final bool busy;
  final String label;
  final String sublabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const CircleBorder(),
      color: LuxColors.red,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : onPressed,
        child: SizedBox(
          width: AppSpacing.panicButtonDiameter,
          height: AppSpacing.panicButtonDiameter,
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
                        const SizedBox(height: 6),
                      ],
                      Text(label, style: LuxType.hero(fontSize: 26, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                        sublabel,
                        textAlign: TextAlign.center,
                        style: LuxType.eyebrow(fontSize: 9, color: Colors.white.withOpacity(0.9), letterSpacing: 0.8),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
