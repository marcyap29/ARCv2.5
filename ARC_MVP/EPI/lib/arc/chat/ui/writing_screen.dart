import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:my_app/arc/chat/services/lumara_cloud_generate.dart';
import 'package:my_app/lumara/agents/research/content_brief.dart';
import 'package:my_app/lumara/agents/services/agents_chronicle_service.dart';
import 'package:my_app/lumara/agents/writing/draft_editor_screen.dart';
import 'package:my_app/lumara/agents/writing/pipeline_draft.dart';
import 'package:my_app/lumara/agents/writing/style_profile_service.dart';
import 'package:my_app/lumara/agents/writing/writing_prompts.dart';
import 'package:my_app/lumara/agents/widgets/agent_tip_banner.dart';
import 'package:my_app/lumara/agents/writing/writing_models.dart';
import 'package:my_app/arc/ui/widgets/reflection_draft_text_field.dart';
import 'package:my_app/lumara/agents/models/research_models.dart';
import 'package:my_app/shared/app_colors.dart';

/// Dedicated screen for the LUMARA Writing Agent.
/// [initialBrief] when set (e.g. from Research "Use in Writing") pre-fills topic and passes brief to Phase 5b pipeline.
/// [initialPrompt] pre-fills "What should we write about?" (e.g. from research report).
/// [draftId] when set opens an existing draft from Outputs for viewing and editing.
class WritingScreen extends StatefulWidget {
  const WritingScreen({
    super.key,
    this.initialPrompt,
    this.draftId,
    this.initialBrief,
  });

