import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:my_app/arc/chat/services/lumara_cloud_generate.dart';
import 'package:my_app/arc/chat/services/lumara_reflection_settings_service.dart';
import 'package:my_app/lumara/agents/services/agents_chronicle_service.dart';
import 'package:my_app/lumara/agents/writing/writing_agent.dart';
import 'package:my_app/lumara/agents/writing/writing_draft_repository.dart';
import 'package:my_app/lumara/agents/writing/writing_models.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/arc/ui/widgets/reflection_draft_text_field.dart';
import 'package:my_app/lumara/agents/models/research_models.dart';

/// Dedicated screen for the LUMARA Writing Agent.
/// User enters a prompt and content type, then sees the generated draft and optional scores.
/// [initialPrompt] pre-fills "What should we write about?" (e.g. from research report).
/// [draftId] when set opens an existing draft from Outputs for viewing and editing.
class WritingScreen extends StatefulWidget {
  const WritingScreen({super.key, this.initialPrompt, this.draftId});

  final String? initialPrompt;
  /// When non-null, load this draft for viewing/editing (e.g. from Outputs tab).
  final String? draftId;

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _customContentTypeController = TextEditingController();
  final TextEditingController _draftBodyController = TextEditingController();
  ContentType _contentType = ContentType.linkedIn;
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
    _customContentTypeController.dispose();
    _draftBodyController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _error = 'Enter a prompt (e.g. what to write about).';
      });
      return;
    }
    final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      setState(() {
        _loading = true;
        _error = null;
        _draft = null;
        _voiceScore = null;
        _themeAlignment = null;
        _suggestedEdits = [];
      });
    try {
      final agent = WritingAgent(
        draftRepository: WritingDraftRepositoryImpl(),
        getAgentOsPrefix: () => LumaraReflectionSettingsService.instance.getAgentOsPrefix(),
        generateContent: ({required systemPrompt, required userPrompt, maxTokens}) async {
          return generateForAgents(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            maxTokens: maxTokens ?? 800,
          );
        },
      );
      final customDesc = _contentType == ContentType.custom
          ? _customContentTypeController.text.trim()
          : null;
      final composed = await agent.composeContent(
        userId: userId,
        prompt: prompt,
        type: _contentType,
        customContentTypeDescription: customDesc?.isEmpty == true ? null : customDesc,
        maxCritiqueIterations: 2,
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _draft = composed.draft;
          _voiceScore = composed.voiceScore;
          _themeAlignment = composed.themeAlignment;
          _suggestedEdits = composed.suggestedEdits;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                labelText: 'What should we write about?',
                hintText: 'e.g. Why CHRONICLE hierarchical aggregation matters for AI memory',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const Gap(16),
            DropdownButtonFormField<ContentType>(
              // ignore: deprecated_member_use
              value: _contentType,
              decoration: const InputDecoration(
                labelText: 'Content type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: ContentType.linkedIn, child: Text('LinkedIn post')),
                DropdownMenuItem(value: ContentType.substack, child: Text('Substack article')),
                DropdownMenuItem(value: ContentType.technical, child: Text('Technical doc')),
                DropdownMenuItem(
                  value: ContentType.custom,
                  child: Text('Fill in what you specifically want'),
                ),
              ],
              onChanged: (v) => setState(() => _contentType = v ?? ContentType.linkedIn),
            ),
            if (_contentType == ContentType.custom) ...[
              const Gap(12),
              TextField(
                controller: _customContentTypeController,
                decoration: const InputDecoration(
                  labelText: 'Describe format and requirements',
                  hintText: 'e.g. 500-word blog post, Twitter thread, email newsletter',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 2,
              ),
            ],
            const Gap(24),
            FilledButton(
              onPressed: _loading ? null : _generate,
              child: _loading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Generate draft'),
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
                Text('Draft', style: Theme.of(context).textTheme.titleMedium),
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
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Your draft will appear here after you generate. Use "Generate draft" above.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              )
            else ...[
              _buildScoresRow(context),
              const Gap(8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _editingDraftId != null
                    ? ReflectionDraftTextField(
                        controller: _draftBodyController,
                        hintText: 'Edit your draft...',
                        minLines: 8,
                      )
                    : SelectableText(_draft!.content),
              ),
              const Gap(12),
              Text(
                'Saved to My Drafts. Open Agents → Writing to see all drafts.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
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
    );
  }
}
