import 'package:flutter/material.dart';
import '../theme/lux_theme.dart';

/// Full-width primary CTA — black fill, matching the weight/shape language
/// of resident_home_screen.dart's _SosBanner and _ServiceRow (solid fill,
/// rounded corners, InkWell ripple). Deliberately black rather than
/// LuxColors.red: lux_theme.dart reserves red specifically for SOS/urgent
/// moments ("used deliberately sparingly ... so it keeps its urgency
/// instead of becoming wallpaper") — a login/register submit button isn't
/// one of those, so it stays black like every other primary action in the
/// app.
class LuxButton extends StatelessWidget {
  const LuxButton({super.key, required this.label, required this.onTap, this.loading = false});

  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: LuxColors.black,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(label, style: LuxType.heading(fontSize: 14, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}
