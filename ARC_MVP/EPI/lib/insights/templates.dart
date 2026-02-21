// lib/insights/templates.dart
import 'dart:core';

class InsightTemplate {
  final String title;
  final String body;
  final String anchor; // Patterns deeplink anchor, e.g., "top_words"
  const InsightTemplate({required this.title, required this.body, required this.anchor});
}

/// Simple placeholder replacement + light cleanup for null/empty values.
/// Example: formatTemplate("Hi {name}, {opt}", {"name":"Marc", "opt":null});
String formatTemplate(String input, Map<String, String?> params) {
  var out = input;
  params.forEach((k, v) {
    out = out.replaceAll('{$k}', v ?? '');
  });
  // light cleanup: collapse double spaces, fix ", ,", " ,", ", , and"
  out = out.replaceAll(RegExp(r'\s{2,}'), ' ');
  out = out.replaceAll(', ,', ',');
  out = out.replaceAll(' ,', ',');
  out = out.replaceAll(RegExp(r'\s+,(\s+|$)'), ', ');
  out = out.replaceAll(RegExp(r'\s+\.'), '.');
  out = out.trim();
  // Remove trailing commas if placeholders removed
  out = out.replaceAll(RegExp(r',\s*\.'), '.');
  out = out.replaceAll(RegExp(r',\s*$'), '');
  return out;
}

/// Template keys referenced by rules_v1.json
/// - TOP_THEMES
/// - PHASE_LEAN
/// - EMOTION_TILT
/// - SAGE_NUDGE
/// - MOMENTUM_UP
/// - MOMENTUM_DOWN
/// - VARIABILITY_STEADYING
/// - STUCK_NUDGE
/// - CONSOLIDATION_AFTER_SURGE
/// - RECOVERY_CARE
/// - THEME_STABILITY
/// - NEW_THEME
const Map<String, InsightTemplate> kInsightTemplates = {
  "TOP_THEMES": InsightTemplate(
    title: "This week's top themes",
    body: "Your frequent words were {w1}{w2Opt}{w3Opt}.",
    anchor: "top_words",
  ),
  // NOTE: supply {w2Opt} as ", {w2}" only if you have w2; same for w3. See helper below.
  "PHASE_LEAN": InsightTemplate(
    title: "Phase trend",
    body: "{rivetPhraseStart} your entries leaned toward {phase} over the past two weeks.",
    anchor: "phase_counts",
  ),
  "EMOTION_TILT": InsightTemplate(
    title: "Overall tone",
    body: "Tone trended {emotionDom}{emotionSecOpt}.",
    anchor: "emotions_sparkline",
  ),
  "SAGE_NUDGE": InsightTemplate(
    title: "Round out your reflection",
    body: "You wrote many {maxTag} notes and fewer {minTag} reflections. Consider a short entry on {minTag}.",
    anchor: "sage_coverage",
  ),
  "MOMENTUM_UP": InsightTemplate(
    title: "Momentum rising",
    body: "Your {phase} momentum increased compared to last week.",
    anchor: "phase_counts",
  ),
  "MOMENTUM_DOWN": InsightTemplate(
    title: "Gentle consolidation",
    body: "Your {phase} momentum eased this week. A brief check-in can help you consolidate.",
    anchor: "phase_counts",
  ),
  "VARIABILITY_STEADYING": InsightTemplate(
    title: "Find a steadying factor",
    body: "You had notable emotional variability while phases mixed. Capture one thing that steadied you.",
    anchor: "emotions_sparkline",
  ),
  "STUCK_NUDGE": InsightTemplate(
    title: "Small next step",
    body: "You mentioned feeling {stuckWord}. Try a two-minute note on one next step.",
    anchor: "top_words",
  ),
  "CONSOLIDATION_AFTER_SURGE": InsightTemplate(
    title: "After the surge",
    body: "Signals suggest consolidation after a recent high-energy stretch. What do you want to preserve?",
    anchor: "phase_counts",
  ),
  "RECOVERY_CARE": InsightTemplate(
    title: "Recovery care",
    body: "Recovery patterns are present. Gentle pacing and shorter entries can support your rhythm.",
    anchor: "emotions_sparkline",
  ),
  "THEME_STABILITY": InsightTemplate(
    title: "Stable themes",
    body: "Your themes stayed consistent this week. Small refinements can deepen clarity.",
    anchor: "top_words",
  ),
  "NEW_THEME": InsightTemplate(
    title: "New theme emerging",
    body: "A fresh theme appeared: {newWord}. Try a quick note on why it matters now.",
    anchor: "top_words",
  ),
};

/// Helpers to build optional segments for placeholders:
/// - joinTopWords(["growth","clarity","change"]) -> "growth, clarity, and change"
/// - emotionSecondary(", with {secondary} mid-week") -> conditional secondary phrase
String joinTopWords(List<String> words) {
  if (words.isEmpty) return '';
  if (words.length == 1) return words.first;
  if (words.length == 2) return "${words[0]} and ${words[1]}";
  final head = words.sublist(0, words.length - 1).join(", ");
  final last = words.last;
  return "$head, and $last";
}

/// Construct optional pieces:
String optWord(String? w, {String prefix = "", String suffix = ""}) {
  if (w == null || w.isEmpty) return "";
  return "$prefix$w$suffix";
}

/// Build the replacement map for TOP_THEMES:
Map<String, String?> buildTopThemesParams(List<String> words) {
  final w1 = words.isNotEmpty ? words[0] : null;
  final w2 = words.length > 1 ? words[1] : null;
  final w3 = words.length > 2 ? words[2] : null;
  return {
    "w1": w1 ?? "",
    "w2Opt": w2 != null ? ", $w2" : "",
    "w3Opt": w3 != null ? ", and $w3" : "",
  };
}

/// Build params for EMOTION_TILT:
Map<String, String?> buildEmotionTiltParams(String dominant, {String? secondary}) {
  return {
    "emotionDom": dominant,
    "emotionSecOpt": secondary != null && secondary.isNotEmpty ? ", with $secondary mid-week" : ""
  };
}

/// Build params for PHASE_LEAN:
/// If RIVET fails, set rivetPhraseStart to "Recently," (trend language).
/// If RIVET passes, set to nothing or "Overall," based on your style.
Map<String, String?> buildPhaseLeanParams(String phase, {bool rivetPass = false}) {
  return {
    "phase": phase,
    "rivetPhraseStart": rivetPass ? "Overall," : "Recently,"
  };
}
