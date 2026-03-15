// lib/lumara/agents/research/research_agent.dart
// Main orchestrator for LUMARA Research Agent: plan → cross-reference → search → synthesize → save.

import 'package:my_app/models/phase_models.dart';
import 'package:my_app/services/user_phase_service.dart';

import 'query_planner.dart';
import 'research_models.dart';
import 'research_session_manager.dart';
import 'search_orchestrator.dart';
import 'synthesis_engine.dart';
import 'web_search_tool.dart';

/// Research depth: drives synthesis depth and optional query scope.
enum ResearchDepth {
  quick_scan,
  standard,
  deep_dive,
}

typedef LlmGenerate = Future<String> Function({
  required String systemPrompt,
  required String userPrompt,
  int? maxTokens,
});

/// Progress update for chat UI during research.
class ResearchProgress {
  final String status;
  final int currentStep;
  final int totalSteps;
  final double percentComplete;

  ResearchProgress({
    required this.status,
    required this.currentStep,
    required this.totalSteps,
  }) : percentComplete = totalSteps > 0 ? currentStep / totalSteps : 0.0;
}

/// Result of research with session id for navigation.
class ResearchResult {
  final ResearchReport report;
  final String sessionId;

  const ResearchResult({required this.report, required this.sessionId});
}

/// Orchestrates multi-step research: query planning, search, synthesis.
/// Research is subject-only; no CHRONICLE (timeline/themes) or user data is used.
class ResearchAgent {
  final QueryPlanner _queryPlanner;
  final SearchOrchestrator _searchOrchestrator;
  final SynthesisEngine _synthesisEngine;
  final ResearchSessionManager _sessionManager;
  final Future<String> Function()? _getAgentOsPrefix;

  ResearchAgent({
    required LlmGenerate generate,
    required WebSearchTool searchTool,
    ResearchSessionManager? sessionManager,
    Future<String> Function()? getAgentOsPrefix,
  })  : _queryPlanner = QueryPlanner(generate: generate),
        _searchOrchestrator = SearchOrchestrator(searchTool: searchTool),
        _synthesisEngine = SynthesisEngine(generate: generate),
        _sessionManager = sessionManager ?? ResearchSessionManager(),
        _getAgentOsPrefix = getAgentOsPrefix;

  static const int _totalSteps = 5;

