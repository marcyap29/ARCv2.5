// lib/shared/ui/settings/advanced_analytics_preference_service.dart
// Service to manage Advanced Analytics toggle preference

import 'package:shared_preferences/shared_preferences.dart';

/// Tab configuration mode for Insights view
enum TabConfigurationMode {
  twoTabs,   // Phase, Settings
  fourTabs, // Phase, Health, Analytics, Settings
}

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
  static const String _keyTabConfigurationMode = 'tab_configuration_mode';
  static const bool _defaultEnabled = false; // Default is OFF
  static const TabConfigurationMode _defaultTabMode = TabConfigurationMode.twoTabs;

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

  /// Get tab configuration mode (default: twoTabs)
  Future<TabConfigurationMode> getTabConfigurationMode() async {
    await initialize();
    final modeIndex = _prefs!.getInt(_keyTabConfigurationMode);
    if (modeIndex == null) {
      return _defaultTabMode;
    }
    return TabConfigurationMode.values[modeIndex];
  }

  /// Set tab configuration mode
  Future<void> setTabConfigurationMode(TabConfigurationMode mode) async {
    await initialize();
    await _prefs!.setInt(_keyTabConfigurationMode, mode.index);
  }

  /// Get effective tab count based on current settings
  /// If Advanced Analytics is enabled, it overrides tab configuration
  Future<int> getEffectiveTabCount() async {
    final analyticsEnabled = await isAdvancedAnalyticsEnabled();
    if (analyticsEnabled) {
      return 4; // Always 4 tabs when Advanced Analytics is enabled
    }
    final tabMode = await getTabConfigurationMode();
    return tabMode == TabConfigurationMode.fourTabs ? 4 : 2;
  }
}

