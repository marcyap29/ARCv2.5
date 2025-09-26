import 'package:hive/hive.dart';

/// Registry for tracking which tips have been seen
class TipRegistry {
  static const String _boxName = 'tip_registry';
  static Box? _box;

  /// Initialize the tip registry box
  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
  }

  /// Check if a tip has been seen
  static bool hasSeenTip(String tipId) {
    return _box?.get(tipId, defaultValue: false) ?? false;
  }

  /// Mark a tip as seen
  static Future<void> markSeen(String tipId) async {
    await _box?.put(tipId, true);
  }

  /// Reset all tips (for testing)
  static Future<void> resetAll() async {
    await _box?.clear();
  }

  /// Close the box
  static Future<void> close() async {
    await _box?.close();
  }
}

/// Tip IDs for consistent tracking
class TipId {
  static const String patterns = 'patterns_tip';
  static const String patternsScreen = 'patterns_screen_tip';
  static const String safety = 'safety_tip';
  static const String aurora = 'aurora_tip';
  static const String veil = 'veil_tip';
}
