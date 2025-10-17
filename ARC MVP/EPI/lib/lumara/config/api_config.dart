// lib/lumara/config/api_config.dart
// Centralized API configuration and key management for LUMARA

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../llm/bridge.pigeon.dart';
import '../services/download_state_service.dart';

/// Supported LLM providers
enum LLMProvider {
  gemini,
  openai,
  anthropic,
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

  final Map<LLMProvider, LLMProviderConfig> _configs = {};
  SharedPreferences? _prefs;
  LLMProvider? _manualProvider; // User's manually selected provider

  /// Initialize the API configuration
  Future<void> initialize() async {
    debugPrint('LUMARA API: Initializing API configuration...');
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
    debugPrint('LUMARA API: Final initialization complete - Best provider: ${bestProvider?.name ?? 'None'}');
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
    try {
      final bridge = LumaraNative();
      
      // Get the model ID for this provider
      String modelId;
      switch (config.provider) {
        case LLMProvider.qwen4b:
          modelId = 'Qwen3-4B-Instruct-2507-Q4_K_S.gguf';
          break;
        case LLMProvider.llama3b:
          modelId = 'Llama-3.2-3b-Instruct-Q4_K_M.gguf';
          break;
        default:
          debugPrint('LUMARA API: Unknown provider type: ${config.provider}');
          return false;
      }
      
      debugPrint('LUMARA API: Checking model availability for: $modelId');
      // Quick file existence check only - don't load or validate the model
      final isDownloaded = await bridge.isModelDownloaded(modelId);
      debugPrint('LUMARA API: Model $modelId availability: $isDownloaded');
      return isDownloaded;
    } catch (e) {
      debugPrint('LUMARA API: Quick check error for ${config.name}: $e');
      return false;
    }
  }

  /// Load configurations from environment and storage
  Future<void> _loadConfigs() async {
    // External API providers - load defaults from environment
    final geminiApiKey = const String.fromEnvironment('GEMINI_API_KEY');
    debugPrint('LUMARA API: Loading Gemini API key from environment: ${geminiApiKey.isNotEmpty ? 'Found' : 'Not found'}');

    _configs[LLMProvider.gemini] = LLMProviderConfig(
      provider: LLMProvider.gemini,
      name: 'Google Gemini',
      apiKey: geminiApiKey,
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
        _configs[LLMProvider.qwen4b] = LLMProviderConfig(
          provider: LLMProvider.qwen4b,
          name: 'Qwen3 4B Q4_K_S (Internal)',
          baseUrl: 'http://localhost:8082', // Local inference server
          additionalConfig: {
            'modelPath': 'assets/models/gguf/Qwen3-4B-Instruct-2507-Q4_K_S.gguf',
            'contextLength': 4096,
            'temperature': 0.7,
            'backend': 'llama.cpp',
            'metal': true,
          },
          isInternal: true,
        );

        _configs[LLMProvider.llama3b] = LLMProviderConfig(
          provider: LLMProvider.llama3b,
          name: 'Llama 3.2 3B (Internal)',
          baseUrl: 'http://localhost:8083', // Local inference server
          additionalConfig: {
            'modelPath': 'assets/models/gguf/Llama-3.2-3b-Instruct-Q4_K_M.gguf',
            'contextLength': 4096,
            'temperature': 0.7,
            'backend': 'llama.cpp',
            'metal': true,
          },
          isInternal: true,
        );


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
    debugPrint('LUMARA API: Best provider: ${bestProvider?.name ?? 'None'}');
  }

  /// Update download state service for a model
  void _updateDownloadStateForModel(LLMProviderConfig config, bool isAvailable) {
    try {
      // Get the model ID for this provider
      String modelId;
      switch (config.provider) {
        case LLMProvider.qwen4b:
          modelId = 'Qwen3-4B-Instruct-2507-Q4_K_S.gguf';
          break;
        case LLMProvider.llama3b:
          modelId = 'Llama-3.2-3b-Instruct-Q4_K_M.gguf';
          break;
        default:
          return;
      }
      
      // Update the download state service to reflect the model status
      DownloadStateService.instance.updateAvailability(modelId, isAvailable);
      debugPrint('LUMARA API: Updated download state for $modelId: ${isAvailable ? 'Available' : 'Not available'}');
    } catch (e) {
      debugPrint('LUMARA API: Error updating download state for ${config.name}: $e');
    }
  }


  /// Check if internal model is available
  Future<bool> _checkInternalModelAvailability(LLMProviderConfig config) async {
    try {
      if (config.provider == LLMProvider.qwen4b) {
        try {
          final bridge = LumaraNative();
          final isDownloaded = await bridge.isModelDownloaded('Qwen3-4B-Instruct-2507-Q4_K_S.gguf');
          debugPrint('LUMARA API: Qwen3 4B model ${isDownloaded ? 'is' : 'is NOT'} downloaded');
          return isDownloaded;
        } catch (e) {
          debugPrint('LUMARA API: Error checking Qwen3 4B availability: $e');
          return false;
        }
      }

      if (config.provider == LLMProvider.llama3b) {
        try {
          final bridge = LumaraNative();
          final isDownloaded = await bridge.isModelDownloaded('Llama-3.2-3b-Instruct-Q4_K_M.gguf');
          debugPrint('LUMARA API: Llama 3B model ${isDownloaded ? 'is' : 'is NOT'} downloaded');
          return isDownloaded;
        } catch (e) {
          debugPrint('LUMARA API: Error checking Llama 3B availability: $e');
          return false;
        }
      }


      debugPrint('LUMARA API: ${config.name} disabled (use LLMAdapter for native inference)');
      return false; // FIXED: Added missing return statement
    } catch (e) {
      debugPrint('LUMARA API: Health check failed for ${config.name}: $e');
      return false;
    }
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

    // Preference order: Internal models first, then external APIs
    final internal = available.where((c) => c.isInternal).toList();
    if (internal.isNotEmpty) return internal.first;

    final external = available.where((c) => !c.isInternal).toList();
    if (external.isNotEmpty) return external.first;

    return null; // No providers available
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
      _configs[provider] = config.copyWith(apiKey: apiKey);
      await _saveConfigs();
      debugPrint('LUMARA API: Configs saved to SharedPreferences');
      await _detectAvailableProviders();
      
      // Log the final status after updating
      final updatedConfig = _configs[provider];
      debugPrint('LUMARA API: After update - ${config.name} available: ${updatedConfig?.isAvailable}');
    } else {
      debugPrint('LUMARA API: ERROR - Provider $provider not found in configs');
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
  }

  /// Clear all saved API keys (for debugging)
  Future<void> clearAllApiKeys() async {
    debugPrint('LUMARA API: Clearing all saved API keys...');

    // Save empty strings for all external providers to override environment variables
    final clearedConfigs = <String, dynamic>{};
    for (final provider in [LLMProvider.gemini, LLMProvider.openai, LLMProvider.anthropic]) {
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
