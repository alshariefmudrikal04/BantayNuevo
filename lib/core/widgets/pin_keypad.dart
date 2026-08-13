import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Shared 0–9 + backspace keypad — used by set_pin_screen.dart (creating a
/// PIN) and pin_lock_screen.dart (entering one to unlock), so the two flows
/// look and feel identical.
class PinKeypad extends StatelessWidget {
  const PinKeypad({super.key, required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final key in row)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: key.isEmpty
                          ? null
                          : Material(
                              color: AppColors.panel,
                              shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => key == '⌫' ? onBackspace() : onDigit(key),
                                child: Center(
                                  child: key == '⌫'
                                      ? const Icon(Icons.backspace_outlined, size: 18, color: AppColors.inkSoft)
                                      : Text(key, style: AppTypography.display(fontSize: 20)),
                                ),
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
