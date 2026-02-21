// lib/shared/ui/settings/advanced_analytics_preference_service.dart
// Service to manage Advanced Analytics toggle preference

import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing Advanced Analytics visibility preference
class AdvancedAnalyticsPreferenceService {
  static AdvancedAnalyticsPreferenceService? _instance;
  static AdvancedAnalyticsPreferenceService get instance {
    _instance ??= AdvancedAnalyticsPreferenceService._();
    return _instance!;
  }

  AdvancedAnalyticsPreferenceService._();

  SharedPreferences? _prefs;
  static const String _keyAdvancedAnalyticsEnabled = 'advanced_analytics_enabled';
  static const bool _defaultEnabled = false; // Default is OFF

  /// Initialize the service
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get Advanced Analytics enabled state (default: false)
  Future<bool> isAdvancedAnalyticsEnabled() async {
    await initialize();
    return _prefs!.getBool(_keyAdvancedAnalyticsEnabled) ?? _defaultEnabled;
  }

  /// Set Advanced Analytics enabled state
  Future<void> setAdvancedAnalyticsEnabled(bool enabled) async {
    await initialize();
    await _prefs!.setBool(_keyAdvancedAnalyticsEnabled, enabled);
  }
}

