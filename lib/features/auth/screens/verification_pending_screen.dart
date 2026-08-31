import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../models/user_model.dart';

/// Shown instead of the real resident app while VerificationStatus is
/// `pending` or `rejected` — see AuthGate (core/router/app_router.dart).
/// A rejected resident CAN still see why (rejectionReason) and can log
/// back in later to check status, but nothing further happens client-side
/// on rejection — re-submitting a corrected ID/face means registering
/// again with a different email, since there's no "resubmit" flow yet.
class VerificationPendingScreen extends StatelessWidget {
  const VerificationPendingScreen({super.key, required this.user, required this.onLogout});

  final UserModel user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final rejected = user.verificationStatus == VerificationStatus.rejected;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    rejected ? Icons.error_outline : Icons.hourglass_top_rounded,
                    size: 56,
                    color: rejected ? AppColors.urgent : AppColors.amber,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    rejected ? 'Verification not approved' : 'Verification pending',
                    style: AppTypography.display(fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rejected
                        ? "A barangay admin reviewed your ID and photo but couldn't verify your account."
                        : "Thanks for signing up, ${user.name.split(' ').first}. A barangay admin still needs to review your ID and photo before you can use the app.",
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySoft(fontSize: 13),
                  ),
                  if (rejected && user.rejectionReason != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.urgentLight, borderRadius: BorderRadius.circular(10)),
                      child: Text(user.rejectionReason!, style: AppTypography.body(fontSize: 12.5)),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    "You'll also get an email at ${user.email} once a decision is made.",
                    textAlign: TextAlign.center,
                    style: AppTypography.mono(fontSize: 10.5, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 24),
                  AppButton(label: 'Log out', variant: AppButtonVariant.ghost, onPressed: onLogout),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
