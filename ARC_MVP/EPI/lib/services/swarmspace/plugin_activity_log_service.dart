// lib/services/swarmspace/plugin_activity_log_service.dart
//
// Local plugin activity: SharedPreferences counter with monthly reset.
// No Firestore. No network. Call logActivity(pluginId) after every successful plugin invocation.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String _key = 'plugin_activity_current_month';

String _currentMonth() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

/// Runs monthly reset if stored month != current month. Returns decoded data (counts may be cleared).
Future<Map<String, dynamic>> _readAndMaybeReset(SharedPreferences prefs) async {
  final raw = prefs.getString(_key);
  Map<String, dynamic> data = {};
  if (raw != null) {
    try {
      data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      data = {};
    }
  }
  final storedMonth = data['month'] as String?;
  final nowMonth = _currentMonth();
  if (storedMonth != nowMonth) {
    data = {'month': nowMonth, 'counts': {}, 'total': 0};
    await prefs.setString(_key, jsonEncode(data));
  }
  return data;
}

/// Service to log and read plugin activity. All data is local; resets at the start of each calendar month.
class PluginActivityLogService {
  PluginActivityLogService._();
  static final PluginActivityLogService instance = PluginActivityLogService._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _prefsAsync async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Call this after every successful plugin invocation.
  /// [pluginId] matches the plugin_id used in PLUGIN_REGISTRY.
  Future<void> logActivity(String pluginId) async {
    if (pluginId.isEmpty) return;
    final prefs = await _prefsAsync;
    final data = await _readAndMaybeReset(prefs);
    final counts = Map<String, int>.from((data['counts'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ?? {});
    final total = (data['total'] as num?)?.toInt() ?? 0;
    counts[pluginId] = (counts[pluginId] ?? 0) + 1;
    final newData = {
      'month': data['month'] ?? _currentMonth(),
      'counts': counts,
      'total': total + 1,
    };
    await prefs.setString(_key, jsonEncode(newData));
  }

  /// Returns the current month's counts for all plugins.
  Future<Map<String, int>> getActivityCounts() async {
    final prefs = await _prefsAsync;
    final data = await _readAndMaybeReset(prefs);
    final counts = (data['counts'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ?? {};
    return Map<String, int>.from(counts);
  }

  /// Returns total calls across all plugins this month.
  Future<int> getTotalThisMonth() async {
    final prefs = await _prefsAsync;
    final data = await _readAndMaybeReset(prefs);
    return (data['total'] as num?)?.toInt() ?? 0;
  }

  /// Returns the reset date (first day of next month).
  DateTime getNextResetDate() {
    final now = DateTime.now();
    if (now.month == 12) {
      return DateTime(now.year + 1, 1, 1);
    }
    return DateTime(now.year, now.month + 1, 1);
  }

  /// Clears all counts. Used for testing only.
  Future<void> clearForTesting() async {
    final prefs = await _prefsAsync;
    await prefs.remove(_key);
    _prefs = null;
  }
}
