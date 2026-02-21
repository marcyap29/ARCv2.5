// lib/arc/chat/prompt_optimization/universal_prompt_optimizer.dart
//
// Universal Prompt Optimizer - provider-agnostic prompt optimization.
// 1. Smart context selection  2. Structured outputs  3. Progressive enhancement

import 'package:flutter/foundation.dart';
import 'package:my_app/chronicle/dual/models/chronicle_models.dart';
import 'package:my_app/chronicle/dual/repositories/lumara_chronicle_repository.dart';
import 'package:my_app/chronicle/dual/services/lumara_connection_fade_preferences.dart';
import 'prompt_optimization_types.dart';
import 'readiness_calculator.dart';

/// Selected context passed to formatting (patterns, relationships, causal chains, learning moments + state).
class SelectedContext {
  final List<Pattern> patterns;
  final List<RelationshipModel> relationships;
  final List<CausalChain> causalChains;
  final List<GapFillEvent> gapFillEvents;
  final CurrentState? state;

  const SelectedContext({
    this.patterns = const [],
    this.relationships = const [],
    this.causalChains = const [],
    this.gapFillEvents = const [],
    this.state,
  });
}

/// Formatted context (structured or prose).
class FormattedContext {
  final bool isStructured;
  final Map<String, dynamic> content;

  const FormattedContext({required this.isStructured, required this.content});
}

class UniversalPromptOptimizer {
  UniversalPromptOptimizer({
    required LumaraChronicleRepository lumaraChronicleRepo,
    required ReadinessCalculator readinessCalculator,
  })  : _lumaraRepo = lumaraChronicleRepo,
        _readinessCalculator = readinessCalculator;

  final LumaraChronicleRepository _lumaraRepo;
  final ReadinessCalculator _readinessCalculator;

  OptimizationStrategy _getStrategy(PromptUseCase useCase) {
    switch (useCase) {
      case PromptUseCase.userChat:
        return const OptimizationStrategy(
          contextNeeded: ContextRequirements(patterns: 5, relationships: 3, causalChains: 8, gapFillEvents: 10, recentEntries: 0, state: true),
          outputFormat: OutputFormat.prose,
          maxTokens: 500,
          cacheable: true,
          priority: OptimizationPriority.balanced,
        );
      case PromptUseCase.userReflect:
        return const OptimizationStrategy(
          contextNeeded: ContextRequirements(patterns: 3, relationships: 2, causalChains: 6, gapFillEvents: 8, recentEntries: 0, state: true),
          outputFormat: OutputFormat.prose,
          maxTokens: 200,
          cacheable: true,
          priority: OptimizationPriority.balanced,
        );
      case PromptUseCase.userVoice:
        return const OptimizationStrategy(
          contextNeeded: ContextRequirements(patterns: 2, relationships: 1, causalChains: 5, gapFillEvents: 5, recentEntries: 0, state: true),
          outputFormat: OutputFormat.prose,
          maxTokens: 150,
          cacheable: true,
          priority: OptimizationPriority.balanced,
        );
      case PromptUseCase.gapClassification:
        return const OptimizationStrategy(
          contextNeeded: ContextRequirements(patterns: 0, relationships: 0, recentEntries: 0, state: false),
          outputFormat: OutputFormat.json,
          maxTokens: 50,
          cacheable: false,
          priority: OptimizationPriority.speed,
        );
      case PromptUseCase.patternExtraction:
        return const OptimizationStrategy(
          contextNeeded: ContextRequirements(patterns: 0, relationships: 0, recentEntries: 0, state: false),
          outputFormat: OutputFormat.json,
          maxTokens: 200,
          cacheable: false,
          priority: OptimizationPriority.speed,
        );
      case PromptUseCase.seekingDetection:
        return const OptimizationStrategy(
          contextNeeded: ContextRequirements(patterns: 0, relationships: 0, recentEntries: 0, state: false),
          outputFormat: OutputFormat.json,
          maxTokens: 20,
          cacheable: true,
          priority: OptimizationPriority.speed,
        );
      case PromptUseCase.intelligenceSummary:
        return const OptimizationStrategy(
          contextNeeded: ContextRequirements(patterns: 20, relationships: 10, causalChains: 20, gapFillEvents: 30, recentEntries: 30, state: true),
          outputFormat: OutputFormat.prose,
          maxTokens: 16000,
          cacheable: false,
          priority: OptimizationPriority.quality,
        );
      case PromptUseCase.crisisDetection:
        return const OptimizationStrategy(
          contextNeeded: ContextRequirements(patterns: 10, relationships: 5, causalChains: 15, gapFillEvents: 15, recentEntries: 20, state: true),
          outputFormat: OutputFormat.json,
          maxTokens: 500,
          cacheable: false,
          priority: OptimizationPriority.accuracy,
        );
    }
  }

