import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/user_model.dart';
import '../../../core/theme/lux_theme.dart';
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
        if (!mounted) return;
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
        if (!mounted) return;
        setState(() {
          _loadingLocation = false;
          _locationError = 'Location permission denied — you can still submit without it.';
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _position = position;
        _loadingLocation = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        _locationError = 'Could not get your location right now.';
      });
    }
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) {
      setState(() => _evidence.add(PickedEvidence(type: 'photo', bytes: bytes, name: file.name)));
    }
  }

  Future<void> _pickVideo() async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) {
      setState(() => _evidence.add(PickedEvidence(type: 'video', bytes: bytes, name: file.name)));
    }
  }

  Future<void> _pickDocument() async {
    // withData: true — bytes work everywhere (web + native), see
    // CloudinaryUploader's doc comment for why a path-based pick breaks
    // on Flutter Web.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
    );
    final picked = result?.files.single;
    final bytes = picked?.bytes;
    if (picked == null || bytes == null) return;
    if (mounted) {
      setState(() => _evidence.add(PickedEvidence(type: 'document', bytes: bytes, name: picked.name)));
    }
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio, withData: true);
    final picked = result?.files.single;
    final bytes = picked?.bytes;
    if (picked == null || bytes == null) return;
    if (mounted) {
      setState(() => _evidence.add(PickedEvidence(type: 'audio', bytes: bytes, name: picked.name)));
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
      if (!mounted) return;
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
      backgroundColor: LuxColors.bg,
      appBar: AppBar(
        backgroundColor: LuxColors.bg,
        elevation: 0,
        title: Text('REPORT AN INCIDENT', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.ink)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('INCIDENT TYPE', style: LuxType.eyebrow(fontSize: 10.5)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: LuxColors.divider)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(border: InputBorder.none),
                    items: _incidentTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t, style: LuxType.body(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setState(() => _type = v ?? _type),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text('DESCRIPTION', style: LuxType.eyebrow(fontSize: 10.5)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: LuxColors.divider)),
                child: TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  style: LuxType.body(fontSize: 13),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                    hintText: 'Describe what happened...',
                    hintStyle: LuxType.body(fontSize: 13, color: LuxColors.inkSoft),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text('LOCATION', style: LuxType.eyebrow(fontSize: 10.5)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: LuxColors.divider)),
                child: Row(
                  children: [
                    if (_loadingLocation)
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Icon(
                        _position != null ? Icons.location_on : Icons.location_off,
                        size: 16,
                        color: _position != null ? LuxColors.red : LuxColors.amber,
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_locationDisplay, style: LuxType.body(fontSize: 11, color: LuxColors.inkSoft)),
                    ),
                    if (!_loadingLocation && _position == null)
                      TextButton(onPressed: _captureLocation, child: Text('RETRY', style: LuxType.eyebrow(fontSize: 10, color: LuxColors.red))),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text('EVIDENCE', style: LuxType.eyebrow(fontSize: 10.5)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _EvidenceButton(label: 'Photo', icon: Icons.add_a_photo_outlined, onTap: _pickPhoto)),
                  const SizedBox(width: 8),
                  Expanded(child: _EvidenceButton(label: 'Video', icon: Icons.videocam_outlined, onTap: _pickVideo)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _EvidenceButton(label: 'Document', icon: Icons.description_outlined, onTap: _pickDocument)),
                  const SizedBox(width: 8),
                  Expanded(child: _EvidenceButton(label: 'Audio', icon: Icons.mic_none_outlined, onTap: _pickAudio)),
                ],
              ),
              if (_evidence.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: LuxColors.divider)),
                  child: Column(
                    children: [
                      for (int i = 0; i < _evidence.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          child: Row(
                            children: [
                              Icon(
                                switch (_evidence[i].type) {
                                  'photo' => Icons.image_outlined,
                                  'video' => Icons.videocam_outlined,
                                  'audio' => Icons.mic_none_outlined,
                                  _ => Icons.description_outlined,
                                },
                                size: 16,
                                color: LuxColors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_evidence[i].name, style: LuxType.body(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: LuxColors.inkSoft),
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
                Text(_submitError!, style: LuxType.eyebrow(fontSize: 10.5, color: LuxColors.red)),
              ],

              const SizedBox(height: 24),
              Material(
                color: LuxColors.red,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _submitting ? null : _submit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    child: Text(
                      _submitting ? 'SUBMITTING...' : 'SUBMIT REPORT',
                      style: LuxType.eyebrow(fontSize: 12, color: Colors.white, letterSpacing: 0.8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SosScreen(user: widget.user, autoStart: true)),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Not urgent right now? ', style: LuxType.body(fontSize: 11, color: LuxColors.inkSoft)),
                        TextSpan(
                          text: 'This is happening now →',
                          style: LuxType.eyebrow(fontSize: 10.5, color: LuxColors.red),
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

/// One evidence-type button — photo/video/document/audio all use the same
/// shape, just a different icon/label.
class _EvidenceButton extends StatelessWidget {
  const _EvidenceButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LuxColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: LuxColors.divider)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: LuxColors.red),
              const SizedBox(height: 6),
              Text(label.toUpperCase(), style: LuxType.eyebrow(fontSize: 9.5, letterSpacing: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}
