import 'dart:convert';
import 'entry_classifier.dart';

class ResponseMode {
  final EntryType entryType;
  final bool pullFullContext;
  final bool runPhaseAnalysis;
  final bool runSemanticSearch;
  final int maxWords;
  final String? personaOverride;
  final bool useReflectionHeader;
  final ContextScope contextScope;

  ResponseMode({
    required this.entryType,
    required this.pullFullContext,
    required this.runPhaseAnalysis,
    required this.runSemanticSearch,
    required this.maxWords,
    this.personaOverride,
    required this.useReflectionHeader,
    required this.contextScope,
  });

  /// Determine response mode based on entry type
  static ResponseMode forEntryType(EntryType type, String entryText) {
    switch (type) {
      case EntryType.factual:
        return ResponseMode(
          entryType: type,
          pullFullContext: false,
          runPhaseAnalysis: false,  // Phase only affects tone
          runSemanticSearch: false,
          maxWords: 100,
          personaOverride: null,  // Let phase determine, but constrain output
          useReflectionHeader: false,
          contextScope: ContextScope.minimal(entryText),
        );

      case EntryType.reflective:
        return ResponseMode(
          entryType: type,
          pullFullContext: true,
          runPhaseAnalysis: true,  // Full phase-aware synthesis
          runSemanticSearch: true,
          maxWords: 300,
          personaOverride: null,  // Phase determines persona
          useReflectionHeader: true,
          contextScope: ContextScope.full(entryText),
        );

      case EntryType.analytical:
        return ResponseMode(
          entryType: type,
          pullFullContext: false,
          runPhaseAnalysis: false,  // Phase modulates tone, not content
          runSemanticSearch: true,  // Light semantic search for relevant thinking
          maxWords: 250,
          personaOverride: null,
          useReflectionHeader: false,
          contextScope: ContextScope.moderate(entryText),
        );

      case EntryType.conversational:
        return ResponseMode(
          entryType: type,
          pullFullContext: false,
          runPhaseAnalysis: false,
          runSemanticSearch: false,
          maxWords: 30,
          personaOverride: 'companion',  // Always brief and warm
          useReflectionHeader: false,
          contextScope: ContextScope.minimal(entryText),
        );

      case EntryType.metaAnalysis:
        return ResponseMode(
          entryType: type,
          pullFullContext: true,
          runPhaseAnalysis: true,
          runSemanticSearch: true,
          maxWords: 600,  // Allow comprehensive analysis
          personaOverride: 'strategist',  // Always analytical for pattern work
          useReflectionHeader: true,  // Use "✨ Pattern Analysis"
          contextScope: ContextScope.maximum(entryText),
        );
    }
  }

  /// Convert to JSON for control state
  Map<String, dynamic> toJson() {
    return {
      'type': entryType.toString().split('.').last,
      'pullFullContext': pullFullContext,
      'runPhaseAnalysis': runPhaseAnalysis,
      'runSemanticSearch': runSemanticSearch,
      'maxWords': maxWords,
      'personaOverride': personaOverride,
      'useReflectionHeader': useReflectionHeader,
      'contextScope': contextScope.toJson(),
    };
  }

  /// Get the appropriate header based on entry type
  String getReflectionHeader() {
    switch (entryType) {
      case EntryType.metaAnalysis:
        return '✨ Pattern Analysis';
      case EntryType.reflective:
        return '✨ Reflection';
      case EntryType.factual:
      case EntryType.analytical:
      case EntryType.conversational:
        return ''; // No header
    }
  }

  /// Get debug information about this response mode
  Map<String, dynamic> getDebugInfo() {
    return {
      'entryType': entryType.toString().split('.').last,
      'configuration': toJson(),
      'expectedHeader': useReflectionHeader ? getReflectionHeader() : 'none',
      'contextStrategy': contextScope.getStrategy(),
    };
  }
}

class ContextScope {
  final int lookbackYears;
  final int maxEntries;
  final double tier1Weight;
  final double tier2Weight;
  final double tier3Weight;
  final bool semanticSearchEnabled;
  final List<String> relevantTopics;

  ContextScope({
    required this.lookbackYears,
    required this.maxEntries,
    required this.tier1Weight,
    required this.tier2Weight,
    required this.tier3Weight,
    required this.semanticSearchEnabled,
    this.relevantTopics = const [],
  });

  /// Minimal context for factual/conversational
  factory ContextScope.minimal(String entryText) {
    return ContextScope(
      lookbackYears: 1,
      maxEntries: 5,
      tier1Weight: 0.8,
      tier2Weight: 0.0,  // Skip chats
      tier3Weight: 0.0,  // Skip drafts
      semanticSearchEnabled: false,
      relevantTopics: _extractTopics(entryText),
    );
  }

  /// Moderate context for analytical
  factory ContextScope.moderate(String entryText) {
    return ContextScope(
      lookbackYears: 1,
      maxEntries: 10,
      tier1Weight: 0.9,
      tier2Weight: 0.0,
      tier3Weight: 0.0,
      semanticSearchEnabled: true,
      relevantTopics: _extractTopics(entryText),
    );
  }

  /// Full context for reflective
  factory ContextScope.full(String entryText) {
    return ContextScope(
      lookbackYears: 0,  // 0 = use user's slider setting
      maxEntries: 20,
      tier1Weight: 1.0,
      tier2Weight: 0.6,
      tier3Weight: 0.4,
      semanticSearchEnabled: true,
      relevantTopics: _extractTopics(entryText),
    );
  }

  /// Maximum context for meta-analysis
  factory ContextScope.maximum(String entryText) {
    return ContextScope(
      lookbackYears: 0,  // Use user's slider setting
      maxEntries: 50,
      tier1Weight: 1.0,
      tier2Weight: 0.6,
      tier3Weight: 0.4,
      semanticSearchEnabled: true,
      relevantTopics: _extractTopics(entryText),
    );
  }