  /// Build chronicle context string for injection into the master prompt.
  /// Uses smart context selection (query-relevant patterns/relationships, use-case size)
  /// and returns prose suitable for [lumaraChronicleContext].
  /// [maxChars] caps length (default 2000 to match existing master prompt expectations).
  Future<String?> getChronicleContextForMasterPrompt(
    String userId,
    String query,
    PromptUseCase useCase, {
    int maxChars = 2000,
  }) async {
    if (userId.isEmpty) return null;
    try {
      final strategy = _getStrategy(useCase);
      final context = await _selectRelevantContext(userId, query, strategy.contextNeeded);
      final prose = _serializeContextToProse(context);
      if (prose.isEmpty) return null;
      return prose.length > maxChars ? prose.substring(0, maxChars) : prose;
    } catch (e) {
      debugPrint('[UniversalOptimizer] getChronicleContextForMasterPrompt failed: $e');
      return null;
    }
  }

  /// Build optimized prompt using universal strategies.
  Future<UniversalPrompt> buildOptimizedPrompt(
    String userId,
    String query,
    PromptUseCase useCase,
  ) async {
    debugPrint('[UniversalOptimizer] Optimizing for $useCase...');
    final stopwatch = Stopwatch()..start();

    final strategy = _getStrategy(useCase);
    final context = await _selectRelevantContext(userId, query, strategy.contextNeeded);
    final formatted = _formatForOutput(query, context, strategy.outputFormat);
    final system = _buildSystemPrompt(strategy);
    final user = strategy.outputFormat == OutputFormat.json
        ? _buildStructuredUserPrompt(formatted.content)
        : _buildProseUserPrompt(formatted.content);

    stopwatch.stop();
    final tokens = _estimateTokens(system + user);
    final contextItems = context.patterns.length + context.relationships.length;

    debugPrint('[UniversalOptimizer] Built in ${stopwatch.elapsedMilliseconds}ms: $tokens tokens');

    return UniversalPrompt(
      system: system,
      user: user,
      metadata: UniversalPromptMetadata(
        useCase: useCase,
        tokensEstimated: tokens,
        contextItemsIncluded: contextItems,
        optimizationDurationMs: stopwatch.elapsedMilliseconds,
        cacheable: strategy.cacheable,
      ),
    );
  }

  Future<SelectedContext> _selectRelevantContext(
    String userId,
    String query,
    ContextRequirements needed,
  ) async {
    final signals = _extractQuerySignals(query);

    final patterns = needed.patterns > 0
        ? await _selectRelevantPatterns(userId, signals, needed.patterns)
        : <Pattern>[];

    final relationships = needed.relationships > 0 && signals.entities.isNotEmpty
        ? await _selectRelevantRelationships(userId, signals.entities, needed.relationships)
        : <RelationshipModel>[];

    List<CausalChain> causalChains = const [];
    if (needed.causalChains > 0) {
      final fadeDays = await LumaraConnectionFadePreferences.getFadeDays();
      final fadeCutoff = DateTime.now().subtract(Duration(days: fadeDays));
      final all = await _lumaraRepo.loadCausalChains(userId, activeAfter: fadeCutoff);
      causalChains = all.where((c) => c.status == InferenceStatus.active).take(needed.causalChains).toList();
    }

    List<GapFillEvent> gapFillEvents = const [];
    if (needed.gapFillEvents > 0) {
      final fadeDays = await LumaraConnectionFadePreferences.getFadeDays();
      final fadeCutoff = DateTime.now().subtract(Duration(days: fadeDays));
      gapFillEvents = (await _lumaraRepo.loadGapFillEvents(userId, activeAfter: fadeCutoff)).take(needed.gapFillEvents).toList();
    }

    CurrentState? state;
    if (needed.state) {
      final readiness = await _readinessCalculator.getCurrent(userId);
      state = CurrentState(readiness: readiness);
    }

    return SelectedContext(
      patterns: patterns,
      relationships: relationships,
      causalChains: causalChains,
      gapFillEvents: gapFillEvents,
      state: state,
    );
  }

  QuerySignals _extractQuerySignals(String query) {
    final lower = query.toLowerCase();
    final entities = RegExp(r'\b[A-Z][a-z]+\b').allMatches(query).map((m) => m.group(0)!).toList();
    const emotionKeywords = ['frustrated', 'happy', 'sad', 'anxious', 'angry'];
    final emotions = emotionKeywords.where((e) => lower.contains(e)).toList();
    const topicKeywords = ['work', 'family', 'health', 'relationship'];
    final topics = topicKeywords.where((t) => lower.contains(t)).toList();
    return QuerySignals(entities: entities, emotions: emotions, topics: topics);
  }

