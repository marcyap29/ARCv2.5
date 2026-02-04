import '../models/command_intent.dart';
import '../models/intent_type.dart';

/// Parses user input (Enterprise commands or natural language) into [CommandIntent].
///
/// Used by [LumaraOrchestrator] to route to subsystems.
/// Enterprise patterns are checked first; then temporal terms; default is recentContext.
class CommandParser {
  /// Parse [userInput] and return a [CommandIntent] for routing.
  ///
  /// Does not set [CommandIntent.userId]; the orchestrator should set that
  /// when invoking subsystems.
  CommandIntent parse(String userInput) {
    final raw = userInput.trim();
    if (raw.isEmpty) {
      return CommandIntent(type: IntentType.recentContext, rawQuery: raw);
    }

    final normalized = raw.toLowerCase();

    // Enterprise-style commands (explicit patterns first)
    if (_matchesRetrieveFrom(normalized)) {
      return CommandIntent(type: IntentType.temporalQuery, rawQuery: raw);
    }
    if (_matchesShowCurrentPhase(normalized)) {
      return CommandIntent(type: IntentType.recentContext, rawQuery: raw);
    }
    if (_matchesShowUsagePatterns(normalized)) {
      return CommandIntent(type: IntentType.usagePatterns, rawQuery: raw);
    }
    if (_matchesShowAggregation(normalized)) {
      return CommandIntent(type: IntentType.temporalQuery, rawQuery: raw);
    }
    if (_matchesDecisionSupport(normalized)) {
      return CommandIntent(type: IntentType.decisionSupport, rawQuery: raw);
    }
    if (_matchesAnalyzeAcross(normalized)) {
      return CommandIntent(type: IntentType.patternAnalysis, rawQuery: raw);
    }
    if (_matchesCompare(normalized)) {
      return CommandIntent(type: IntentType.comparison, rawQuery: raw);
    }
    if (_matchesOptimalTiming(normalized)) {
      return CommandIntent(type: IntentType.optimalTiming, rawQuery: raw);
    }

    // Natural language: temporal references → temporalQuery
    if (_hasTemporalReference(normalized)) {
      return CommandIntent(type: IntentType.temporalQuery, rawQuery: raw);
    }

    // Natural language: pattern/theme wording → patternAnalysis
    if (_hasPatternWording(normalized)) {
      return CommandIntent(type: IntentType.patternAnalysis, rawQuery: raw);
    }

    // Natural language: comparison wording → comparison
    if (_hasComparisonWording(normalized)) {
      return CommandIntent(type: IntentType.comparison, rawQuery: raw);
    }

    // Default: recent context (reflection, general question)
    return CommandIntent(type: IntentType.recentContext, rawQuery: raw);
  }

  static bool _matchesRetrieveFrom(String s) {
    return RegExp(r'^retrieve\s+.+\s+from\s+.+', caseSensitive: false).hasMatch(s);
  }

  static bool _matchesShowCurrentPhase(String s) {
    return RegExp(r'^show\s+current\s+phase', caseSensitive: false).hasMatch(s);
  }

  static bool _matchesShowUsagePatterns(String s) {
    return RegExp(r'^show\s+usage\s+patterns', caseSensitive: false).hasMatch(s);
  }

  static bool _matchesShowAggregation(String s) {
    return RegExp(r'^show\s+.+\s+aggregation', caseSensitive: false).hasMatch(s);
  }

  static bool _matchesDecisionSupport(String s) {
    return RegExp(r'^decision\s+support\s+for\s+.+', caseSensitive: false).hasMatch(s);
  }

  static bool _matchesAnalyzeAcross(String s) {
    return RegExp(r'^analyze\s+.+\s+across\s+.+', caseSensitive: false).hasMatch(s);
  }

  static bool _matchesCompare(String s) {
    return RegExp(r'^compare\s+.+\s+(and|vs?\.?)\s+.+', caseSensitive: false).hasMatch(s);
  }

  static bool _matchesOptimalTiming(String s) {
    return RegExp(r'^(when\s+is\s+optimal|optimal\s+timing)', caseSensitive: false).hasMatch(s);
  }

  static final _temporalTerms = [
    'january', 'february', 'march', 'april', 'may', 'june',
    'july', 'august', 'september', 'october', 'november', 'december',
    'last month', 'last year', 'this week', 'this month', 'this year',
    'today', 'yesterday', 'last week', '2020', '2021', '2022', '2023', '2024', '2025',
    'tell me about my week', 'tell me about my month', 'tell me about my year',
  ];

  static bool _hasTemporalReference(String s) {
    return _temporalTerms.any((term) => s.contains(term));
  }

  static bool _hasPatternWording(String s) {
    const terms = ['pattern', 'themes recur', 'recurring', 'trend', 'over time'];
    return terms.any((term) => s.contains(term));
  }

  static bool _hasComparisonWording(String s) {
    const terms = ['compare', 'vs', ' versus ', 'difference between', 'changed since'];
    return terms.any((term) => s.contains(term));
  }
}