  /// Extract relevant topics from entry text for focused context
  static List<String> _extractTopics(String text) {
    final keywords = <String>[];
    final lowerText = text.toLowerCase();

    // Technical topics
    if (lowerText.contains('calculus')) keywords.add('calculus');
    if (lowerText.contains('newton')) keywords.add('physics');
    if (lowerText.contains('kalman')) keywords.add('kalman_filter');
    if (RegExp(r'\b(code|coding|programming)\b').hasMatch(lowerText)) {
      keywords.add('programming');
    }

    // Personal topics
    if (RegExp(r'\b(weight|lbs|pounds)\b').hasMatch(lowerText)) {
      keywords.add('weight_loss');
    }
    if (RegExp(r'\b(epi|arc|ppi)\b').hasMatch(lowerText)) {
      keywords.add('arc_development');
    }
    if (RegExp(r'\b(ghost|sbir|military)\b').hasMatch(lowerText)) {
      keywords.add('ghost_variant');
    }

    // Relationship topics
    if (lowerText.contains('eiffel')) keywords.add('eiffel');
    if (lowerText.contains('lucas')) keywords.add('lucas');

    // Health topics
    if (RegExp(r'\b(sleep|tired|energy|exercise)\b').hasMatch(lowerText)) {
      keywords.add('health');
    }

    // Work/productivity topics
    if (RegExp(r'\b(work|productivity|focus|meeting)\b').hasMatch(lowerText)) {
      keywords.add('work');
    }

    return keywords;
  }

  /// Get strategy description for debugging
  String getStrategy() {
    if (lookbackYears == 0 && maxEntries >= 50) return 'maximum';
    if (tier2Weight > 0 && tier3Weight > 0) return 'full';
    if (semanticSearchEnabled && maxEntries >= 10) return 'moderate';
    return 'minimal';
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'lookbackYears': lookbackYears,
      'maxEntries': maxEntries,
      'tier1Weight': tier1Weight,
      'tier2Weight': tier2Weight,
      'tier3Weight': tier3Weight,
      'semanticSearchEnabled': semanticSearchEnabled,
      'relevantTopics': relevantTopics,
      'strategy': getStrategy(),
    };
  }
}

/// User preferences for classification behavior
class ClassificationPreferences {
  final bool alwaysUseFullContext;
  final int preferredResponseLength;
  final bool showClassificationDebug;
  final Map<EntryType, int> customWordLimits;

  ClassificationPreferences({
    this.alwaysUseFullContext = false,
    this.preferredResponseLength = 100,
    this.showClassificationDebug = false,
    this.customWordLimits = const {},
  });

  /// Apply preferences to a response mode
  ResponseMode applyPreferences(ResponseMode baseMode, String entryText) {
    // If user wants full context always, override
    if (alwaysUseFullContext) {
      return ResponseMode(
        entryType: baseMode.entryType,
        pullFullContext: true,
        runPhaseAnalysis: true,
        runSemanticSearch: true,
        maxWords: customWordLimits[baseMode.entryType] ??
                  (baseMode.maxWords * preferredResponseLength ~/ 100),
        personaOverride: baseMode.personaOverride,
        useReflectionHeader: baseMode.useReflectionHeader,
        contextScope: ContextScope.full(entryText),
      );
    }

    // Apply custom word limits if specified
    if (customWordLimits.containsKey(baseMode.entryType)) {
      return ResponseMode(
        entryType: baseMode.entryType,
        pullFullContext: baseMode.pullFullContext,
        runPhaseAnalysis: baseMode.runPhaseAnalysis,
        runSemanticSearch: baseMode.runSemanticSearch,
        maxWords: customWordLimits[baseMode.entryType]!,
        personaOverride: baseMode.personaOverride,
        useReflectionHeader: baseMode.useReflectionHeader,
        contextScope: baseMode.contextScope,
      );
    }

    // Apply length preference scaling
    if (preferredResponseLength != 100) {
      return ResponseMode(
        entryType: baseMode.entryType,
        pullFullContext: baseMode.pullFullContext,
        runPhaseAnalysis: baseMode.runPhaseAnalysis,
        runSemanticSearch: baseMode.runSemanticSearch,
        maxWords: (baseMode.maxWords * preferredResponseLength ~/ 100),
        personaOverride: baseMode.personaOverride,
        useReflectionHeader: baseMode.useReflectionHeader,
        contextScope: baseMode.contextScope,
      );
    }

    return baseMode;
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'alwaysUseFullContext': alwaysUseFullContext,
      'preferredResponseLength': preferredResponseLength,
      'showClassificationDebug': showClassificationDebug,
      'customWordLimits': customWordLimits.map(
        (key, value) => MapEntry(key.toString().split('.').last, value),
      ),
    };
  }

  /// Create from JSON
  factory ClassificationPreferences.fromJson(Map<String, dynamic> json) {
    final customWordLimits = <EntryType, int>{};
    final rawLimits = json['customWordLimits'] as Map<String, dynamic>? ?? {};

    for (final entry in rawLimits.entries) {
      final entryType = EntryType.values.firstWhere(
        (e) => e.toString().split('.').last == entry.key,
        orElse: () => EntryType.reflective,
      );
      customWordLimits[entryType] = entry.value as int;
    }

    return ClassificationPreferences(
      alwaysUseFullContext: json['alwaysUseFullContext'] as bool? ?? false,
      preferredResponseLength: json['preferredResponseLength'] as int? ?? 100,
      showClassificationDebug: json['showClassificationDebug'] as bool? ?? false,
      customWordLimits: customWordLimits,
    );
  }
}