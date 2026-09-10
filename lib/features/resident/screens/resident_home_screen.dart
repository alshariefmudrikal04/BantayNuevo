import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/user_model.dart';
import '../../../models/report_model.dart';
import '../../../models/notification_model.dart';
import '../../../core/theme/lux_theme.dart';
import '../../../core/widgets/live_map.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/philsms_service.dart';
import 'report_form_screen.dart';
import 'sos_screen.dart';
import 'my_reports_screen.dart';
import 'report_detail_screen.dart';
import 'notifications_screen.dart';
import 'profile/emergency_contacts_screen.dart';
import '../data/report_repository.dart';
import '../data/notification_repository.dart';
import '../data/emergency_contact_repository.dart';
import '../../auth/data/auth_repository.dart';

/// Resident Home — reskinned to the "luxury minimal" reference
/// (dribbble.com/shots/27499918): white background, a giant bold
/// "WELCOME BACK" greeting, a full-width red SOS banner as the primary
/// CTA, then a "QUICK SERVICES" list of real app features styled as
/// clean icon rows. All business logic below (location loading, share
/// location, reports stream, notifications) is unchanged from before —
/// only the presentation layer changed. Deliberately does NOT reuse the
/// shared cross-role widgets (AppCard, SectionTitle, StatusBadge, etc.)
/// here, since those are still used by tanod/police/admin on the old
/// palette — see lux_theme.dart's doc comment on the staged rollout plan.
class ResidentHomeScreen extends StatefulWidget {
  const ResidentHomeScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends State<ResidentHomeScreen> {
  final _reportRepository = ReportRepository();
  final _notificationRepository = NotificationRepository();
  final _emergencyContactRepository = EmergencyContactRepository();
  final _authRepository = AuthRepository();

  late final Stream<List<ReportModel>> _recentReportsStream =
      _reportRepository.streamRecentReports(widget.user.uid, limit: 2);
  late final Stream<List<NotificationModel>> _notificationsStream =
      _notificationRepository.streamForUser(widget.user.uid);

  Position? _currentPosition;
  DateTime? _positionUpdatedAt;
  bool _locatingSelf = true;
  bool _sharingLocation = false;

  @override
  void initState() {
    super.initState();
    FcmService.registerToken(widget.user.uid);
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() => _locatingSelf = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _locatingSelf = false);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locatingSelf = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _positionUpdatedAt = DateTime.now();
        _locatingSelf = false;
      });
    } catch (_) {
      if (mounted) setState(() => _locatingSelf = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? LuxColors.red : LuxColors.black),
    );
  }

  Future<void> _shareMyLocation() async {
    setState(() => _sharingLocation = true);
    try {
      final position = _currentPosition ?? await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 15));
      final contacts = await _emergencyContactRepository.streamForResident(widget.user.uid).first;
      if (contacts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Add an emergency contact first to use this.'),
              backgroundColor: LuxColors.red,
              action: SnackBarAction(
                label: 'Add',
                textColor: Colors.white,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => EmergencyContactsScreen(user: widget.user)),
                ),
              ),
            ),
          );
        }
        return;
      }
      final mapsLink = 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      final sent = await PhilSmsService.sendSms(
        numbers: contacts.map((c) => c.phone).toList(),
        message: '[Bantay Nuevo] ${widget.user.name} shared their location: $mapsLink',
      );
      if (sent) {
        _showSnack('Location shared with your emergency contacts.');
      } else {
        _showSnack('Could not send the message — check your connection and try again.', isError: true);
      }
    } catch (_) {
      _showSnack('Could not get your location — check permissions and try again.', isError: true);
    } finally {
      if (mounted) setState(() => _sharingLocation = false);
    }
  }

  String _relativeTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes} min ago';
    return 'Updated ${diff.inHours} hr ago';
  }

  String _formatReportDate(DateTime? date) {
    if (date == null) return 'Just now';
    return 'Filed ${date.month}/${date.day}/${date.year}';
  }

  ({String label, Color color}) _statusMeta(ReportStatus s) => switch (s) {
        ReportStatus.pending => (label: 'PENDING', color: LuxColors.amber),
        ReportStatus.inProgress => (label: 'IN PROGRESS', color: LuxColors.black),
        ReportStatus.resolved => (label: 'RESOLVED', color: LuxColors.success),
      };

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final firstName = user.name.trim().isEmpty ? 'THERE' : user.name.trim().split(' ').first.toUpperCase();

    return Scaffold(
      backgroundColor: LuxColors.bg,
      appBar: AppBar(
        backgroundColor: LuxColors.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          StreamBuilder<List<NotificationModel>>(
            stream: _notificationsStream,
            builder: (context, snapshot) {
              final unread = (snapshot.data ?? []).where((n) => !n.read).length;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none, size: 22, color: LuxColors.black),
                    tooltip: 'Notifications',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => NotificationsScreen(user: user)),
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: LuxColors.red, shape: BoxShape.circle),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20, color: LuxColors.black),
            tooltip: 'Log out',
            onPressed: _authRepository.logout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacingLux.h, 0, AppSpacingLux.h, AppSpacingLux.h),
        children: [
          Text('WELCOME BACK,', style: LuxType.eyebrow(fontSize: 11)),
          const SizedBox(height: 2),
          Text(firstName, style: LuxType.hero(fontSize: 40)),
          const SizedBox(height: 24),

          Text('HOW CAN WE HELP?', style: LuxType.eyebrow(fontSize: 10.5)),
          const SizedBox(height: 10),
          _SosBanner(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SosScreen(user: user, autoStart: true)),
            ),
          ),
          const SizedBox(height: 26),

          Text('QUICK SERVICES', style: LuxType.eyebrow(fontSize: 10.5)),
          const SizedBox(height: 10),
          _ServiceRow(
            icon: Icons.edit_note,
            title: 'Report an Incident',
            subtitle: 'Help keep your community safe',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ReportFormScreen(user: user)),
            ),
          ),
          _ServiceRow(
            icon: Icons.share_location,
            title: 'Share My Location',
            subtitle: 'Let trusted contacts know where you are',
            busy: _sharingLocation,
            onTap: _sharingLocation ? null : _shareMyLocation,
          ),
          _ServiceRow(
            icon: Icons.folder_open,
            title: 'My Reports',
            subtitle: 'Track the status of everything you filed',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MyReportsScreen(user: user)),
            ),
          ),
          _ServiceRow(
            icon: Icons.contacts_outlined,
            title: 'Emergency Contacts',
            subtitle: 'Who gets texted when you send an SOS',
            isLast: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EmergencyContactsScreen(user: user)),
            ),
          ),
          const SizedBox(height: 26),

          Text('YOUR LOCATION', style: LuxType.eyebrow(fontSize: 10.5)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: LuxColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LuxColors.divider),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 140,
                  child: _locatingSelf
                      ? const ColoredBox(color: LuxColors.surfaceMuted, child: Center(child: CircularProgressIndicator()))
                      : _currentPosition == null
                          ? ColoredBox(
                              color: LuxColors.surfaceMuted,
                              child: Center(child: Text('Location unavailable', style: LuxType.body(fontSize: 12, color: LuxColors.inkSoft))),
                            )
                          : LiveMap(
                              selfLat: _currentPosition!.latitude,
                              selfLng: _currentPosition!.longitude,
                              selfLabel: 'You',
                              showBoundary: true,
                            ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: LuxColors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${user.barangay}, Purok ${user.purok}', style: LuxType.heading(fontSize: 14)),
                            if (_positionUpdatedAt != null)
                              Text(_relativeTime(_positionUpdatedAt), style: LuxType.eyebrow(fontSize: 9, color: LuxColors.inkSoft, letterSpacing: 0.3)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18, color: LuxColors.ink),
                        tooltip: 'Refresh location',
                        onPressed: _locatingSelf ? null : _loadCurrentLocation,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RECENT ACTIVITY', style: LuxType.eyebrow(fontSize: 10.5)),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MyReportsScreen(user: user)),
                ),
                child: Text('SEE ALL', style: LuxType.eyebrow(fontSize: 10.5, color: LuxColors.red)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<ReportModel>>(
            stream: _recentReportsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final reports = snapshot.data ?? [];
              if (reports.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
                  child: Text('No reports yet. Filed reports will show up here.', style: LuxType.body(fontSize: 12, color: LuxColors.inkSoft)),
                );
              }
              return Container(
                decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (int i = 0; i < reports.length; i++)
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ReportDetailScreen(reportId: reports[i].id)),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: i == reports.length - 1
                              ? null
                              : const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.divider))),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(reports[i].type, style: LuxType.heading(fontSize: 13.5)),
                                    const SizedBox(height: 2),
                                    Text(_formatReportDate(reports[i].createdAt), style: LuxType.eyebrow(fontSize: 9, color: LuxColors.inkSoft, letterSpacing: 0.3)),
                                  ],
                                ),
                              ),
                              _StatusPill(meta: _statusMeta(reports[i].status)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Just so this file doesn't need to import app_spacing.dart's shared
/// scale (kept resident-local, matching lux_theme.dart's own separation).
class AppSpacingLux {
  AppSpacingLux._();
  static const h = 20.0;
}

/// Full-width red "ACTIVE SOS — TAP FOR HELP" banner — the reference's
/// primary CTA on Home, replacing the old circular PanicButton with a
/// wider, more scannable shape better suited to a list-based home screen.
/// PanicButton itself is currently unused (sos_screen.dart's own trigger
/// button is built inline there instead) but kept around, restyled to
/// match this same palette, in case a future screen wants that exact
/// circular treatment again.
class _SosBanner extends StatelessWidget {
  const _SosBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LuxColors.red,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ACTIVE SOS', style: LuxType.eyebrow(fontSize: 10.5, color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text('TAP FOR HELP', style: LuxType.hero(fontSize: 24, color: Colors.white)),
                  ],
                ),
              ),
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward, color: LuxColors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row in "QUICK SERVICES" — icon circle, title, subtitle, chevron.
/// Matches the reference's service-list rows, mapped to this app's real
/// features rather than the reference's placeholder medical/travel ones.
class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.busy = false,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool busy;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Material(
        color: LuxColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: LuxColors.divider)),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: LuxColors.surfaceMuted, shape: BoxShape.circle),
                  child: busy
                      ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(icon, size: 19, color: LuxColors.red),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: LuxType.heading(fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: LuxType.body(fontSize: 11, color: LuxColors.inkSoft)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: LuxColors.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.meta});

  final ({String label, Color color}) meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: meta.color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(meta.label, style: LuxType.eyebrow(fontSize: 9, color: meta.color, letterSpacing: 0.4)),
    );
  }
}
