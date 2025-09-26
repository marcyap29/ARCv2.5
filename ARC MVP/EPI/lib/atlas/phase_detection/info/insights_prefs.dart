import 'package:hive/hive.dart';

/// Preferences for Insights features
class InsightsPrefs {
  static const String _boxName = 'insights_prefs';
  static const String _hasSeenIntroKey = 'has_seen_insights_intro';
  
  static Box? _box;

  /// Initialize the preferences box
  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
  }

  /// Check if user has seen the insights intro
  static bool get hasSeenInsightsIntro {
    return _box?.get(_hasSeenIntroKey, defaultValue: false) ?? false;
  }

  /// Mark that user has seen the insights intro
  static Future<void> setHasSeenInsightsIntro() async {
    await _box?.put(_hasSeenIntroKey, true);
  }

  /// Reset intro status (for testing)
  static Future<void> resetIntroStatus() async {
    await _box?.put(_hasSeenIntroKey, false);
  }

  /// Close the box
  static Future<void> close() async {
    await _box?.close();
  }
}
