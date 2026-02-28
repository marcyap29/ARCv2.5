import 'package:flutter/material.dart';
import 'package:my_app/arc/chat/ui/writing_screen.dart';
import 'package:my_app/arc/chat/widgets/lumara_message_body.dart';
import 'package:my_app/lumara/agents/models/research_models.dart';
import 'package:my_app/lumara/agents/screens/report_editor_screen.dart';
import 'package:my_app/lumara/agents/services/agents_chronicle_service.dart';
import 'package:my_app/lumara/agents/services/report_export_service.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/shared/app_colors.dart';

class ResearchReportDetailScreen extends StatelessWidget {
  final ResearchReport report;
  final VoidCallback? onDeleted;

  const ResearchReportDetailScreen({super.key, required this.report, this.onDeleted});

  Future<void> _editReport(BuildContext context) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => ReportEditorScreen(report: report)),
    );
    if (updated == true && context.mounted) {
      onDeleted?.call();
      Navigator.pop(context, true);
    }
  }

  Future<void> _deleteReport(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete report?'),
        content: Text('Delete "${report.query}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
    await AgentsChronicleService.instance.deleteResearchReport(userId, report.id);
    if (!context.mounted) return;
    onDeleted?.call();
    Navigator.pop(context, true);
  }

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

  /// Build a section with markdown-rendered content (same architecture as reflection preview).
  Widget _buildMarkdownSection(
      BuildContext context, String title, String content) {
    if (content.trim().isEmpty) return const SizedBox.shrink();
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kcSurfaceAltColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: LumaraMessageBody(
            content: content,
            textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  color: kcPrimaryTextColor,
                ),
            linkColor: kcPrimaryColor,
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
          onPressed: () => _showExportOptions(context),
          icon: const Icon(Icons.file_download),
          label: const Text('Export Report'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            foregroundColor: kcPrimaryColor,
          ),
        ),
      ],
    );
  }

  Future<void> _showExportOptions(BuildContext context) async {
    final result = await showModalBottomSheet<({ReportExportFormat format, ReportExportDestination dest})>(
      context: context,
      backgroundColor: kcSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ReportExportSheet(report: report),
    );
    if (result == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final svc = ReportExportService.instance;

    try {
      if (result.dest == ReportExportDestination.device) {
        final path = await svc.exportToFile(report, format: result.format);
        if (path != null && context.mounted) {
          messenger.showSnackBar(SnackBar(
            content: Text('Saved to device: ${path.split('/').last}'),
            backgroundColor: Colors.green,
          ));
        } else {
          messenger.showSnackBar(const SnackBar(content: Text('Export failed'), backgroundColor: Colors.red));
        }
      } else if (result.dest == ReportExportDestination.share) {
        final ok = await svc.exportAndShare(report, format: result.format);
        if (context.mounted) {
          messenger.showSnackBar(SnackBar(
            content: Text(ok ? 'Share sheet opened' : 'Export failed'),
            backgroundColor: ok ? Colors.green : Colors.red,
          ));
        }
      } else if (result.dest == ReportExportDestination.googleDrive) {
        final fileId = await svc.exportToGoogleDrive(report, format: result.format);
        if (context.mounted) {
          messenger.showSnackBar(SnackBar(
            content: Text(fileId != null ? 'Uploaded to Google Drive' : 'Upload failed. Sign in to Google Drive in Settings.'),
            backgroundColor: fileId != null ? Colors.green : Colors.orange,
          ));
        }
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
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
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => _editReport(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete') _deleteReport(context);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red), SizedBox(width: 12), Text('Delete report', style: TextStyle(color: Colors.red))])),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to Outputs',
            onPressed: () => Navigator.of(context).pop(),
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
            _buildMarkdownSection(context, 'Summary', report.summary),
            const SizedBox(height: 24),
            if (report.keyInsights.isNotEmpty) ...[
              _buildInsightsSection(context),
              const SizedBox(height: 24),
            ],
            _buildMarkdownSection(
                context, 'Detailed Findings', report.detailedFindings),
            if (report.strategicImplications.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildMarkdownSection(context, 'Strategic Implications',
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

/// Bottom sheet for choosing export format and destination.
class _ReportExportSheet extends StatefulWidget {
  final ResearchReport report;

  const _ReportExportSheet({required this.report});

  @override
  State<_ReportExportSheet> createState() => _ReportExportSheetState();
}

class _ReportExportSheetState extends State<_ReportExportSheet> {
  ReportExportFormat _format = ReportExportFormat.markdown;
  ReportExportDestination _dest = ReportExportDestination.share;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Export Report',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: kcPrimaryTextColor,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Format',
              style: TextStyle(
                color: kcSecondaryTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _FormatChip(
                  label: '.md',
                  selected: _format == ReportExportFormat.markdown,
                  onTap: () => setState(() => _format = ReportExportFormat.markdown),
                ),
                const SizedBox(width: 8),
                _FormatChip(
                  label: '.pdf',
                  selected: _format == ReportExportFormat.pdf,
                  onTap: () => setState(() => _format = ReportExportFormat.pdf),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Save to',
              style: TextStyle(
                color: kcSecondaryTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DestChip(
                  icon: Icons.phone_android,
                  label: 'Device',
                  selected: _dest == ReportExportDestination.device,
                  onTap: () => setState(() => _dest = ReportExportDestination.device),
                ),
                _DestChip(
                  icon: Icons.share,
                  label: 'Share',
                  subtitle: 'Email, Dropbox, etc.',
                  selected: _dest == ReportExportDestination.share,
                  onTap: () => setState(() => _dest = ReportExportDestination.share),
                ),
                _DestChip(
                  icon: Icons.cloud_upload,
                  label: 'Google Drive',
                  selected: _dest == ReportExportDestination.googleDrive,
                  onTap: () => setState(() => _dest = ReportExportDestination.googleDrive),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, (format: _format, dest: _dest)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kcPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Export'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FormatChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: kcPrimaryColor.withValues(alpha: 0.3),
      checkmarkColor: kcPrimaryColor,
    );
  }
}

class _DestChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _DestChip({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: Icon(icon, size: 18, color: selected ? kcPrimaryColor : kcSecondaryTextColor),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(fontSize: 10, color: kcSecondaryTextColor.withValues(alpha: 0.8)),
            ),
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: kcPrimaryColor.withValues(alpha: 0.3),
      checkmarkColor: kcPrimaryColor,
    );
  }
}
