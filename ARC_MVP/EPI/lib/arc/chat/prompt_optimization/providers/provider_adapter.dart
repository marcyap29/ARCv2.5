// lib/arc/chat/prompt_optimization/providers/provider_adapter.dart
//
// Provider-agnostic interface for LLM completion.

import '../prompt_optimization_types.dart';

/// Interface for LLM providers (Groq, OpenAI, Claude, etc.).
abstract class ProviderAdapter {
  String get name;

  Future<CompletionResponse> complete(CompletionRequest request);

  Future<bool> isAvailable();

  double estimateCost(CompletionRequest request);
}