  final String? initialPrompt;
  /// When non-null, load this draft for viewing/editing (e.g. from Outputs tab).
  final String? draftId;
  /// Phase 5b: When set, topic is pre-filled and brief is used as context for gemini-flash.
  final ContentBrief? initialBrief;

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _draftBodyController = TextEditingController();
  Draft? _draft;
  double? _voiceScore;
  double? _themeAlignment;
  List<String> _suggestedEdits = [];
  bool _loading = false;
  bool _loadingDraft = false;
  bool _saving = false;
  String? _error;
  /// When set, we're viewing/editing an existing draft (e.g. from Outputs).
  String? _editingDraftId;
  // Phase 5b
  WritingFormat _phase5bFormat = WritingFormat.article;
  WritingTone _phase5bTone = WritingTone.informative;
  bool _styleProfileOn = false;
  String? _styleExcerpt;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyInitialPrompt();
      _loadDraftIfNeeded();
      _loadStyleProfile();
    });
  }

  Future<void> _loadStyleProfile() async {
    final profile = await StyleProfileService.instance.getProfile();
    if (!mounted) return;
    setState(() {
      _styleExcerpt = profile;
      _styleProfileOn = profile != null && profile.isNotEmpty;
    });
  }

  void _applyInitialPrompt() {
    if (!mounted) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    String? prompt;
    if (widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty) {
      prompt = widget.initialPrompt;
    } else if (args is Map<String, dynamic>) {
      if (args['initialPrompt'] is String) {
        prompt = args['initialPrompt'] as String;
      } else if (args['researchContext'] != null) {
        final report = args['researchContext'];
        if (report is ResearchReport) {
          final buf = StringBuffer();
          buf.writeln('# Research: ${report.query}');
          buf.writeln();
          buf.writeln(report.summary);
          if (report.keyInsights.isNotEmpty) {
            buf.writeln();
            buf.writeln('Key insights:');
            for (final i in report.keyInsights) {
              buf.writeln('- ${i.statement}');
            }
          }
          buf.writeln();
          buf.writeln(report.detailedFindings);
          prompt = buf.toString();
        }
      }
    }
    if (prompt != null && _promptController.text.trim().isEmpty) {
      _promptController.text = prompt;
      setState(() {});
    }
    if (widget.initialBrief != null && _promptController.text.trim().isEmpty) {
      _promptController.text = widget.initialBrief!.title;
      setState(() {});
    }
  }

  Future<void> _loadDraftIfNeeded() async {
    final draftId = widget.draftId ?? (ModalRoute.of(context)?.settings.arguments is Map<String, dynamic> ? (ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>)['draftId'] as String? : null);
    if (draftId == null || draftId.isEmpty) return;
    setState(() {
      _editingDraftId = draftId;
      _loadingDraft = true;
      _error = null;
    });
    try {
      final userId = await AgentsChronicleService.instance.getCurrentUserId();
      final result = await AgentsChronicleService.instance.getDraftById(userId, draftId);
      if (!mounted) return;
      if (result != null) {
        _draft = result.draft;
        _draftBodyController.text = result.draft.content;
        _voiceScore = result.draft.voiceScore;
        _themeAlignment = result.draft.themeAlignment;
      } else {
        _error = 'Draft not found';
      }
    } catch (e) {
      if (mounted) _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loadingDraft = false);
      }
    }
  }

  Future<void> _saveDraftEdits() async {
    if (_editingDraftId == null) return;
    final content = _draftBodyController.text;
    setState(() => _saving = true);
    try {
      final userId = await AgentsChronicleService.instance.getCurrentUserId();
      await AgentsChronicleService.instance.updateDraftContent(userId, _editingDraftId!, content);
      if (!mounted) return;
      _draft = _draft?.copyWith(content: content);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _draftBodyController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _copyDraft() {
    final text = _editingDraftId != null ? _draftBodyController.text : _draft?.content;
    if (text != null && text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft copied to clipboard')),
      );
    }
  }

  /// Run writing pipeline using the same path as legacy (generateForAgents: SwarmSpace then Groq).
  /// Uses Phase 5b prompt: Format, Tone, Style, optional Brief. Navigates to DraftEditorScreen.
  Future<void> _runPhase5bPipeline() async {
    final topic = _promptController.text.trim();
    if (topic.isEmpty) {
      setState(() => _error = 'Enter a topic (e.g. what to write about).');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final styleExcerpt = _styleProfileOn == true ? _styleExcerpt : null;
      final promptResult = buildPhase5bWritingPrompt(
        topic: topic,
        format: _phase5bFormat,
        tone: _phase5bTone,
        styleExcerpt: styleExcerpt,
        brief: widget.initialBrief,
      );
      final body = await generateForAgents(
        systemPrompt: promptResult.systemPrompt,
        userPrompt: promptResult.userPrompt,
        maxTokens: 1500,
      );
      if (!mounted) return;
      if (body.trim().isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No draft text returned.';
        });
        return;
      }
      final draft = PipelineDraft(
        id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
        topic: topic,
        format: _phase5bFormat,
        tone: _phase5bTone,
        body: body.trim(),
        briefId: widget.initialBrief?.title,
        createdAt: DateTime.now(),
        versions: [],
      );
      setState(() => _loading = false);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DraftEditorScreen(
            draft: draft,
            onRegenerate: _runPhase5bPipelineForRegenerate,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  /// Called from DraftEditorScreen Regenerate: same inputs, new body; append current body to versions.
  /// Uses generateForAgents (same working path as Generate).
  Future<PipelineDraft?> _runPhase5bPipelineForRegenerate(PipelineDraft current) async {
    final topic = current.topic;
    final styleExcerpt = _styleProfileOn == true ? _styleExcerpt : null;
    final promptResult = buildPhase5bWritingPrompt(
      topic: topic,
      format: current.format,
      tone: current.tone,
      styleExcerpt: styleExcerpt,
      brief: widget.initialBrief,
    );
    try {
      final body = await generateForAgents(
        systemPrompt: promptResult.systemPrompt,
        userPrompt: promptResult.userPrompt,
        maxTokens: 1500,
      );
      if (body.trim().isEmpty) return null;
      final newVersions = [...current.versions, current.body];
      return current.copyWith(
        body: body.trim(),
        versions: newVersions,
      );
    } catch (_) {
      return null;
    }
  }

  void _showStyleProfileSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your voice',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Gap(8),
              Text(
                'When on, LUMARA uses a style profile from your journal entries so drafts sound like you. '
                'Write a few journal entries to enable. You can refresh the profile anytime.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Gap(16),
              SwitchListTile(
                title: const Text('Use my voice'),
                value: _styleProfileOn,
                onChanged: (v) => setState(() {
                  _styleProfileOn = v;
                  Navigator.pop(ctx);
                }),
              ),
              FutureBuilder<int>(
                future: StyleProfileService.instance.getJournalEntryCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count < _minStyleEntries && snapshot.hasData) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Write a few more journal entries to enable your personal voice.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              FilledButton(
                onPressed: () async {
                  final updated = await StyleProfileService.instance.refresh(ctx);
                  if (!ctx.mounted) return;
                  setState(() {
                    _styleExcerpt = updated;
                    _styleProfileOn = updated != null && updated.isNotEmpty;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Refresh style profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const int _minStyleEntries = 3;

  Widget _buildScoresRow(BuildContext context) {
    final voicePct = _draft?.metadata.voiceMatchEstimate ??
        (_voiceScore != null ? _voiceScore! * 100 : null);
    final themePct = _draft?.metadata.themeMatchEstimate ??
        (_themeAlignment != null ? _themeAlignment! * 100 : null);
    if (voicePct == null && themePct == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Voice: ${voicePct?.toStringAsFixed(0) ?? "—"}%  •  Theme: ${themePct?.toStringAsFixed(0) ?? "—"}%',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LUMARA Writing'),
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AgentTipBanner(),
            const Gap(12),
            if (widget.initialBrief != null && !_bannerDismissed)
              Dismissible(
                key: const ValueKey('research_banner'),
                onDismissed: (_) => setState(() => _bannerDismissed = true),
                child: Material(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Using research: ${widget.initialBrief!.title}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => setState(() => _bannerDismissed = true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (widget.initialBrief != null && !_bannerDismissed) const Gap(12),
            TextField(
              controller: _promptController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What do you want to write about?',
                hintText: 'e.g. Why CHRONICLE hierarchical aggregation matters for AI memory',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const Gap(12),
            Text('Format', style: Theme.of(context).textTheme.labelLarge),
            const Gap(4),
            Wrap(
              spacing: 8,
              children: WritingFormat.values.map((f) {
                final label = f.name == 'article'
                    ? 'Article'
                    : f.name == 'linkedin'
                        ? 'LinkedIn'
                        : f.name == 'substack'
                            ? 'Substack'
                            : f.name == 'bluesky'
                                ? 'Bluesky'
                                : 'Threads';
                final selected = _phase5bFormat == f;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() => _phase5bFormat = f),
                );
              }).toList(),
            ),
            const Gap(12),
            Text('Tone', style: Theme.of(context).textTheme.labelLarge),
            const Gap(4),
            Wrap(
              spacing: 8,
              children: WritingTone.values.map((t) {
                final label = t.name[0].toUpperCase() + t.name.substring(1);
                final selected = _phase5bTone == t;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() => _phase5bTone = t),
                );
              }).toList(),
            ),
            const Gap(12),
            InkWell(
              onTap: _showStyleProfileSheet,
              borderRadius: BorderRadius.circular(20),
              child: Chip(
                avatar: Icon(
                  _styleProfileOn ? Icons.record_voice_over : Icons.voice_over_off,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                label: Text(_styleProfileOn ? 'Your voice: On' : 'Your voice: Off'),
              ),
            ),
            const Gap(24),
            FilledButton(
              onPressed: _loading ? null : () async { await _runPhase5bPipeline(); },
              child: _loading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Generate'),
            ),
            if (_error != null) ...[
              const Gap(16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const Gap(24),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Draft',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: kcPrimaryTextColor,
                      ),
                ),
                if (_draft != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_editingDraftId != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _saveDraftEdits,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save, size: 18),
                            label: Text(_saving ? 'Saving...' : 'Save'),
                          ),
                        ),
                      TextButton.icon(
                        onPressed: _copyDraft,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy'),
                      ),
                    ],
                  ),
              ],
            ),
            if (_loadingDraft)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                child: const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      Gap(16),
                      Text('Loading draft...'),
                    ],
                  ),
                ),
              )
            else if (_draft == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kcSurfaceAltColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Tap Generate above to create a draft, then edit it in the next screen.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: kcSecondaryTextColor,
                      ),
                ),
              )
            else ...[
              _buildScoresRow(context),
              const Gap(12),
              Text(
                'Draft content',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: kcPrimaryTextColor,
                    ),
              ),
              const Gap(12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kcSurfaceAltColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _editingDraftId != null
                    ? ReflectionDraftTextField(
                        controller: _draftBodyController,
                        hintText: 'Edit your draft...',
                        minLines: 8,
                        maxLines: null,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                              color: kcPrimaryTextColor,
                            ),
                      )
                    : SelectableText(
                        _draft!.content,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                              color: kcPrimaryTextColor,
                            ),
                      ),
              ),
              const Gap(12),
              Text(
                'Saved to My Drafts. Open Agents → Writing to see all drafts.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: kcSecondaryTextColor,
                    ),
              ),
              if (_draft!.metadata.contextSignalsUsed != null &&
                  _draft!.metadata.contextSignalsUsed!.isNotEmpty) ...[
                const Gap(12),
                ExpansionTile(
                  title: Text(
                    'Context used',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        _draft!.metadata.contextSignalsUsed!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              if (_suggestedEdits.isNotEmpty) ...[
                const Gap(16),
                Text('Suggestions', style: Theme.of(context).textTheme.titleSmall),
                const Gap(4),
                ..._suggestedEdits.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s, style: Theme.of(context).textTheme.bodySmall)),
                        ],
                      ),
                    )),
              ],
            ],
          ],
        ),
        ),
      ),
    );
  }
}
