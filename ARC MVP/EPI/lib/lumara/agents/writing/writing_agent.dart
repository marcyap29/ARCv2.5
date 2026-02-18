import 'package:my_app/arc/agents/drafts/agent_draft.dart';
import 'package:my_app/arc/agents/drafts/draft_repository.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/lumara/agents/services/timeline_context_service.dart';
import 'package:my_app/lumara/agents/writing/writing_models.dart';
import 'package:my_app/lumara/agents/writing/voice_analyzer.dart';
import 'package:my_app/lumara/agents/writing/theme_tracker.dart';
import 'package:my_app/lumara/agents/writing/tone_calibrator.dart';
import 'package:my_app/lumara/agents/writing/draft_composer.dart';
import 'package:my_app/lumara/agents/writing/self_critic.dart';

/// Orchestrates the Writing Agent pipeline: timeline context → voice → themes → tone → compose (→ critique loop when enabled).
class WritingAgent {
  final VoiceAnalyzer _voiceAnalyzer;
  final ThemeTracker _themeTracker;
  final ToneCalibrator _toneCalibrator;
  final DraftComposer _draftComposer;
  final SelfCritic _selfCritic;
  final WritingDraftRepository? _draftRepository;
  final TimelineContextService _timelineContextService;
  final Future<String> Function()? _getAgentOsPrefix;

  WritingAgent({
    VoiceAnalyzer? voiceAnalyzer,
    ThemeTracker? themeTracker,
    ToneCalibrator? toneCalibrator,
    DraftComposer? draftComposer,
    SelfCritic? selfCritic,
    WritingDraftRepository? draftRepository,
    TimelineContextService? timelineContextService,
    Future<String> Function()? getAgentOsPrefix,
    required WritingLlmGenerate generateContent,
  })  : _voiceAnalyzer = voiceAnalyzer ?? VoiceAnalyzer(),
        _themeTracker = themeTracker ?? ThemeTracker(),
        _toneCalibrator = toneCalibrator ?? ToneCalibrator(),
        _draftComposer = draftComposer ?? DraftComposer(generate: generateContent),
        _selfCritic = selfCritic ?? SelfCritic(),
        _draftRepository = draftRepository,
        _timelineContextService = timelineContextService ?? TimelineContextService(),
        _getAgentOsPrefix = getAgentOsPrefix;

