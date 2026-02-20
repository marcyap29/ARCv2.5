// lib/chronicle/dual/intelligence/agentic_loop_orchestrator.dart
//
// Executes the 7-step agentic loop. User context from CHRONICLE (Layer 0 + promoted);
// all learnings stored in LUMARA CHRONICLE. User's CHRONICLE is never modified.

import '../models/chronicle_models.dart';
import '../repositories/lumara_chronicle_repository.dart';
import '../repositories/intelligence_summary_repository.dart';
import '../services/lumara_connection_fade_preferences.dart';
import '../services/chronicle_query_adapter.dart';
import '../services/lumara_comments_loader.dart';
import 'gap/gap_analyzer.dart';
import 'gap/gap_classifier.dart';
import 'interrupt/interrupt_decision_engine.dart';
import 'interrupt/clarification_processor.dart';

class AgenticLoopContext {
  final String userQuery;
  final AgenticContext context;

  const AgenticLoopContext({
    required this.userQuery,
    required this.context,
  });
}

class LoopResult {
  final String type; // 'response' | 'interrupt'
  final String? content;
  final String? question;
  final String? gapId;
  final AgenticContext? context;
  final bool? promotionOffered;
  final int? durationMs;

  const LoopResult({
    required this.type,
    this.content,
    this.question,
    this.gapId,
    this.context,
    this.promotionOffered,
    this.durationMs,
  });
}

class AgenticLoopOrchestrator {
  AgenticLoopOrchestrator({
    ChronicleQueryAdapter? chronicleAdapter,
    LumaraChronicleRepository? lumaraRepo,
    GapAnalyzer? gapAnalyzer,
    GapClassifier? gapClassifier,
    InterruptDecisionEngine? interruptEngine,
    ClarificationProcessor? clarificationProcessor,
    IntelligenceSummaryRepository? intelligenceSummaryRepo,
    LumaraCommentsLoader? lumaraCommentsLoader,
  })  : _chronicleAdapter = chronicleAdapter ?? ChronicleQueryAdapter(),
        _lumaraRepo = lumaraRepo ?? LumaraChronicleRepository(),
        _gapAnalyzer = gapAnalyzer ?? GapAnalyzer(),
        _gapClassifier = gapClassifier ?? GapClassifier(),
        _interruptEngine = interruptEngine ?? InterruptDecisionEngine(),
        _clarificationProcessor = clarificationProcessor ?? ClarificationProcessor(),
        _intelligenceSummaryRepo = intelligenceSummaryRepo,
        _lumaraCommentsLoader = lumaraCommentsLoader;

  final ChronicleQueryAdapter _chronicleAdapter;
  final LumaraChronicleRepository _lumaraRepo;
  final GapAnalyzer _gapAnalyzer;
  final GapClassifier _gapClassifier;
  final InterruptDecisionEngine _interruptEngine;
  final ClarificationProcessor _clarificationProcessor;
  final IntelligenceSummaryRepository? _intelligenceSummaryRepo;
  final LumaraCommentsLoader? _lumaraCommentsLoader;

  Future<LoopResult> execute(
    String userId,
    String query,
    AgenticContext context, {
    String? lumaraCommentsContext,
  }) async {
    final start = DateTime.now();
    print('LUMARA learning: Agentic loop started (query length=${query.length}).');
    String? lumaraContext = lumaraCommentsContext;
    if (lumaraContext == null && _lumaraCommentsLoader != null) {
      lumaraContext = await _lumaraCommentsLoader!.load(userId);
    }

    final layer0 = await _chronicleAdapter.queryLayer0(userId, query);
    final fadeDays = await LumaraConnectionFadePreferences.getFadeDays();
    final fadeCutoff = DateTime.now().subtract(Duration(days: fadeDays));
    final inferred = await _lumaraRepo.queryInferences(userId, query, activeAfter: fadeCutoff);
    final gapFills = await _lumaraRepo.loadGapFillEvents(userId, activeAfter: fadeCutoff);

    print('LUMARA learning: Layer0 entries=${layer0.entries.length}, causal chains=${inferred.causalChains.length}, gap fills=${gapFills.length}.');

    final gapAnalysis = await _gapAnalyzer.analyze(query, layer0, inferred);
    final classified = await _gapClassifier.classify(
      gapAnalysis.identifiedGaps,
      userId,
    );

    print('LUMARA learning: Gaps identified=${gapAnalysis.gapCount}, clarification=${classified.clarificationGaps.length}, interrupt offered=${classified.clarificationGaps.isNotEmpty}.');

    if (classified.clarificationGaps.isNotEmpty) {
      final decision = await _interruptEngine.shouldInterrupt(context, classified);
      if (decision.shouldInterrupt && decision.question != null && decision.gapId != null) {
        print('LUMARA learning: Interrupt with clarifying question (gapId=${decision.gapId}).');
        return LoopResult(
          type: 'interrupt',
          question: decision.question,
          gapId: decision.gapId,
          context: context,
          durationMs: DateTime.now().difference(start).inMilliseconds,
        );
      }
    }

    // Update LUMARA CHRONICLE only (e.g. mark searchable gaps filled if we had deeper search)
    for (final gap in classified.searchableGaps) {
      if (gap.status == 'open') {
        await _lumaraRepo.updateGap(userId, gap.id, gap.copyWith(status: 'filled'));
      }
    }

    // Layer 3: Mark Intelligence Summary stale so it regenerates (e.g. nightly)
    _intelligenceSummaryRepo?.markStale(userId).catchError((e) {
      // Non-fatal
    });

    final content = _synthesizeResponse(layer0, inferred, lumaraContext, gapFills);
    final durationMs = DateTime.now().difference(start).inMilliseconds;
    print('LUMARA learning: Agentic loop finished (response, ${durationMs}ms). No Groq used for inference.');
    return LoopResult(
      type: 'response',
      content: content,
      context: context,
      durationMs: durationMs,
    );
  }

