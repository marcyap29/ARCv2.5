// lib/lumara/llm/prompts/prompt_profile_manager.dart
// Manages LUMARA prompt profiles and model-specific configurations

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Context flags for profile selection
class PromptContext {
  final bool isOffline;
  final bool isFastMode;
  final bool isPhaseFocus;
  final bool isLowLatency;

  const PromptContext({
    this.isOffline = false,
    this.isFastMode = false,
    this.isPhaseFocus = false,
    this.isLowLatency = false,
  });
}

/// Generation settings for a specific model
class GenerationSettings {
  final double temperature;
  final double topP;
  final double repeatPenalty;
  final int maxTokens;
  final double minP;

  const GenerationSettings({
    required this.temperature,
    required this.topP,
    required this.repeatPenalty,
    required this.maxTokens,
    required this.minP,
  });

  factory GenerationSettings.fromJson(Map<String, dynamic> json) {
    return GenerationSettings(
      temperature: (json['temperature'] as num).toDouble(),
      topP: (json['top_p'] as num).toDouble(),
      repeatPenalty: (json['repeat_penalty'] as num).toDouble(),
      maxTokens: json['max_tokens'] as int,
      minP: (json['min_p'] as num).toDouble(),
    );
  }
}

/// Model configuration
class ModelConfig {
  final String defaultProfile;
  final String appendSystem;
  final GenerationSettings generation;

  const ModelConfig({
    required this.defaultProfile,
    required this.appendSystem,
    required this.generation,
  });

  factory ModelConfig.fromJson(Map<String, dynamic> json) {
    return ModelConfig(
      defaultProfile: json['default_profile'] as String,
      appendSystem: json['append_system'] as String,
      generation: GenerationSettings.fromJson(json['generation'] as Map<String, dynamic>),
    );
  }
}

/// Prompt profile data
class PromptProfile {
  final String systemPrompt;

  const PromptProfile({
    required this.systemPrompt,
  });

  factory PromptProfile.fromJson(Map<String, dynamic> json) {
    return PromptProfile(
      systemPrompt: json['system_prompt'] as String,
    );
  }
}

/// Complete prompt profiles configuration
class PromptProfilesConfig {
  final Map<String, PromptProfile> profiles;
  final Map<String, ModelConfig> models;

  const PromptProfilesConfig({
    required this.profiles,
    required this.models,
  });

  factory PromptProfilesConfig.fromJson(Map<String, dynamic> json) {
    final profilesJson = json['profiles'] as Map<String, dynamic>;
    final modelsJson = json['models'] as Map<String, dynamic>;

    final profiles = <String, PromptProfile>{};
    for (final entry in profilesJson.entries) {
      profiles[entry.key] = PromptProfile.fromJson(entry.value as Map<String, dynamic>);
    }

    final models = <String, ModelConfig>{};
    for (final entry in modelsJson.entries) {
      models[entry.key] = ModelConfig.fromJson(entry.value as Map<String, dynamic>);
    }

    return PromptProfilesConfig(profiles: profiles, models: models);
  }
}

/// Manages LUMARA prompt profiles and model-specific configurations
class PromptProfileManager {
  static PromptProfileManager? _instance;
  PromptProfilesConfig? _config;

  PromptProfileManager._();

  static PromptProfileManager get instance {
    _instance ??= PromptProfileManager._();
    return _instance!;
  }

  /// Initialize the manager by loading the prompt profiles JSON
  Future<void> initialize() async {
    try {
      final file = File('lib/lumara/llm/prompts/lumara_prompt_profiles.json');
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      _config = PromptProfilesConfig.fromJson(jsonData);
      debugPrint('PromptProfileManager: Loaded ${_config!.profiles.length} profiles and ${_config!.models.length} model configs');
    } catch (e) {
      debugPrint('PromptProfileManager: Failed to load prompt profiles: $e');
      // Fallback to default configuration
      _config = _createDefaultConfig();
    }
  }

  /// Get the best profile for a given model and context
  String getProfileForModel(String modelId, PromptContext context) {
    if (_config == null) {
      debugPrint('PromptProfileManager: Config not initialized, using default profile');
      return 'core';
    }

    final modelConfig = _config!.models[modelId];
    if (modelConfig == null) {
      debugPrint('PromptProfileManager: Model $modelId not found, using core profile');
      return 'core';
    }

    // Override profile based on context
    if (context.isPhaseFocus) {
      return 'phase';
    } else if (context.isFastMode || context.isLowLatency) {
      return 'mobile';
    } else if (context.isOffline) {
      return 'offline';
    }

    return modelConfig.defaultProfile;
  }

  /// Get the complete system prompt for a model and context
  String getSystemPrompt(String modelId, PromptContext context) {
    if (_config == null) {
      return _getFallbackSystemPrompt();
    }

    final profile = getProfileForModel(modelId, context);
    final profileData = _config!.profiles[profile];
    final modelConfig = _config!.models[modelId];

    if (profileData == null) {
      debugPrint('PromptProfileManager: Profile $profile not found, using fallback');
      return _getFallbackSystemPrompt();
    }

    String systemPrompt = profileData.systemPrompt;
    
    if (modelConfig != null) {
      systemPrompt += '\n${modelConfig.appendSystem}';
    }

    return systemPrompt;
  }

  /// Get generation settings for a model
  GenerationSettings? getGenerationSettings(String modelId) {
    if (_config == null) return null;
    
    final modelConfig = _config!.models[modelId];
    return modelConfig?.generation;
  }

  /// Get all available model IDs
  List<String> getAvailableModels() {
    if (_config == null) return [];
    return _config!.models.keys.toList();
  }

  /// Get all available profile names
  List<String> getAvailableProfiles() {
    if (_config == null) return ['core'];
    return _config!.profiles.keys.toList();
  }

  /// Check if a model is supported
  bool isModelSupported(String modelId) {
    if (_config == null) return false;
    return _config!.models.containsKey(modelId);
  }

  /// Create a context for common scenarios
  static PromptContext createContext({
    bool isOffline = false,
    bool isFastMode = false,
    bool isPhaseFocus = false,
    bool isLowLatency = false,
  }) {
    return PromptContext(
      isOffline: isOffline,
      isFastMode: isFastMode,
      isPhaseFocus: isPhaseFocus,
      isLowLatency: isLowLatency,
    );
  }

  /// Fallback system prompt when config is not available
  String _getFallbackSystemPrompt() {
    return '''You are LUMARA, the on-device reflection core of the Evolving Personal Intelligence (EPI) system.
Your purpose is to infer meaning and provide concise guidance that supports personal growth through the ARC and ATLAS frameworks.

Output only a single JSON object. No prose.
Output Format (JSON):
{
  "intent": "...",
  "emotion": "...",
  "phase": "...",
  "insight": "..."
}''';
  }

  /// Create default configuration as fallback
  PromptProfilesConfig _createDefaultConfig() {
    return PromptProfilesConfig(
      profiles: {
        'core': PromptProfile(
          systemPrompt: _getFallbackSystemPrompt(),
        ),
      },
      models: {},
    );
  }
}
