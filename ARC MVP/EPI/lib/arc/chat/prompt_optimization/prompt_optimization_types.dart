// lib/arc/chat/prompt_optimization/prompt_optimization_types.dart
//
// Universal Prompt Optimization - 80/20 Framework
// Provider-agnostic types for LUMARA prompt optimization.

/// Use cases for prompt optimization (determines context and format).
enum PromptUseCase {
  // User-facing
  userChat,
  userReflect,
  userVoice,
  // Agentic loop
  gapClassification,
  patternExtraction,
  seekingDetection,
  // Batch
  intelligenceSummary,
  // Safety
  crisisDetection,
}

/// Priority for optimization (speed vs quality vs accuracy).
enum OptimizationPriority {
  speed,
  quality,
  accuracy,
  balanced,
}

/// Output format requested from the model.
enum OutputFormat {
  json,
  prose,
}

/// How much context to include.
class ContextRequirements {
  final int patterns;
  final int relationships;
  final int causalChains;
  final int gapFillEvents;
  final int recentEntries;
  final bool state;

  const ContextRequirements({
    this.patterns = 0,
    this.relationships = 0,
    this.causalChains = 0,
    this.gapFillEvents = 0,
    this.recentEntries = 0,
    this.state = false,
  });
}

/// Strategy for a given use case.
class OptimizationStrategy {
  final ContextRequirements contextNeeded;
  final OutputFormat outputFormat;
  final int maxTokens;
  final bool cacheable;
  final OptimizationPriority priority;

  const OptimizationStrategy({
    required this.contextNeeded,
    required this.outputFormat,
    required this.maxTokens,
    required this.cacheable,
    required this.priority,
  });
}

/// Signals extracted from the user query.
class QuerySignals {
  final List<String> entities;
  final List<String> emotions;
  final List<String> topics;

  const QuerySignals({
    this.entities = const [],
    this.emotions = const [],
    this.topics = const [],
  });
}

/// Current user state (e.g. readiness).
class CurrentState {
  final int readiness;

  const CurrentState({this.readiness = 0});
}

/// Result of building an optimized prompt.
class UniversalPrompt {
  final String system;
  final String user;
  final UniversalPromptMetadata metadata;

  const UniversalPrompt({
    required this.system,
    required this.user,
    required this.metadata,
  });
}

class UniversalPromptMetadata {
  final PromptUseCase useCase;
  final int tokensEstimated;
  final int contextItemsIncluded;
  final int optimizationDurationMs;
  final bool cacheable;

  const UniversalPromptMetadata({
    required this.useCase,
    required this.tokensEstimated,
    required this.contextItemsIncluded,
    required this.optimizationDurationMs,
    required this.cacheable,
  });
}

/// Request to complete a prompt (provider-agnostic).
class CompletionRequest {
  final String system;
  final String user;
  final int maxTokens;
  final double temperature;
  final PromptUseCase useCase;

  const CompletionRequest({
    required this.system,
    required this.user,
    required this.maxTokens,
    this.temperature = 0.7,
    required this.useCase,
  });
}

/// Token usage from the provider.
class TokenUsage {
  final int prompt;
  final int completion;
  final int total;

  const TokenUsage({
    required this.prompt,
    required this.completion,
    required this.total,
  });
}

/// Response from a provider.
class CompletionResponse {
  final String content;
  final TokenUsage tokensUsed;
  final double cost;
  final int latencyMs;
  final String model;

  const CompletionResponse({
    required this.content,
    required this.tokensUsed,
    required this.cost,
    required this.latencyMs,
    required this.model,
  });
}

/// Result of universal response generation (with cache and metadata).
class GeneratedResponse {
  final String content;
  final bool fromCache;
  final String provider;
  final GeneratedResponseMetadata metadata;

  const GeneratedResponse({
    required this.content,
    required this.fromCache,
    required this.provider,
    required this.metadata,
  });
}

class GeneratedResponseMetadata {
  final int totalDurationMs;
  final int tokensUsed;
  final double cost;
  final String? model;
  final OptimizationSavings? optimizationSavings;

  const GeneratedResponseMetadata({
    required this.totalDurationMs,
    required this.tokensUsed,
    required this.cost,
    this.model,
    this.optimizationSavings,
  });
}

class OptimizationSavings {
  final int tokensBefore;
  final int tokensAfter;
  final int reductionPercent;

  const OptimizationSavings({
    required this.tokensBefore,
    required this.tokensAfter,
    required this.reductionPercent,
  });
}
