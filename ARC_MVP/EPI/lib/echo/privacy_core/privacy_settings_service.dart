// Privacy Settings Service for user-configurable PII protection

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/services/lumara/pii_scrub.dart';

import 'privacy_settings_types.dart';

export 'privacy_settings_types.dart';

/// Service for managing privacy settings (singleton). Syncs to [PiiScrubber] for LUMARA egress.
class PrivacySettingsService {
  PrivacySettingsService._();
  static final PrivacySettingsService instance = PrivacySettingsService._();
  factory PrivacySettingsService() => instance;

  static const String _keyPrivacyLevel = 'privacy_level';
  static const String _keyPrivacySettings = 'privacy_settings';
  static const String _keyFirstTimeSetup = 'privacy_first_time_setup';

  PrivacyLevel _currentLevel = PrivacyLevel.balanced;
  PrivacySettings _currentSettings = PrivacySettings.fromLevel(PrivacyLevel.balanced);
  bool _isFirstTimeSetup = true;

  PrivacyLevel get currentLevel => _currentLevel;
  PrivacySettings get currentSettings => _currentSettings;
  bool get isFirstTimeSetup => _isFirstTimeSetup;

  void _syncLumaraEgress() {
    PiiScrubber.applyEgressPrivacySettings(_currentSettings);
  }

  /// Initialize privacy settings from storage
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    final levelIndex = prefs.getInt(_keyPrivacyLevel);
    if (levelIndex != null && levelIndex >= 0 && levelIndex < PrivacyLevel.values.length) {
      _currentLevel = PrivacyLevel.values[levelIndex];
    }

    final settingsJson = prefs.getString(_keyPrivacySettings);
    if (settingsJson != null && settingsJson.trim().isNotEmpty && settingsJson.trim() != '{}') {
      try {
        final decoded = jsonDecode(settingsJson);
        if (decoded is Map<String, dynamic>) {
          _currentSettings = PrivacySettings.fromJson(decoded);
        } else {
          _currentSettings = PrivacySettings.fromLevel(_currentLevel);
        }
      } catch (e) {
        _currentSettings = PrivacySettings.fromLevel(_currentLevel);
      }
    } else {
      _currentSettings = PrivacySettings.fromLevel(_currentLevel);
    }

    _isFirstTimeSetup = !(prefs.getBool(_keyFirstTimeSetup) ?? false);
    _syncLumaraEgress();
  }

  /// Set privacy level and update settings
  Future<void> setPrivacyLevel(PrivacyLevel level) async {
    _currentLevel = level;

    if (level != PrivacyLevel.custom) {
      _currentSettings = PrivacySettings.fromLevel(level);
    }

    await _saveSettings();
  }

  /// Update custom privacy settings
  Future<void> updateSettings(PrivacySettings settings) async {
    _currentSettings = settings;
    _currentLevel = PrivacyLevel.custom;
    await _saveSettings();
  }

  /// Complete first-time setup
  Future<void> completeFirstTimeSetup() async {
    _isFirstTimeSetup = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstTimeSetup, true);
  }

  /// Save settings to storage
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPrivacyLevel, _currentLevel.index);
    await prefs.setString(_keyPrivacySettings, jsonEncode(_currentSettings.toJson()));
    _syncLumaraEgress();
  }

  /// Get privacy impact description
  String getPrivacyImpactDescription() {
    switch (_currentLevel) {
      case PrivacyLevel.maximum:
        return 'All personal information is thoroughly protected. Some text readability may be reduced.';
      case PrivacyLevel.balanced:
        return 'Good privacy protection while maintaining text readability and utility.';
      case PrivacyLevel.minimal:
        return 'Basic privacy protection focused on sensitive data like SSNs and credit cards.';
      case PrivacyLevel.custom:
        return 'Custom privacy settings based on your specific preferences.';
    }
  }

  /// Get expected performance impact
  String getPerformanceImpact() {
    final processingTime = _currentSettings.maxProcessingTime;
    final realTimeEnabled = _currentSettings.enableRealTimeScanning;

    if (!realTimeEnabled) return 'Minimal impact - protection on-demand only';
    if (processingTime < 500) return 'Low impact - optimized for speed';
    if (processingTime < 1000) return 'Moderate impact - balanced processing';
    return 'Higher impact - thorough protection';
  }

  /// Reset to default settings
  Future<void> resetToDefaults() async {
    await setPrivacyLevel(PrivacyLevel.balanced);
  }
}
