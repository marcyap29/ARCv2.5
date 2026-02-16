// lib/lumara/agents/research/research_agent.dart
// Main orchestrator for LUMARA Research Agent: plan → cross-reference → search → synthesize → save.

import 'package:my_app/models/phase_models.dart';
import 'package:my_app/services/user_phase_service.dart';

import 'chronicle_cross_reference.dart';
import 'query_planner.dart';
import 'research_models.dart';
import 'research_session_manager.dart';
import 'search_orchestrator.dart';
import 'synthesis_engine.dart';
import 'web_search_tool.dart';

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

/// Orchestrates multi-step research: CHRONICLE cross-reference, query planning, search, synthesis.
class ResearchAgent {
  final QueryPlanner _queryPlanner;
  final ChronicleCrossReference _chronicleCrossRef;
  final SearchOrchestrator _searchOrchestrator;
  final SynthesisEngine _synthesisEngine;
  final ResearchSessionManager _sessionManager;

  ResearchAgent({
    required LlmGenerate generate,
    required WebSearchTool searchTool,
    ChronicleCrossReference? chronicleCrossRef,
    ResearchSessionManager? sessionManager,
  })  : _queryPlanner = QueryPlanner(generate: generate),
        _chronicleCrossRef = chronicleCrossRef ?? ChronicleCrossReference(),
        _searchOrchestrator = SearchOrchestrator(searchTool: searchTool),
        _synthesisEngine = SynthesisEngine(generate: generate),
        _sessionManager = sessionManager ?? ResearchSessionManager();

  static const int _totalSteps = 6;

  /// Run full research pipeline and return report with session id.
  /// [onProgress] is optional; when provided, called at each step for chat UI.
  Future<ResearchResult> conductResearch({
    required String userId,
    required String query,
    bool allowFollowUps = true,
    PhaseLabel? phaseOverride,
    double? readinessOverride,
    void Function(ResearchProgress)? onProgress,
  }) async {
    final phase = phaseOverride ?? _phaseFromString(await UserPhaseService.getCurrentPhase());
    final readiness = readinessOverride ?? 50.0;

    onProgress?.call(ResearchProgress(
      status: 'Checking prior research in CHRONICLE...',
      currentStep: 1,
      totalSteps: _totalSteps,
    ));

    final session = await _sessionManager.createSession(
      userId: userId,
      initialQuery: query,
      phase: phase,
      readinessScore: readiness,
    );

    final priorContext = await _chronicleCrossRef.checkPriorResearch(
      userId: userId,
      query: query,
    );

    onProgress?.call(ResearchProgress(
      status: 'Planning research queries...',
      currentStep: 2,
      totalSteps: _totalSteps,
    ));

    final plan = await _queryPlanner.planResearch(
      userQuery: query,
      currentPhase: phase,
    );

    onProgress?.call(ResearchProgress(
      status: 'Executing ${plan.subQueries.length} searches...',
      currentStep: 3,
      totalSteps: _totalSteps,
    ));

    final searchResults = await _searchOrchestrator.executeSearches(
      queries: plan.subQueries,
      strategy: plan.executionStrategy,
      priorContext: priorContext,
    );

    session.searchResults.addAll(searchResults);

    onProgress?.call(ResearchProgress(
      status: 'Synthesizing findings...',
      currentStep: 4,
      totalSteps: _totalSteps,
    ));

    final report = await _synthesisEngine.synthesizeFindings(
      originalQuery: query,
      searchResults: searchResults,
      priorContext: priorContext,
      currentPhase: phase,
      readinessScore: readiness,
    );

    onProgress?.call(ResearchProgress(
      status: 'Saving research session...',
      currentStep: 5,
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

    final refinedReport = await _synthesisEngine.synthesizeFindings(
      originalQuery: '${session.queries.first} → $followUpQuery',
      searchResults: allResults,
      priorContext: priorContext,
      currentPhase: session.phase,
      readinessScore: session.readinessScore,
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
}
