// lib/arc/chat/services/lumara_reflection_settings_service.dart
// Service to persist and retrieve LUMARA reflection settings

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../models/engagement_discipline.dart';

/// LUMARA Persona types
enum LumaraPersona {
  auto,       // Auto-adapts based on context
  companion,  // Warm, supportive, adaptive
  therapist,  // Deep therapeutic, ECHO+SAGE
  strategist, // Operational, diagnostic, action-oriented
  challenger, // Direct, pushes growth, high challenge
}

/// Extension to get display names and descriptions for personas
extension LumaraPersonaExtension on LumaraPersona {
  String get displayName {
    switch (this) {
      case LumaraPersona.auto:
        return 'Auto';
      case LumaraPersona.companion:
        return 'The Companion';
      case LumaraPersona.therapist:
        return 'The Therapist';
      case LumaraPersona.strategist:
        return 'The Strategist';
      case LumaraPersona.challenger:
        return 'The Challenger';
    }
  }
  
  String get description {
    switch (this) {
      case LumaraPersona.auto:
        return 'Adapts personality based on context and your needs';
      case LumaraPersona.companion:
        return 'Warm, supportive presence for daily reflection';
      case LumaraPersona.therapist:
        return 'Deep therapeutic support with gentle pacing';
      case LumaraPersona.strategist:
        return 'Sharp, analytical insights with concrete actions';
      case LumaraPersona.challenger:
        return 'Direct feedback that pushes your growth';
    }
  }
  
  String get icon {
    switch (this) {
      case LumaraPersona.auto:
        return '🔄';
      case LumaraPersona.companion:
        return '🤝';
      case LumaraPersona.therapist:
        return '💜';
      case LumaraPersona.strategist:
        return '🎯';
      case LumaraPersona.challenger:
        return '⚡';
    }
  }
}

/// Service for managing LUMARA reflection settings persistence
class LumaraReflectionSettingsService {
  static LumaraReflectionSettingsService? _instance;
  static LumaraReflectionSettingsService get instance {
    _instance ??= LumaraReflectionSettingsService._();
    return _instance!;
  }

  LumaraReflectionSettingsService._();

  SharedPreferences? _prefs;

  // Default values
  static const double _defaultSimilarityThreshold = 0.55;
  static const int _defaultLookbackYears = 5;
  static const int _defaultMaxMatches = 5;
  static const bool _defaultCrossModalEnabled = true;
  static const bool _defaultTherapeuticPresenceEnabled = true;
  static const int _defaultTherapeuticDepthLevel = 2;
  static const bool _defaultTherapeuticAutomaticMode = false;
  static const bool _defaultWebAccessEnabled = false; // Opt-in by default
  static const String _defaultLumaraPersona = 'auto'; // Auto-adapt by default
  
  // Response length defaults
  static const bool _defaultResponseLengthAuto = true; // Auto by default
  static const int _defaultMaxSentences = -1; // -1 means infinity (no limit)
  static const int _defaultSentencesPerParagraph = 4; // Default: 4 sentences per paragraph

  // Engagement discipline defaults
  static const EngagementMode _defaultEngagementMode = EngagementMode.reflect;
  static const bool _defaultAdaptToVeilState = true;
  static const bool _defaultAdaptToAtlasPhase = true;

  // Keys for SharedPreferences
  static const String _keySimilarityThreshold = 'lumara_similarity_threshold';
  static const String _keyLookbackYears = 'lumara_lookback_years';
  static const String _keyMaxMatches = 'lumara_max_matches';
  static const String _keyCrossModalEnabled = 'lumara_cross_modal_enabled';
  static const String _keyTherapeuticPresenceEnabled = 'lumara_therapeutic_presence_enabled';
  static const String _keyTherapeuticDepthLevel = 'lumara_therapeutic_depth_level';
  static const String _keyTherapeuticAutomaticMode = 'lumara_therapeutic_automatic_mode';
  static const String _keyWebAccessEnabled = 'lumara_web_access_enabled';
  static const String _keyLumaraPersona = 'lumara_persona';
  
