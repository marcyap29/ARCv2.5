// lib/arc/chat/prompt_optimization/response_cache.dart
// Simple response cache by (userId, query) for cacheable use cases.

import 'package:shared_preferences/shared_preferences.dart';

abstract class ResponseCache {
  Future<String?> get(String userId, String query);
  Future<void> set(String userId, String query, String content);
}

const String _prefix = 'lumara_prompt_cache_';
const int _maxKeys = 200;
const int _maxValueLength = 8000;

/// In-memory + SharedPreferences cache with key cap and size limit.
class DefaultResponseCache implements ResponseCache {
  DefaultResponseCache() : _memory = <String, String>{};

  final Map<String, String> _memory;
  SharedPreferences? _prefs;
  final List<String> _keyOrder = [];

  String _key(String userId, String query) {
    final normalized = query.trim().toLowerCase();
    return '$_prefix${userId}_${normalized.hashCode}';
  }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<String?> get(String userId, String query) async {
    final k = _key(userId, query);
    if (_memory.containsKey(k)) return _memory[k];
    final prefs = await _getPrefs();
    return prefs.getString(k);
  }

  @override
  Future<void> set(String userId, String query, String content) async {
    if (content.length > _maxValueLength) return;
    final k = _key(userId, query);
    _memory[k] = content;
    _keyOrder.remove(k);
    _keyOrder.add(k);
    while (_keyOrder.length > _maxKeys) {
      final evict = _keyOrder.removeAt(0);
      _memory.remove(evict);
      final prefs = await _getPrefs();
      await prefs.remove(evict);
    }
    final prefs = await _getPrefs();
    await prefs.setString(k, content);
  }
}
