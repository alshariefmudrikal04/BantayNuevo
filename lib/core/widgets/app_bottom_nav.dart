import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppBottomNavItem {
  const AppBottomNavItem({required this.icon, required this.label, this.isDanger = false, this.isRaised = false});

  final IconData icon;
  final String label;
  final bool isDanger;

  /// Renders this item as a larger circular badge, vertically centered in
  /// the bar rather than matching the other items' icon-over-label layout.
  /// Still fully contained within the bar's own height — no Positioned/
  /// Stack overlap into the screen content above it.
  final bool isRaised;
}

/// Persistent bottom tab bar. Resident nav is 3 items — Home, SOS
/// (isRaised + isDanger, larger red circle), Settings — see
/// resident_shell_screen.dart. Report and Resources were removed from here:
/// Report already has a card on Home next to Share my location, and
/// Resources now lives inside Settings instead of its own tab.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.items, required this.currentIndex, required this.onTap});

  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        // No fixed height on the outer Container — that was the actual
        // overflow bug. A hard-coded height (72/56) doesn't know how much
        // bottom system inset SafeArea needs to reserve on a given device
        // (gesture nav vs. 3-button nav vs. none), so on devices with a
        // larger inset, the content had less room than it needed and
        // overflowed by however many pixels were missing. Letting the
        // Container size itself to its child (content height + SafeArea's
        // own inset) fixes this on every device, not just the one being
        // tested on.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: items[i].isRaised ? _raisedItem(i) : _standardItem(i),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _raisedItem(int i) {
    return InkWell(
      onTap: () => onTap(i),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            // Bigger and easier to hit than the old 46px — this is the
            // primary emergency action, it should be the easiest tap
            // target on the whole bar.
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: items[i].isDanger ? AppColors.urgent : AppColors.navy,
              boxShadow: [
                BoxShadow(
                  color: (items[i].isDanger ? AppColors.urgent : AppColors.navy).withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(items[i].icon, size: 28, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            items[i].label,
            style: AppTypography.body(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: items[i].isDanger ? AppColors.urgent : AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _standardItem(int i) {
    final selected = currentIndex == i;
    return InkWell(
      onTap: () => onTap(i),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: selected ? AppColors.navy : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(items[i].icon, size: 20, color: selected ? AppColors.navy : AppColors.inkSoft),
            const SizedBox(height: 2),
            Text(
              items[i].label,
              style: AppTypography.body(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: selected ? AppColors.navy : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
