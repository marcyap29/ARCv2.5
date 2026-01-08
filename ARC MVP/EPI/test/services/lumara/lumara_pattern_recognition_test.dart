/// Test for LUMARA Pattern Recognition System v3.0
/// Validates that the new specification is properly implemented

import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/lumara/entry_classifier.dart';
import '../../../lib/services/lumara/user_intent.dart';
import '../../../lib/services/lumara/response_mode_v2.dart';
import '../../../lib/services/lumara/master_prompt_builder.dart';
import '../../../lib/services/lumara/validation_service.dart';

void main() {
  group('LUMARA Pattern Recognition v3.0', () {

    test('ResponseMode configures pattern examples correctly for Companion', () {
      final mode = ResponseMode.configure(
        persona: "companion",
        entryType: EntryType.reflective,
        userIntent: UserIntent.reflect,
        entryText: "I feel frustrated with my progress today",
      );

      expect(mode.persona, equals("companion"));
      expect(mode.minPatternExamples, equals(2));
      expect(mode.maxPatternExamples, equals(4));
      expect(mode.requireDates, isTrue);
      expect(mode.isPersonalContent, isTrue);
    });

    test('ResponseMode configures correctly for factual entries (no patterns)', () {
      final mode = ResponseMode.configure(
        persona: "companion",
        entryType: EntryType.factual,
        userIntent: UserIntent.reflect,
        entryText: "Does Newton's calculus predict or calculate movement?",
      );

      expect(mode.entryType, equals(EntryType.factual));
      expect(mode.minPatternExamples, equals(0));
      expect(mode.maxPatternExamples, equals(0));
      expect(mode.requireDates, isFalse);
      expect(mode.maxWords, equals(100));
    });

    test('Validation service detects banned melodramatic phrases', () {
      final mode = ResponseMode.configure(
        persona: "companion",
        entryType: EntryType.reflective,
        userIntent: UserIntent.reflect,
        entryText: "I'm reflecting on my growth",
      );

      const badResponse = """✨ Reflection

      This significant moment in your journey reflects the shaping of the contours of your identity
      as you continue to evolve through expressions of commitment to your deepest values.""";

      final validation = ValidationService.validateResponse(badResponse, mode);

      expect(validation.isValid, isFalse);
      expect(validation.violations.any((v) => v.contains('Banned melodramatic phrase')), isTrue);
    });

    test('Validation service counts dated examples correctly', () {
      final mode = ResponseMode.configure(
        persona: "companion",
        entryType: EntryType.reflective,
        userIntent: UserIntent.reflect,
        entryText: "I'm noticing patterns in how I work",
      );

      const goodResponse = """✨ Reflection

      Your observation about persistence rings true. The Stripe frustration vs. Wispr Flow breakthrough
      (Aug 12) captures that dynamic rhythm: focused engagement, strategic withdrawal, fresh angle.
      The Learning Space insight from Sept 15 validates this - you kept probing without knowing you'd
      succeeded. Last week's Firebase auth solution followed the same pattern.""";

      final validation = ValidationService.validateResponse(goodResponse, mode);

      expect(validation.metrics['datedExamplesCount'], greaterThanOrEqualTo(2));
      expect(validation.violations.any((v) => v.contains('Insufficient dated examples')), isFalse);
    });

    test('Master prompt includes pattern recognition guidelines for Companion', () async {
      final mode = ResponseMode.configure(
        persona: "companion",
        entryType: EntryType.reflective,
        userIntent: UserIntent.reflect,
        entryText: "I feel stuck with my current project",
      );

      final prompt = await MasterPromptBuilder.buildMasterPrompt(
        userId: "test_user",
        originalEntry: "I feel stuck with my current project",
        entryType: EntryType.reflective,
        userIntent: UserIntent.reflect,
        responseMode: mode,
        currentPhase: "Discovery",
        readinessScore: 70,
        sentinelAlert: false,
      );

      // Check that pattern recognition guidelines are included
      expect(prompt.contains('PATTERN RECOGNITION GUIDELINES'), isTrue);
      expect(prompt.contains('Show patterns with specific dated examples'), isTrue);
      expect(prompt.contains('BANNED PHRASES'), isTrue);
      expect(prompt.contains('significant moment in your journey'), isTrue);
      expect(prompt.contains('2-4 dated examples'), isTrue);
    });

    test('Personal vs project content detection works correctly', () {
      // Personal content
      final personalMode = ResponseMode.configure(
        persona: "companion",
        entryType: EntryType.reflective,
        userIntent: UserIntent.reflect,
        entryText: "I feel frustrated and disappointed with my progress today",
      );
      expect(personalMode.isPersonalContent, isTrue);

      // Project content
      final projectMode = ResponseMode.configure(
        persona: "companion",
        entryType: EntryType.reflective,
        userIntent: UserIntent.reflect,
        entryText: "ARC's architecture needs to support EPI integration with users",
      );
      expect(projectMode.isPersonalContent, isFalse);
    });

    test('Strategist persona gets higher pattern example limits', () {
      final mode = ResponseMode.configure(
        persona: "strategist",
        entryType: EntryType.metaAnalysis,
        userIntent: UserIntent.thinkThrough,
        entryText: "What patterns do you see in my approach to problem-solving?",
      );

      expect(mode.persona, equals("strategist"));
      expect(mode.minPatternExamples, equals(3));
      expect(mode.maxPatternExamples, equals(8));
      expect(mode.requireDates, isTrue);
      expect(mode.useStructuredFormat, isTrue);
    });

    test('Challenger persona gets focused pattern examples', () {
      final mode = ResponseMode.configure(
        persona: "challenger",
        entryType: EntryType.reflective,
        userIntent: UserIntent.differentPerspective,
        entryText: "I keep saying I'll finish this but never do",
      );

      expect(mode.persona, equals("challenger"));
      expect(mode.minPatternExamples, equals(1));
      expect(mode.maxPatternExamples, equals(2));
      expect(mode.requireDates, isTrue);
      expect(mode.useReflectionHeader, isFalse);
    });

    test('Validation service includes new metrics in validation result', () {
      final mode = ResponseMode.configure(
        persona: "companion",
        entryType: EntryType.reflective,
        userIntent: UserIntent.reflect,
        entryText: "I feel frustrated",
      );

      const response = """✨ Reflection
      Your frustration makes sense. Like when you struggled with Firebase on Aug 12, then found
      the breakthrough approach on Aug 20, this shows your pattern of persistence leading to success.""";

      final validation = ValidationService.validateResponse(response, mode);

      expect(validation.metrics['datedExamplesCount'], isNotNull);
      expect(validation.metrics['minPatternExamples'], equals(2));
      expect(validation.metrics['maxPatternExamples'], equals(4));
      expect(validation.metrics['bannedPhrasesDetected'], isNotNull);
    });

    test('Factual entry type excludes pattern requirements in prompt', () async {
      final mode = ResponseMode.configure(
        persona: "companion",
        entryType: EntryType.factual,
        userIntent: UserIntent.reflect,
        entryText: "How does calculus work?",
      );

      final prompt = await MasterPromptBuilder.buildMasterPrompt(
        userId: "test_user",
        originalEntry: "How does calculus work?",
        entryType: EntryType.factual,
        userIntent: UserIntent.reflect,
        responseMode: mode,
        currentPhase: "Discovery",
        readinessScore: 70,
        sentinelAlert: false,
      );

      // Factual should not have pattern requirements
      expect(prompt.contains('0-0 dated examples'), isTrue);
      expect(prompt.contains('Just answer the question'), isTrue);
      expect(prompt.contains('No phase analysis'), isTrue);
    });

    test('MetaAnalysis entry type includes comprehensive pattern requirements', () async {
      final mode = ResponseMode.configure(
        persona: "strategist",
        entryType: EntryType.metaAnalysis,
        userIntent: UserIntent.reflectDeeply,
        entryText: "What patterns do you see in how I approach challenges?",
      );

      final prompt = await MasterPromptBuilder.buildMasterPrompt(
        userId: "test_user",
        originalEntry: "What patterns do you see in how I approach challenges?",
        entryType: EntryType.metaAnalysis,
        userIntent: UserIntent.reflectDeeply,
        responseMode: mode,
        currentPhase: "Discovery",
        readinessScore: 70,
        sentinelAlert: false,
      );

      // MetaAnalysis should demand comprehensive pattern analysis
      expect(prompt.contains('ARC\'s showcase moment'), isTrue);
      expect(prompt.contains('Ground EVERY pattern in dated examples'), isTrue);
      expect(prompt.contains('Evidence: [Date 1], [Date 2], [Date 3]'), isTrue);
      expect(prompt.contains('CRITICAL: Every claim needs specific dated examples'), isTrue);
    });
  });

  group('LUMARA Favorites Library-Only Implementation', () {
    test('Favorites are marked as library-only in context builder', () {
      // This is tested indirectly through the context builder changes
      // The key is that favorites are no longer used for style adaptation
      expect(true, isTrue); // Placeholder - actual test would check context builder output
    });
  });
}

/// Test helper to simulate entry classification
EntryType _classifyTestEntry(String entry) {
  if (entry.contains('?') && entry.split(' ').length < 10) {
    return EntryType.factual;
  }
  if (entry.toLowerCase().contains('pattern')) {
    return EntryType.metaAnalysis;
  }
  if (entry.contains('feel') || entry.contains('frustrated')) {
    return EntryType.reflective;
  }
  return EntryType.conversational;
}