  // Response length keys
  static const String _keyResponseLengthAuto = 'lumara_response_length_auto';
  static const String _keyMaxSentences = 'lumara_max_sentences';
  static const String _keySentencesPerParagraph = 'lumara_sentences_per_paragraph';

  // Engagement discipline keys
  static const String _keyEngagementSettings = 'lumara_engagement_settings';
  static const String _keyConversationEngagementOverride = 'lumara_conversation_engagement_override';

  /// Initialize the service
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get similarity threshold (default: 0.55)
  Future<double> getSimilarityThreshold() async {
    await initialize();
    return _prefs!.getDouble(_keySimilarityThreshold) ?? _defaultSimilarityThreshold;
  }

  /// Set similarity threshold
  Future<void> setSimilarityThreshold(double value) async {
    await initialize();
    await _prefs!.setDouble(_keySimilarityThreshold, value);
  }

  /// Get lookback years (default: 5)
  Future<int> getLookbackYears() async {
    await initialize();
    return _prefs!.getInt(_keyLookbackYears) ?? _defaultLookbackYears;
  }

  /// Set lookback years
  Future<void> setLookbackYears(int value) async {
    await initialize();
    await _prefs!.setInt(_keyLookbackYears, value);
  }

  /// Get max matches (default: 5)
  Future<int> getMaxMatches() async {
    await initialize();
    return _prefs!.getInt(_keyMaxMatches) ?? _defaultMaxMatches;
  }

  /// Set max matches
  Future<void> setMaxMatches(int value) async {
    await initialize();
    await _prefs!.setInt(_keyMaxMatches, value);
  }

  /// Check if cross-modal awareness is enabled (default: true)
  Future<bool> isCrossModalEnabled() async {
    await initialize();
    return _prefs!.getBool(_keyCrossModalEnabled) ?? _defaultCrossModalEnabled;
  }

  /// Set cross-modal awareness
  Future<void> setCrossModalEnabled(bool value) async {
    await initialize();
    await _prefs!.setBool(_keyCrossModalEnabled, value);
  }

  /// Check if therapeutic presence is enabled (default: true)
  Future<bool> isTherapeuticPresenceEnabled() async {
    await initialize();
    return _prefs!.getBool(_keyTherapeuticPresenceEnabled) ?? _defaultTherapeuticPresenceEnabled;
  }

  /// Set therapeutic presence enabled
  Future<void> setTherapeuticPresenceEnabled(bool value) async {
    await initialize();
    await _prefs!.setBool(_keyTherapeuticPresenceEnabled, value);
  }

  /// Get therapeutic depth level (default: 2, range: 1-3)
  Future<int> getTherapeuticDepthLevel() async {
    await initialize();
    return _prefs!.getInt(_keyTherapeuticDepthLevel) ?? _defaultTherapeuticDepthLevel;
  }

  /// Set therapeutic depth level (1=Light, 2=Moderate, 3=Deep)
  Future<void> setTherapeuticDepthLevel(int value) async {
    await initialize();
    // Clamp value to valid range
    final clampedValue = value.clamp(1, 3);
    await _prefs!.setInt(_keyTherapeuticDepthLevel, clampedValue);
  }

  /// Check if therapeutic automatic mode is enabled (default: false)
  Future<bool> isTherapeuticAutomaticMode() async {
    await initialize();
    return _prefs!.getBool(_keyTherapeuticAutomaticMode) ?? _defaultTherapeuticAutomaticMode;
  }

  /// Set therapeutic automatic mode
  Future<void> setTherapeuticAutomaticMode(bool value) async {
    await initialize();
    await _prefs!.setBool(_keyTherapeuticAutomaticMode, value);
  }

  /// Check if web access is enabled (default: false, opt-in)
  Future<bool> isWebAccessEnabled() async {
    await initialize();
    return _prefs!.getBool(_keyWebAccessEnabled) ?? _defaultWebAccessEnabled;
  }

