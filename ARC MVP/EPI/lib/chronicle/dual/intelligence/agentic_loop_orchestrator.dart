// lib/chronicle/dual/intelligence/agentic_loop_orchestrator.dart
//
// Executes the 7-step agentic loop while maintaining sacred separation.
// User Chronicle is never modified automatically.

import '../repositories/user_chronicle_repository.dart';
import '../repositories/lumara_chronicle_repository.dart';
import '../repositories/intelligence_summary_repository.dart';
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
    UserChronicleRepository? userRepo,
    LumaraChronicleRepository? lumaraRepo,
    GapAnalyzer? gapAnalyzer,
    GapClassifier? gapClassifier,
    InterruptDecisionEngine? interruptEngine,
    ClarificationProcessor? clarificationProcessor,
    IntelligenceSummaryRepository? intelligenceSummaryRepo,
  })  : _userRepo = userRepo ?? UserChronicleRepository(),
        _lumaraRepo = lumaraRepo ?? LumaraChronicleRepository(),
        _gapAnalyzer = gapAnalyzer ?? GapAnalyzer(),
        _gapClassifier = gapClassifier ?? GapClassifier(),
        _interruptEngine = interruptEngine ?? InterruptDecisionEngine(),
        _clarificationProcessor = clarificationProcessor ?? ClarificationProcessor(),
        _intelligenceSummaryRepo = intelligenceSummaryRepo;

  final UserChronicleRepository _userRepo;
  final LumaraChronicleRepository _lumaraRepo;
  final GapAnalyzer _gapAnalyzer;
  final GapClassifier _gapClassifier;
  final InterruptDecisionEngine _interruptEngine;
  final ClarificationProcessor _clarificationProcessor;
  final IntelligenceSummaryRepository? _intelligenceSummaryRepo;

  Future<LoopResult> execute(
    String userId,
    String query,
    AgenticContext context,
  ) async {
    final start = DateTime.now();

    final layer0 = await _userRepo.queryLayer0(userId, query);
    final inferred = await _lumaraRepo.queryInferences(userId, query);

    final gapAnalysis = await _gapAnalyzer.analyze(query, layer0, inferred);
    final classified = await _gapClassifier.classify(
      gapAnalysis.identifiedGaps,
      userId,
    );

    if (classified.clarificationGaps.isNotEmpty) {
      final decision = await _interruptEngine.shouldInterrupt(context, classified);
      if (decision.shouldInterrupt && decision.question != null && decision.gapId != null) {
        return LoopResult(
          type: 'interrupt',
          question: decision.question,
          gapId: decision.gapId,
          context: context,
          durationMs: DateTime.now().difference(start).inMilliseconds,
        );
      }
    }

    // Update LUMARA Chronicle only (e.g. mark searchable gaps filled if we had deeper search)
    for (final gap in classified.searchableGaps) {
      if (gap.status == 'open') {
        await _lumaraRepo.updateGap(userId, gap.id, gap.copyWith(status: 'filled'));
      }
    }

    // Layer 3: Mark Intelligence Summary stale so it regenerates (e.g. nightly)
    _intelligenceSummaryRepo?.markStale(userId).catchError((e) {
      // Non-fatal
    });

    final content = _synthesizeResponse(layer0, inferred);
    return LoopResult(
      type: 'response',
      content: content,
      context: context,
      durationMs: DateTime.now().difference(start).inMilliseconds,
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

    final layer0 = await _userRepo.queryLayer0(userId, originalContext.userQuery);
    final inferred = await _lumaraRepo.queryInferences(userId, originalContext.userQuery);
    final content = _synthesizeResponse(layer0, inferred);

    return LoopResult(
      type: 'response',
      content: content,
      promotionOffered: result.offeredForPromotion,
      context: originalContext.context,
    );
  }

  String _synthesizeResponse(
    UserChronicleLayer0Result layer0,
    LumaraInferredResult inferred,
  ) {
    // In production, combine with LLM/synthesis; here return a simple summary.
    final parts = <String>[];
    if (layer0.entries.isNotEmpty) {
      parts.add('From your timeline: ${layer0.entries.length} relevant entries.');
    }
    if (layer0.annotations.isNotEmpty) {
      parts.add('${layer0.annotations.length} approved insights.');
    }
    if (inferred.causalChains.isNotEmpty) {
      parts.add('Patterns I have: ${inferred.causalChains.length} causal links.');
    }
    return parts.isEmpty
        ? 'I don\'t have much context yet. Tell me more when you\'re ready.'
        : parts.join(' ');
  }
}
