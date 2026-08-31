import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../models/sos_alert_model.dart';
import '../data/admin_repository.dart';

/// Org-wide Alarm Sounds control — the single admin-owned source of truth
/// for what plays on every tanod's phone per emergency type (see
/// core/services/alarm_sound_service.dart). This replaced an earlier
/// per-tanod local picker; the admin's choice here is what everyone hears.
class AdminAlarmSoundsSection extends StatefulWidget {
  const AdminAlarmSoundsSection({super.key});

  @override
  State<AdminAlarmSoundsSection> createState() => _AdminAlarmSoundsSectionState();
}

class _AdminAlarmSoundsSectionState extends State<AdminAlarmSoundsSection> {
  final _repository = AdminRepository();
  final _previewPlayer = AudioPlayer();
  EmergencyType? _busyType;

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _pick(EmergencyType type) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio, withData: false);
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() => _busyType = type);
    try {
      await _repository.uploadAlarmSound(type.value, File(path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyType = null);
    }
  }

  Future<void> _reset(EmergencyType type) async {
    setState(() => _busyType = type);
    try {
      await _repository.resetAlarmSoundToDefault(type.value);
    } finally {
      if (mounted) setState(() => _busyType = null);
    }
  }

  Future<void> _preview(String url) async {
    await _previewPlayer.stop();
    await _previewPlayer.play(UrlSource(url));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, String>>(
      stream: _repository.streamAlarmSoundConfig(),
      builder: (context, snapshot) {
        final config = snapshot.data ?? {};

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text('Alarm sounds', style: AppTypography.display(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              'The sound that plays on every tanod\'s phone when a new SOS of each type '
              'comes in. This applies org-wide — there is no per-tanod override.',
              style: AppTypography.bodySoft(fontSize: 12),
            ),
            const SizedBox(height: 16),
            for (final type in EmergencyType.values) _row(type, config[type.value]),
          ],
        );
      },
    );
  }

  Widget _row(EmergencyType type, String? url) {
    final isCustom = url != null;
    final isBusy = _busyType == type;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isCustom ? AppColors.tealLight : AppColors.line.withOpacity(0.5),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(isCustom ? Icons.music_note : Icons.notifications_none, size: 18, color: isCustom ? AppColors.teal : AppColors.inkSoft),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.label, style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(isCustom ? p.basename(Uri.parse(url).path) : 'Default sound', style: AppTypography.mono(fontSize: 10), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (isBusy)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            if (isCustom)
              IconButton(icon: const Icon(Icons.play_arrow), tooltip: 'Preview', onPressed: () => _preview(url)),
            IconButton(icon: const Icon(Icons.folder_open), tooltip: 'Choose file', onPressed: () => _pick(type)),
            if (isCustom) IconButton(icon: const Icon(Icons.restore), tooltip: 'Reset to default', onPressed: () => _reset(type)),
          ],
        ],
      ),
    );
  }
}
