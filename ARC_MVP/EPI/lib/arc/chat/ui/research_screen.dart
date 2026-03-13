// lib/arc/chat/ui/research_screen.dart
// Dedicated screen for the LUMARA Research Agent (Agents tab).
// Phase 3: Research pipeline; Phase 4: Scan document; Phase 5a: Auto-save to Outputs.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:my_app/arc/outputs/output_tagging.dart';
import 'package:my_app/arc/outputs/outputs_chronicle_service.dart';
import 'package:my_app/arc/outputs/outputs_models.dart';
import 'package:my_app/arc/outputs/outputs_repository.dart';
import 'package:my_app/arc/chat/ui/writing_screen.dart';
import 'package:my_app/lumara/agents/research/content_brief.dart';
import 'package:my_app/lumara/agents/research/research_pipeline.dart';
import 'package:my_app/lumara/agents/screens/research_agent_tab.dart';
import 'package:my_app/lumara/agents/vision/document_parser.dart';
import 'package:my_app/lumara/agents/vision/parsed_document.dart';
import 'package:my_app/lumara/agents/widgets/agent_tip_banner.dart';

/// Screen for the LUMARA Research Agent: enter a question, get a synthesized report.
class ResearchScreen extends StatefulWidget {
  const ResearchScreen({super.key, this.initialQuery, this.initialDocumentContext});

  final String? initialQuery;
  /// Phase 5a: When opening from post-scan "Add to Research", pre-fill document context.
  final String? initialDocumentContext;

