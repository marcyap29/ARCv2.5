/// Response Mode Configuration with Strict Companion Controls
/// Part of LUMARA Response Generation System v2.1
///
/// CRITICAL CHANGES:
/// 1. Strict reference limits for Companion mode
/// 2. Personal vs. Project detection
/// 3. Enhanced anti-over-referencing controls

import 'entry_classifier.dart';
import 'user_intent.dart';

class ResponseMode {
  final String persona;
  final EntryType entryType;
  final UserIntent userIntent;
  final int maxWords;
  final bool useReflectionHeader;
  final bool useStructuredFormat;
  final ContextScope contextScope;
  final String toneGuidance;
  final int maxPastReferences;  // NEW: Strict limit on references
  final bool isPersonalContent;  // NEW: Personal vs. project detection

  ResponseMode({
    required this.persona,
    required this.entryType,
    required this.userIntent,
    required this.maxWords,
    required this.useReflectionHeader,
    required this.useStructuredFormat,
    required this.contextScope,
    required this.toneGuidance,
    required this.maxPastReferences,
    required this.isPersonalContent,
  });

  /// Configure response mode with strict Companion controls
  factory ResponseMode.configure({
    required String persona,
    required EntryType entryType,
    required UserIntent userIntent,
    required String entryText,  // NEW: Need text to detect personal vs. project
  }) {
    // Detect if content is personal reflection vs. project planning
    final isPersonal = _detectPersonalContent(entryText);

    // Special handling for factual (always brief)
    if (entryType == EntryType.factual) {
      return ResponseMode(
        persona: persona,
        entryType: entryType,
        userIntent: userIntent,
        maxWords: 100,
        useReflectionHeader: false,
        useStructuredFormat: false,
        contextScope: ContextScope.minimal(),
        toneGuidance: "Direct, helpful, concise, educational",
        maxPastReferences: 0,  // No references for factual
        isPersonalContent: false,
      );
    }

    // Special handling for conversational (always minimal)
    if (entryType == EntryType.conversational) {
      return ResponseMode(
        persona: persona,
        entryType: entryType,
        userIntent: userIntent,
        maxWords: 50,
        useReflectionHeader: false,
        useStructuredFormat: false,
        contextScope: ContextScope.minimal(),
        toneGuidance: "Warm, brief, acknowledging",
        maxPastReferences: 0,  // No references for conversational
        isPersonalContent: false,
      );
    }

    // Persona-specific configuration
    switch (persona) {
      case "companion":
        return _companionMode(entryType, userIntent, isPersonal);
      case "therapist":
        return _therapistMode(entryType, userIntent);
      case "strategist":
        return _strategistMode(entryType, userIntent);
      case "challenger":
        return _challengerMode(entryType, userIntent);
      default:
        return _companionMode(entryType, userIntent, isPersonal);
    }
  }

  /// Detect if entry is personal reflection vs. project planning
  static bool _detectPersonalContent(String text) {
    final lowerText = text.toLowerCase();

    // Personal indicators
    final personalPatterns = [
      r'\bmy (superpower|strength|weakness|challenge)\b',
      r'\bi (feel|felt|think|believe|realize|notice)\b',
      r'\bpersonal\b',
      r'\bfrustrat(ed|ing)\b',
      r'\bexcit(ed|ing)\b',
      r'\bproud\b',
      r'\bdisappoint(ed|ing)\b',
      r'\bstress(ed|ful)\b',
    ];

    // Project indicators
    final projectPatterns = [
      r'\barc\b',
      r'\bepi\b',
      r'\bppi\b',
      r'\bstrateg(y|ic)\b',
      r'\bmarket\b',
      r'\blaunch\b',
      r'\barchitecture\b',
      r'\bintegration\b',
      r'\buser(s)?\b',
    ];

    int personalCount = 0;
    for (var pattern in personalPatterns) {
      if (RegExp(pattern).hasMatch(lowerText)) personalCount++;
    }

    int projectCount = 0;
    for (var pattern in projectPatterns) {
      if (RegExp(pattern).hasMatch(lowerText)) projectCount++;
    }

    // If more personal indicators than project indicators, it's personal
    return personalCount > projectCount;
  }

  /// Configure Companion persona mode (STRICT CONTROLS)
  static ResponseMode _companionMode(
    EntryType type,
    UserIntent intent,
    bool isPersonal,
  ) {
    // STRICT: Personal content gets maximum 1 reference
    // Project content can have 2-3 references
    int maxRefs = isPersonal ? 1 : 3;

    return ResponseMode(
      persona: "companion",
      entryType: type,
      userIntent: intent,
      maxWords: 250,
      useReflectionHeader: true,
      useStructuredFormat: false,
      contextScope: ContextScope.moderate(),
      toneGuidance: "Warm, supportive, conversational, validating, friendly",
      maxPastReferences: maxRefs,
      isPersonalContent: isPersonal,
    );
  }

