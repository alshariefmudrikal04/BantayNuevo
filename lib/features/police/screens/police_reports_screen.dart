import 'package:flutter/material.dart';

import '../../../models/user_model.dart';
import '../../../models/report_model.dart';
import '../../../core/theme/lux_theme.dart';
import '../data/police_repository.dart';
import 'police_report_review_screen.dart';

/// Every incident report assigned to this police officer, with
/// pending/in-progress/resolved count cards.
class PoliceReportsScreen extends StatefulWidget {
  const PoliceReportsScreen({
    super.key,
    required this.user,
  });

  final UserModel user;

  @override
  State<PoliceReportsScreen> createState() => _PoliceReportsScreenState();
}

class _PoliceReportsScreenState extends State<PoliceReportsScreen> {
  final _repository = PoliceRepository();

  late final Stream<List<ReportModel>> _reportsStream =
      _repository.streamMyReports(widget.user.uid);

  String _formatDate(DateTime? date) {
    if (date == null) return 'just now';

    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxColors.bg,

      appBar: AppBar(
        backgroundColor: LuxColors.bg,
        elevation: 0,
        title: Text(
          'ASSIGNED REPORTS',
          style: LuxType.eyebrow(
            fontSize: 11,
            color: LuxColors.ink,
          ),
        ),
      ),

      body: StreamBuilder<List<ReportModel>>(
        stream: _reportsStream,

        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Get reports
          final reports = snapshot.data ?? [];

          // Count report statuses
          final pending = reports
              .where((r) => r.status == ReportStatus.pending)
              .length;

          final inProgress = reports
              .where((r) => r.status == ReportStatus.inProgress)
              .length;

          final resolved = reports
              .where((r) => r.status == ReportStatus.resolved)
              .length;

          return ListView(
            padding: const EdgeInsets.all(20),

            children: [
              // ============================================================
              // COUNT CARDS
              // ============================================================

              Row(
                children: [
                  Expanded(
                    child: _CountCard(
                      label: 'PENDING',
                      count: pending,
                      color: LuxColors.amber,
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: _CountCard(
                      label: 'IN PROGRESS',
                      count: inProgress,
                      color: LuxColors.black,
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: _CountCard(
                      label: 'RESOLVED',
                      count: resolved,
                      color: LuxColors.success,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ============================================================
              // SECTION TITLE
              // ============================================================

              Text(
                'ASSIGNED TO YOU',
                style: LuxType.eyebrow(
                  fontSize: 10.5,
                ),
              ),

              const SizedBox(height: 8),

              // ============================================================
              // NO REPORTS
              // ============================================================

              if (reports.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: LuxColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: LuxColors.divider,
                    ),
                  ),

                  child: Text(
                    'No reports assigned to you yet.',
                    style: LuxType.body(
                      fontSize: 12,
                      color: LuxColors.inkSoft,
                    ),
                  ),
                )

              // ============================================================
              // REPORT LIST
              // ============================================================

              else
                Container(
                  decoration: BoxDecoration(
                    color: LuxColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: LuxColors.divider,
                    ),
                  ),

                  clipBehavior: Clip.antiAlias,

                  child: Column(
                    children: [
                      for (int i = 0; i < reports.length; i++)

                        InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PoliceReportReviewScreen(
                                  reportId: reports[i].id,
                                  user: widget.user,
                                ),
                              ),
                            );
                          },

                          child: Container(
                            padding: const EdgeInsets.all(14),

                            decoration: i == reports.length - 1
                                ? null
                                : const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: LuxColors.divider,
                                      ),
                                    ),
                                  ),

                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,

                              children: [
                                // ==================================================
                                // REPORT INFORMATION
                                // ==================================================

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,

                                    children: [
                                      Text(
                                        reports[i].type,
                                        style: LuxType.heading(
                                          fontSize: 14,
                                        ),
                                      ),

                                      const SizedBox(height: 2),

                                      Text(
                                        '${reports[i].id} · ${_formatDate(reports[i].createdAt)}',

                                        style: LuxType.eyebrow(
                                          fontSize: 9,
                                          color: LuxColors.inkSoft,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // ==================================================
                                // STATUS
                                // ==================================================

                                _LuxStatusPill(
                                  status: reports[i].status.value,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// COUNT CARD
// ============================================================================

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: LuxColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: LuxColors.divider,
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            label,
            style: LuxType.eyebrow(
              fontSize: 8.5,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            '$count',
            style: LuxType.hero(
              fontSize: 22,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STATUS PILL
// ============================================================================
//
// This replaces the missing LuxStatusPill widget.
// It is defined locally so you don't need another import.
//

class _LuxStatusPill extends StatelessWidget {
  const _LuxStatusPill({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = status.toLowerCase().trim();

    Color textColor;
    Color backgroundColor;

    // ------------------------------------------------------------
    // PENDING
    // ------------------------------------------------------------

    if (normalizedStatus == 'pending') {
      textColor = LuxColors.amber;
      backgroundColor = LuxColors.amber.withOpacity(0.12);
    }

    // ------------------------------------------------------------
    // IN PROGRESS
    // ------------------------------------------------------------

    else if (
        normalizedStatus == 'in progress' ||
        normalizedStatus == 'in_progress') {
      textColor = LuxColors.black;
      backgroundColor = LuxColors.black.withOpacity(0.08);
    }

    // ------------------------------------------------------------
    // RESOLVED
    // ------------------------------------------------------------

    else if (normalizedStatus == 'resolved') {
      textColor = LuxColors.success;
      backgroundColor = LuxColors.success.withOpacity(0.12);
    }

    // ------------------------------------------------------------
    // OTHER / UNKNOWN STATUS
    // ------------------------------------------------------------

    else {
      textColor = LuxColors.inkSoft;
      backgroundColor = LuxColors.inkSoft.withOpacity(0.10);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),

      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),

      child: Text(
        status.toUpperCase(),

        style: LuxType.eyebrow(
          fontSize: 8,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}