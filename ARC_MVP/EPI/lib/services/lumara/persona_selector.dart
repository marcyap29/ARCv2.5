/// Companion-First Persona Selector
/// Part of LUMARA Response Generation System v2.1
///
/// CRITICAL: Companion is now primary persona (50-60% usage)
/// Other personas are escalations only when needed
library;

import 'entry_classifier.dart';
import 'user_intent.dart';

class PersonaSelector {

  /// Select persona based on entry type, user intent, and state
  /// COMPANION-FIRST: Defaults to Companion unless strong reason to escalate
  ///
  /// NO MANUAL OVERRIDE - Personas are backend-only
  static String selectPersona({
    required EntryType entryType,
    required UserIntent userIntent,
    required String phase,
    required int readinessScore,
    required bool sentinelAlert,
    required double emotionalIntensity,
  }) {
    // Priority 1: SAFETY OVERRIDE (highest priority)
    // Sentinel alert always returns Therapist
    if (sentinelAlert) {
      return "therapist";
    }

    // Priority 2: HIGH DISTRESS OVERRIDE
    // Very high emotional intensity or very low readiness → Therapist
    if (emotionalIntensity > 0.5 || readinessScore < 25) {
      return "therapist";
    }

    // Priority 3: USER INTENT (Button Pressed)
    // Explicit user requests via buttons
    String? intentPersona = _getPersonaForIntent(
      userIntent: userIntent,
      entryType: entryType,
      readinessScore: readinessScore,
      emotionalIntensity: emotionalIntensity,
    );

    if (intentPersona != null) {
      return intentPersona;
    }

    // Priority 4: ENTRY TYPE DEFAULT (Companion-first)
    return _getDefaultPersonaForEntryType(
      entryType: entryType,
      emotionalIntensity: emotionalIntensity,
      readinessScore: readinessScore,
    );
  }

  /// Get persona based on user intent (button pressed)
  /// Returns null if intent is "reflect" (use entry type default)
  static String? _getPersonaForIntent({
    required UserIntent userIntent,
    required EntryType entryType,
    required int readinessScore,
    required double emotionalIntensity,
  }) {
    switch (userIntent) {
      case UserIntent.reflect:
        // Default button - no override, use entry type default
        return null;

      case UserIntent.suggestIdeas:
        // Creative brainstorming - always Companion
        return "companion";

      case UserIntent.thinkThrough:
      case UserIntent.suggestSteps:
        // Structured analysis or action planning - always Strategist
        return "strategist";

      case UserIntent.differentPerspective:
        // Challenge thinking
        // Only use Challenger if readiness is high enough (60+)
        // Otherwise use Strategist
        if (readinessScore >= 60) {
          return "challenger";
        }
        return "strategist";

      case UserIntent.reflectDeeply:
        // Deep reflection - depends on content
        // Emotional content → Therapist
        // Analytical content → Strategist
        if (entryType == EntryType.reflective && emotionalIntensity > 0.25) {
          return "therapist";
        }
        if (entryType == EntryType.metaAnalysis ||
            entryType == EntryType.analytical) {
          return "strategist";
        }
        // Otherwise use Companion (deeper but still supportive)
        return "companion";
    }
  }

  /// Get default persona for entry type (COMPANION-FIRST)
  /// Called when no button override and no high distress
  static String _getDefaultPersonaForEntryType({
    required EntryType entryType,
    required double emotionalIntensity,
    required int readinessScore,
  }) {
    switch (entryType) {
      case EntryType.factual:
      case EntryType.conversational:
        // Simple entries ALWAYS get Companion
        return "companion";

      case EntryType.reflective:
        // Personal/emotional entries
        // Moderate-high distress (0.4-0.5) → Therapist
        // Otherwise → Companion (DEFAULT)
        if (emotionalIntensity > 0.4 && emotionalIntensity <= 0.5) {
          return "therapist";
        }
        return "companion";

      case EntryType.analytical:
        // Analytical essays DEFAULT to Companion (light engagement)
        // User must press "think through" to get Strategist
        return "companion";

      case EntryType.metaAnalysis:
        // ONLY EXCEPTION: Explicit pattern requests always get Strategist
        return "strategist";
    }
  }

