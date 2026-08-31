import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../models/user_model.dart';
import '../data/admin_repository.dart';

/// Side-by-side ID photo + face photo review for one pending resident,
/// with Approve / Reject(+ reason). Both decisions email the resident
/// (see AdminRepository._sendVerificationEmail) and pop back to the queue.
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
      await _repository.approveVerification(widget.resident);
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
      await _repository.rejectVerification(widget.resident, reason.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showSnack('Could not reject: $e', isError: true);
      if (mounted) setState(() => _busy = false);
    }
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
          Text('${r.email} · ${r.phone}', style: AppTypography.bodySoft(fontSize: 12)),
          Text(r.purok.isNotEmpty ? 'Purok ${r.purok}' : '', style: AppTypography.mono(fontSize: 10.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _PhotoBlock(label: 'Valid ID', url: r.idPhotoUrl)),
              const SizedBox(width: 12),
              Expanded(child: _PhotoBlock(label: 'Face photo', url: r.facePhotoUrl)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Compare the face in both photos, and check the name on the ID matches what was entered above.',
            style: AppTypography.bodySoft(fontSize: 11.5),
          ),
          const SizedBox(height: 24),
          AppButton(label: _busy ? 'Working...' : 'Approve', onPressed: _busy ? null : _approve),
          const SizedBox(height: 8),
          AppButton(label: 'Reject', variant: AppButtonVariant.ghost, onPressed: _busy ? null : _reject),
        ],
      ),
    );
  }
}

class _PhotoBlock extends StatelessWidget {
  const _PhotoBlock({required this.label, required this.url});

  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTypography.mono(fontSize: 10, letterSpacing: 0.4)),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: url != null
                ? Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _MissingPhoto())
                : const _MissingPhoto(),
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
