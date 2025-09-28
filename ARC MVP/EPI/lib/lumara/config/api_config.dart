// lib/lumara/config/api_config.dart
// Centralized API configuration and key management for LUMARA

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported LLM providers
enum LLMProvider {
  gemini,
  openai,
  anthropic,
  llama,      // Internal Llama model
  qwen,       // Internal Qwen model
  ruleBased,  // Fallback rule-based responses
}

/// API configuration for different providers
class LLMProviderConfig {
  final LLMProvider provider;
  final String name;
  final String? apiKey;
  final String? baseUrl;
  final Map<String, dynamic>? additionalConfig;
  final bool isInternal;
  final bool isAvailable;

  const LLMProviderConfig({
    required this.provider,
    required this.name,
    this.apiKey,
    this.baseUrl,
    this.additionalConfig,
    this.isInternal = false,
    this.isAvailable = false,
  });

  Map<String, dynamic> toJson() => {
    'provider': provider.name,
    'name': name,
    'apiKey': apiKey != null ? '[REDACTED]' : null,
    'baseUrl': baseUrl,
    'additionalConfig': additionalConfig,
    'isInternal': isInternal,
    'isAvailable': isAvailable,
  };
}

/// Centralized API configuration manager
class LumaraAPIConfig {
  static const String _prefsKey = 'lumara_api_config';
  
  static LumaraAPIConfig? _instance;
  static LumaraAPIConfig get instance => _instance ??= LumaraAPIConfig._();
  
  LumaraAPIConfig._();

  final Map<LLMProvider, LLMProviderConfig> _configs = {};
  SharedPreferences? _prefs;

  /// Initialize the API configuration
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadConfigs();
    await _detectAvailableProviders();
  }

  /// Load configurations from environment and storage
  Future<void> _loadConfigs() async {
    // External API providers
    _configs[LLMProvider.gemini] = LLMProviderConfig(
      provider: LLMProvider.gemini,
      name: 'Google Gemini',
      apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      isInternal: false,
    );

    _configs[LLMProvider.openai] = LLMProviderConfig(
      provider: LLMProvider.openai,
      name: 'OpenAI GPT',
      apiKey: const String.fromEnvironment('OPENAI_API_KEY'),
      baseUrl: 'https://api.openai.com/v1',
      isInternal: false,
    );

    _configs[LLMProvider.anthropic] = LLMProviderConfig(
      provider: LLMProvider.anthropic,
      name: 'Anthropic Claude',
      apiKey: const String.fromEnvironment('ANTHROPIC_API_KEY'),
      baseUrl: 'https://api.anthropic.com/v1',
      isInternal: false,
    );

    // Internal LLM providers
    _configs[LLMProvider.llama] = LLMProviderConfig(
      provider: LLMProvider.llama,
      name: 'Llama (Internal)',
      baseUrl: 'http://localhost:8080', // Local inference server
      additionalConfig: {
        'modelPath': 'models/llama-2-7b-chat.gguf',
        'contextLength': 4096,
        'temperature': 0.7,
      },
      isInternal: true,
    );

    _configs[LLMProvider.qwen] = LLMProviderConfig(
      provider: LLMProvider.qwen,
      name: 'Qwen (Internal)',
      baseUrl: 'http://localhost:8081', // Local inference server
      additionalConfig: {
        'modelPath': 'models/qwen-7b-chat.gguf',
        'contextLength': 8192,
        'temperature': 0.7,
      },
      isInternal: true,
    );

    // Rule-based fallback
    _configs[LLMProvider.ruleBased] = LLMProviderConfig(
      provider: LLMProvider.ruleBased,
      name: 'Rule-Based Responses',
      isInternal: true,
      isAvailable: true, // Always available
    );
  }

  /// Detect which providers are available
  Future<void> _detectAvailableProviders() async {
    for (final config in _configs.values) {
      if (config.isInternal) {
        // For internal models, check if the local server is running
        _configs[config.provider] = config.copyWith(
          isAvailable: await _checkInternalModelAvailability(config),
        );
      } else {
        // For external APIs, check if API key is available
        _configs[config.provider] = config.copyWith(
          isAvailable: config.apiKey?.isNotEmpty == true,
        );
      }
    }
  }

  /// Check if internal model is available
  Future<bool> _checkInternalModelAvailability(LLMProviderConfig config) async {
    if (config.baseUrl == null) return false;
    
    try {
      // TODO: Implement actual health check for local inference servers
      // This would typically involve a simple HTTP request to the model server
      return false; // Placeholder - implement actual health check
    } catch (e) {
      debugPrint('LUMARA API: Health check failed for ${config.name}: $e');
      return false;
    }
  }

  /// Get configuration for a specific provider
  LLMProviderConfig? getConfig(LLMProvider provider) => _configs[provider];

  /// Get all available providers
  List<LLMProviderConfig> getAvailableProviders() {
    return _configs.values.where((config) => config.isAvailable).toList();
  }

  /// Get the best available provider (preference order)
  LLMProviderConfig? getBestProvider() {
    final available = getAvailableProviders();
    if (available.isEmpty) return null;

    // Preference order: Internal models first, then external APIs, then rule-based
    final internal = available.where((c) => c.isInternal && c.provider != LLMProvider.ruleBased).toList();
    if (internal.isNotEmpty) return internal.first;

    final external = available.where((c) => !c.isInternal).toList();
    if (external.isNotEmpty) return external.first;

    return available.first; // Fallback to rule-based
  }

  /// Update API key for a provider
  Future<void> updateApiKey(LLMProvider provider, String apiKey) async {
    final config = _configs[provider];
    if (config == null) return;

    _configs[provider] = config.copyWith(apiKey: apiKey);
    await _saveConfigs();
  }

  /// Save configurations to persistent storage
  Future<void> _saveConfigs() async {
    if (_prefs == null) return;

    final configsJson = _configs.map(
      (key, value) => MapEntry(key.name, value.toJson()),
    );
    
    await _prefs!.setString(_prefsKey, jsonEncode(configsJson));
  }


  /// Get API key for a provider (with security masking)
  String? getApiKey(LLMProvider provider) {
    final config = _configs[provider];
    return config?.apiKey;
  }

  /// Check if a provider is configured and available
  bool isProviderAvailable(LLMProvider provider) {
    final config = _configs[provider];
    return config?.isAvailable == true;
  }

  /// Get provider status summary
  Map<String, dynamic> getStatusSummary() {
    return {
      'totalProviders': _configs.length,
      'availableProviders': getAvailableProviders().length,
      'bestProvider': getBestProvider()?.name,
      'providers': _configs.map(
        (key, value) => MapEntry(key.name, {
          'available': value.isAvailable,
          'internal': value.isInternal,
          'configured': value.apiKey?.isNotEmpty == true || value.isInternal,
        }),
      ),
    };
  }
}

/// Extension to add copyWith method to LLMProviderConfig
extension LLMProviderConfigExtension on LLMProviderConfig {
  LLMProviderConfig copyWith({
    LLMProvider? provider,
    String? name,
    String? apiKey,
    String? baseUrl,
    Map<String, dynamic>? additionalConfig,
    bool? isInternal,
    bool? isAvailable,
  }) {
    return LLMProviderConfig(
      provider: provider ?? this.provider,
      name: name ?? this.name,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      additionalConfig: additionalConfig ?? this.additionalConfig,
      isInternal: isInternal ?? this.isInternal,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}
