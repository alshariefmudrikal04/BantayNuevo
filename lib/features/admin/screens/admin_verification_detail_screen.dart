import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/photo_viewer_screen.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/user_model.dart';
import '../data/admin_repository.dart';

/// Side-by-side ID photo + face photo review for one pending resident,
/// with Approve / Reject(+ reason). Both decisions email the resident
/// (see AdminRepository._sendVerificationEmail) and pop back to the queue.
///
/// Previously this was almost entirely two full-width square photos with
/// a single line of text above them — plenty of pixels spent on images an
/// admin mostly glances at once, and almost none on the actual identity
/// details (purok, barangay, when they applied) that matter for the
/// decision. Photos are now fixed-height thumbnails with a "tap to
/// enlarge" affordance (full detail is one tap away in the shared
/// PhotoViewerScreen, so nothing is lost), and that freed-up space goes
/// to a proper identity card above them.
class AdminVerificationDetailScreen extends StatefulWidget {
  const AdminVerificationDetailScreen({super.key, required this.resident});

  final UserModel resident;

  @override
  State<AdminVerificationDetailScreen> createState() => _AdminVerificationDetailScreenState();
}

class _AdminVerificationDetailScreenState extends State<AdminVerificationDetailScreen> {
  final _repository = AdminRepository();
  bool _busy = false;

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? AppColors.urgent : AppColors.navyDeep),
    );
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      final result = await _repository.approveVerification(widget.resident);
      if (!mounted) return;
      if (!result.allSent) {
        await _warnNotificationFailed(result);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showSnack('Could not approve: $e', isError: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _RejectReasonDialog());
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _busy = true);
    try {
      final result = await _repository.rejectVerification(widget.resident, reason.trim());
      if (!mounted) return;
      if (!result.allSent) {
        await _warnNotificationFailed(result);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showSnack('Could not reject: $e', isError: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Shown before popping back to the queue whenever the email or SMS
  /// notification didn't actually go out. Deliberately a blocking dialog
  /// rather than a SnackBar: a SnackBar fired right before Navigator.pop()
  /// is easy to miss entirely, and this is the one moment the admin can
  /// still act on it (calling the resident directly) before the queue
  /// entry disappears.
  Future<void> _warnNotificationFailed(VerificationNotificationResult result) {
    final missing = [
      if (!result.emailSent) 'email',
      if (!result.smsSent) 'text message',
    ].join(' and ');
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Decision saved'),
        content: Text(
          'The $missing to ${widget.resident.name} could not be sent. The decision itself was saved — '
          'consider letting them know directly (call, or in person) so they\'re not left waiting.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  void _openPhoto(String label, String? url) {
    if (url == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PhotoViewerScreen(title: label, url: url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resident;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(r.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // --- Identity card: everything an admin needs to check a name
          // against an ID, at a glance, before ever looking at a photo. ---
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r.name, style: AppTypography.display(fontSize: 17)),
                    ),
                    StatusBadge(status: _toAppStatus(r.verificationStatus)),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(icon: Icons.mail_outline, label: 'Email', value: r.email),
                _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: r.phone.isNotEmpty ? r.phone : 'Not provided'),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Address',
                  value: r.purok.isNotEmpty ? 'Purok ${r.purok}, ${r.barangay}' : r.barangay,
                ),
                _InfoRow(icon: Icons.event_outlined, label: 'Applied', value: _formatDate(r.createdAt), isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text('IDENTITY PHOTOS', style: AppTypography.mono(fontSize: 10.5, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PhotoThumb(
                  label: 'Valid ID',
                  url: r.idPhotoUrl,
                  onTap: () => _openPhoto('Valid ID', r.idPhotoUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PhotoThumb(
                  label: 'Face photo',
                  url: r.facePhotoUrl,
                  onTap: () => _openPhoto('Face photo', r.facePhotoUrl),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: AppColors.inkSoft),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tap a photo to enlarge. Check the face matches across both, and the name on the ID matches above.',
                  style: AppTypography.bodySoft(fontSize: 11.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AppButton(label: _busy ? 'Working...' : 'Approve', onPressed: _busy ? null : _approve),
          const SizedBox(height: 8),
          AppButton(label: 'Reject', variant: AppButtonVariant.ghost, onPressed: _busy ? null : _reject),
        ],
      ),
    );
  }

  static AppStatus _toAppStatus(VerificationStatus status) => switch (status) {
        VerificationStatus.pending => AppStatus.pending,
        VerificationStatus.approved => AppStatus.resolved,
        VerificationStatus.rejected => AppStatus.rejected,
      };

  static String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.isLast = false});

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.inkSoft),
          const SizedBox(width: 10),
          SizedBox(
            width: 62,
            child: Text(label, style: AppTypography.mono(fontSize: 10.5)),
          ),
          Expanded(child: Text(value, style: AppTypography.body(fontSize: 13))),
        ],
      ),
    );
  }
}

/// A moderate, fixed-height thumbnail rather than a full-width square —
/// enough to sanity-check at a glance without the photo dominating the
/// screen over the identity details above it. Tapping opens the full
/// photo full-screen with pinch/zoom via the shared PhotoViewerScreen.
class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.label, required this.url, required this.onTap});

  final String label;
  final String? url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTypography.mono(fontSize: 10, letterSpacing: 0.4)),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: url != null ? onTap : null,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: url != null
                      ? Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _MissingPhoto())
                      : const _MissingPhoto(),
                ),
              ),
              if (url != null)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.zoom_in, size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MissingPhoto extends StatelessWidget {
  const _MissingPhoto();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.panel,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, color: AppColors.inkSoft),
    );
  }
}

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog();

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reason for rejecting'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'e.g. ID photo is blurry, name doesn\'t match'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: const Text('Reject')),
      ],
    );
  }
}