  /// Set web access enabled
  Future<void> setWebAccessEnabled(bool value) async {
    await initialize();
    await _prefs!.setBool(_keyWebAccessEnabled, value);
  }

  /// Get LUMARA Persona (default: auto)
  Future<LumaraPersona> getLumaraPersona() async {
    await initialize();
    final personaString = _prefs!.getString(_keyLumaraPersona) ?? _defaultLumaraPersona;
    return LumaraPersona.values.firstWhere(
      (p) => p.name == personaString,
      orElse: () => LumaraPersona.auto,
    );
  }

  /// Set LUMARA Persona
  Future<void> setLumaraPersona(LumaraPersona persona) async {
    await initialize();
    await _prefs!.setString(_keyLumaraPersona, persona.name);
  }

  /// Check if response length is set to auto (default: true)
  Future<bool> isResponseLengthAuto() async {
    await initialize();
    return _prefs!.getBool(_keyResponseLengthAuto) ?? _defaultResponseLengthAuto;
  }

  /// Set response length auto mode
  Future<void> setResponseLengthAuto(bool value) async {
    await initialize();
    await _prefs!.setBool(_keyResponseLengthAuto, value);
  }

  /// Get max sentences (-1 means infinity/no limit, default: -1)
  Future<int> getMaxSentences() async {
    await initialize();
    return _prefs!.getInt(_keyMaxSentences) ?? _defaultMaxSentences;
  }

  /// Set max sentences (-1 for infinity/no limit)
  Future<void> setMaxSentences(int value) async {
    await initialize();
    // Allow -1 for infinity, or valid sentence counts: 3, 5, 10, 15
    if (value == -1 || value == 3 || value == 5 || value == 10 || value == 15) {
      await _prefs!.setInt(_keyMaxSentences, value);
    }
  }

  /// Get sentences per paragraph (default: 4, valid: 3, 4, 5)
  Future<int> getSentencesPerParagraph() async {
    await initialize();
    final value = _prefs!.getInt(_keySentencesPerParagraph) ?? _defaultSentencesPerParagraph;
    // Clamp to valid range
    return value.clamp(3, 5);
  }

  /// Set sentences per paragraph (valid: 3, 4, 5)
  Future<void> setSentencesPerParagraph(int value) async {
    await initialize();
    // Clamp to valid range
    final clampedValue = value.clamp(3, 5);
    await _prefs!.setInt(_keySentencesPerParagraph, clampedValue);
  }

  /// Get effective lookback years adjusted for therapeutic depth level
  /// Depth 1 (Light): Reduce by 40%
  /// Depth 2 (Moderate): Standard
  /// Depth 3 (Deep): Extend by 40%
  Future<int> getEffectiveLookbackYears() async {
    final baseYears = await getLookbackYears();
    final therapeuticEnabled = await isTherapeuticPresenceEnabled();
    
    if (!therapeuticEnabled) {
      return baseYears;
    }

    final depthLevel = await getTherapeuticDepthLevel();
    switch (depthLevel) {
      case 1: // Light
        return (baseYears * 0.6).round().clamp(1, 10);
      case 3: // Deep
        return (baseYears * 1.4).round().clamp(1, 10);
      default: // Moderate (2)
        return baseYears;
    }
  }

  /// Get effective max matches adjusted for therapeutic depth level
  /// Depth 1 (Light): Reduce by 40%
  /// Depth 2 (Moderate): Standard
  /// Depth 3 (Deep): Increase by 60%
  Future<int> getEffectiveMaxMatches() async {
    final baseMatches = await getMaxMatches();
    final therapeuticEnabled = await isTherapeuticPresenceEnabled();
    
    if (!therapeuticEnabled) {
      return baseMatches;
    }

    final depthLevel = await getTherapeuticDepthLevel();
    switch (depthLevel) {
      case 1: // Light
        return (baseMatches * 0.6).round().clamp(1, 20);
      case 3: // Deep
        return (baseMatches * 1.6).round().clamp(1, 20);
      default: // Moderate (2)
        return baseMatches;
    }
  }