  @override
  State<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends State<ResearchScreen> {
  late final TextEditingController _queryController;

  ContentBrief? _brief;
  bool _loading = false;
  String? _stage;
  String? _error;
  final List<String> _pipelineError = [];
  /// Context from scanned document (Phase 4); injected into pipeline when running research.
  String? _documentContext;
  static final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialDocumentContext != null) {
      _documentContext = widget.initialDocumentContext;
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _runResearch() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() => _error = 'Enter a research question.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _stage = null;
      _brief = null;
      _pipelineError.clear();
    });
    final brief = await runResearchPipeline(
      query: query,
      context: context,
      onStage: (stage) {
        if (mounted) setState(() => _stage = stage);
      },
      errorOut: _pipelineError,
      documentContext: _documentContext,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _stage = null;
      _brief = brief;
      if (brief == null && _pipelineError.isNotEmpty) {
        _error = _pipelineError.first;
      }
    });
    // Phase 5a: Auto-save research brief to Outputs
    if (brief != null) {
      _saveBriefToOutputs(brief);
    }
  }

  Future<void> _saveBriefToOutputs(ContentBrief brief) async {
    try {
      final repo = OutputsRepository.instance;
      final autoTags = [...pathTags('research', 'research'), ...contentTagsFromBrief(brief)];
      final item = OutputItem(
        id: '',
        agentKey: 'research',
        folderKey: 'research',
        title: brief.title,
        createdAt: brief.createdAt,
        contentJson: jsonEncode(brief.toJson()),
        autoTags: autoTags,
        userTags: const [],
      );
      final saved = await repo.save(item);
      OutputsChronicleService.instance.onOutputSaved(type: 'output_created', item: saved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to Outputs')),
        );
      }
    } catch (_) {
      // Fire-and-forget; don't surface errors
    }
  }

  void _copyBrief() {
    if (_brief == null) return;
    final buf = StringBuffer();
    buf.writeln('# ${_brief!.title}');
    buf.writeln();
    buf.writeln(_brief!.summary);
    buf.writeln();
    for (final k in _brief!.keyPoints) {
      buf.writeln('- $k');
    }
    buf.writeln();
    buf.writeln('## Sources');
    for (final s in _brief!.sources) {
      buf.writeln('- ${s.title} ${s.url}');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Brief copied to clipboard')),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _scanDocument() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final xFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (xFile == null || !mounted) return;
    setState(() {
      _loading = true;
      _stage = 'Scanning document...';
      _error = null;
    });
    final parseError = <String>[];
    final parsed = await parseDocument(
      image: xFile,
      context: context,
      errorOut: parseError,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _stage = null;
      if (parsed.rawText.isEmpty && parsed.keyFields.isEmpty) {
        _error = parseError.isNotEmpty ? parseError.first : 'No text could be read from the image.';
      } else {
        _documentContext = _buildDocumentContext(parsed);
        _error = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document context added. Run research to use it.')),
        );
      }
    });
  }

  String _buildDocumentContext(ParsedDocument doc) {
    final buf = StringBuffer();
    if (doc.title != null && doc.title!.trim().isNotEmpty) {
      buf.writeln('Document title: ${doc.title!.trim()}');
    }
    if (doc.date != null && doc.date!.trim().isNotEmpty) {
      buf.writeln('Date: ${doc.date!.trim()}');
    }
    for (final f in doc.keyFields) {
      if (f.label.trim().isNotEmpty || f.value.trim().isNotEmpty) {
        buf.writeln('${f.label}: ${f.value}');
      }
    }
    buf.writeln();
    buf.write(doc.rawText);
    return buf.toString();
  }

  /// Less dense on mobile: larger line height and spacing.
  TextStyle _bodyStyle(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 600;
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return isNarrow
        ? base.copyWith(height: 1.65, fontSize: (base.fontSize ?? 14) * 1.05)
        : base;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LUMARA Research'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    appBar: AppBar(
                      title: const Text('My Research'),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    ),
                    body: const ResearchAgentTab(),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.folder_open, size: 20),
            label: const Text('My Research'),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final padding = EdgeInsets.all(isMobile ? 20 : 16);
          final sectionGap = isMobile ? 20.0 : 12.0;
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: SingleChildScrollView(
        padding: padding,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AgentTipBanner(),
            Gap(sectionGap),
            TextField(
              controller: _queryController,
              decoration: const InputDecoration(
                labelText: 'Research question',
                hintText: 'e.g. SBIR Phase I requirements and how ARC maps to defense priorities',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            if (_documentContext != null) ...[
              const Gap(8),
              Row(
                children: [
                  Icon(Icons.document_scanner, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Document context added',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _documentContext = null),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ],
            const Gap(16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _runResearch,
                    child: _loading
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              if (_stage != null) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _stage!,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ],
                          )
                        : const Text('Run research'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _scanDocument,
                  icon: const Icon(Icons.document_scanner, size: 20),
                  label: const Text('Scan document'),
                ),
              ],
            ),
            if (_error != null) ...[
              const Gap(16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            Gap(sectionGap * 2),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Research brief',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_brief != null)
                  TextButton.icon(
                    onPressed: _copyBrief,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
              ],
            ),
            if (_brief == null && !_loading)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Your research brief will appear here after you run a query. We search the web and academic sources, then synthesise key points.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              )
            else if (_brief != null) ...[
              const Gap(12),
              _ContentBriefCard(
                brief: _brief!,
                bodyStyle: _bodyStyle,
                onOpenUrl: _openUrl,
                onUseInWriting: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WritingScreen(initialBrief: _brief),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
      );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const Gap(6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _ContentBriefCard extends StatefulWidget {
  final ContentBrief brief;
  final TextStyle Function(BuildContext) bodyStyle;
  final Future<void> Function(String url) onOpenUrl;
  final VoidCallback onUseInWriting;

  const _ContentBriefCard({
    required this.brief,
    required this.bodyStyle,
    required this.onOpenUrl,
    required this.onUseInWriting,
  });

  @override
  State<_ContentBriefCard> createState() => _ContentBriefCardState();
}

class _ContentBriefCardState extends State<_ContentBriefCard> {
  bool _summaryExpanded = false;
  static const int _summaryPreviewLength = 200;

  @override
  Widget build(BuildContext context) {
    final brief = widget.brief;
    final sectionGap = MediaQuery.sizeOf(context).width < 600 ? 20.0 : 12.0;
    final isLongSummary = brief.summary.length > _summaryPreviewLength;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          brief.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        Gap(sectionGap),
        _Section(
          title: 'Summary',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                _summaryExpanded || !isLongSummary
                    ? brief.summary
                    : '${brief.summary.substring(0, _summaryPreviewLength)}...',
                style: widget.bodyStyle(context),
              ),
              if (isLongSummary)
                TextButton(
                  onPressed: () => setState(() => _summaryExpanded = !_summaryExpanded),
                  child: Text(_summaryExpanded ? 'Show less' : 'Show more'),
                ),
            ],
          ),
        ),
        if (brief.keyPoints.isNotEmpty) ...[
          Gap(sectionGap),
          _Section(
            title: 'Key points',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: brief.keyPoints
                  .map((k) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: widget.bodyStyle(context)),
                            Expanded(
                              child: SelectableText(k, style: widget.bodyStyle(context)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
        if (brief.sources.isNotEmpty) ...[
          Gap(sectionGap),
          _Section(
            title: 'Sources',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: brief.sources
                  .map((s) => InkWell(
                        onTap: () => widget.onOpenUrl(s.url),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            s.title.isNotEmpty ? s.title : s.url,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
        Gap(sectionGap),
        OutlinedButton.icon(
          onPressed: widget.onUseInWriting,
          icon: const Icon(Icons.edit_note, size: 20),
          label: const Text('Use in Writing'),
        ),
      ],
    );
  }
}
