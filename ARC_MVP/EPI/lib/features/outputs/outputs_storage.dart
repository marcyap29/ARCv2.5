import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'output_model.dart';

class OutputsStorage {
  static const _key = 'lumara_outputs';

  static Future<List<WorkflowOutput>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) {
          try {
            return WorkflowOutput.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<WorkflowOutput>()
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> save(WorkflowOutput output) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadAll();
    // Keep max 50 outputs
    final updated = [output, ...existing].take(50).toList();
    await prefs.setStringList(
      _key,
      updated.map((o) => jsonEncode(o.toJson())).toList(),
    );
  }

  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadAll();
    final updated = existing.where((o) => o.id != id).toList();
    await prefs.setStringList(
      _key,
      updated.map((o) => jsonEncode(o.toJson())).toList(),
    );
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