  /// Configure Therapist persona mode
  static ResponseMode _therapistMode(EntryType type, UserIntent intent) {
    return ResponseMode(
      persona: "therapist",
      entryType: type,
      userIntent: intent,
      maxWords: 300,
      useReflectionHeader: true,
      useStructuredFormat: false,
      contextScope: ContextScope.full(),
      toneGuidance: "Gentle, grounding, containing, therapeutic, empathetic",
      maxPastReferences: 2,  // Can reference past struggles/patterns
      isPersonalContent: true,
    );
  }

  /// Configure Strategist persona mode
  static ResponseMode _strategistMode(EntryType type, UserIntent intent) {
    bool useStructure = (
      intent == UserIntent.thinkThrough ||
      intent == UserIntent.suggestSteps ||
      intent == UserIntent.reflectDeeply ||
      type == EntryType.metaAnalysis
    );

    int wordLimit = useStructure ? 500 : 300;

    return ResponseMode(
      persona: "strategist",
      entryType: type,
      userIntent: intent,
      maxWords: wordLimit,
      useReflectionHeader: true,
      useStructuredFormat: useStructure,
      contextScope: ContextScope.full(),
      toneGuidance: useStructure
        ? "Analytical, structured, concrete, decisive, action-oriented"
        : "Analytical but conversational, insightful, clear",
      maxPastReferences: 5,  // Can pull more context for analysis
      isPersonalContent: false,
    );
  }

  /// Configure Challenger persona mode
  static ResponseMode _challengerMode(EntryType type, UserIntent intent) {
    return ResponseMode(
      persona: "challenger",
      entryType: type,
      userIntent: intent,
      maxWords: 250,
      useReflectionHeader: false,
      useStructuredFormat: false,
      contextScope: ContextScope.moderate(),
      toneGuidance: "Direct, challenging, growth-oriented, honest",
      maxPastReferences: 2,  // Limited references, focus on current
      isPersonalContent: true,
    );
  }

  /// Convert to JSON for control state
  Map<String, dynamic> toJson() {
    return {
      'persona': persona,
      'entryType': entryType.toString().split('.').last,
      'userIntent': userIntent.toString().split('.').last,
      'maxWords': maxWords,
      'useReflectionHeader': useReflectionHeader,
      'useStructuredFormat': useStructuredFormat,
      'contextScope': contextScope.toJson(),
      'toneGuidance': toneGuidance,
      'maxPastReferences': maxPastReferences,
      'isPersonalContent': isPersonalContent,
    };
  }

  /// Copy with modifications
  ResponseMode copyWith({
    String? persona,
    EntryType? entryType,
    UserIntent? userIntent,
    int? maxWords,
    bool? useReflectionHeader,
    bool? useStructuredFormat,
    ContextScope? contextScope,
    String? toneGuidance,
    int? maxPastReferences,
    bool? isPersonalContent,
  }) {
    return ResponseMode(
      persona: persona ?? this.persona,
      entryType: entryType ?? this.entryType,
      userIntent: userIntent ?? this.userIntent,
      maxWords: maxWords ?? this.maxWords,
      useReflectionHeader: useReflectionHeader ?? this.useReflectionHeader,
      useStructuredFormat: useStructuredFormat ?? this.useStructuredFormat,
      contextScope: contextScope ?? this.contextScope,
      toneGuidance: toneGuidance ?? this.toneGuidance,
      maxPastReferences: maxPastReferences ?? this.maxPastReferences,
      isPersonalContent: isPersonalContent ?? this.isPersonalContent,
    );
  }
}

class ContextScope {
  final int lookbackYears;
  final int maxEntries;
  final bool pullSemanticSimilar;
  final bool pullChats;
  final bool pullDrafts;

  ContextScope({
    required this.lookbackYears,
    required this.maxEntries,
    required this.pullSemanticSimilar,
    required this.pullChats,
    required this.pullDrafts,
  });

  factory ContextScope.minimal() {
    return ContextScope(
      lookbackYears: 1,
      maxEntries: 3,
      pullSemanticSimilar: false,
      pullChats: false,
      pullDrafts: false,
    );
  }

  factory ContextScope.moderate() {
    return ContextScope(
      lookbackYears: 1,
      maxEntries: 10,
      pullSemanticSimilar: true,
      pullChats: false,
      pullDrafts: false,
    );
  }

  factory ContextScope.full() {
    return ContextScope(
      lookbackYears: 0,  // Use user's slider setting
      maxEntries: 20,
      pullSemanticSimilar: true,
      pullChats: true,
      pullDrafts: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lookbackYears': lookbackYears,
      'maxEntries': maxEntries,
      'pullSemanticSimilar': pullSemanticSimilar,
      'pullChats': pullChats,
      'pullDrafts': pullDrafts,
    };
  }
}