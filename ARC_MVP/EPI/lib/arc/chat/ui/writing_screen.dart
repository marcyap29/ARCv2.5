import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/arc/chat/services/lumara_cloud_generate.dart';
import 'package:my_app/lumara/agents/research/content_brief.dart';
import 'package:my_app/lumara/agents/services/agents_chronicle_service.dart';
import 'package:my_app/lumara/agents/writing/draft_editor_screen.dart';
import 'package:my_app/lumara/agents/writing/pipeline_draft.dart';
import 'package:my_app/lumara/agents/writing/style_profile_service.dart';
import 'package:my_app/lumara/agents/writing/writing_prompts.dart';
import 'package:my_app/lumara/agents/widgets/agent_tip_banner.dart';
import 'package:my_app/features/agents/agents_data.dart';
import 'package:my_app/features/agents/worker_service.dart';
import 'package:my_app/lumara/agents/widgets/lumara_writing_format_card.dart';
import 'package:my_app/shared/ui/lumara_bottom_tab_bar.dart';
import 'package:my_app/lumara/agents/writing/writing_models.dart';
import 'package:my_app/arc/ui/widgets/reflection_draft_text_field.dart';
import 'package:my_app/lumara/agents/models/research_models.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

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
  final TextEditingController _writingFormatSpecsController =
      TextEditingController();
  final TextEditingController _researchPaperSpecsController =
      TextEditingController();
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
  String _writingFormatTierId = LumaraWritingFormatIds.mediumSocial;
  bool _includeWritingSources = false;
  late Map<String, bool> _formatSocialSelections;
  WritingTone _phase5bTone = WritingTone.informative;
  bool _styleProfileOn = false;
  String? _styleExcerpt;
  bool _bannerDismissed = false;
  /// Set when opened from a saved research output (question shown separately from topic field).
  String? _researchQuestionFromContext;

  WritingFormat _formatForTier(String id) {
    switch (id) {
      case LumaraWritingFormatIds.researchPaper:
      case LumaraWritingFormatIds.article:
      case LumaraWritingFormatIds.xlWhitePaper:
        return WritingFormat.article;
      case LumaraWritingFormatIds.shortThreads:
        return WritingFormat.threads;
      case LumaraWritingFormatIds.mediumSocial:
        return WritingFormat.linkedin;
      case LumaraWritingFormatIds.largeSubstack:
        return WritingFormat.substack;
      default:
        return WritingFormat.linkedin;
    }
  }

  String _displayNameForTier(String id) {
    switch (id) {
      case LumaraWritingFormatIds.researchPaper:
        return 'Research paper';
      case LumaraWritingFormatIds.article:
        return 'Article';
      case LumaraWritingFormatIds.shortThreads:
        return 'Short (X / Threads)';
      case LumaraWritingFormatIds.mediumSocial:
        return 'Medium (LinkedIn / Reddit)';
      case LumaraWritingFormatIds.largeSubstack:
        return 'Substack';
      case LumaraWritingFormatIds.xlWhitePaper:
        return 'White paper';
      default:
        return 'Medium (LinkedIn / Reddit)';
    }
  }

  String _toneChipLabel(WritingTone t) {
    switch (t) {
      case WritingTone.informative:
        return 'Informative';
      case WritingTone.conversational:
        return 'Conversational';
      case WritingTone.persuasive:
        return 'Persuasive';
      case WritingTone.reflective:
        return 'Reflective';
    }
  }

  @override
  void initState() {
    super.initState();
    _formatSocialSelections = {
      for (final p in WritingPlatforms.all) p.id: p.defaultSelected,
    };
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
          _researchQuestionFromContext = report.query.trim().isNotEmpty
              ? report.query.trim()
              : null;
          final body = report.detailedFindings.trim();
          final sum = report.summary.trim();
          prompt = body.isNotEmpty
              ? body
              : (sum.isNotEmpty
                  ? sum
                  : (report.keyInsights.isNotEmpty
                      ? report.keyInsights.map((i) => i.statement).join('\n')
                      : ''));
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
    _writingFormatSpecsController.dispose();
    _researchPaperSpecsController.dispose();
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

  /// Run writing pipeline via [generateForAgents] (Gemini-first, then Groq/Ollama fallbacks).
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
      final wf = _formatForTier(_writingFormatTierId);
      final specs = _writingFormatTierId == LumaraWritingFormatIds.researchPaper
          ? (_researchPaperSpecsController.text.trim().isEmpty
              ? _writingFormatSpecsController.text.trim()
              : _researchPaperSpecsController.text.trim())
          : _writingFormatSpecsController.text.trim();
      final promptResult = buildPhase5bWritingPrompt(
        topic: topic,
        format: wf,
        tone: _phase5bTone,
        styleExcerpt: styleExcerpt,
        brief: widget.initialBrief,
        formatDisplayName: _displayNameForTier(_writingFormatTierId),
        formatSpecs: specs.isEmpty ? null : specs,
        includeSourcesList: _includeWritingSources,
        reviseInPlaceIntent: AgentsData.isReviseCopyIntent(topic),
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
        format: wf,
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
    final specs = _writingFormatTierId == LumaraWritingFormatIds.researchPaper
        ? (_researchPaperSpecsController.text.trim().isEmpty
            ? _writingFormatSpecsController.text.trim()
            : _researchPaperSpecsController.text.trim())
        : _writingFormatSpecsController.text.trim();
    final promptResult = buildPhase5bWritingPrompt(
      topic: topic,
      format: current.format,
      tone: current.tone,
      styleExcerpt: styleExcerpt,
      brief: widget.initialBrief,
      formatDisplayName: _displayNameForTier(_writingFormatTierId),
      formatSpecs: specs.isEmpty ? null : specs,
      includeSourcesList: _includeWritingSources,
      reviseInPlaceIntent: AgentsData.isReviseCopyIntent(topic),
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

  static const _lumaraBorder = Color(0xFF1C1C30);
  static const _lumaraCard = Color(0xFF14142A);
  static const _lumaraFill = Color(0xFF0C0C1A);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: kcBackgroundColor,
        bottomNavigationBar: const LumaraUnifiedBottomBar(currentIndex: 0),
        appBar: AppBar(
          backgroundColor: kcBackgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            'LUMARA Writing',
            style: heading1Style(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AgentTipBanner(),
                const Gap(12),
                if (_researchQuestionFromContext != null &&
                    _researchQuestionFromContext!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _lumaraCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _lumaraBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RESEARCH QUESTION',
                          style: GoogleFonts.robotoMono(
                            color: const Color(0xFF33334A),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const Gap(8),
                        Text(
                          _researchQuestionFromContext!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.45,
                            color: const Color(0xFFC8C8E0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(16),
                ],
                if (widget.initialBrief != null && !_bannerDismissed)
                  Dismissible(
                    key: const ValueKey('research_banner'),
                    onDismissed: (_) => setState(() => _bannerDismissed = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _lumaraCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _lumaraBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_outline,
                              size: 20, color: Color(0xFF8888FF)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Using research: ${widget.initialBrief!.title}',
                              style: GoogleFonts.inter(
                                color: kcPrimaryTextColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: Color(0xFF7A7A9A)),
                            onPressed: () => setState(() => _bannerDismissed = true),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (widget.initialBrief != null && !_bannerDismissed) const Gap(12),
                Text(
                  'TOPIC & INSTRUCTIONS',
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFF33334A),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const Gap(8),
                TextField(
                  controller: _promptController,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFFE0E0F0),
                  ),
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'What should we write? Paste research, bullets, or a thesis…',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF44445A),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: _lumaraFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _lumaraBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _lumaraBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF5B5BD6)),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const Gap(16),
                LumaraWritingFormatCard(
                  selectedId: _writingFormatTierId,
                  onSelect: (id) => setState(() => _writingFormatTierId = id),
                  specsController: _writingFormatSpecsController,
                  researchPaperSpecsController: _researchPaperSpecsController,
                  includeSources: _includeWritingSources,
                  onIncludeSourcesChanged: (v) =>
                      setState(() => _includeWritingSources = v),
                  socialSelections: _formatSocialSelections,
                  onSocialSelectionsChanged: (m) =>
                      setState(() => _formatSocialSelections = m),
                ),
                const Gap(16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _lumaraCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _lumaraBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WRITING TONE',
                        style: GoogleFonts.robotoMono(
                          color: const Color(0xFF33334A),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const Gap(6),
                      Text(
                        'Overall voice for this draft.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF5A5A7A),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const Gap(12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: WritingTone.values.map((t) {
                          final active = _phase5bTone == t;
                          return GestureDetector(
                            onTap: () => setState(() => _phase5bTone = t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: active
                                    ? const Color(0xFF5B5BD6)
                                        .withValues(alpha: 0.15)
                                    : const Color(0xFF0F0F1E),
                                border: Border.all(
                                  color: active
                                      ? const Color(0xFF5B5BD6)
                                      : const Color(0xFF1A1A2C),
                                ),
                              ),
                              child: Text(
                                _toneChipLabel(t),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: active
                                      ? const Color(0xFF8888FF)
                                      : const Color(0xFF55556A),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const Gap(12),
                GestureDetector(
                  onTap: _showStyleProfileSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _lumaraCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _lumaraBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _styleProfileOn
                              ? Icons.record_voice_over
                              : Icons.voice_over_off,
                          size: 18,
                          color: const Color(0xFF8888FF),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _styleProfileOn ? 'Your voice: On' : 'Your voice: Off',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kcPrimaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(24),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF5B5BD6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onPressed:
                        _loading ? null : () async => _runPhase5bPipeline(),
                    child: _loading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Generate',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                if (_error != null) ...[
                  const Gap(16),
                  Text(
                    _error!,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFF6B6B),
                      fontSize: 13,
                    ),
                  ),
                ],
                const Gap(24),
                Divider(color: _lumaraBorder, height: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Draft',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
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
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
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
      ),
    );
  }
}
