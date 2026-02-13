import 'package:shared_preferences/shared_preferences.dart';

const String _kPrefix = 'chronicle_pattern_index_last_updated';

/// Persists and reads the last time the CHRONICLE pattern index (vectorizer) was updated.
class PatternIndexLastUpdatedStorage {
  /// Key for current user (default_user when not signed in).
  static String _key(String userId) => '${_kPrefix}_$userId';

  /// Save last updated timestamp for [userId].
  static Future<void> setLastUpdated(String userId, DateTime when) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), when.toIso8601String());
  }

  /// Read last updated timestamp for [userId], or null if never updated.
  static Future<DateTime?> getLastUpdated(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key(userId));
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}
