import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const String _kPrefix = 'chronicle_theme_ignore_list';

/// Persists and reads the list of CHRONICLE theme labels (canonical labels)
/// that the user has chosen to ignore in the pattern index.
/// Ignored themes are excluded from vectorized pattern display and from
/// pattern queries (e.g. LUMARA context).
class ChronicleThemeIgnoreListStorage {
  static String _key(String userId) => '${_kPrefix}_$userId';

  /// Save the ignore list for [userId]. Replaces any existing list.
  static Future<void> setIgnored(String userId, List<String> canonicalLabels) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), jsonEncode(canonicalLabels));
  }

  /// Read the ignore list for [userId], or empty list if none.
  static Future<List<String>> getIgnored(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key(userId));
    if (s == null || s.isEmpty) return [];
    final decoded = jsonDecode(s);
    if (decoded is! List) return [];
    return List<String>.from(decoded.map((e) => e.toString()));
  }

  /// Add a single theme label to the ignore list for [userId].
  static Future<void> addIgnored(String userId, String canonicalLabel) async {
    final list = await getIgnored(userId);
    final trimmed = canonicalLabel.trim();
    if (trimmed.isEmpty || list.contains(trimmed)) return;
    list.add(trimmed);
    await setIgnored(userId, list);
  }

  /// Remove a theme label from the ignore list for [userId].
  static Future<void> removeIgnored(String userId, String canonicalLabel) async {
    final list = await getIgnored(userId);
    final trimmed = canonicalLabel.trim();
    list.remove(trimmed);
    await setIgnored(userId, list);
  }
}
