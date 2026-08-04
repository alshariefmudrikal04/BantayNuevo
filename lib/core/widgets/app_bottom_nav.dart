import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppBottomNavItem {
  const AppBottomNavItem({required this.icon, required this.label, this.isDanger = false});

  final IconData icon;
  final String label;
  final bool isDanger;
}

/// Persistent bottom tab bar, matching the reference UI's original 5-tab
/// design (Home / Report / SOS / Resources / Profile). SOS is visually
/// distinct (red) since it's always a full-screen push, not a tab body —
/// see resident_shell_screen.dart for how selection is handled around it.
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
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: currentIndex == i
                              ? (items[i].isDanger ? AppColors.urgent : AppColors.navy)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          items[i].icon,
                          size: 20,
                          color: currentIndex == i
                              ? (items[i].isDanger ? AppColors.urgent : AppColors.navy)
                              : (items[i].isDanger ? AppColors.urgent.withOpacity(0.65) : AppColors.inkSoft),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].label,
                          style: AppTypography.body(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: currentIndex == i
                                ? (items[i].isDanger ? AppColors.urgent : AppColors.navy)
                                : AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
