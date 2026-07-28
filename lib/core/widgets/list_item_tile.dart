import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Bottom-bordered row used throughout — report lists, profile menu items,
/// notifications, contacts. Matches the reference UI's .list-item pattern.
class ListItemTile extends StatelessWidget {
  const ListItemTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.isLast = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
                  Text(title, style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w500)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: AppTypography.mono(fontSize: 10.5)),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (showChevron) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.inkSoft),
            ],
          ],
        ),
      ),
    );
  }
}