  /// Load all settings (for UI initialization)
  Future<Map<String, dynamic>> loadAllSettings() async {
    await initialize();
    return {
      'similarityThreshold': await getSimilarityThreshold(),
      'lookbackYears': await getLookbackYears(),
      'maxMatches': await getMaxMatches(),
      'crossModalEnabled': await isCrossModalEnabled(),
      'therapeuticPresenceEnabled': await isTherapeuticPresenceEnabled(),
      'therapeuticDepthLevel': await getTherapeuticDepthLevel(),
      'therapeuticAutomaticMode': await isTherapeuticAutomaticMode(),
      'webAccessEnabled': await isWebAccessEnabled(),
      'lumaraPersona': await getLumaraPersona(),
    };
  }

  /// Save all settings (for UI persistence)
  Future<void> saveAllSettings({
    double? similarityThreshold,
    int? lookbackYears,
    int? maxMatches,
    bool? crossModalEnabled,
    bool? therapeuticPresenceEnabled,
    int? therapeuticDepthLevel,
    bool? therapeuticAutomaticMode,
    bool? webAccessEnabled,
    LumaraPersona? lumaraPersona,
  }) async {
    await initialize();
    
    if (similarityThreshold != null) {
      await setSimilarityThreshold(similarityThreshold);
    }
    if (lookbackYears != null) {
      await setLookbackYears(lookbackYears);
    }
    if (maxMatches != null) {
      await setMaxMatches(maxMatches);
    }
    if (crossModalEnabled != null) {
      await setCrossModalEnabled(crossModalEnabled);
    }
    if (therapeuticPresenceEnabled != null) {
      await setTherapeuticPresenceEnabled(therapeuticPresenceEnabled);
    }
    if (therapeuticDepthLevel != null) {
      await setTherapeuticDepthLevel(therapeuticDepthLevel);
    }
    if (therapeuticAutomaticMode != null) {
      await setTherapeuticAutomaticMode(therapeuticAutomaticMode);
    }
    if (webAccessEnabled != null) {
      await setWebAccessEnabled(webAccessEnabled);
    }
    if (lumaraPersona != null) {
      await setLumaraPersona(lumaraPersona);
    }
  }

  // === ENGAGEMENT DISCIPLINE METHODS ===

  /// Get engagement settings
  Future<EngagementSettings> getEngagementSettings() async {
    await initialize();
    final settingsJson = _prefs!.getString(_keyEngagementSettings);

    if (settingsJson == null) {
      return const EngagementSettings(); // Return default settings
    }

    try {
      return EngagementSettings.fromJson(jsonDecode(settingsJson));
    } catch (e) {
      // If JSON is corrupted, return default settings
      return const EngagementSettings();
    }
  }

  /// Save engagement settings
  Future<void> setEngagementSettings(EngagementSettings settings) async {
    await initialize();
    await _prefs!.setString(_keyEngagementSettings, jsonEncode(settings.toJson()));
  }

  /// Get conversation-specific engagement mode override
  Future<EngagementMode?> getConversationEngagementOverride() async {
    await initialize();
    final overrideString = _prefs!.getString(_keyConversationEngagementOverride);

    if (overrideString == null) {
      return null;
    }

    try {
      return EngagementModeExtension.fromJson(overrideString);
    } catch (e) {
      return null;
    }
  }

  /// Set conversation-specific engagement mode override
  Future<void> setConversationEngagementOverride(EngagementMode? mode) async {
    await initialize();

    if (mode == null) {
      await _prefs!.remove(_keyConversationEngagementOverride);
    } else {
      await _prefs!.setString(_keyConversationEngagementOverride, mode.toJson());
    }
  }

  /// Clear conversation override to return to default mode
  Future<void> clearConversationEngagementOverride() async {
    await setConversationEngagementOverride(null);
  }

