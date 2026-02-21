// lib/shared/ui/settings/voiceover_preference_service.dart
// Service to manage Voiceover mode preference for AI responses

import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing Voiceover mode preference
class VoiceoverPreferenceService {
  static VoiceoverPreferenceService? _instance;
  static VoiceoverPreferenceService get instance {
    _instance ??= VoiceoverPreferenceService._();
    return _instance!;
  }

  VoiceoverPreferenceService._();

  SharedPreferences? _prefs;
  static const String _keyVoiceoverEnabled = 'voiceover_enabled';
  static const bool _defaultEnabled = false; // Default is OFF

  /// Initialize the service
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get Voiceover enabled state (default: false)
  Future<bool> isVoiceoverEnabled() async {
    await initialize();
    return _prefs!.getBool(_keyVoiceoverEnabled) ?? _defaultEnabled;
  }

  /// Set Voiceover enabled state
  Future<void> setVoiceoverEnabled(bool enabled) async {
    await initialize();
    await _prefs!.setBool(_keyVoiceoverEnabled, enabled);
  }
}

