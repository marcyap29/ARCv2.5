// lib/arc/chat/services/lumara_reflection_settings_service.dart
// Service to persist and retrieve LUMARA reflection settings

import 'package:shared_preferences/shared_preferences.dart';

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

  // Keys for SharedPreferences
  static const String _keySimilarityThreshold = 'lumara_similarity_threshold';
  static const String _keyLookbackYears = 'lumara_lookback_years';
  static const String _keyMaxMatches = 'lumara_max_matches';
  static const String _keyCrossModalEnabled = 'lumara_cross_modal_enabled';
  static const String _keyTherapeuticPresenceEnabled = 'lumara_therapeutic_presence_enabled';
  static const String _keyTherapeuticDepthLevel = 'lumara_therapeutic_depth_level';

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
  }
}

