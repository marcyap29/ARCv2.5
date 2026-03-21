import 'package:flutter/material.dart';
import 'package:my_app/arc/chat/ui/writing_screen.dart';
import 'package:my_app/arc/chat/widgets/lumara_message_body.dart';
import 'package:my_app/arc/ui/widgets/reflection_draft_text_field.dart';
import 'package:my_app/lumara/agents/models/research_models.dart';
import 'package:my_app/lumara/agents/services/agents_chronicle_service.dart';
import 'package:my_app/lumara/agents/services/report_export_service.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/shared/app_colors.dart';

class ResearchReportDetailScreen extends StatefulWidget {
  final ResearchReport report;
  final VoidCallback? onDeleted;

  const ResearchReportDetailScreen({super.key, required this.report, this.onDeleted});

  @override
  State<ResearchReportDetailScreen> createState() => _ResearchReportDetailScreenState();
}

class _ResearchReportDetailScreenState extends State<ResearchReportDetailScreen> {
  late TextEditingController _queryController;
  late TextEditingController _summaryController;
  late TextEditingController _detailedFindingsController;
  late List<String> _tags;
  bool _saving = false;
  String? _saveError;
  /// When false, Detailed Findings is shown as rendered markdown; when true, as editable text field.
  bool _detailedFindingsEditing = false;
  final ScrollController _bodyScrollController = ScrollController();
  double _lastBodyScrollOffset = 0;
  bool _showJumpToBottom = false;
  bool _showJumpToTop = false;
  ResearchReport get report => widget.report;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: report.query);
    _summaryController = TextEditingController(text: report.summary);
    _detailedFindingsController = TextEditingController(text: report.detailedFindings);
    _tags = List<String>.from(report.tags);
    _bodyScrollController.addListener(_onBodyScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onBodyScroll();
    });
  }

  void _onBodyScroll() {
    if (!_bodyScrollController.hasClients) return;
    final offset = _bodyScrollController.offset;
    final maxExtent = _bodyScrollController.position.maxScrollExtent;
    const threshold = 150.0;
    final nearTop = offset < threshold;
    final nearBottom = offset > maxExtent - threshold;
    final scrollingDown = offset > _lastBodyScrollOffset;
    final scrollingUp = offset < _lastBodyScrollOffset;
    _lastBodyScrollOffset = offset;

    bool showBottom = false;
    bool showTop = false;
    if (maxExtent > 400) {
      if (scrollingDown && !nearBottom) showBottom = true;
      if (scrollingUp && !nearTop) showTop = true;
    }
    if (showBottom != _showJumpToBottom || showTop != _showJumpToTop) {
      setState(() {
        _showJumpToBottom = showBottom;
        _showJumpToTop = showTop;
      });
    }
  }

  void _scrollBodyToTop() {
    _bodyScrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    setState(() => _showJumpToTop = false);
  }

  void _scrollBodyToBottom() {
    if (!_bodyScrollController.hasClients) return;
    _bodyScrollController.animateTo(
      _bodyScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
    setState(() => _showJumpToBottom = false);
  }

  @override
  void dispose() {
    _bodyScrollController.removeListener(_onBodyScroll);
    _bodyScrollController.dispose();
    _queryController.dispose();
    _summaryController.dispose();
    _detailedFindingsController.dispose();
    super.dispose();
  }

  Future<void> _saveEdits() async {
    final query = _queryController.text.trim();
    final summary = _summaryController.text.trim();
    final detailed = _detailedFindingsController.text.trim();
    if (query.isEmpty) {
      setState(() => _saveError = 'Enter a title');
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      await AgentsChronicleService.instance.updateResearchReport(
        userId,
        report.id,
        query: query,
        summary: summary,
        detailedFindings: detailed,
        tags: _tags,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved. Changes appear in timeline and Outputs.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = e.toString();
        });
      }
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
    widget.onDeleted?.call();
    Navigator.pop(context, true);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
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
        ReflectionDraftTextField(
          controller: _queryController,
          hintText: 'Research question or title',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: kcPrimaryTextColor,
              ),
        ),
      ],
    );
  }

  Widget _buildTagsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags (for CHRONICLE)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: kcSecondaryTextColor,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._tags.map((tag) => Chip(
                  label: Text(tag),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => setState(() => _tags.remove(tag)),
                  backgroundColor: kcPrimaryColor.withValues(alpha: 0.15),
                )),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18, color: kcPrimaryColor),
              label: const Text('Add tag'),
              onPressed: () async {
                final text = await showDialog<String>(
                  context: context,
                  builder: (ctx) {
                    final controller = TextEditingController();
                    return AlertDialog(
                      title: const Text('Add tag'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'e.g. project name, topic',
                        ),
                        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                          child: const Text('Add'),
                        ),
                      ],
                    );
                  },
                );
                if (text != null && text.isNotEmpty && mounted) {
                  setState(() => _tags.add(text));
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Editable section (reflection-style) for Summary and Detailed Findings.
  Widget _buildEditableSection(
    BuildContext context,
    String title,
    TextEditingController controller, {
    bool isMobile = false,
    int minLines = 3,
  }) {
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
          padding: EdgeInsets.all(isMobile ? 16 : 12),
          decoration: BoxDecoration(
            color: kcSurfaceAltColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ReflectionDraftTextField(
            controller: controller,
            hintText: title,
            minLines: minLines,
            maxLines: null,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: isMobile ? 1.75 : 1.6,
                  color: kcPrimaryTextColor,
                  fontSize: isMobile ? 16 : null,
                ),
          ),
        ),
      ],
    );
  }

  /// Build a section with markdown-rendered content (same architecture as reflection preview).
  /// [isMobile] reduces density with larger line height and padding.
  Widget _buildMarkdownSection(
      BuildContext context, String title, String content, [bool isMobile = false]) {
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
          padding: EdgeInsets.all(isMobile ? 16 : 12),
          decoration: BoxDecoration(
            color: kcSurfaceAltColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: LumaraMessageBody(
            content: content,
            textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: isMobile ? 1.75 : 1.6,
                  color: kcPrimaryTextColor,
                  fontSize: isMobile ? 16 : null,
                ),
            linkColor: kcPrimaryColor,
          ),
        ),
      ],
    );
  }

  /// Detailed Findings: by default show markdown-rendered content; "Edit" reveals the text field.
  Widget _buildDetailedFindingsSection(BuildContext context, bool isMobile) {
    final content = _detailedFindingsController.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Detailed Findings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: kcPrimaryTextColor,
                  ),
            ),
            if (!_detailedFindingsEditing)
              TextButton.icon(
                onPressed: () => setState(() => _detailedFindingsEditing = true),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
                style: TextButton.styleFrom(foregroundColor: kcPrimaryColor),
              )
            else
              TextButton.icon(
                onPressed: () => setState(() => _detailedFindingsEditing = false),
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('Done'),
                style: TextButton.styleFrom(foregroundColor: kcPrimaryColor),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 16 : 12),
          decoration: BoxDecoration(
            color: kcSurfaceAltColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: _detailedFindingsEditing
              ? ReflectionDraftTextField(
                  controller: _detailedFindingsController,
                  hintText: 'Detailed Findings',
                  minLines: 8,
                  maxLines: null,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: isMobile ? 1.75 : 1.6,
                        color: kcPrimaryTextColor,
                        fontSize: isMobile ? 16 : null,
                      ),
                )
              : (content.trim().isEmpty
                  ? Text(
                      'No detailed findings yet.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: kcSecondaryColor,
                            height: isMobile ? 1.75 : 1.6,
                          ),
                    )
                  : LumaraMessageBody(
                      content: content,
                      textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: isMobile ? 1.75 : 1.6,
                            color: kcPrimaryTextColor,
                            fontSize: isMobile ? 16 : null,
                          ),
                      linkColor: kcPrimaryColor,
                    )),
        ),
      ],
    );
  }

  Widget _buildInsightsSection(BuildContext context, [bool isMobile = false]) {
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
                padding: EdgeInsets.all(isMobile ? 20 : 16),
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
        ...report.citations.asMap().entries.map((entry) {
          final refNum = entry.key + 1;
          final citation = entry.value;
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
                    '[$refNum]',
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

  Future<void> _quickShareReport(BuildContext context) async {
    final format = await showModalBottomSheet<ReportExportFormat>(
      context: context,
      backgroundColor: kcSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Share as',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: kcPrimaryTextColor,
                    ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('Markdown (.md)'),
                onTap: () => Navigator.pop(ctx, ReportExportFormat.markdown),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('PDF'),
                onTap: () => Navigator.pop(ctx, ReportExportFormat.pdf),
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Word (.docx)'),
                onTap: () => Navigator.pop(ctx, ReportExportFormat.docx),
              ),
            ],
          ),
        ),
      ),
    );
    if (format == null || !context.mounted) return;
    final ok = await ReportExportService.instance.exportAndShare(report, format: format);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Share sheet opened' : 'Share failed'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const WritingScreen(),
                settings: RouteSettings(arguments: {'researchContext': report}),
              ),
            );
          },
          icon: const Icon(Icons.edit_note, size: 20),
          label: const Text('Use in Writing'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            foregroundColor: kcPrimaryColor,
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
            content: Text('Saved to LUMARA_Backups/LUMARA_Outputs: ${path.split('/').last}'),
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
          if (_saveError != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                _saveError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () => _quickShareReport(context),
          ),
          IconButton(
            icon: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            tooltip: 'Save',
            onPressed: _saving ? null : _saveEdits,
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
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final padding = EdgeInsets.all(isMobile ? 20 : 16);
          final sectionSpacing = isMobile ? 28.0 : 24.0;
          return Stack(
            children: [
              SingleChildScrollView(
                controller: _bodyScrollController,
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    SizedBox(height: sectionSpacing),
                    _buildTagsSection(context),
                    SizedBox(height: sectionSpacing),
                    if (report.abstractBullets.isNotEmpty) ...[
                      _buildAbstractSection(context, isMobile),
                      SizedBox(height: sectionSpacing),
                    ],
                    _buildEditableSection(context, 'Summary', _summaryController, isMobile: isMobile),
                    SizedBox(height: sectionSpacing),
                    _buildDetailedFindingsSection(context, isMobile),
                    if (report.keyInsights.isNotEmpty) ...[
                      SizedBox(height: sectionSpacing),
                      _buildInsightsSection(context, isMobile),
                      SizedBox(height: sectionSpacing),
                    ],
                    if (report.strategicImplications.isNotEmpty) ...[
                      SizedBox(height: sectionSpacing),
                      _buildMarkdownSection(context, 'Strategic Implications',
                          report.strategicImplications, isMobile),
                    ],
                    if (report.nextSteps.isNotEmpty) ...[
                      SizedBox(height: sectionSpacing),
                      _buildNextStepsSection(context),
                    ],
                    SizedBox(height: sectionSpacing),
                    if (report.citations.isNotEmpty) _buildSourcesSection(context),
                    const SizedBox(height: 32),
                    _buildActionButtons(context),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              if (_showJumpToBottom || _showJumpToTop)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _showJumpToBottom ? _scrollBodyToBottom : _scrollBodyToTop,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: kcSurfaceColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: kcPrimaryColor.withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showJumpToBottom ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                color: kcPrimaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _showJumpToBottom ? 'Jump to bottom' : 'Jump to top',
                                style: const TextStyle(
                                  color: kcPrimaryColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAbstractSection(BuildContext context, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Abstract',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: kcPrimaryTextColor,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 16 : 12),
          decoration: BoxDecoration(
            color: kcSurfaceAltColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: report.abstractBullets
                .map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                              color: kcPrimaryColor,
                              height: isMobile ? 1.7 : 1.5,
                              fontSize: isMobile ? 16 : 14,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              b,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    height: isMobile ? 1.7 : 1.6,
                                    color: kcPrimaryTextColor,
                                    fontSize: isMobile ? 16 : null,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FormatChip(
                  label: '.md',
                  selected: _format == ReportExportFormat.markdown,
                  onTap: () => setState(() => _format = ReportExportFormat.markdown),
                ),
                _FormatChip(
                  label: '.txt',
                  selected: _format == ReportExportFormat.plainText,
                  onTap: () => setState(() => _format = ReportExportFormat.plainText),
                ),
                _FormatChip(
                  label: '.pdf',
                  selected: _format == ReportExportFormat.pdf,
                  onTap: () => setState(() => _format = ReportExportFormat.pdf),
                ),
                _FormatChip(
                  label: '.docx',
                  selected: _format == ReportExportFormat.docx,
                  onTap: () => setState(() => _format = ReportExportFormat.docx),
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
                  subtitle: 'LUMARA_Backups/LUMARA_Outputs',
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
