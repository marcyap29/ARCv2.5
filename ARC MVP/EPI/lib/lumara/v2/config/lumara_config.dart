// lib/lumara/v2/config/lumara_config.dart
// Simplified configuration for LUMARA v2.0

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';

/// Simplified configuration for LUMARA v2.0
class LumaraConfig {
  static LumaraConfig? _instance;
  static LumaraConfig get instance => _instance ??= LumaraConfig._();
  
  LumaraConfig._();
  
  // Core configuration
  late final LumaraAPIConfig _apiConfig;
  SharedPreferences? _prefs;
  
  // Settings
  LumaraSettings _settings = LumaraSettings.defaults();
  
  /// Initialize configuration
  Future<void> initialize() async {
    try {
      debugPrint('LUMARA Config: Initializing...');
      
      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();
      
      // Initialize API configuration
      _apiConfig = LumaraAPIConfig.instance;
      await _apiConfig.initialize();
      
      // Load settings
      await _loadSettings();
      
      debugPrint('LUMARA Config: Initialized successfully');
    } catch (e) {
      debugPrint('LUMARA Config: Initialization failed: $e');
      rethrow;
    }
  }
  
  /// Get API configuration
  LumaraAPIConfig get apiConfig => _apiConfig;
  
  /// Get current settings
  LumaraSettings get settings => _settings;
  
  /// Update settings
  Future<void> updateSettings(LumaraSettings newSettings) async {
    try {
      _settings = newSettings;
      await _saveSettings();
      debugPrint('LUMARA Config: Settings updated');
    } catch (e) {
      debugPrint('LUMARA Config: Error updating settings: $e');
      rethrow;
    }
  }
  
  /// Check if LUMARA is properly configured
  Future<bool> isConfigured() async {
    try {
      final availableProviders = _apiConfig.getAvailableProviders();
      return availableProviders.isNotEmpty;
    } catch (e) {
      debugPrint('LUMARA Config: Error checking configuration: $e');
      return false;
    }
  }
  
  /// Get best available provider
  Future<LLMProvider?> getBestProvider() async {
    try {
      return _apiConfig.getBestProvider();
    } catch (e) {
      debugPrint('LUMARA Config: Error getting best provider: $e');
      return null;
    }
  }
  
  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      if (_prefs == null) return;
      
      final settingsJson = _prefs!.getString('lumara_settings');
      if (settingsJson != null) {
        _settings = LumaraSettings.fromJson(settingsJson);
      }
    } catch (e) {
      debugPrint('LUMARA Config: Error loading settings: $e');
      _settings = LumaraSettings.defaults();
    }
  }
  
  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      if (_prefs == null) return;
      
      await _prefs!.setString('lumara_settings', _settings.toJson());
    } catch (e) {
      debugPrint('LUMARA Config: Error saving settings: $e');
    }
  }
}

/// LUMARA settings
class LumaraSettings {
  final bool enableJournalAccess;
  final bool enableDraftAccess;
  final bool enableChatAccess;
  final bool enableMediaAccess;
  final bool enablePhaseDetection;
  final int maxContextEntries;
  final int contextDaysBack;
  final LumaraResponseStyle responseStyle;
  final Map<String, dynamic> customSettings;
  
  const LumaraSettings({
    this.enableJournalAccess = true,
    this.enableDraftAccess = true,
    this.enableChatAccess = true,
    this.enableMediaAccess = true,
    this.enablePhaseDetection = true,
    this.maxContextEntries = 50,
    this.contextDaysBack = 30,
    this.responseStyle = LumaraResponseStyle.balanced,
    this.customSettings = const {},
  });
  
  factory LumaraSettings.defaults() {
    return const LumaraSettings();
  }
  
  factory LumaraSettings.fromJson(String jsonString) {
    try {
      // Simple JSON parsing for settings
      // TODO: Implement proper JSON parsing
      return LumaraSettings.defaults();
    } catch (e) {
      debugPrint('LUMARA Settings: Error parsing JSON: $e');
      return LumaraSettings.defaults();
    }
  }
  
  String toJson() {
    // Simple JSON serialization for settings
    // TODO: Implement proper JSON serialization
    return '{}';
  }
  
  LumaraSettings copyWith({
    bool? enableJournalAccess,
    bool? enableDraftAccess,
    bool? enableChatAccess,
    bool? enableMediaAccess,
    bool? enablePhaseDetection,
    int? maxContextEntries,
    int? contextDaysBack,
    LumaraResponseStyle? responseStyle,
    Map<String, dynamic>? customSettings,
  }) {
    return LumaraSettings(
      enableJournalAccess: enableJournalAccess ?? this.enableJournalAccess,
      enableDraftAccess: enableDraftAccess ?? this.enableDraftAccess,
      enableChatAccess: enableChatAccess ?? this.enableChatAccess,
      enableMediaAccess: enableMediaAccess ?? this.enableMediaAccess,
      enablePhaseDetection: enablePhaseDetection ?? this.enablePhaseDetection,
      maxContextEntries: maxContextEntries ?? this.maxContextEntries,
      contextDaysBack: contextDaysBack ?? this.contextDaysBack,
      responseStyle: responseStyle ?? this.responseStyle,
      customSettings: customSettings ?? this.customSettings,
    );
  }
}

/// Response style for LUMARA
enum LumaraResponseStyle {
  concise,
  balanced,
  detailed,
  creative,
}
