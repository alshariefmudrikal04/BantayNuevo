import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';
import 'sos_screen.dart';
import 'report_detail_screen.dart';
import '../data/report_repository.dart';
import '../../../core/utils/geofence.dart';

const _incidentTypes = [
  'Physical injury / maltreatment',
  'Threats',
  'Abuse involving a minor',
  'Other',
];

class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _reportRepository = ReportRepository();
  final _descriptionController = TextEditingController();

  String _type = _incidentTypes.first;
  final List<PickedEvidence> _evidence = [];

  Position? _position;
  bool _loadingLocation = true;
  String? _locationError;

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _captureLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() {
          _loadingLocation = false;
          _locationError = 'Location services are off. You can still submit — turn them on for a more accurate report.';
        });
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          _loadingLocation = false;
          _locationError = 'Location permission denied — you can still submit without it.';
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _position = position;
        _loadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _loadingLocation = false;
        _locationError = 'Could not get your location right now.';
      });
    }
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) {
      setState(() => _evidence.add(PickedEvidence(type: 'photo', file: File(file.path), name: file.name)));
    }
  }

  Future<void> _pickVideo() async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _evidence.add(PickedEvidence(type: 'video', file: File(file.path), name: file.name)));
    }
  }

  Future<void> _submit() async {
    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _submitError = 'Please describe what happened.');
      return;
    }
    if (_isOutsideBoundary()) {
      await _showOutOfBoundsDialog();
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final newReportId = await _reportRepository.createReport(
        residentId: widget.user.uid,
        type: _type,
        description: _descriptionController.text.trim(),
        evidence: _evidence,
        lat: _position?.latitude,
        lng: _position?.longitude,
        locationAddress: 'Purok ${widget.user.purok}, ${widget.user.barangay}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted.')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ReportDetailScreen(reportId: newReportId)),
      );
    } catch (e) {
      setState(() {
        _submitting = false;
        _submitError = 'Could not submit report: $e';
      });
    }
  }

  /// Hard block for reports — per project scope, this app only covers
  /// Barangay Camino Nuevo. Skipped entirely if _position is null (GPS
  /// unavailable) since that's already a separate, pre-existing warning
  /// (_locationError below) — no need to double-punish a resident whose
  /// GPS just failed to get a fix.
  bool _isOutsideBoundary() {
    if (_position == null) return false;
    final result = checkBarangayBoundary(_position!.latitude, _position!.longitude);
    return !result.withinBoundary;
  }

  Future<void> _showOutOfBoundsDialog() {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Outside service area'),
        content: const Text(
          "Bantay Nuevo currently only covers Barangay Camino Nuevo. Your current location "
          "appears to be outside that area, so this report can't be submitted from here. "
          'Try again once you\'re back within the barangay.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  String get _locationDisplay {
    if (_loadingLocation) return 'Capturing your location...';
    if (_position != null) {
      return '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)} · Purok ${widget.user.purok}';
    }
    return _locationError ?? 'Location unavailable';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Report an incident')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Incident type', topPadding: 0),
              DropdownButtonFormField<String>(
                value: _type,
                items: _incidentTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t, style: AppTypography.body(fontSize: 12.5))))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),

              const SectionTitle('Description'),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Describe what happened...'),
              ),

              const SectionTitle('Location'),
              AppCard(
                child: Row(
                  children: [
                    if (_loadingLocation)
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Icon(
                        _position != null ? Icons.location_on : Icons.location_off,
                        size: 16,
                        color: _position != null ? AppColors.teal : AppColors.amber,
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_locationDisplay, style: AppTypography.mono(fontSize: 10.5)),
                    ),
                    if (!_loadingLocation && _position == null)
                      TextButton(onPressed: _captureLocation, child: const Text('Retry')),
                  ],
                ),
              ),

              const SectionTitle('Evidence'),
              Row(
                children: [
                  Expanded(child: AppButton(label: '＋ Photo', variant: AppButtonVariant.outline, onPressed: _pickPhoto)),
                  const SizedBox(width: 8),
                  Expanded(child: AppButton(label: '＋ Video', variant: AppButtonVariant.outline, onPressed: _pickVideo)),
                ],
              ),
              if (_evidence.isNotEmpty) ...[
                const SizedBox(height: 10),
                AppCard(
                  child: Column(
                    children: [
                      for (int i = 0; i < _evidence.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                _evidence[i].type == 'photo' ? Icons.image_outlined : Icons.videocam_outlined,
                                size: 16,
                                color: AppColors.inkSoft,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_evidence[i].name, style: AppTypography.body(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => setState(() => _evidence.removeAt(i)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              if (_submitError != null) ...[
                const SizedBox(height: 10),
                Text(_submitError!, style: AppTypography.mono(fontSize: 11, color: AppColors.urgent)),
              ],

              const SizedBox(height: 20),
              AppButton(
                label: _submitting ? 'Submitting...' : 'Submit report',
                onPressed: _submitting ? null : _submit,
              ),

              const SizedBox(height: 14),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SosScreen(user: widget.user)),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Not urgent right now? ', style: AppTypography.mono(fontSize: 10.5)),
                        TextSpan(
                          text: 'This is happening now →',
                          style: AppTypography.mono(fontSize: 10.5, color: AppColors.urgent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
