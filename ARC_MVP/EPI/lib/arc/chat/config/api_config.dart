// lib/lumara/config/api_config.dart
// Centralized API configuration and key management for LUMARA

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported LLM providers
/// LUMARA uses Gemini as primary, Groq (Llama 3.3 70B) as fallback.
/// Claude, ChatGPT (openai), Venice, OpenRouter are not used by LUMARA.
enum LLMProvider {
  groq,       // Groq: Llama 3.3 70B (fallback for LUMARA)
  gemini,
  openai,
  anthropic,
  venice,     // Venice AI
  openrouter, // OpenRouter
  qwen4b,     // Internal Qwen3 4B Q4_K_S model
  llama3b,    // Internal Llama 3.2 3B model
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
    'apiKey': apiKey, // Save actual key - SharedPreferences is already secure
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

  // Model registry for valid model IDs
  static const Map<String, String> _modelRegistry = {};

  static bool isValidModelId(String modelId) => _modelRegistry.containsKey(modelId);
  
  static String? getProviderForModel(String modelId) => _modelRegistry[modelId];

  final Map<LLMProvider, LLMProviderConfig> _configs = {};
  SharedPreferences? _prefs;
  LLMProvider? _manualProvider; // User's manually selected provider
  bool _initialized = false;

  /// Initialize the API configuration.
  /// Skips if already initialized unless [force] is true (e.g. after key changes).
  Future<void> initialize({bool force = false}) async {
    if (_initialized && !force) return;
    
    debugPrint('LUMARA API: Initializing API configuration...');
    
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadConfigs();
      await _detectAvailableProviders();

      // Load manual provider preference
      final manualProviderName = _prefs?.getString('manual_provider');
      if (manualProviderName != null) {
        try {
          _manualProvider = LLMProvider.values.firstWhere(
            (p) => p.name == manualProviderName,
          );
          debugPrint('LUMARA API: Manual provider set to: ${_manualProvider?.name}');
        } catch (e) {
          // Invalid provider name, clear it
          _manualProvider = null;
          await _prefs?.remove('manual_provider');
          debugPrint('LUMARA API: Invalid manual provider name, cleared');
        }
      }

      // Perform quick startup model availability check (lightweight)
      // Full model validation happens on-demand when actually needed
      await _performStartupModelCheck();
      
      // Final status check
      final bestProvider = getBestProvider();
      debugPrint('LUMARA API: Final initialization complete - Best provider (Cloud APIs prioritized): ${bestProvider?.name ?? 'None'}');
      
      // Log detailed provider status on first init only
      _logDetailedProviderStatus();
      _initialized = true;
    } catch (e) {
      debugPrint('LUMARA API: Initialization error: $e');
      rethrow;
    }
  }

  /// Perform startup check for model availability
  /// This is a lightweight check to avoid slowing down app startup
  Future<void> _performStartupModelCheck() async {
    debugPrint('LUMARA API: Performing quick startup model availability check...');
    
    // Check all internal models with lightweight validation
    for (final config in _configs.values) {
      if (config.isInternal) {
        try {
          // Quick check: just verify files exist, don't load the model
          final isAvailable = await _quickCheckModelAvailability(config);
          debugPrint('LUMARA API: Startup check - ${config.name}: ${isAvailable ? 'Available' : 'Not available'}');
          
          // Update the configuration with the current availability status
          _configs[config.provider] = config.copyWith(isAvailable: isAvailable);
          
          // Update download state service
          _updateDownloadStateForModel(config, isAvailable);
        } catch (e) {
          debugPrint('LUMARA API: Startup check failed for ${config.name}: $e');
          _configs[config.provider] = config.copyWith(isAvailable: false);
        }
      }
    }
    
    debugPrint('LUMARA API: Quick startup model check completed');
  }
  
  /// Quick lightweight check - just verifies files exist without loading model
  Future<bool> _quickCheckModelAvailability(LLMProviderConfig config) async {
    // Internal models (Llama/Qwen3) are no longer supported
    debugPrint('LUMARA API: Internal model checks disabled (models not installed)');
    return false;
  }

  /// Load configurations from environment and storage
  Future<void> _loadConfigs() async {
    // Groq: fallback for LUMARA (Llama 3.3 70B)
    const groqApiKey = String.fromEnvironment('GROQ_API_KEY');
    debugPrint('LUMARA API: Loading Groq API key from environment: ${groqApiKey.isNotEmpty ? 'Found' : 'Not found'}');

    _configs[LLMProvider.groq] = const LLMProviderConfig(
      provider: LLMProvider.groq,
      name: 'Groq (Llama 3.3 70B)',
      apiKey: groqApiKey,
      baseUrl: 'https://api.groq.com/openai/v1',
      isInternal: false,
    );

    // External API providers - load defaults from environment
    const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
    debugPrint('LUMARA API: Loading Gemini API key from environment: ${geminiApiKey.isNotEmpty ? 'Found' : 'Not found'}');

    _configs[LLMProvider.gemini] = const LLMProviderConfig(
      provider: LLMProvider.gemini,
      name: 'Google Gemini',
      apiKey: geminiApiKey,
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      isInternal: false,
    );

    _configs[LLMProvider.openai] = const LLMProviderConfig(
      provider: LLMProvider.openai,
      name: 'OpenAI GPT',
      apiKey: String.fromEnvironment('OPENAI_API_KEY'),
      baseUrl: 'https://api.openai.com/v1',
      isInternal: false,
    );

    _configs[LLMProvider.anthropic] = const LLMProviderConfig(
      provider: LLMProvider.anthropic,
      name: 'Anthropic Claude',
      apiKey: String.fromEnvironment('ANTHROPIC_API_KEY'),
      baseUrl: 'https://api.anthropic.com/v1',
      isInternal: false,
    );

    _configs[LLMProvider.venice] = const LLMProviderConfig(
      provider: LLMProvider.venice,
      name: 'Venice AI',
      apiKey: String.fromEnvironment('VENICE_API_KEY'),
      baseUrl: 'https://api.venice.ai/v1',
      isInternal: false,
    );

    _configs[LLMProvider.openrouter] = const LLMProviderConfig(
      provider: LLMProvider.openrouter,
      name: 'OpenRouter',
      apiKey: String.fromEnvironment('OPENROUTER_API_KEY'),
      baseUrl: 'https://openrouter.ai/api/v1',
      isInternal: false,
    );

    // Internal LLM providers - removed (models not installed)


    // Load saved API keys from SharedPreferences (overrides environment)
    if (_prefs != null) {
      final savedConfigsJson = _prefs!.getString(_prefsKey);
      if (savedConfigsJson != null) {
        try {
          final savedConfigs = jsonDecode(savedConfigsJson) as Map<String, dynamic>;
          for (final entry in savedConfigs.entries) {
            final providerName = entry.key;
            final configData = entry.value as Map<String, dynamic>;

            // Find the corresponding provider enum
            try {
              final provider = LLMProvider.values.firstWhere(
                (p) => p.name == providerName,
              );

              // Update API key if saved (including empty strings to override environment)
              if (configData.containsKey('apiKey')) {
                final savedApiKey = configData['apiKey'] as String?;
                final currentConfig = _configs[provider];
                if (currentConfig != null) {
                  final keyToUse = savedApiKey ?? '';
                  _configs[provider] = currentConfig.copyWith(apiKey: keyToUse);

                  if (keyToUse.isNotEmpty) {
                    final maskedKey = keyToUse.length > 8
                        ? '${keyToUse.substring(0, 4)}...${keyToUse.substring(keyToUse.length - 4)}'
                        : '***';
                    debugPrint('LUMARA API: Loaded saved API key for ${currentConfig.name}: $maskedKey (length: ${keyToUse.length})');
                  } else {
                    debugPrint('LUMARA API: Loaded empty API key for ${currentConfig.name} (overrides environment)');
                  }
                }
              }
            } catch (e) {
              debugPrint('LUMARA API: Unknown provider in saved configs: $providerName');
            }
          }
        } catch (e) {
          debugPrint('LUMARA API: Error loading saved configs: $e');
        }
      }
      
      // Auto-save API keys from runtime environment variables if not already saved
      // This allows users to set GEMINI_API_KEY as an environment variable and have it persist
      final runtimeGeminiKey = Platform.environment['GEMINI_API_KEY'];
      if (runtimeGeminiKey != null && runtimeGeminiKey.isNotEmpty) {
        final savedConfigsJson = _prefs!.getString(_prefsKey);
        Map<String, dynamic> savedConfigs = {};
        if (savedConfigsJson != null) {
          try {
            savedConfigs = jsonDecode(savedConfigsJson) as Map<String, dynamic>;
          } catch (e) {
            debugPrint('LUMARA API: Error parsing saved configs for auto-save: $e');
          }
        }
        
        // Check if Gemini key is already saved
        final geminiConfig = savedConfigs['gemini'] as Map<String, dynamic>?;
        final savedGeminiKey = geminiConfig?['apiKey'] as String?;
        
        if (savedGeminiKey == null || savedGeminiKey.isEmpty) {
          debugPrint('LUMARA API: Auto-saving Gemini API key from runtime environment variable...');
          savedConfigs['gemini'] = {
            'provider': 'gemini',
            'name': 'Google Gemini',
            'apiKey': runtimeGeminiKey,
            'baseUrl': 'https://generativelanguage.googleapis.com/v1beta',
            'isInternal': false,
            'isAvailable': true,
          };
          await _prefs!.setString(_prefsKey, jsonEncode(savedConfigs));
          
          // Update the in-memory config
          final currentConfig = _configs[LLMProvider.gemini];
          if (currentConfig != null) {
            _configs[LLMProvider.gemini] = currentConfig.copyWith(apiKey: runtimeGeminiKey);
            final maskedKey = runtimeGeminiKey.length > 8
                ? '${runtimeGeminiKey.substring(0, 4)}...${runtimeGeminiKey.substring(runtimeGeminiKey.length - 4)}'
                : '***';
            debugPrint('LUMARA API: Auto-saved Gemini API key from environment: $maskedKey (length: ${runtimeGeminiKey.length})');
          }
        }
      }

      // Auto-save Groq API key from runtime environment if not already saved
      final runtimeGroqKey = Platform.environment['GROQ_API_KEY'];
      if (runtimeGroqKey != null && runtimeGroqKey.isNotEmpty) {
        final savedConfigsJson = _prefs!.getString(_prefsKey);
        Map<String, dynamic> savedConfigs = {};
        if (savedConfigsJson != null) {
          try {
            savedConfigs = jsonDecode(savedConfigsJson) as Map<String, dynamic>;
          } catch (e) {
            debugPrint('LUMARA API: Error parsing saved configs for Groq auto-save: $e');
          }
        }
        final groqConfig = savedConfigs['groq'] as Map<String, dynamic>?;
        final savedGroqKey = groqConfig?['apiKey'] as String?;
        if (savedGroqKey == null || savedGroqKey.isEmpty) {
          debugPrint('LUMARA API: Auto-saving Groq API key from runtime environment variable...');
          savedConfigs['groq'] = {
            'provider': 'groq',
            'name': 'Groq (Llama 3.3 70B)',
            'apiKey': runtimeGroqKey,
            'baseUrl': 'https://api.groq.com/openai/v1',
            'isInternal': false,
            'isAvailable': true,
          };
          await _prefs!.setString(_prefsKey, jsonEncode(savedConfigs));
          final currentConfig = _configs[LLMProvider.groq];
          if (currentConfig != null) {
            _configs[LLMProvider.groq] = currentConfig.copyWith(apiKey: runtimeGroqKey);
          }
        }
      }
    }
  }

  /// Detect which providers are available
  Future<void> _detectAvailableProviders() async {
    debugPrint('LUMARA API: Detecting available providers...');
    for (final config in _configs.values) {
      if (config.isInternal) {
        // For internal models, check if the local server is running
        final isAvailable = await _checkInternalModelAvailability(config);
        debugPrint('LUMARA API: Internal provider ${config.name}: ${isAvailable ? 'Available' : 'Not available'}');
        _configs[config.provider] = config.copyWith(
          isAvailable: isAvailable,
        );
      } else {
        // For external APIs, check if API key is available
        final hasApiKey = config.apiKey?.isNotEmpty == true;
        debugPrint('LUMARA API: External provider ${config.name}: ${hasApiKey ? 'API key found (length: ${config.apiKey?.length})' : 'No API key'}');
        _configs[config.provider] = config.copyWith(
          isAvailable: hasApiKey,
        );
      }
    }
    
    // Log final provider status
    final availableProviders = getAvailableProviders();
    debugPrint('LUMARA API: Available providers: ${availableProviders.map((p) => p.name).join(', ')}');
    final bestProvider = getBestProvider();
    debugPrint('LUMARA API: Best provider (Cloud APIs prioritized): ${bestProvider?.name ?? 'None'}');
  }

  /// Update download state service for a model
  void _updateDownloadStateForModel(LLMProviderConfig config, bool isAvailable) {
    // Internal models (Llama/Qwen3) are no longer supported
    // No-op: models not installed
  }


  /// Check if internal model is available
  Future<bool> _checkInternalModelAvailability(LLMProviderConfig config) async {
    // Internal models (Llama/Qwen3) are no longer supported
    debugPrint('LUMARA API: Internal model checks disabled (models not installed)');
    return false;
  }

  /// Get configuration for a specific provider
  LLMProviderConfig? getConfig(LLMProvider provider) => _configs[provider];

  /// Get all providers (both available and unavailable)
  List<LLMProviderConfig> getAllProviders() {
    return _configs.values.toList();
  }

  /// Get all available providers
  List<LLMProviderConfig> getAvailableProviders() {
    return _configs.values.where((config) => config.isAvailable).toList();
  }

  /// Get the best available provider (preference order)
  LLMProviderConfig? getBestProvider() {
    final available = getAvailableProviders();
    if (available.isEmpty) return null;

    // Check if user has manually selected a provider
    if (_manualProvider != null) {
      final manualConfig = _configs[_manualProvider];
      if (manualConfig != null && manualConfig.isAvailable) {
        return manualConfig;
      }
      // If manual selection is no longer available, clear it
      _manualProvider = null;
      _prefs?.remove('manual_provider');
    }

    // Preference order: Gemini first (primary), then Groq (Llama 3.3 70B fallback)
    final geminiConfig = _configs[LLMProvider.gemini];
    if (geminiConfig != null && geminiConfig.isAvailable) {
      return geminiConfig;
    }

    final groqConfig = _configs[LLMProvider.groq];
    if (groqConfig != null && groqConfig.isAvailable) {
      return groqConfig;
    }

    // Fallback to other external/cloud APIs if Groq/Gemini not available
    final external = available.where((c) => !c.isInternal).toList();
    if (external.isNotEmpty) return external.first;

    // Finally, internal models as last resort
    final internal = available.where((c) => c.isInternal && _isValidInternalModel(c)).toList();
    if (internal.isNotEmpty) return internal.first;

    return null; // No providers available
  }

  /// Check if an internal model is valid according to the registry
  bool _isValidInternalModel(LLMProviderConfig config) {
    if (!config.isInternal) return false;
    
    final modelId = _getModelIdForProvider(config.provider);
    return isValidModelId(modelId);
  }

  /// Get model ID for a provider
  String _getModelIdForProvider(LLMProvider provider) {
    // Internal models (Llama/Qwen3) are no longer supported
    return '';
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

  /// Update API key for a provider
  Future<void> updateApiKey(LLMProvider provider, String apiKey) async {
    final config = _configs[provider];
    if (config != null) {
      final maskedKey = apiKey.length > 8
          ? '${apiKey.substring(0, 4)}...${apiKey.substring(apiKey.length - 4)}'
          : '***';
      debugPrint('LUMARA API: Saving API key for ${config.name} ($provider): $maskedKey (length: ${apiKey.length})');
      
      try {
        _configs[provider] = config.copyWith(apiKey: apiKey);
        await _saveConfigs();
        debugPrint('LUMARA API: Configs saved to SharedPreferences');
        
        // Refresh provider availability to update the isAvailable status
        await _detectAvailableProviders();
        
        // Log the final status after updating
        final updatedConfig = _configs[provider];
        debugPrint('LUMARA API: After update - ${config.name} available: ${updatedConfig?.isAvailable}');
        
        _logDetailedProviderStatus(verbose: true);
      } catch (e) {
        debugPrint('LUMARA API: Error updating API key for ${config.name}: $e');
        rethrow;
      }
    } else {
      debugPrint('LUMARA API: ERROR - Provider $provider not found in configs');
      throw Exception('Provider $provider not found in configuration');
    }
  }

  /// Clear manual provider selection (return to auto-selection)
  Future<void> clearManualProvider() async {
    _manualProvider = null;
    await _prefs?.remove('manual_provider');
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

  /// Refresh model availability status
  Future<void> refreshModelAvailability() async {
    debugPrint('LUMARA API: Refreshing model availability status...');
    await _performStartupModelCheck();
  }

  /// Set manual provider selection
  Future<void> setManualProvider(LLMProvider? provider) async {
    _manualProvider = provider;
    if (provider != null) {
      await _prefs?.setString('manual_provider', provider.name);
      debugPrint('LUMARA API: Manual provider set to: ${provider.name}');
    } else {
      await _prefs?.remove('manual_provider');
      debugPrint('LUMARA API: Manual provider cleared');
    }
  }

  /// Get current manual provider
  LLMProvider? getManualProvider() {
    return _manualProvider;
  }

  /// Force refresh all provider availability (useful after API key changes)
  Future<void> refreshProviderAvailability() async {
    debugPrint('LUMARA API: Force refreshing all provider availability...');
    await _detectAvailableProviders();
    _logDetailedProviderStatus(verbose: true);
  }

  /// Force re-initialization (e.g. after API key changes from outside)
  void markNeedsReinit() => _initialized = false;

  /// Log detailed provider status for debugging.
  /// Full per-provider dump only when [verbose] is true (e.g. after key changes);
  /// otherwise prints a compact one-line summary.
  void _logDetailedProviderStatus({bool verbose = false}) {
    final availableProviders = getAvailableProviders();
    final bestProvider = getBestProvider();
    final unavailable = _configs.values.where((c) => !c.isAvailable).map((c) => c.name);

    if (verbose) {
      debugPrint('LUMARA API: === DETAILED PROVIDER STATUS ===');
      for (final config in _configs.values) {
        final apiKeyLength = config.apiKey?.length ?? 0;
        final apiKeyMasked = config.apiKey?.isNotEmpty == true
            ? '${config.apiKey!.substring(0, config.apiKey!.length > 8 ? 4 : 0)}...${config.apiKey!.substring(config.apiKey!.length - 4)}'
            : 'none';

        debugPrint('LUMARA API: ${config.name}:');
        debugPrint('LUMARA API:   - Available: ${config.isAvailable}');
        debugPrint('LUMARA API:   - Internal: ${config.isInternal}');
        debugPrint('LUMARA API:   - API Key: $apiKeyMasked (length: $apiKeyLength)');
        debugPrint('LUMARA API:   - Base URL: ${config.baseUrl ?? 'none'}');
      }
      debugPrint('LUMARA API: === END PROVIDER STATUS ===');
    }

    debugPrint('LUMARA API: Available: [${availableProviders.map((p) => p.name).join(', ')}] | '
        'Best: ${bestProvider?.name ?? 'None'} | '
        'Unavailable: ${unavailable.isEmpty ? 'none' : unavailable.join(', ')}');
  }

  /// Clear all saved API keys (for debugging)
  Future<void> clearAllApiKeys() async {
    debugPrint('LUMARA API: Clearing all saved API keys...');

    // Save empty strings for all external providers to override environment variables
    final clearedConfigs = <String, dynamic>{};
    for (final provider in [LLMProvider.groq, LLMProvider.gemini, LLMProvider.openai, LLMProvider.anthropic, LLMProvider.venice, LLMProvider.openrouter]) {
      clearedConfigs[provider.name] = {'apiKey': ''}; // Empty string overrides environment
    }

    await _prefs?.setString(_prefsKey, jsonEncode(clearedConfigs));
    debugPrint('LUMARA API: Saved empty API keys to override environment variables');

    // Reset configs to defaults (which will then be overridden by empty strings)
    await _loadConfigs();
    await _detectAvailableProviders();
    debugPrint('LUMARA API: All API keys cleared');
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