  /// Get effective engagement settings with conversation override applied
  Future<EngagementSettings> getEffectiveEngagementSettings() async {
    final settings = await getEngagementSettings();
    final conversationOverride = await getConversationEngagementOverride();

    if (conversationOverride != null) {
      return settings.copyWith(conversationOverride: conversationOverride);
    }

    return settings;
  }

  /// Update engagement mode (affects default, not conversation override)
  Future<void> updateEngagementMode(EngagementMode mode) async {
    final currentSettings = await getEngagementSettings();
    final updatedSettings = currentSettings.copyWith(defaultMode: mode);
    await setEngagementSettings(updatedSettings);
  }

  /// Update synthesis preferences
  Future<void> updateSynthesisPreferences(SynthesisPreferences preferences) async {
    final currentSettings = await getEngagementSettings();
    final updatedSettings = currentSettings.copyWith(synthesisPreferences: preferences);
    await setEngagementSettings(updatedSettings);
  }

  /// Update response discipline
  Future<void> updateResponseDiscipline(ResponseDiscipline discipline) async {
    final currentSettings = await getEngagementSettings();
    final updatedSettings = currentSettings.copyWith(responseDiscipline: discipline);
    await setEngagementSettings(updatedSettings);
  }

  /// Build engagement context for LUMARA Control State integration
  Future<EngagementContext> buildEngagementContext({
    required String atlasPhase,
    required int readinessScore,
    required Map<String, dynamic> veilState,
    required Map<String, dynamic> favoritesProfile,
    bool sentinelAlert = false,
  }) async {
    final settings = await getEffectiveEngagementSettings();

    // Compute behavioral parameters
    final behaviorParams = EngagementBehaviorComputer.computeEngagementBehavior(
      engagementSettings: settings,
      atlasPhase: atlasPhase,
      readinessScore: readinessScore,
      veilState: veilState,
      favoritesProfile: favoritesProfile,
      sentinelAlert: sentinelAlert,
    );

    return EngagementContext(
      settings: settings,
      effectiveMode: settings.activeMode,
      computedBehaviorParams: behaviorParams,
    );
  }

  /// Load all settings including engagement (for UI initialization)
  Future<Map<String, dynamic>> loadAllSettingsWithEngagement() async {
    final baseSettings = await loadAllSettings();
    final engagementSettings = await getEngagementSettings();
    final conversationOverride = await getConversationEngagementOverride();

    return {
      ...baseSettings,
      'engagementSettings': engagementSettings.toJson(),
      'conversationEngagementOverride': conversationOverride?.toJson(),
    };
  }

  /// Save all settings including engagement (for UI persistence)
  Future<void> saveAllSettingsWithEngagement({
    double? similarityThreshold,
    int? lookbackYears,
    int? maxMatches,
    bool? crossModalEnabled,
    bool? therapeuticPresenceEnabled,
    int? therapeuticDepthLevel,
    bool? therapeuticAutomaticMode,
    bool? webAccessEnabled,
    LumaraPersona? lumaraPersona,
    EngagementSettings? engagementSettings,
    EngagementMode? conversationEngagementOverride,
  }) async {
    // Save base settings
    await saveAllSettings(
      similarityThreshold: similarityThreshold,
      lookbackYears: lookbackYears,
      maxMatches: maxMatches,
      crossModalEnabled: crossModalEnabled,
      therapeuticPresenceEnabled: therapeuticPresenceEnabled,
      therapeuticDepthLevel: therapeuticDepthLevel,
      therapeuticAutomaticMode: therapeuticAutomaticMode,
      webAccessEnabled: webAccessEnabled,
      lumaraPersona: lumaraPersona,
    );

    // Save engagement settings
    if (engagementSettings != null) {
      await setEngagementSettings(engagementSettings);
    }

    if (conversationEngagementOverride != null) {
      await setConversationEngagementOverride(conversationEngagementOverride);
    }
  }
}