  Future<List<Pattern>> _selectRelevantPatterns(String userId, QuerySignals signals, int limit) async {
    final all = await _lumaraRepo.loadPatterns(userId);
    final scored = all.map((p) => MapEntry(p, _scorePatternRelevance(p, signals))).toList();
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
  }

  double _scorePatternRelevance(Pattern pattern, QuerySignals signals) {
    final text = '${pattern.description} ${pattern.category} ${pattern.recurrence}'.toLowerCase();
    double score = 0;
    for (final e in signals.entities) {
      if (text.contains(e.toLowerCase())) score += 3;
    }
    for (final e in signals.emotions) {
      if (text.contains(e)) score += 2;
    }
    for (final t in signals.topics) {
      if (text.contains(t)) score += 1;
    }
    return score * pattern.confidence;
  }

  Future<List<RelationshipModel>> _selectRelevantRelationships(
    String userId,
    List<String> entities,
    int limit,
  ) async {
    final all = await _lumaraRepo.loadRelationships(userId);
    final relevant = all.where((r) =>
        entities.any((e) => r.entityName.toLowerCase() == e.toLowerCase())).toList();
    return relevant.take(limit).toList();
  }

  FormattedContext _formatForOutput(String query, SelectedContext context, OutputFormat format) {
    if (format == OutputFormat.json) {
      return FormattedContext(
        isStructured: true,
        content: {
          'query': query,
          'context': _serializeContextToJson(context),
        },
      );
    }
    return FormattedContext(
      isStructured: false,
      content: {
        'query': query,
        'context': _serializeContextToProse(context),
      },
    );
  }

  Map<String, dynamic> _serializeContextToJson(SelectedContext context) {
    return {
      'patterns': context.patterns.map((p) => {
        'name': p.description,
        'frequency': p.recurrence,
        'confidence': (p.confidence * 100).round(),
      }).toList(),
      'relationships': context.relationships.map((r) => {
        'name': r.entityName,
        'sentiment': r.role,
      }).toList(),
      'causal_chains': context.causalChains.map((c) => {'trigger': c.trigger, 'response': c.response}).toList(),
      'gap_fill_events': context.gapFillEvents.map((g) {
        final s = g.extractedSignal;
        String signal = '';
        if (s.causalChain != null) {
          signal = '${s.causalChain!.trigger} → ${s.causalChain!.response}';
        } else if (s.pattern != null) {
          signal = s.pattern!.description;
        } else if (s.relationship != null) {
          signal = '${s.relationship!.entity} (${s.relationship!.role})';
        }
        return {'query': g.trigger.originalQuery, 'signal': signal};
      }).toList(),
      'readiness': context.state?.readiness,
    };
  }

  String _serializeContextToProse(SelectedContext context) {
    final parts = <String>[];
    if (context.patterns.isNotEmpty) {
      parts.add('Patterns: ${context.patterns.map((p) => '${p.description} (${p.recurrence})').join(', ')}');
    }
    if (context.relationships.isNotEmpty) {
      parts.add('People: ${context.relationships.map((r) => '${r.entityName} (${r.role})').join(', ')}');
    }
    if (context.causalChains.isNotEmpty) {
      parts.add('Causal links: ${context.causalChains.map((c) => '"${c.trigger}" → "${c.response}"').join('; ')}');
    }
    if (context.gapFillEvents.isNotEmpty) {
      final moments = context.gapFillEvents.map((g) {
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
    if (context.state != null) {
      parts.add('Readiness: ${context.state!.readiness}/100');
    }
    return parts.join('\n');
  }

  String _buildSystemPrompt(OptimizationStrategy strategy) {
    String s = 'You are LUMARA, a biographical AI assistant.';
    switch (strategy.priority) {
      case OptimizationPriority.speed:
        s += ' Respond concisely.';
        break;
      case OptimizationPriority.quality:
        s += ' Provide thoughtful, detailed analysis.';
        break;
      case OptimizationPriority.accuracy:
        s += ' Accuracy is critical. Be precise.';
        break;
      case OptimizationPriority.balanced:
        break;
    }
    if (strategy.outputFormat == OutputFormat.json) {
      s += ' Always respond with valid JSON only.';
    }
    return s;
  }

  String _buildStructuredUserPrompt(Map<String, dynamic> content) {
    final ctx = content['context'];
    final query = content['query'] as String? ?? '';
    return 'Context: $ctx\n\nQuery: $query\n\nResponse (JSON only):';
  }

  String _buildProseUserPrompt(Map<String, dynamic> content) {
    final ctx = content['context'].toString();
    final query = content['query'] as String? ?? '';
    return '$ctx\n\nUser: $query';
  }

  int _estimateTokens(String text) => (text.length / 4).ceil();
}
