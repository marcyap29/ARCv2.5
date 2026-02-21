// lib/chronicle/dual/services/lumara_connection_fade_preferences.dart
//
// User preference for how long connections (causal chains, learning moments)
// stay in context before fading. Options: weeks, months, years.

import 'package:shared_preferences/shared_preferences.dart';

const String _kFadeDaysKey = 'lumara_connection_fade_days';

/// Preset options for connection memory window (how long before items fade).
enum ConnectionFadePreset {
  weeks2(14, '2 weeks'),
  weeks4(28, '4 weeks'),
  month1(30, '1 month'),
  months3(90, '3 months'),
  months6(180, '6 months'),
  year1(365, '1 year'),
  years2(730, '2 years');

  const ConnectionFadePreset(this.days, this.label);
  final int days;
  final String label;

  /// Default preset (6 months).
  static const ConnectionFadePreset defaultPreset = ConnectionFadePreset.months6;
}

/// Default fade in days when no preference is set (6 months).
const int defaultFadeDays = 180;

/// Persists and reads the user's chosen connection memory window (fade duration).
class LumaraConnectionFadePreferences {
  /// Returns the number of days after which connections fade from context.
  /// Uses stored preference or [defaultFadeDays] (6 months).
  static Future<int> getFadeDays() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_kFadeDaysKey);
    if (value == null || value < 1) return defaultFadeDays;
    return value;
  }

  /// Saves the fade duration in days. Use a value from [ConnectionFadePreset.days]
  /// or any positive number.
  static Future<void> setFadeDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kFadeDaysKey, days.clamp(1, 365 * 5));
  }

  /// Returns the current preset that matches stored days, or [ConnectionFadePreset.defaultPreset].
  static Future<ConnectionFadePreset> getPreset() async {
    final days = await getFadeDays();
    for (final p in ConnectionFadePreset.values) {
      if (p.days == days) return p;
    }
    return ConnectionFadePreset.defaultPreset;
  }

  /// Saves the chosen preset (sets fade days to preset.days).
  static Future<void> setPreset(ConnectionFadePreset preset) async {
    await setFadeDays(preset.days);
  }
}
