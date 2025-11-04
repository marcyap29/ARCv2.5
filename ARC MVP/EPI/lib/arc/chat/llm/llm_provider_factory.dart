// lib/lumara/llm/llm_provider_factory.dart
// Factory for creating LLM providers

import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'llm_provider.dart';
import 'providers/gemini_provider.dart';
import 'providers/openai_provider.dart';
import 'providers/anthropic_provider.dart';
import 'providers/llama_provider.dart';
import 'providers/qwen_provider.dart';

/// Factory for creating LLM providers
class LLMProviderFactory {
  final LumaraAPIConfig _apiConfig;

  LLMProviderFactory(this._apiConfig);

  /// Create a provider based on type
  LLMProviderBase? createProvider(LLMProviderType type) {
    try {
      switch (type) {
        case LLMProviderType.gemini:
          return GeminiProvider(_apiConfig);
        case LLMProviderType.openai:
          return OpenAIProvider(_apiConfig);
        case LLMProviderType.anthropic:
          return AnthropicProvider(_apiConfig);
        case LLMProviderType.qwen4b:
          return QwenProvider(_apiConfig);
        case LLMProviderType.llama3b:
          return LlamaProvider(_apiConfig);
      }
    } catch (e) {
      debugPrint('LLMProviderFactory: Failed to create provider $type: $e');
      return null;
    }
  }

  /// Get the best available provider
  LLMProviderBase? getBestProvider() {
    final bestConfig = _apiConfig.getBestProvider();
    if (bestConfig == null) return null;

    final providerType = _getProviderTypeFromConfig(bestConfig);
    return createProvider(providerType);
  }

  /// Get all available providers
  List<LLMProviderBase> getAvailableProviders() {
    final availableConfigs = _apiConfig.getAvailableProviders();
    final providers = <LLMProviderBase>[];

    for (final config in availableConfigs) {
      final providerType = _getProviderTypeFromConfig(config);
      final provider = createProvider(providerType);
      if (provider != null) {
        providers.add(provider);
      }
    }

    return providers;
  }

  /// Convert config to provider type
  LLMProviderType _getProviderTypeFromConfig(LLMProviderConfig config) {
    return switch (config.provider) {
      LLMProvider.gemini => LLMProviderType.gemini,
      LLMProvider.openai => LLMProviderType.openai,
      LLMProvider.anthropic => LLMProviderType.anthropic,
      LLMProvider.qwen4b => LLMProviderType.qwen4b,
      LLMProvider.llama3b => LLMProviderType.llama3b,
    };
  }
}

/// Supported LLM provider types
enum LLMProviderType {
  gemini,
  openai,
  anthropic,
  qwen4b,
  llama3b,
}
