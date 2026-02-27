import 'package:flutter/material.dart';
import 'package:my_app/arc/chat/ui/writing_screen.dart';
import 'package:my_app/lumara/agents/models/research_models.dart';
import 'package:my_app/shared/app_colors.dart';

class ResearchReportDetailScreen extends StatelessWidget {
  final ResearchReport report;

  const ResearchReportDetailScreen({super.key, required this.report});

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

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) return Colors.green;
    if (confidence >= 0.75) return Colors.blue;
    if (confidence >= 0.6) return Colors.amber;
    return Colors.orange;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildHeader(BuildContext context) {
    final phaseColor = _getPhaseColor(report.phase);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: phaseColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${report.phase.name} Phase',
                style: TextStyle(
                  color: phaseColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),
            Text(
              _formatDate(report.generatedAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: kcSecondaryColor,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          report.query,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: kcPrimaryTextColor,
              ),
        ),
      ],
    );
  }

  Widget _buildSection(
      BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: kcPrimaryTextColor,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.6,
                color: kcPrimaryTextColor,
              ),
        ),
      ],
    );
  }

  Widget _buildInsightsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Insights',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: kcPrimaryTextColor,
              ),
        ),
        const SizedBox(height: 12),
        ...report.keyInsights.asMap().entries.map((entry) {
          final index = entry.key;
          final insight = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              color: kcSurfaceAltColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: kcPrimaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: kcPrimaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            insight.statement,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: kcPrimaryTextColor,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      insight.evidence,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                            color: kcPrimaryTextColor,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Wrap(
                          spacing: 4,
                          children: insight.citationIds.map((id) {
                            return Chip(
                              label: Text(
                                '[$id]',
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: kcSurfaceColor,
                            );
                          }).toList(),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: _getConfidenceColor(insight.confidence),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(insight.confidence * 100).toInt()}% confidence',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: _getConfidenceColor(
                                        insight.confidence),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNextStepsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended Next Steps',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: kcPrimaryTextColor,
              ),
        ),
        const SizedBox(height: 12),
        ...report.nextSteps.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.arrow_forward,
                    size: 20, color: kcPrimaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: kcPrimaryTextColor,
                        ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSourcesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sources',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: kcPrimaryTextColor,
              ),
        ),
        const SizedBox(height: 12),
        ...report.citations.map((citation) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                // TODO: _openUrl(citation.url);
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '[${citation.id}]',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kcPrimaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          citation.title,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: kcPrimaryTextColor,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          citation.source,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: kcSecondaryColor),
                        ),
                        if (citation.publishDate != null)
                          Text(
                            _formatDate(citation.publishDate!),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: kcSecondaryColor),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.open_in_new,
                      size: 16, color: kcSecondaryColor),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const WritingScreen(),
                settings: RouteSettings(arguments: {'researchContext': report}),
              ),
            );
          },
          icon: const Icon(Icons.edit_note),
          label: const Text('Create Content from This Research'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: kcPrimaryColor,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.file_download),
          label: const Text('Export as PDF'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            foregroundColor: kcPrimaryColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: Text(
          'Research Report',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: kcPrimaryTextColor,
              ),
        ),
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildSection(context, 'Summary', report.summary),
            const SizedBox(height: 24),
            if (report.keyInsights.isNotEmpty) ...[
              _buildInsightsSection(context),
              const SizedBox(height: 24),
            ],
            _buildSection(
                context, 'Detailed Findings', report.detailedFindings),
            if (report.strategicImplications.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSection(context, 'Strategic Implications',
                  report.strategicImplications),
            ],
            if (report.nextSteps.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildNextStepsSection(context),
            ],
            const SizedBox(height: 24),
            if (report.citations.isNotEmpty) _buildSourcesSection(context),
            const SizedBox(height: 32),
            _buildActionButtons(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
