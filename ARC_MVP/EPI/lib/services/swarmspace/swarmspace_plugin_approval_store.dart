// lib/services/swarmspace/swarmspace_plugin_approval_store.dart
//
// Per-plugin approval persistence for LUMARA–SwarmSpace docking (first-use
// consent interrupt). Approval is stored per plugin, not per session.
// See LUMARA_SwarmSpace_Docking_Spec: "swarmspace_plugin_approved: { brave_search: true, ... }"

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String _keyApproved = 'swarmspace_plugin_approved';

/// Persists which SwarmSpace plugins the user has approved for research.
/// First-time use of a plugin triggers consent UI; once approved, never again.
class SwarmSpacePluginApprovalStore {
  SwarmSpacePluginApprovalStore._();
  static final SwarmSpacePluginApprovalStore instance = SwarmSpacePluginApprovalStore._();

  SharedPreferences? _prefs;
  Map<String, bool>? _cache;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<Map<String, bool>> _load() async {
    if (_cache != null) return _cache!;
    final prefs = await _getPrefs();
    final raw = prefs.getString(_keyApproved);
    if (raw == null || raw.isEmpty) {
      _cache = {};
      return _cache!;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>?;
      _cache = decoded?.map((k, v) => MapEntry(k, v == true)) ?? {};
    } catch (_) {
      _cache = {};
    }
    return _cache!;
  }

  Future<void> _save() async {
    if (_cache == null) return;
    final prefs = await _getPrefs();
    await prefs.setString(_keyApproved, jsonEncode(_cache));
  }

  /// Returns true if the user has approved this plugin (first-use consent already given).
  Future<bool> isApproved(String pluginId) async {
    final map = await _load();
    return map[pluginId] == true;
  }

  /// Mark the plugin as approved so the consent interrupt does not show again.
  Future<void> setApproved(String pluginId) async {
    final map = await _load();
    map[pluginId] = true;
    await _save();
  }

  /// All plugin IDs the user has approved.
  Future<Set<String>> getApprovedPlugins() async {
    final map = await _load();
    return map.entries.where((e) => e.value).map((e) => e.key).toSet();
  }
}
