import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/user_model.dart';
import '../../../models/report_model.dart';
import '../../../models/notification_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/list_item_tile.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/live_map.dart';
import '../../../core/services/fcm_service.dart';
import 'report_form_screen.dart';
import 'sos_screen.dart';
import 'my_reports_screen.dart';
import 'report_detail_screen.dart';
import 'notifications_screen.dart';
import 'profile/emergency_contacts_screen.dart';
import '../data/report_repository.dart';
import '../data/notification_repository.dart';
import '../data/emergency_contact_repository.dart';
import '../widgets/panic_button.dart';
import '../../auth/data/auth_repository.dart';

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

  // Created ONCE here instead of inline in build() — a fresh stream on
  // every rebuild resets StreamBuilder to "waiting" each time, causing
  // content to flash and disappear. Same fix applied across all resident
  // screens that stream from Firestore.
  late final Stream<List<ReportModel>> _recentReportsStream =
      _reportRepository.streamRecentReports(widget.user.uid, limit: 2);
  late final Stream<List<NotificationModel>> _notificationsStream =
      _notificationRepository.streamForUser(widget.user.uid);

  // Point-in-time location, captured once when Home opens — deliberately
  // NOT continuous/background tracking (that's a bigger privacy/battery
  // tradeoff nobody asked for). Refreshing means reopening Home, or tapping
  // the card's refresh icon.
  Position? _currentPosition;
  DateTime? _positionUpdatedAt;
  bool _locatingSelf = true;
  bool _sharingLocation = false;

  @override
  void initState() {
    super.initState();
    // Registers this device's FCM token so onSosCreated/onReportCreated
    // (Prompt 4.5) can actually push to it — free on Spark, no Blaze needed.
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
      SnackBar(content: Text(message), backgroundColor: isError ? AppColors.urgent : AppColors.navyDeep),
    );
  }

  /// Texts current location to every saved emergency contact — a routine
  /// "let people know where I am" convenience, distinct from SOS (which
  /// creates an alert doc, notifies tanod/police, and expects a response).
  /// Reuses the same sms: composer approach as the offline SOS path in
  /// sos_screen.dart, just with non-emergency wording and no Firestore
  /// write at all.
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
              backgroundColor: AppColors.urgent,
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
      final numbers = contacts.map((c) => c.phone).where((p) => p.isNotEmpty).toSet();
      final mapsLink = 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      final message = '[Bantay Nuevo] ${widget.user.name} is sharing their current location: $mapsLink';
      final uri = Uri(scheme: 'sms', path: numbers.join(','), queryParameters: {'body': message});
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnack('Could not open your SMS app.', isError: true);
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

  AppStatus _toAppStatus(ReportStatus s) => switch (s) {
        ReportStatus.pending => AppStatus.pending,
        ReportStatus.inProgress => AppStatus.progress,
        ReportStatus.resolved => AppStatus.resolved,
      };

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text('Bantay Nuevo'),
          ],
        ),
        actions: [
          StreamBuilder<List<NotificationModel>>(
            stream: _notificationsStream,
            builder: (context, snapshot) {
              final unread = (snapshot.data ?? []).where((n) => !n.read).length;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none, size: 22),
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
                        decoration: const BoxDecoration(color: AppColors.urgent, shape: BoxShape.circle),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Log out',
            onPressed: _authRepository.logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SectionTitle('Your location', topPadding: 0),
          AppCard(
            padding: const EdgeInsets.all(0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: SizedBox(
                    height: 150,
                    child: _locatingSelf
                        ? const ColoredBox(color: AppColors.tealLight, child: Center(child: CircularProgressIndicator()))
                        : _currentPosition == null
                            ? ColoredBox(
                                color: AppColors.tealLight,
                                child: Center(
                                  child: Text('Location unavailable', style: AppTypography.bodySoft(fontSize: 12)),
                                ),
                              )
                            : LiveMap(
                                selfLat: _currentPosition!.latitude,
                                selfLng: _currentPosition!.longitude,
                                selfLabel: 'You',
                                showBoundary: true,
                              ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(13),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: AppColors.teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your live location', style: AppTypography.bodySoft(fontSize: 10.5)),
                            Text('${user.barangay}, Purok ${user.purok}', style: AppTypography.display(fontSize: 13.5)),
                            if (_positionUpdatedAt != null)
                              Text(_relativeTime(_positionUpdatedAt), style: AppTypography.mono(fontSize: 9.5, color: AppColors.teal)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        tooltip: 'Refresh location',
                        onPressed: _locatingSelf ? null : _loadCurrentLocation,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          

          Row(
            children: [
              Expanded(
                child: _HomeActionCard(
                  icon: Icons.share_location,
                  title: 'Share my location',
                  description: 'Let trusted contacts know where you are',
                  color: AppColors.navy,
                  onTap: _sharingLocation ? null : _shareMyLocation,
                  busy: _sharingLocation,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HomeActionCard(
                  icon: Icons.edit_note,
                  title: 'Report an incident',
                  description: 'Help keep your community safe',
                  color: AppColors.panel,
                  iconColor: AppColors.teal,
                  titleColor: AppColors.ink,
                  descriptionColor: AppColors.inkSoft,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ReportFormScreen(user: user)),
                  ),
                ),
              ),
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionTitle('Recent activity', topPadding: 4),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MyReportsScreen(user: user)),
                ),
                child: const Text('See all'),
              ),
            ],
          ),
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
                return AppCard(
                  child: Text(
                    'No reports yet. Filed reports will show up here.',
                    style: AppTypography.bodySoft(fontSize: 12),
                  ),
                );
              }
              return AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Column(
                  children: [
                    for (int i = 0; i < reports.length; i++)
                      ListItemTile(
                        title: reports[i].type,
                        subtitle: _formatReportDate(reports[i].createdAt),
                        trailing: StatusBadge(status: _toAppStatus(reports[i].status)),
                        isLast: i == reports.length - 1,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ReportDetailScreen(reportId: reports[i].id)),
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

/// Two-color tappable action card matching the "Share my location" /
/// "Report an incident" pattern — filled navy for the primary action,
/// panel/white with a teal icon accent for the secondary one, both using
/// existing AGENTS.md §4 tokens (no new colors introduced).
class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.iconColor = Colors.white,
    this.titleColor = Colors.white,
    this.descriptionColor = const Color(0xCCFFFFFF),
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Color iconColor;
  final Color titleColor;
  final Color descriptionColor;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final isFilled = color != AppColors.panel;
    return Material(
      color: color,
      borderRadius: AppSpacing.cardRadius,
      child: InkWell(
        borderRadius: AppSpacing.cardRadius,
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppSpacing.cardRadius,
            border: isFilled ? null : Border.all(color: AppColors.line, width: AppSpacing.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isFilled ? Colors.white.withOpacity(0.15) : AppColors.tealLight,
                      shape: BoxShape.circle,
                    ),
                    child: busy
                        ? Padding(
                            padding: const EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2, color: iconColor),
                          )
                        : Icon(icon, size: 17, color: iconColor),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: descriptionColor),
                ],
              ),
              const SizedBox(height: 10),
              Text(title, style: AppTypography.display(fontSize: 14.5, color: titleColor)),
              const SizedBox(height: 3),
              Text(description, style: AppTypography.bodySoft(fontSize: 11).copyWith(color: descriptionColor)),
            ],
          ),
        ),
      ),
    );
  }
}