  /// Calculate emotional intensity from entry text
  static double calculateEmotionalIntensity(String entryText) {
    // Use the public debug info to access classification data
    final debugInfo = EntryClassifier.getClassificationDebugInfo(entryText);
    final emotionalDensity = debugInfo['emotionalDensity'] as double;
    final hasStruggle = debugInfo['hasStruggleLanguage'] as bool;

    // Boost intensity if struggle language present
    double intensity = emotionalDensity;
    if (hasStruggle) {
      intensity = (intensity + 0.3).clamp(0.0, 1.0);
    }

    return intensity;
  }

  /// Get human-readable description of persona
  static String getPersonaDescription(String persona) {
    switch (persona) {
      case "companion":
        return "Warm, supportive presence for daily reflection";
      case "therapist":
        return "Deep therapeutic support for difficult times";
      case "strategist":
        return "Analytical insights and structured planning";
      case "challenger":
        return "Direct feedback that pushes growth";
      default:
        return "Adaptive response based on context";
    }
  }

  /// Get target distribution percentages for monitoring
  static Map<String, String> getTargetDistribution() {
    return {
      "companion": "50-60%",
      "strategist": "20-30%",
      "therapist": "10-15%",
      "challenger": "2-5%",
    };
  }

  /// Get debug information for persona selection
  static Map<String, dynamic> getPersonaSelectionDebugInfo({
    required EntryType entryType,
    required UserIntent userIntent,
    required String phase,
    required int readinessScore,
    required bool sentinelAlert,
    required double emotionalIntensity,
  }) {
    final selectedPersona = selectPersona(
      entryType: entryType,
      userIntent: userIntent,
      phase: phase,
      readinessScore: readinessScore,
      sentinelAlert: sentinelAlert,
      emotionalIntensity: emotionalIntensity,
    );

    // Determine the reason for selection
    String selectionReason;
    if (sentinelAlert) {
      selectionReason = "Safety override (sentinel alert)";
    } else if (emotionalIntensity > 0.5 || readinessScore < 25) {
      selectionReason = "High distress override";
    } else {
      final intentPersona = _getPersonaForIntent(
        userIntent: userIntent,
        entryType: entryType,
        readinessScore: readinessScore,
        emotionalIntensity: emotionalIntensity,
      );
      if (intentPersona != null) {
        selectionReason = "User intent: ${userIntent.toString().split('.').last}";
      } else {
        selectionReason = "Entry type default: ${entryType.toString().split('.').last}";
      }
    }

    return {
      'entryType': entryType.toString().split('.').last,
      'userIntent': userIntent.toString().split('.').last,
      'phase': phase,
      'readinessScore': readinessScore,
      'sentinelAlert': sentinelAlert,
      'emotionalIntensity': emotionalIntensity,
      'selectedPersona': selectedPersona,
      'selectionReason': selectionReason,
      'isCompanionFirst': selectedPersona == "companion",
      'description': getPersonaDescription(selectedPersona),
    };
  }
}

/// Persona Selection Decision Tree (for documentation/debugging)
///
/// Entry + Button
///     ↓
/// Is sentinel alert active?
///     YES → Therapist (safety override)
///     NO ↓
///
/// Is emotional intensity > 0.5 OR readiness < 25?
///     YES → Therapist (distress override)
///     NO ↓
///
/// Did user press button?
///     "Think through" / "Suggest steps" → Strategist
///     "Different perspective" + readiness ≥ 60 → Challenger
///     "Different perspective" + readiness < 60 → Strategist
///     "Reflect deeply" + emotional content → Therapist
///     "Reflect deeply" + analytical content → Strategist
///     "Suggest ideas" → Companion
///     "Reflect" (default) or no button → Continue ↓
///
/// What entry type?
///     Factual → Companion
///     Conversational → Companion
///     Reflective + emotional intensity > 0.4 → Therapist
///     Reflective + emotional intensity ≤ 0.4 → Companion
///     Analytical → Companion (light engagement)
///     MetaAnalysis → Strategist