/// Comprehensive Test Suite for Companion-First LUMARA System
/// Tests all components: classification, intent detection, persona selection, validation

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/lumara/entry_classifier.dart';
import 'package:my_app/services/lumara/user_intent.dart';
import 'package:my_app/services/lumara/persona_selector.dart';
import 'package:my_app/services/lumara/response_mode_v2.dart';
import 'package:my_app/services/lumara/validation_service.dart';

void main() {
  group('Entry Classification Tests', () {
    test('classifies factual questions correctly', () {
      final entry = "Does Newton's calculus predict or calculate movement?";
      final result = EntryClassifier.classify(entry);
      expect(result, EntryType.factual);
    });

    test('classifies personal reflections correctly', () {
      final entry = "I'm frustrated with Stripe today but proud of getting Wispr Flow working. My superpower is persistence.";
      final result = EntryClassifier.classify(entry);
      expect(result, EntryType.reflective);
    });

    test('classifies conversational updates correctly', () {
      final entry = "Had coffee with Sarah.";
      final result = EntryClassifier.classify(entry);
      expect(result, EntryType.conversational);
    });

    test('classifies meta-analysis requests correctly', () {
      final entry = "What patterns do you see in my weight loss attempts?";
      final result = EntryClassifier.classify(entry);
      expect(result, EntryType.metaAnalysis);
    });

    test('classifies analytical essays correctly', () {
      final entry = "The theory of AI adoption suggests that there are specific choke points in the transition from early adopters to mainstream users. This framework posits that breakthrough technologies must navigate through institutional barriers, user interface complexity, and trust mechanisms before achieving widespread adoption.";
      final result = EntryClassifier.classify(entry);
      expect(result, EntryType.analytical);
    });
  });

  group('User Intent Detection Tests', () {
    test('detects default reflect intent', () {
      final intent = UserIntentDetector.detectIntent(null);
      expect(intent, UserIntent.reflect);
    });

    test('detects think through intent', () {
      final intent = UserIntentDetector.detectIntent("Think through");
      expect(intent, UserIntent.thinkThrough);
    });

    test('detects different perspective intent', () {
      final intent = UserIntentDetector.detectIntent("Different perspective");
      expect(intent, UserIntent.differentPerspective);
    });

    test('detects suggest steps intent', () {
      final intent = UserIntentDetector.detectIntent("Suggest steps");
      expect(intent, UserIntent.suggestSteps);
    });

    test('handles unknown button text', () {
      final intent = UserIntentDetector.detectIntent("Unknown button");
      expect(intent, UserIntent.reflect);
    });
  });

  group('Companion-First Persona Selection Tests', () {
    test('defaults to Companion for personal reflections', () {
      final persona = PersonaSelector.selectPersona(
        entryType: EntryType.reflective,
        userIntent: UserIntent.reflect,
        phase: "Discovery",
        readinessScore: 70,
        sentinelAlert: false,
        emotionalIntensity: 0.3,
      );
      expect(persona, "companion");
    });

    test('uses Strategist when Think Through button pressed', () {
      final persona = PersonaSelector.selectPersona(
        entryType: EntryType.reflective,
        userIntent: UserIntent.thinkThrough,
        phase: "Discovery",
        readinessScore: 70,
        sentinelAlert: false,
        emotionalIntensity: 0.3,
      );
      expect(persona, "strategist");
    });

    test('escalates to Therapist for high emotional intensity', () {
      final persona = PersonaSelector.selectPersona(
        entryType: EntryType.reflective,
        userIntent: UserIntent.reflect,
        phase: "Discovery",
        readinessScore: 70,
        sentinelAlert: false,
        emotionalIntensity: 0.6, // High distress
      );
      expect(persona, "therapist");
    });

    test('escalates to Therapist for low readiness', () {
      final persona = PersonaSelector.selectPersona(
        entryType: EntryType.reflective,
        userIntent: UserIntent.reflect,
        phase: "Recovery",
        readinessScore: 20, // Very low readiness
        sentinelAlert: false,
        emotionalIntensity: 0.3,
      );
      expect(persona, "therapist");
    });

    test('uses Therapist for sentinel alert override', () {
      final persona = PersonaSelector.selectPersona(
        entryType: EntryType.analytical,
        userIntent: UserIntent.thinkThrough,
        phase: "Breakthrough",
        readinessScore: 90,
        sentinelAlert: true, // Safety override
        emotionalIntensity: 0.1,
      );
      expect(persona, "therapist");
    });

    test('uses Challenger for different perspective when ready', () {
      final persona = PersonaSelector.selectPersona(
        entryType: EntryType.reflective,
        userIntent: UserIntent.differentPerspective,
        phase: "Breakthrough",
        readinessScore: 80, // High readiness
        sentinelAlert: false,
        emotionalIntensity: 0.2,
      );
      expect(persona, "challenger");
    });

    test('falls back to Strategist for different perspective when not ready', () {
      final persona = PersonaSelector.selectPersona(
        entryType: EntryType.reflective,
        userIntent: UserIntent.differentPerspective,
        phase: "Recovery",
        readinessScore: 40, // Lower readiness
        sentinelAlert: false,
        emotionalIntensity: 0.2,
      );
      expect(persona, "strategist");
    });

    test('always uses Strategist for meta-analysis', () {
      final persona = PersonaSelector.selectPersona(
        entryType: EntryType.metaAnalysis,
        userIntent: UserIntent.reflect,
        phase: "Discovery",
        readinessScore: 50,
        sentinelAlert: false,
        emotionalIntensity: 0.2,
      );
      expect(persona, "strategist");
    });

    test('defaults Companion for analytical entries (unless button pressed)', () {
      final persona = PersonaSelector.selectPersona(
        entryType: EntryType.analytical,
        userIntent: UserIntent.reflect,
        phase: "Discovery",
        readinessScore: 70,
        sentinelAlert: false,
        emotionalIntensity: 0.1,
      );
      expect(persona, "companion"); // Should be Companion, not Strategist
    });
  });

  group('Response Mode Configuration Tests', () {
    test('detects personal vs. project content', () {
      final personalEntry = "My superpower is persistence. I'm frustrated with Stripe.";
      final isPersonal = ResponseMode._detectPersonalContent(personalEntry);
      expect(isPersonal, true);

      final projectEntry = "ARC's architecture needs to integrate Stripe for payments.";
      final isProject = ResponseMode._detectPersonalContent(projectEntry);
      expect(isProject, false);
    });

    test('sets strict reference limits for personal Companion mode', () {
      final mode = ResponseMode.configure(
        persona: "companion",
        entryType: EntryType.reflective,
        userIntent: UserIntent.reflect,
        entryText: "My superpower is persistence.",
      );
      expect(mode.maxPastReferences, 1); // Strict limit for personal
      expect(mode.isPersonalContent, true);
    });

    test('allows more references for project Companion mode', () {
      final mode = ResponseMode.configure(
        persona: "companion",
        entryType: EntryType.reflective,
        userIntent: UserIntent.reflect,
        entryText: "ARC's integration with Stripe needs work.",
      );
      expect(mode.maxPastReferences, 3); // More for project content
      expect(mode.isPersonalContent, false);
    });

    test('configures factual mode correctly', () {
      final mode = ResponseMode.configure(
        persona: "companion",
        entryType: EntryType.factual,
        userIntent: UserIntent.reflect,
        entryText: "How does calculus work?",
      );
      expect(mode.maxWords, 100);
      expect(mode.useReflectionHeader, false);
      expect(mode.maxPastReferences, 0);
    });

    test('configures conversational mode correctly', () {
      final mode = ResponseMode.configure(
        persona: "companion",
        entryType: EntryType.conversational,
        userIntent: UserIntent.reflect,
        entryText: "Had coffee with Sarah.",
      );
      expect(mode.maxWords, 50);
      expect(mode.useReflectionHeader, false);
      expect(mode.maxPastReferences, 0);
    });

    test('enables structured format for Strategist with appropriate intent', () {
      final mode = ResponseMode.configure(
        persona: "strategist",
        entryType: EntryType.reflective,
        userIntent: UserIntent.thinkThrough,
        entryText: "I need to plan my approach to this problem.",
      );
      expect(mode.useStructuredFormat, true);
      expect(mode.maxWords, 500); // Higher limit for structured
    });
  });

  group('Validation Tests', () {
    test('validates word count compliance', () {
      final responseMode = ResponseMode.configure(
        persona: "companion",
        entryType: EntryType.conversational,
        userIntent: UserIntent.reflect,
        entryText: "Had coffee with Sarah.",
      );

      final longResponse = "This is a very long response that exceeds the word limit for conversational entries by a significant margin and should definitely be flagged as a violation because it's way too verbose for a simple update like having coffee with someone.";

      final validation = ValidationService.validateResponse(longResponse, responseMode);
      expect(validation.isValid, false);
      expect(validation.violations, contains(matches(r'.*word.*limit.*')));
    });

    test('detects reference limit violations for Companion personal mode', () {
      final responseMode = ResponseMode.configure(
        persona: "companion",
        entryType: EntryType.reflective,
        userIntent: UserIntent.reflect,
        entryText: "My superpower is persistence.", // Personal content
      );

      final overReferencingResponse = "This persistence drives your ARC journey, reflecting your conviction in EPI's market potential, mirroring your Learning Space insights, aligning with your goal to build one thing per month, addressing the AI adoption choke point.";

      final validation = ValidationService.validateResponse(overReferencingResponse, responseMode);
      expect(validation.isValid, false);
      expect(validation.violations, contains(matches(r'.*reference.*limit.*')));
    });

    test('detects factual response violations', () {
      final responseMode = ResponseMode.configure(
        persona: "companion",
        entryType: EntryType.factual,
        userIntent: UserIntent.reflect,
        entryText: "How does calculus work?",
      );

      final badFactualResponse = "✨ Reflection\n\nThis insight reflects your pattern of systematic learning and aligns with your Discovery phase...";

      final validation = ValidationService.validateResponse(badFactualResponse, responseMode);
      expect(validation.isValid, false);
      expect(validation.violations.length, greaterThan(1)); // Multiple violations
    });

    test('validates correct responses', () {
      final responseMode = ResponseMode.configure(
        persona: "companion",
        entryType: EntryType.reflective,
        userIntent: UserIntent.reflect,
        entryText: "I'm feeling good about my progress today.",
      );

      final goodResponse = "✨ Reflection\n\nThat sense of progress is really meaningful - it sounds like you're recognizing the momentum you've built. Keep trusting that forward movement.";

      final validation = ValidationService.validateResponse(goodResponse, responseMode);
      expect(validation.isValid, true);
      expect(validation.violations, isEmpty);
    });

    test('detects Companion format bleeding into Strategist responses', () {
      final responseMode = ResponseMode.configure(
        persona: "companion",
        entryType: EntryType.reflective,
        userIntent: UserIntent.reflect,
        entryText: "I need to plan my next steps.",
      );

      final strategistFormatResponse = "**1. Signal Separation**\nYour entry suggests...\n\n**2. Phase Determination**\nCurrently in Discovery phase...";

      final validation = ValidationService.validateResponse(strategistFormatResponse, responseMode);
      expect(validation.isValid, false);
      expect(validation.violations, contains(matches(r'.*Strategist.*format.*')));
    });
  });

  group('Integration Tests', () {
    test('personal reflection gets Companion with strict limits', () {
      final entryText = "I think my superpower is never giving up. Stripe is frustrating but I got Wispr Flow working.";

      // Test entry classification
      final entryType = EntryClassifier.classify(entryText);
      expect(entryType, EntryType.reflective);

      // Test intent detection (no button)
      final userIntent = UserIntentDetector.detectIntent(null);
      expect(userIntent, UserIntent.reflect);

      // Test persona selection (should be Companion)
      final persona = PersonaSelector.selectPersona(
        entryType: entryType,
        userIntent: userIntent,
        phase: "Discovery",
        readinessScore: 70,
        sentinelAlert: false,
        emotionalIntensity: 0.3,
      );
      expect(persona, "companion");

      // Test response mode (should have strict limits)
      final responseMode = ResponseMode.configure(
        persona: persona,
        entryType: entryType,
        userIntent: userIntent,
        entryText: entryText,
      );
      expect(responseMode.isPersonalContent, true);
      expect(responseMode.maxPastReferences, 1); // Strict for personal
      expect(responseMode.maxWords, 250);
    });

    test('analytical entry with think through button gets Strategist', () {
      final entryText = "The theory of AI adoption suggests there are specific choke points...";

      // Should classify as analytical
      final entryType = EntryClassifier.classify(entryText);
      expect(entryType, EntryType.analytical);

      // Button pressed
      final userIntent = UserIntentDetector.detectIntent("Think through");
      expect(userIntent, UserIntent.thinkThrough);

      // Should get Strategist due to button
      final persona = PersonaSelector.selectPersona(
        entryType: entryType,
        userIntent: userIntent,
        phase: "Discovery",
        readinessScore: 70,
        sentinelAlert: false,
        emotionalIntensity: 0.1,
      );
      expect(persona, "strategist");

      // Should use structured format
      final responseMode = ResponseMode.configure(
        persona: persona,
        entryType: entryType,
        userIntent: userIntent,
        entryText: entryText,
      );
      expect(responseMode.useStructuredFormat, true);
      expect(responseMode.maxWords, 500);
    });

    test('high distress entry gets Therapist regardless of button', () {
      final entryText = "I'm really struggling and feel overwhelmed. Everything is falling apart.";

      final entryType = EntryClassifier.classify(entryText);
      final userIntent = UserIntentDetector.detectIntent("Think through"); // User wants analysis

      final emotionalIntensity = PersonaSelector.calculateEmotionalIntensity(entryText);
      expect(emotionalIntensity, greaterThan(0.5)); // Should detect high distress

      // Should override to Therapist despite button
      final persona = PersonaSelector.selectPersona(
        entryType: entryType,
        userIntent: userIntent,
        phase: "Recovery",
        readinessScore: 30,
        sentinelAlert: false,
        emotionalIntensity: emotionalIntensity,
      );
      expect(persona, "therapist"); // Override to support mode
    });
  });

  group('Persona Distribution Tests', () {
    test('generates expected personas across different scenarios', () {
      final scenarios = [
        // Personal reflections should mostly get Companion
        {"entryText": "My superpower is persistence.", "expectedPersona": "companion"},
        {"entryText": "I'm proud of my progress today.", "expectedPersona": "companion"},
        {"entryText": "Had a good day working on my goals.", "expectedPersona": "companion"},

        // Quick updates should always get Companion
        {"entryText": "Had coffee with Sarah.", "expectedPersona": "companion"},
        {"entryText": "Finished the book.", "expectedPersona": "companion"},

        // Meta-analysis should always get Strategist
        {"entryText": "What patterns do you see in my entries?", "expectedPersona": "strategist"},

        // High distress should get Therapist
        {"entryText": "I'm really struggling and feel lost.", "expectedPersona": "therapist"},
      ];

      final personas = <String, int>{};

      for (final scenario in scenarios) {
        final entryText = scenario['entryText'] as String;
        final entryType = EntryClassifier.classify(entryText);
        final userIntent = UserIntentDetector.detectIntent(null);
        final emotionalIntensity = PersonaSelector.calculateEmotionalIntensity(entryText);

        final persona = PersonaSelector.selectPersona(
          entryType: entryType,
          userIntent: userIntent,
          phase: "Discovery",
          readinessScore: 70,
          sentinelAlert: false,
          emotionalIntensity: emotionalIntensity,
        );

        personas[persona] = (personas[persona] ?? 0) + 1;

        // Verify expected persona for this scenario
        expect(persona, scenario['expectedPersona'],
               reason: "Entry '$entryText' should get ${scenario['expectedPersona']} but got $persona");
      }

      // Check that Companion is the most frequent
      final companionCount = personas['companion'] ?? 0;
      final totalCount = personas.values.reduce((a, b) => a + b);
      final companionPercentage = (companionCount / totalCount) * 100;

      expect(companionPercentage, greaterThan(50),
             reason: "Companion should be >50% but was ${companionPercentage.toStringAsFixed(1)}%");

      print('Persona distribution: $personas');
      print('Companion percentage: ${companionPercentage.toStringAsFixed(1)}%');
    });
  });
}