  /// Run full research pipeline and return report with session id.
  /// [onProgress] is optional; when provided, called at each step for chat UI.
  /// [researchDepth] optional: quick_scan, standard, deep_dive (default derived from phase/readiness).
  Future<ResearchResult> conductResearch({
    required String userId,
    required String query,
    bool allowFollowUps = true,
    PhaseLabel? phaseOverride,
    double? readinessOverride,
    ResearchDepth? researchDepth,
    void Function(ResearchProgress)? onProgress,
    /// Optional context from a scanned document (e.g. Research screen).
    String? documentContext,
  }) async {
    final phase = phaseOverride ?? _phaseFromString(await UserPhaseService.getCurrentPhase());
    final readiness = readinessOverride ?? 50.0;

    onProgress?.call(ResearchProgress(
      status: 'Planning research queries...',
      currentStep: 1,
      totalSteps: _totalSteps,
    ));

    final session = await _sessionManager.createSession(
      userId: userId,
      initialQuery: query,
      phase: phase,
      readinessScore: readiness,
    );

    // Research is subject-only: no CHRONICLE (timeline/themes) or prior user data.
    final priorContext = PriorResearchContext(
      hasRelatedResearch: false,
      priorSessions: const [],
      relatedEntries: const [],
      existingKnowledge: const ExistingKnowledge(summary: ''),
      knowledgeGaps: [query],
    );

    final plan = await _queryPlanner.planResearch(
      userQuery: query,
      currentPhase: phase,
    );

    // Brief depth: fewer sub-queries to reduce API usage and keep synthesis short.
    final effectivePlan = researchDepth == ResearchDepth.quick_scan && plan.subQueries.length > 3
        ? ResearchPlan(
            originalQuery: plan.originalQuery,
            subQueries: plan.subQueries.take(3).toList(),
            executionStrategy: plan.executionStrategy,
            estimatedDuration: plan.estimatedDuration,
          )
        : plan;

    onProgress?.call(ResearchProgress(
      status: 'Executing ${effectivePlan.subQueries.length} searches...',
      currentStep: 2,
      totalSteps: _totalSteps,
    ));

    final searchResults = await _searchOrchestrator.executeSearches(
      queries: effectivePlan.subQueries,
      strategy: plan.executionStrategy,
      priorContext: priorContext,
      onProgress: (status) => onProgress?.call(ResearchProgress(
        status: status,
        currentStep: 2,
        totalSteps: _totalSteps,
      )),
    );

    session.searchResults.addAll(searchResults);

    onProgress?.call(ResearchProgress(
      status: 'Preparing synthesis...',
      currentStep: 3,
      totalSteps: _totalSteps,
    ));

    onProgress?.call(ResearchProgress(
      status: 'Synthesizing findings...',
      currentStep: 3,
      totalSteps: _totalSteps,
    ));

    // No CHRONICLE/timeline: research is subject-only for the user to learn about the topic.
    final depthLabel = researchDepth != null ? _researchDepthToLabel(researchDepth) : null;
    final systemPromptPrefix = _getAgentOsPrefix != null ? await _getAgentOsPrefix!() : null;

    final report = await _synthesisEngine.synthesizeFindings(
      originalQuery: query,
      searchResults: searchResults,
      priorContext: priorContext,
      currentPhase: phase,
      readinessScore: readiness,
      timelineContext: null,
      researchDepthLabel: depthLabel,
      systemPromptPrefix: systemPromptPrefix,
      documentContext: documentContext,
    );

    onProgress?.call(ResearchProgress(
      status: 'Saving research session...',
      currentStep: 4,
      totalSteps: _totalSteps,
    ));

    _sessionManager.updateSessionWithReport(session, report);
    await _sessionManager.saveSession(session: session, finalReport: report);

    onProgress?.call(ResearchProgress(
      status: 'Complete!',
      currentStep: _totalSteps,
      totalSteps: _totalSteps,
    ));

    return ResearchResult(report: report, sessionId: session.id);
  }

  /// Refine with a follow-up question in the same session.
  Future<ResearchReport?> refineResearch({
    required String sessionId,
    required String followUpQuery,
  }) async {
    final session = _sessionManager.getSession(sessionId);
    if (session == null || session.synthesisHistory.isEmpty) return null;

    await _sessionManager.addFollowUp(sessionId: sessionId, followUpQuery: followUpQuery);

    final priorReport = session.synthesisHistory.last;
    final priorContext = PriorResearchContext(
      hasRelatedResearch: true,
      priorSessions: [],
      existingKnowledge: ExistingKnowledge(summary: priorReport.summary),
      knowledgeGaps: [followUpQuery],
    );

    final plan = await _queryPlanner.planResearch(
      userQuery: followUpQuery,
      currentPhase: session.phase,
    );

    final additionalResults = await _searchOrchestrator.executeSearches(
      queries: plan.subQueries,
      strategy: plan.executionStrategy,
      priorContext: priorContext,
    );

    session.searchResults.addAll(additionalResults);

    final allResults = List<SearchResult>.from(session.searchResults);
    final systemPromptPrefix = _getAgentOsPrefix != null ? await _getAgentOsPrefix!() : null;

    final refinedReport = await _synthesisEngine.synthesizeFindings(
      originalQuery: '${session.queries.first} → $followUpQuery',
      searchResults: allResults,
      priorContext: priorContext,
      currentPhase: session.phase,
      readinessScore: session.readinessScore,
      timelineContext: null,
      systemPromptPrefix: systemPromptPrefix,
    );

    _sessionManager.updateSessionWithReport(session, refinedReport);
    return refinedReport;
  }

  PhaseLabel _phaseFromString(String name) {
    final lower = name.trim().toLowerCase();
    for (final p in PhaseLabel.values) {
      if (p.name == lower) return p;
    }
    return PhaseLabel.discovery;
  }

  String _researchDepthToLabel(ResearchDepth depth) {
    switch (depth) {
      case ResearchDepth.quick_scan:
        return 'quick_scan';
      case ResearchDepth.standard:
        return 'standard';
      case ResearchDepth.deep_dive:
        return 'deep_dive';
    }
  }
}
