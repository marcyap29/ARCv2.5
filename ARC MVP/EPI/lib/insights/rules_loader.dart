// lib/insights/rules_loader.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class RuleSpec {
  final String id;
  final bool enabled;
  final int priority;
  final int? windowDays;
  final Map<String, dynamic> when;
  final String templateKey;
  final String gate; // "none" | "rivet" | future gates
  final String deeplinkAnchor;

  RuleSpec({
    required this.id,
    required this.enabled,
    required this.priority,
    required this.windowDays,
    required this.when,
    required this.templateKey,
    required this.gate,
    required this.deeplinkAnchor,
  });

  factory RuleSpec.fromJson(Map<String, dynamic> j) {
    return RuleSpec(
      id: j["id"] as String,
      enabled: (j["enabled"] as bool?) ?? true,
      priority: (j["priority"] as num?)?.toInt() ?? 999,
      windowDays: (j["windowDays"] as num?)?.toInt(),
      when: (j["when"] as Map<String, dynamic>? ?? {}),
      templateKey: j["templateKey"] as String,
      gate: (j["gate"] as String?) ?? "none",
      deeplinkAnchor: (j["deeplinkAnchor"] as String?) ?? "",
    );
  }
}

class RulePack {
  final int version;
  final List<RuleSpec> rules;

  RulePack({required this.version, required this.rules});

  factory RulePack.fromJson(Map<String, dynamic> j) {
    final version = (j["version"] as num?)?.toInt() ?? 1;
    final rulesJson = (j["rules"] as List<dynamic>? ?? []);
    final rules = rulesJson
        .whereType<Map<String, dynamic>>()
        .map((m) => RuleSpec.fromJson(m))
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return RulePack(version: version, rules: rules);
  }
}

Future<RulePack> loadInsightRules({String assetPath = "assets/insights/rules_v1.json"}) async {
  final raw = await rootBundle.loadString(assetPath);
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return RulePack.fromJson(decoded);
}
