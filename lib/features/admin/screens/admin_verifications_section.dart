import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../models/user_model.dart';
import '../data/admin_repository.dart';
import 'admin_verification_detail_screen.dart';

/// Queue of residents whose self-registration (ID photo + face photo) is
/// waiting on a decision — see VerificationStatus on UserModel and
/// AdminRepository.streamPendingVerifications.
class AdminVerificationsSection extends StatelessWidget {
  const AdminVerificationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = AdminRepository();

    return StreamBuilder<List<UserModel>>(
      stream: repository.streamPendingVerifications(),
      builder: (context, snapshot) {
        final pending = snapshot.data ?? [];

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pending verifications', style: AppTypography.display(fontSize: 18)),
              const SizedBox(height: 4),
              Text(
                'New residents who signed up with an ID + face photo, waiting on review.',
                style: AppTypography.bodySoft(fontSize: 12),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: pending.isEmpty
                    ? Center(child: Text('Nothing pending right now.', style: AppTypography.bodySoft(fontSize: 12)))
                    : ListView(
                        children: [
                          for (final resident in pending)
                            InkWell(
                              borderRadius: BorderRadius.circular(11),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => AdminVerificationDetailScreen(resident: resident)),
                              ),
                              child: AppCard(
                                child: Row(
                                  children: [
                                    if (resident.facePhotoUrl != null)
                                      CircleAvatar(backgroundImage: NetworkImage(resident.facePhotoUrl!))
                                    else
                                      const CircleAvatar(child: Icon(Icons.person_outline)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(resident.name, style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600)),
                                          Text(
                                            resident.purok.isNotEmpty ? 'Purok ${resident.purok} · ${resident.email}' : resident.email,
                                            style: AppTypography.mono(fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, size: 18, color: AppColors.inkSoft),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
