import 'package:flutter/material.dart';
import '../../../../core/theme/lux_theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxColors.bg,
      appBar: AppBar(
        backgroundColor: LuxColors.bg,
        elevation: 0,
        title: Text('PRIVACY & DATA', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Data Privacy Act compliance', style: LuxType.heading(fontSize: 14)),
                const SizedBox(height: 6),
                Text(
                  'Your reports and evidence are classified as sensitive personal information under '
                  'RA 10173 and are encrypted and access-limited accordingly.',
                  style: LuxType.body(fontSize: 11.5, color: LuxColors.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text('RETENTION', style: LuxType.eyebrow(fontSize: 10.5)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: LuxColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxColors.divider)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _InfoRow(title: 'Evidence retention period', trailing: 'Until case closed + 1 year'),
                _InfoRow(title: 'Who can access your case', trailing: 'Assigned Tanod + escalated PNP only', isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text('YOUR DATA RIGHTS', style: LuxType.eyebrow(fontSize: 10.5)),
          const SizedBox(height: 8),
          Material(
            color: LuxColors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showSnack(context, "Request noted. We'll email you a copy within the timeframe required by RA 10173."),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: LuxColors.divider)),
                alignment: Alignment.center,
                child: Text('REQUEST A COPY OF MY DATA', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.ink, letterSpacing: 0.4)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showSnack(context, 'Request noted. A barangay official will follow up to confirm before deletion.'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: LuxColors.divider)),
                alignment: Alignment.center,
                child: Text('REQUEST ACCOUNT DELETION', style: LuxType.eyebrow(fontSize: 11, color: LuxColors.red, letterSpacing: 0.4)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.trailing, this.isLast = false});

  final String title;
  final String trailing;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: isLast ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.divider))),
      child: Row(
        children: [
          Expanded(child: Text(title, style: LuxType.heading(fontSize: 13))),
          Text(trailing, style: LuxType.body(fontSize: 10.5, color: LuxColors.inkSoft)),
        ],
      ),
    );
  }
}
