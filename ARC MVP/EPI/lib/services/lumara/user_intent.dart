/// User Intent Detection - Maps button interactions to intent types
/// Part of LUMARA Response Generation System v2.1

import 'entry_classifier.dart';

enum UserIntent {
  reflect,              // Default button or no button - standard reflection
  suggestIdeas,         // Creative brainstorming button
  thinkThrough,         // Structured analysis button
  differentPerspective, // Challenge thinking button
  suggestSteps,         // Action planning button
  reflectDeeply,        // Comprehensive reflection button
}

class UserIntentDetector {

  /// Detect user intent from button pressed
  /// Returns UserIntent.reflect if no button or unrecognized button
  static UserIntent detectIntent(String? buttonPressed) {
    if (buttonPressed == null || buttonPressed.trim().isEmpty) {
      return UserIntent.reflect;
    }

    final normalized = buttonPressed.toLowerCase().trim();

    // Map button text to intent
    switch (normalized) {
      case 'suggest ideas':
      case 'suggestideas':
      case 'brainstorm':
      case 'ideas':
        return UserIntent.suggestIdeas;

      case 'think through':
      case 'thinkthrough':
      case 'analyze':
      case 'breakdown':
        return UserIntent.thinkThrough;

      case 'different perspective':
      case 'differentperspective':
      case 'challenge':
      case 'pushback':
      case 'alternative':
        return UserIntent.differentPerspective;

      case 'suggest steps':
      case 'suggeststeps':
      case 'next steps':
      case 'action plan':
      case 'actionplan':
      case 'steps':
        return UserIntent.suggestSteps;

      case 'reflect deeply':
      case 'reflectdeeply':
      case 'deep reflection':
      case 'comprehensive':
      case 'explore':
        return UserIntent.reflectDeeply;

      case 'reflect':
      case 'standard':
      case 'normal':
      default:
        return UserIntent.reflect;
    }
  }

  /// Get human-readable description of intent
  static String getIntentDescription(UserIntent intent) {
    switch (intent) {
      case UserIntent.reflect:
        return 'Standard Reflection';
      case UserIntent.suggestIdeas:
        return 'Creative Brainstorming';
      case UserIntent.thinkThrough:
        return 'Structured Analysis';
      case UserIntent.differentPerspective:
        return 'Challenge Thinking';
      case UserIntent.suggestSteps:
        return 'Action Planning';
      case UserIntent.reflectDeeply:
        return 'Deep Reflection';
    }
  }

  /// Get context explanation for each intent (used in prompts)
  static String getIntentContext(UserIntent intent) {
    switch (intent) {
      case UserIntent.reflect:
        return 'User chose standard reflection - provide warm, supportive response focused on current entry.';

      case UserIntent.suggestIdeas:
        return 'User requested creative brainstorming - generate innovative ideas and possibilities.';

      case UserIntent.thinkThrough:
        return 'User requested structured analysis - break down the situation systematically with clear reasoning.';

      case UserIntent.differentPerspective:
        return 'User requested alternative perspective - challenge assumptions and offer different viewpoints.';

      case UserIntent.suggestSteps:
        return 'User requested action planning - provide concrete, actionable next steps.';

      case UserIntent.reflectDeeply:
        return 'User requested deep reflection - provide comprehensive, thoughtful analysis with broader connections.';
    }
  }

  /// Check if intent should trigger Strategist persona
  static bool isStrategistIntent(UserIntent intent) {
    return [
      UserIntent.thinkThrough,
      UserIntent.suggestSteps,
    ].contains(intent);
  }

  /// Check if intent should trigger Challenger persona (if readiness allows)
  static bool isChallengerIntent(UserIntent intent) {
    return intent == UserIntent.differentPerspective;
  }

  /// Check if intent should trigger deeper Therapist mode
  static bool isDeepTherapistIntent(UserIntent intent, EntryType entryType) {
    return intent == UserIntent.reflectDeeply &&
           entryType == EntryType.reflective;
  }

  /// Check if intent should stay with Companion (creative/supportive)
  static bool isCompanionIntent(UserIntent intent) {
    return [
      UserIntent.reflect,
      UserIntent.suggestIdeas,
    ].contains(intent);
  }

  /// Get debug information for intent detection
  static Map<String, dynamic> getIntentDebugInfo(String? buttonPressed) {
    final intent = detectIntent(buttonPressed);

    return {
      'buttonPressed': buttonPressed,
      'detectedIntent': intent.toString().split('.').last,
      'description': getIntentDescription(intent),
      'context': getIntentContext(intent),
      'isStrategistIntent': isStrategistIntent(intent),
      'isChallengerIntent': isChallengerIntent(intent),
      'isCompanionIntent': isCompanionIntent(intent),
    };
  }
}

// Extension to add convenience methods to UserIntent enum
extension UserIntentExtension on UserIntent {

  /// Get the display name for UI
  String get displayName => UserIntentDetector.getIntentDescription(this);

  /// Get the context explanation for prompts
  String get context => UserIntentDetector.getIntentContext(this);

  /// Check if this intent prefers Strategist persona
  bool get prefersStrategist => UserIntentDetector.isStrategistIntent(this);

  /// Check if this intent prefers Challenger persona
  bool get prefersChallenger => UserIntentDetector.isChallengerIntent(this);

  /// Check if this intent prefers Companion persona
  bool get prefersCompanion => UserIntentDetector.isCompanionIntent(this);
}