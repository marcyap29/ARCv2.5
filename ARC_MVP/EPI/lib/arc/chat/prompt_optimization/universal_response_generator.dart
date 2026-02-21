// lib/arc/chat/prompt_optimization/universal_response_generator.dart
// Provider-agnostic response generation with optimization and caching.

import 'package:flutter/foundation.dart';
import 'prompt_optimization_types.dart';
import 'universal_prompt_optimizer.dart';
import 'provider_manager.dart';
import 'response_cache.dart';

class UniversalResponseGenerator {
  UniversalResponseGenerator({
    required UniversalPromptOptimizer optimizer,
    required ProviderManager providerManager,
    required ResponseCache responseCache,
  })  : _optimizer = optimizer,
        _providerManager = providerManager,
        _responseCache = responseCache;

  final UniversalPromptOptimizer _optimizer;
  final ProviderManager _providerManager;
  final ResponseCache _responseCache;

  static const int _defaultUnoptimizedTokens = 5000;

  Future<GeneratedResponse> generate(
    String userId,
    String query,
    PromptUseCase useCase,
  ) async {
    debugPrint('[UniversalResponse] Generating for $useCase...');
    final start = DateTime.now();

    if (_isCacheable(useCase)) {
      final cached = await _responseCache.get(userId, query);
      if (cached != null && cached.isNotEmpty) {
        debugPrint('[UniversalResponse] Cache HIT');
        return GeneratedResponse(
          content: cached,
          fromCache: true,
          provider: 'cache',
          metadata: GeneratedResponseMetadata(
            totalDurationMs: DateTime.now().difference(start).inMilliseconds,
            tokensUsed: 0,
            cost: 0,
          ),
        );
      }
    }

    return _generateWithOptimization(userId, query, useCase, start);
  }

  Future<GeneratedResponse> _generateWithOptimization(
    String userId,
    String query,
    PromptUseCase useCase,
    DateTime start,
  ) async {
    final optimized = await _optimizer.buildOptimizedPrompt(userId, query, useCase);
    debugPrint('[UniversalResponse] Optimized: ${optimized.metadata.tokensEstimated} tokens');

    final provider = await _providerManager.getProvider();
    debugPrint('[UniversalResponse] Using provider: ${provider.name}');

    final request = CompletionRequest(
      system: optimized.system,
      user: optimized.user,
      maxTokens: _maxTokensForUseCase(useCase),
      useCase: useCase,
    );

    final response = await provider.complete(request);

    if (optimized.metadata.cacheable) {
      await _responseCache.set(userId, query, response.content);
    }

    final totalMs = DateTime.now().difference(start).inMilliseconds;
    debugPrint('[UniversalResponse] Complete: ${totalMs}ms, ${response.tokensUsed.total} tokens, \$${response.cost.toStringAsFixed(4)}');

    final reduction = optimized.metadata.tokensEstimated < _defaultUnoptimizedTokens
        ? ((1 - optimized.metadata.tokensEstimated / _defaultUnoptimizedTokens) * 100).round()
        : 0;

    return GeneratedResponse(
      content: response.content,
      fromCache: false,
      provider: provider.name,
      metadata: GeneratedResponseMetadata(
        totalDurationMs: totalMs,
        tokensUsed: response.tokensUsed.total,
        cost: response.cost,
        model: response.model,
        optimizationSavings: OptimizationSavings(
          tokensBefore: _defaultUnoptimizedTokens,
          tokensAfter: optimized.metadata.tokensEstimated,
          reductionPercent: reduction,
        ),
      ),
    );
  }

  bool _isCacheable(PromptUseCase useCase) {
    switch (useCase) {
      case PromptUseCase.userChat:
      case PromptUseCase.userReflect:
      case PromptUseCase.userVoice:
      case PromptUseCase.seekingDetection:
        return true;
      default:
        return false;
    }
  }

  int _maxTokensForUseCase(PromptUseCase useCase) {
    switch (useCase) {
      case PromptUseCase.userChat:
        return 500;
      case PromptUseCase.userReflect:
        return 200;
      case PromptUseCase.userVoice:
        return 150;
      case PromptUseCase.gapClassification:
        return 50;
      case PromptUseCase.patternExtraction:
        return 200;
      case PromptUseCase.seekingDetection:
        return 20;
      case PromptUseCase.intelligenceSummary:
        return 16000;
      case PromptUseCase.crisisDetection:
        return 500;
    }
  }
}
