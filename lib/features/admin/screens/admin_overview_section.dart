import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../models/report_model.dart';
import '../../../models/sos_alert_model.dart';
import '../../../models/user_model.dart';
import '../data/admin_repository.dart';
import 'admin_home_screen.dart';

/// Landing section of the dashboard — at-a-glance counts across active
/// SOS, pending reports, and staff, each linking straight into the
/// relevant section, plus a weekly/monthly activity trend and a report
/// status breakdown so an admin can actually see how things are moving
/// over time, not just a snapshot of right now. The live incident map /
/// full monitoring view is still a later phase (see AdminHomeScreen's doc
/// comment) — this stays a reporting/oversight view.
class AdminOverviewSection extends StatelessWidget {
  const AdminOverviewSection({super.key, required this.onNavigate});

  final void Function(AdminSection) onNavigate;

  @override
  Widget build(BuildContext context) {
    final repository = AdminRepository();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: StreamBuilder<List<SosAlertModel>>(
        stream: repository.streamAllSosAlerts(),
        builder: (context, sosSnap) {
          return StreamBuilder<List<ReportModel>>(
            stream: repository.streamAllReports(),
            builder: (context, reportSnap) {
              return StreamBuilder<List<UserModel>>(
                stream: repository.streamAllUsers(),
                builder: (context, userSnap) {
                  return StreamBuilder<List<UserModel>>(
                    stream: repository.streamPendingVerifications(),
                    builder: (context, verificationSnap) {
                  final alerts = sosSnap.data ?? [];
                  final reports = reportSnap.data ?? [];
                  final users = userSnap.data ?? [];
                  final pendingVerifications = verificationSnap.data?.length ?? 0;

                  final activeAlerts = alerts.where((a) => a.status == SosStatus.active).length;
                  final respondingAlerts = alerts.where((a) => a.status == SosStatus.responded).length;
                  final pendingReports = reports.where((r) => r.status == ReportStatus.pending).length;
                  final tanodCount = users.where((u) => u.role == UserRole.tanod).length;
                  final policeCount = users.where((u) => u.role == UserRole.police).length;
                  final residentCount = users.where((u) => u.role == UserRole.resident).length;

                  return ListView(
                    children: [
                      Text('System overview', style: AppTypography.display(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text('Barangay Camino Nuevo · live counts', style: AppTypography.bodySoft(fontSize: 12.5)),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _StatCard(
                            label: 'Active SOS',
                            value: '$activeAlerts',
                            color: activeAlerts > 0 ? AppColors.urgent : AppColors.teal,
                            onTap: () => onNavigate(AdminSection.incidents),
                          ),
                          _StatCard(
                            label: 'Being responded to',
                            value: '$respondingAlerts',
                            color: AppColors.amber,
                            onTap: () => onNavigate(AdminSection.incidents),
                          ),
                          _StatCard(
                            label: 'Pending reports',
                            value: '$pendingReports',
                            color: pendingReports > 0 ? AppColors.amber : AppColors.teal,
                            onTap: () => onNavigate(AdminSection.incidents),
                          ),
                          _StatCard(
                            label: 'Tanod',
                            value: '$tanodCount',
                            color: AppColors.teal,
                            onTap: () => onNavigate(AdminSection.responders),
                          ),
                          _StatCard(
                            label: 'Police',
                            value: '$policeCount',
                            color: AppColors.teal,
                            onTap: () => onNavigate(AdminSection.responders),
                          ),
                          _StatCard(
                            label: 'Residents',
                            value: '$residentCount',
                            color: AppColors.navy,
                            onTap: () => onNavigate(AdminSection.users),
                          ),
                          _StatCard(
                            label: 'Pending verifications',
                            value: '$pendingVerifications',
                            color: pendingVerifications > 0 ? AppColors.amber : AppColors.teal,
                            onTap: () => onNavigate(AdminSection.verifications),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (activeAlerts > 0)
                        AppCard(
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.urgent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '$activeAlerts SOS alert${activeAlerts == 1 ? '' : 's'} waiting for a responder.',
                                  style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              TextButton(
                                onPressed: () => onNavigate(AdminSection.incidents),
                                child: const Text('Assign now'),
                              ),
                            ],
                          ),
                        ),
                      if (pendingVerifications > 0) ...[
                        const SizedBox(height: 12),
                        AppCard(
                          child: Row(
                            children: [
                              const Icon(Icons.fact_check_outlined, color: AppColors.amber),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '$pendingVerifications resident${pendingVerifications == 1 ? '' : 's'} waiting on ID verification.',
                                  style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              TextButton(
                                onPressed: () => onNavigate(AdminSection.verifications),
                                child: const Text('Review now'),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 720;
                          final trend = _ActivityTrendCard(reports: reports, alerts: alerts);
                          final breakdown = _StatusBreakdownCard(reports: reports);
                          if (!isWide) {
                            return Column(
                              children: [
                                trend,
                                const SizedBox(height: 16),
                                breakdown,
                              ],
                            );
                          }
                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 3, child: trend),
                                const SizedBox(width: 16),
                                Expanded(flex: 2, child: breakdown),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color, required this.onTap});

  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppSpacing.cardRadius,
      onTap: onTap,
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: AppSpacing.cardRadius,
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTypography.display(fontSize: 28, color: color)),
            const SizedBox(height: 4),
            Text(label, style: AppTypography.bodySoft(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

enum _TrendPeriod { weekly, monthly }

/// New reports vs. new SOS alerts over time, toggled between the last 7
/// days and the last 6 months — the "weekly / monthly reports" view an
/// admin actually needs to notice whether things are trending up or down,
/// instead of only ever seeing today's snapshot in the stat cards above.
/// Both series are bucketed client-side from the same streams the stat
/// cards already use (see AdminRepository.streamAllReports /
/// streamAllSosAlerts) — no extra Firestore reads.
class _ActivityTrendCard extends StatefulWidget {
  const _ActivityTrendCard({required this.reports, required this.alerts});

  final List<ReportModel> reports;
  final List<SosAlertModel> alerts;

  @override
  State<_ActivityTrendCard> createState() => _ActivityTrendCardState();
}

class _ActivityTrendCardState extends State<_ActivityTrendCard> {
  _TrendPeriod _period = _TrendPeriod.weekly;

  @override
  Widget build(BuildContext context) {
    final buckets = _period == _TrendPeriod.weekly ? 7 : 6;
    final labels = _period == _TrendPeriod.weekly ? _dayLabels(buckets) : _monthLabels(buckets);
    final reportCounts = _period == _TrendPeriod.weekly
        ? _bucketByDay(widget.reports.map((r) => r.createdAt), buckets)
        : _bucketByMonth(widget.reports.map((r) => r.createdAt), buckets);
    final sosCounts = _period == _TrendPeriod.weekly
        ? _bucketByDay(widget.alerts.map((a) => a.createdAt), buckets)
        : _bucketByMonth(widget.alerts.map((a) => a.createdAt), buckets);

    final maxCount = [...reportCounts, ...sosCounts, 1].reduce((a, b) => a > b ? a : b);
    final totalReports = reportCounts.fold<int>(0, (a, b) => a + b);
    final totalSos = sosCounts.fold<int>(0, (a, b) => a + b);

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _period == _TrendPeriod.weekly ? 'Activity — last 7 days' : 'Activity — last 6 months',
                  style: AppTypography.display(fontSize: 15),
                ),
              ),
              _PeriodToggle(
                period: _period,
                onChanged: (p) => setState(() => _period = p),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _LegendDot(color: AppColors.navy, label: 'Reports · $totalReports'),
              const SizedBox(width: 16),
              _LegendDot(color: AppColors.urgent, label: 'SOS alerts · $totalSos'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: (maxCount + (maxCount * 0.25).ceil()).toDouble(),
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxCount / 4).clamp(1, double.infinity).ceilToDouble(),
                  getDrawingHorizontalLine: (_) => FlLine(color: AppColors.line, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(labels[i], style: AppTypography.mono(fontSize: 9.5)),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.navyDeep,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final isReport = rodIndex == 0;
                      return BarTooltipItem(
                        '${isReport ? 'Reports' : 'SOS'}: ${rod.toY.toInt()}',
                        const TextStyle(color: Colors.white, fontSize: 11),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < buckets; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: reportCounts[i].toDouble(),
                          color: AppColors.navy,
                          width: 8,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        BarChartRodData(
                          toY: sosCounts[i].toDouble(),
                          color: AppColors.urgent,
                          width: 8,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.period, required this.onChanged});

  final _TrendPeriod period;
  final ValueChanged<_TrendPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.line)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment('Weekly', _TrendPeriod.weekly),
          _segment('Monthly', _TrendPeriod.monthly),
        ],
      ),
    );
  }

  Widget _segment(String label, _TrendPeriod value) {
    final selected = period == value;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: selected ? AppColors.navy : Colors.transparent, borderRadius: BorderRadius.circular(6)),
        child: Text(
          label,
          style: AppTypography.mono(fontSize: 10, color: selected ? Colors.white : AppColors.inkSoft, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.bodySoft(fontSize: 11.5)),
      ],
    );
  }
}

/// Donut breakdown of every report by status — pending / in progress /
/// resolved — so an admin can see the overall health of the case load at
/// a glance (a barangay with a lot of red "pending" share needs more
/// tanod attention, one that's mostly green is keeping up).
class _StatusBreakdownCard extends StatelessWidget {
  const _StatusBreakdownCard({required this.reports});

  final List<ReportModel> reports;

  @override
  Widget build(BuildContext context) {
    final pending = reports.where((r) => r.status == ReportStatus.pending).length;
    final inProgress = reports.where((r) => r.status == ReportStatus.inProgress).length;
    final resolved = reports.where((r) => r.status == ReportStatus.resolved).length;
    final total = pending + inProgress + resolved;

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reports by status', style: AppTypography.display(fontSize: 15)),
          const SizedBox(height: 4),
          Text('All-time, $total total', style: AppTypography.bodySoft(fontSize: 11.5)),
          const SizedBox(height: 16),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No reports yet.', style: AppTypography.bodySoft(fontSize: 12))),
            )
          else ...[
            SizedBox(
              height: 130,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 32,
                  sections: [
                    if (pending > 0)
                      PieChartSectionData(value: pending.toDouble(), color: AppColors.amber, radius: 26, showTitle: false),
                    if (inProgress > 0)
                      PieChartSectionData(value: inProgress.toDouble(), color: AppColors.teal, radius: 26, showTitle: false),
                    if (resolved > 0)
                      PieChartSectionData(value: resolved.toDouble(), color: AppColors.resolvedFg, radius: 26, showTitle: false),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _BreakdownRow(color: AppColors.amber, label: 'Pending', count: pending, total: total),
            const SizedBox(height: 8),
            _BreakdownRow(color: AppColors.teal, label: 'In progress', count: inProgress, total: total),
            const SizedBox(height: 8),
            _BreakdownRow(color: AppColors.resolvedFg, label: 'Resolved', count: resolved, total: total),
          ],
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.color, required this.label, required this.count, required this.total});

  final Color color;
  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (count / total * 100).round();
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: AppTypography.body(fontSize: 12.5))),
        Text('$count · $pct%', style: AppTypography.mono(fontSize: 10.5)),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Date bucketing helpers — shared by weekly (last 7 days) and monthly
// (last 6 months) trend views. Pure functions, no Firestore/BuildContext
// involved, so they're easy to reason about independently of the widgets
// above.
// ---------------------------------------------------------------------

List<int> _bucketByDay(Iterable<DateTime?> dates, int days) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final counts = List<int>.filled(days, 0);
  for (final d in dates) {
    if (d == null) continue;
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff >= 0 && diff < days) {
      counts[days - 1 - diff]++;
    }
  }
  return counts;
}

List<String> _dayLabels(int days) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final now = DateTime.now();
  return List.generate(days, (i) {
    final date = now.subtract(Duration(days: days - 1 - i));
    return names[date.weekday - 1];
  });
}

List<int> _bucketByMonth(Iterable<DateTime?> dates, int months) {
  final now = DateTime.now();
  final counts = List<int>.filled(months, 0);
  for (final d in dates) {
    if (d == null) continue;
    final monthsAgo = (now.year - d.year) * 12 + (now.month - d.month);
    if (monthsAgo >= 0 && monthsAgo < months) {
      counts[months - 1 - monthsAgo]++;
    }
  }
  return counts;
}

List<String> _monthLabels(int months) {
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final now = DateTime.now();
  return List.generate(months, (i) {
    final monthsAgo = months - 1 - i;
    final index = ((now.month - 1 - monthsAgo) % 12 + 12) % 12;
    return names[index];
  });
}
