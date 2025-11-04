// lib/lumara/llm/llm_provider.dart
// Abstract base class for LLM providers

import '../config/api_config.dart';

/// Abstract base class for all LLM providers
abstract class LLMProviderBase {
  final LumaraAPIConfig _apiConfig;
  final String name;
  final bool isInternal;

  LLMProviderBase(this._apiConfig, this.name, this.isInternal);

  /// Generate a response using the LLM
  Future<String> generateResponse(Map<String, dynamic> context);

  /// Check if the provider is available
  Future<bool> isAvailable();

  /// Get provider configuration
  LLMProviderConfig? getConfig() {
    return _apiConfig.getConfig(getProviderType());
  }

  /// Get the provider type
  LLMProvider getProviderType();

  /// Get provider status
  Map<String, dynamic> getStatus() {
    return {
      'name': name,
      'isInternal': isInternal,
      'isAvailable': false, // Override in subclasses
      'config': getConfig()?.toJson(),
    };
  }
}
