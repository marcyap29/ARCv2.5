// lib/lumara/agents/agent_tips.dart
//
// Tips shown occasionally on agent screens (Research, Writing, Plugin Catalog, Agents).
// Helps users remember agent capabilities (no references to other AI model names).

import 'package:shared_preferences/shared_preferences.dart';

const String _keyLastIndex = 'agent_tip_last_index';
const String _keyLastShownAt = 'agent_tip_last_shown_at';
/// Minimum interval between showing a tip (milliseconds). ~2 hours.
const int _minIntervalMs = 2 * 60 * 60 * 1000;

/// Single tip: short text for the banner.
class AgentTip {
  const AgentTip(this.text);
  final String text;
}

/// All tips shown in rotation. Add new ones here.
final List<AgentTip> kAgentTips = [
  const AgentTip('Vision vs OCR: Use Vision for exact text extraction; use LUMARA for understanding and summarizing images.'),
  const AgentTip('Research uses Brave Search, Tavily, and more—sources are cited in the report.'),
  const AgentTip('Writing keeps your voice and themes; paste a research summary for better drafts.'),
  const AgentTip('Plugins in the catalog show tier (free/standard/premium) and example queries.'),
  const AgentTip('URL Reader fetches and extracts article content for Research—great for deep dives.'),
  const AgentTip('First time using a plugin? You\'ll be asked to approve it once; then it\'s remembered.'),
];

/// Returns the next tip to show, or null if we should not show one yet (too soon).
/// Call when an agent screen is built; advances index and timestamp when a tip is returned.
Future<AgentTip?> getNextAgentTip() async {
  final prefs = await SharedPreferences.getInstance();
  final lastIndex = prefs.getInt(_keyLastIndex) ?? 0;
  final lastShownAt = prefs.getInt(_keyLastShownAt) ?? 0;
  final now = DateTime.now().millisecondsSinceEpoch;
  if (now - lastShownAt < _minIntervalMs && lastShownAt > 0) {
    return null;
  }
  final tip = kAgentTips[lastIndex % kAgentTips.length];
  await prefs.setInt(_keyLastIndex, lastIndex + 1);
  await prefs.setInt(_keyLastShownAt, now);
  return tip;
}

/// Call when user dismisses the banner so we don't show another until next interval.
Future<void> markAgentTipShown() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_keyLastShownAt, DateTime.now().millisecondsSinceEpoch);
}