  Future<LoopResult> continueAfterInterrupt(
    String userId,
    AgenticLoopContext originalContext,
    String clarifyingQuestion,
    String userResponse,
    String gapId,
  ) async {
    final result = await _clarificationProcessor.processClarification(
      userId,
      originalContext.userQuery,
      clarifyingQuestion,
      userResponse,
      gapId,
    );

    // Layer 3: Mark Intelligence Summary stale after learning from clarification
    _intelligenceSummaryRepo?.markStale(userId).catchError((e) {
      // Non-fatal
    });

    final layer0 = await _chronicleAdapter.queryLayer0(userId, originalContext.userQuery);
    final fadeDays = await LumaraConnectionFadePreferences.getFadeDays();
    final fadeCutoff = DateTime.now().subtract(Duration(days: fadeDays));
    final inferred = await _lumaraRepo.queryInferences(userId, originalContext.userQuery, activeAfter: fadeCutoff);
    final gapFills = await _lumaraRepo.loadGapFillEvents(userId, activeAfter: fadeCutoff);
    final content = _synthesizeResponse(layer0, inferred, null, gapFills);

    return LoopResult(
      type: 'response',
      content: content,
      promotionOffered: result.offeredForPromotion,
      context: originalContext.context,
    );
  }

  String _synthesizeResponse(
    UserChronicleLayer0Result layer0,
    LumaraInferredResult inferred, [
    String? lumaraCommentsContext,
    List<GapFillEvent> gapFills = const [],
  ]) {
    final parts = <String>[];
    if (lumaraCommentsContext != null && lumaraCommentsContext.trim().isNotEmpty) {
      parts.add('Prior LUMARA context available for inference.');
    }
    if (layer0.entries.isNotEmpty) {
      parts.add('From your timeline: ${layer0.entries.length} relevant entries.');
    }
    if (layer0.annotations.isNotEmpty) {
      parts.add('${layer0.annotations.length} approved insights.');
    }
    if (inferred.causalChains.isNotEmpty) {
      parts.add('Causal links I have: ${inferred.causalChains.take(8).map((c) => '"${c.trigger}" → "${c.response}"').join('; ')}.');
    }
    if (inferred.patterns.isNotEmpty) {
      parts.add('Patterns: ${inferred.patterns.take(5).map((p) => p.description).join('; ')}.');
    }
    if (gapFills.isNotEmpty) {
      final moments = gapFills.take(5).map((g) {
        final s = g.extractedSignal;
        if (s.causalChain != null) return '${s.causalChain!.trigger} → ${s.causalChain!.response}';
        if (s.pattern != null) return s.pattern!.description;
        if (s.relationship != null) return '${s.relationship!.entity} (${s.relationship!.role})';
        return g.trigger.originalQuery.replaceAll('\n', ' ').length > 60
            ? '${g.trigger.originalQuery.replaceAll('\n', ' ').substring(0, 60)}...'
            : g.trigger.originalQuery.replaceAll('\n', ' ');
      }).join('; ');
      parts.add('Learning moments: $moments');
    }
    return parts.isEmpty
        ? 'I don\'t have much context yet. Tell me more when you\'re ready.'
        : parts.join(' ');
  }
}
