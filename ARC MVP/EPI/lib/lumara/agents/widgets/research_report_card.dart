import 'package:flutter/material.dart';
import 'package:my_app/arc/chat/ui/writing_screen.dart';
import 'package:my_app/lumara/agents/models/research_models.dart';
import 'package:my_app/lumara/agents/screens/research_report_detail_screen.dart';
import 'package:my_app/shared/app_colors.dart';

class ResearchReportCard extends StatelessWidget {
  final ResearchReport report;
  final VoidCallback? onTap;

  const ResearchReportCard({
    super.key,
    required this.report,
    this.onTap,
  });

  Color _getPhaseColor(AtlasPhase phase) {
    switch (phase) {
      case AtlasPhase.recovery:
        return Colors.blue;
      case AtlasPhase.transition:
        return Colors.amber;
      case AtlasPhase.discovery:
        return Colors.purple;
      case AtlasPhase.expansion:
        return Colors.green;
      case AtlasPhase.breakthrough:
        return Colors.orange;
      case AtlasPhase.consolidation:
        return Colors.teal;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  int _estimateReadTime(ResearchReport report) {
    final wordCount = report.detailedFindings.split(' ').length;
    return (wordCount / 200).ceil().clamp(1, 999);
  }

  Widget _buildPhaseChip(BuildContext context, AtlasPhase phase) {
    final color = _getPhaseColor(phase);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        phase.name,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildMetadataChip(
      BuildContext context, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: kcSecondaryColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: kcSecondaryColor,
              ),
        ),
      ],
    );
  }

  void _openReport(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ResearchReportDetailScreen(report: report),
      ),
    );
  }

  void _showReportMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Create Content from Research'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const WritingScreen(),
                    settings: RouteSettings(
                      arguments: {'researchContext': report},
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phaseColor = _getPhaseColor(report.phase);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: kcSurfaceAltColor,
      child: InkWell(
        onTap: () => _openReport(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: phaseColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.search, size: 20, color: phaseColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.query,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: kcPrimaryTextColor,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 14, color: kcSecondaryColor),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(report.generatedAt),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: kcSecondaryColor),
                            ),
                            const SizedBox(width: 12),
                            _buildPhaseChip(context, report.phase),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showReportMenu(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                report.summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: kcPrimaryTextColor,
                    ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildMetadataChip(
                    context,
                    Icons.article,
                    '${report.citations.length} sources',
                  ),
                  _buildMetadataChip(
                    context,
                    Icons.lightbulb_outline,
                    '${report.keyInsights.length} insights',
                  ),
                  _buildMetadataChip(
                    context,
                    Icons.subject,
                    '${_estimateReadTime(report)} min read',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