  /// Compose content for the user. Optionally pass [phaseOverride] and [readinessOverride]
  /// when the caller has already resolved ATLAS state (e.g. from LUMARA control state).
  /// When not provided, phase is resolved via [UserPhaseService.getCurrentPhase] and readiness defaults to 50.
  ///
  /// [maxCritiqueIterations] 0 = no self-critique; 1–2 = up to that many re-drafts after critique.
  /// [onProgress] optional; when provided (e.g. from chat), called with status for each step.
  Future<ComposedContent> composeContent({
    required String userId,
    required String prompt,
    required ContentType type,
    String? customContentTypeDescription,
    String? phaseOverride,
    double? readinessOverride,
    int maxCritiqueIterations = 0,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Resolving phase and tone...');
    final phaseStr = phaseOverride ?? await UserPhaseService.getCurrentPhase();
    final phaseLabel = _phaseStringToLabel(phaseStr);
    final readiness = readinessOverride ?? 50.0;

    onProgress?.call('Analyzing your voice from CHRONICLE...');
    final voice = await _voiceAnalyzer.analyzeVoice(userId: userId, sampleSize: 20);
    onProgress?.call('Loading theme context...');
    final themes = await _themeTracker.getThemeContext(userId: userId, contentTopic: prompt);
    final tone = _toneCalibrator.calibrateTone(
      currentPhase: phaseLabel,
      readinessScore: readiness,
      contentType: type,
    );
    onProgress?.call('Loading timeline context...');
    final timelineContext = await _timelineContextService.getWritingContext(
      userId: userId,
      contentTopic: prompt,
    );
    final systemPromptPrefix = _getAgentOsPrefix != null ? await _getAgentOsPrefix!() : null;

    String? draftsSnippet;
    try {
      final ctx = await DraftRepository.instance.getDraftsAndArchivedForContext(
        draftLimit: 5,
        archiveLimit: 5,
      );
      draftsSnippet = _formatDraftsAndArchiveForPrompt(ctx.drafts, ctx.archived);
    } catch (_) {
      draftsSnippet = null;
    }

    onProgress?.call('Composing draft...');
    var draft = await _draftComposer.composeDraft(
      prompt: prompt,
      voice: voice,
      themes: themes,
      tone: tone,
      type: type,
      timelineContext: timelineContext,
      systemPromptPrefix: systemPromptPrefix,
      draftsAndArchiveSnippet: draftsSnippet,
      customContentTypeDescription: customContentTypeDescription,
    );

    double? voiceScore;
    double? themeAlignment;
    final suggestedEdits = <String>[];
    int iterations = 0;

    while (maxCritiqueIterations > 0 && iterations < maxCritiqueIterations) {
      final critique = await _selfCritic.critiqueDraft(
        draft: draft,
        expectedVoice: voice,
        expectedThemes: themes,
      );
      voiceScore = critique.voiceScore;
      themeAlignment = critique.themeScore;
      if (critique.passesThreshold) break;
      suggestedEdits.addAll(critique.suggestions);
      final improvedPrompt = '$prompt\n\nIMPROVEMENTS NEEDED:\n${critique.suggestions.join('\n')}';
      draft = await _draftComposer.composeDraft(
        prompt: improvedPrompt,
        voice: voice,
        themes: themes,
        tone: tone,
        type: type,
        timelineContext: timelineContext,
        systemPromptPrefix: systemPromptPrefix,
        draftsAndArchiveSnippet: draftsSnippet,
        customContentTypeDescription: customContentTypeDescription,
      );
      iterations++;
    }

    if (voiceScore == null && maxCritiqueIterations > 0) {
      final critique = await _selfCritic.critiqueDraft(
        draft: draft,
        expectedVoice: voice,
        expectedThemes: themes,
      );
      voiceScore = critique.voiceScore;
      themeAlignment = critique.themeScore;
      if (suggestedEdits.isEmpty) suggestedEdits.addAll(critique.suggestions);
    }

    final composed = ComposedContent(
      draft: draft.copyWith(voiceScore: voiceScore, themeAlignment: themeAlignment),
      voiceScore: voiceScore,
      themeAlignment: themeAlignment,
      suggestedEdits: suggestedEdits,
    );

    if (_draftRepository != null) {
      await _draftRepository!.storeDraft(
        userId: userId,
        draft: draft.copyWith(voiceScore: voiceScore, themeAlignment: themeAlignment),
        metadata: draft.metadata,
      );
    }

    return composed;
  }

  static const int _draftPreviewChars = 500;

  static String? _formatDraftsAndArchiveForPrompt(
    List<AgentDraft> drafts,
    List<AgentDraft> archived,
  ) {
    final parts = <String>[];
    if (drafts.isNotEmpty) {
      parts.add('Drafts (for reference):');
      for (final d in drafts) {
        final preview = d.content.length > _draftPreviewChars
            ? '${d.content.substring(0, _draftPreviewChars)}...'
            : d.content;
        parts.add('[${d.title}]\n$preview');
      }
    }
    if (archived.isNotEmpty) {
      parts.add('Archive (for reference):');
      for (final d in archived) {
        final preview = d.content.length > _draftPreviewChars
            ? '${d.content.substring(0, _draftPreviewChars)}...'
            : d.content;
        parts.add('[${d.title}]\n$preview');
      }
    }
    if (parts.isEmpty) return null;
    return parts.join('\n\n');
  }

  PhaseLabel _phaseStringToLabel(String phaseStr) {
    final normalized = phaseStr.trim().toLowerCase();
    if (normalized.isEmpty) return PhaseLabel.discovery;
    switch (normalized) {
      case 'discovery':
        return PhaseLabel.discovery;
      case 'expansion':
        return PhaseLabel.expansion;
      case 'transition':
        return PhaseLabel.transition;
      case 'consolidation':
        return PhaseLabel.consolidation;
      case 'recovery':
        return PhaseLabel.recovery;
      case 'breakthrough':
        return PhaseLabel.breakthrough;
      default:
        return PhaseLabel.discovery;
    }
  }
}
