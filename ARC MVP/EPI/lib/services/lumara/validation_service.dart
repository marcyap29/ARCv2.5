/// LUMARA Response Validation Service
/// Validates responses against Companion-first rules and logs violations
///
/// Key validations:
/// 1. Word count compliance
/// 2. Reference count limits (especially for Companion mode)
/// 3. Entry-type specific violations
/// 4. Persona behavioral compliance

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'entry_classifier.dart';
import 'user_intent.dart';
import 'response_mode_v2.dart';

class ValidationResult {
  final bool isValid;
  final List<String> violations;
  final Map<String, dynamic> metrics;

  ValidationResult({
    required this.isValid,
    required this.violations,
    required this.metrics,
  });

  Map<String, dynamic> toJson() => {
    'isValid': isValid,
    'violations': violations,
    'metrics': metrics,
  };
}

class ValidationService {

  /// Validate response with STRICT companion checks
  static ValidationResult validateResponse(
    String response,
    ResponseMode responseMode,
    {String? userId}
  ) {
    final violations = <String>[];
    final wordCount = _countWords(response);
    final persona = responseMode.persona;
    final maxWords = responseMode.maxWords;
    final maxRefs = responseMode.maxPastReferences;
    final entryType = responseMode.entryType;

    // Word count validation
    if (wordCount > maxWords + 50) { // Allow 50 word buffer
      violations.add('Response exceeds word limit: $wordCount words (max $maxWords)');
    }

    // NEW: Banned phrases validation (melodrama prevention)
    final bannedPhraseViolations = _detectBannedPhrases(response);
    violations.addAll(bannedPhraseViolations);

    // NEW: Pattern examples validation (for pattern-enabled personas)
    if (responseMode.minPatternExamples > 0 && persona == "companion") {
      final exampleCount = _countDatedExamples(response);

      if (exampleCount < responseMode.minPatternExamples) {
        violations.add('Insufficient dated examples: $exampleCount found (min ${responseMode.minPatternExamples})');
      }

      if (exampleCount > responseMode.maxPatternExamples) {
        violations.add('Too many examples: $exampleCount found (max ${responseMode.maxPatternExamples})');
      }
    }

    // Reference count validation (CRITICAL for Companion mode)
    if (persona == "companion") {
      final refCount = _countPastReferences(response);
      final isPersonal = responseMode.isPersonalContent;

      if (refCount > maxRefs) {
        final severity = isPersonal ? 'SEVERE' : 'MODERATE';
        violations.add('$severity: Companion exceeded reference limit: $refCount references (max $maxRefs)');
      }

      // Check for specific over-referencing patterns
      final overReferenceViolations = _detectOverReferencing(response, isPersonal);
      violations.addAll(overReferenceViolations);
    }

    // Entry-type specific validations
    switch (entryType) {
      case EntryType.factual:
        if (response.contains('✨')) {
          violations.add('Factual response contains ✨ header');
        }
        if (_containsPhaseReferences(response)) {
          violations.add('Factual response mentions phases or journey');
        }
        if (_containsLifeArcLanguage(response)) {
          violations.add('Factual response contains life arc synthesis');
        }
        break;

      case EntryType.analytical:
        if (response.contains('✨ Reflection')) {
          violations.add('Analytical response uses reflective header');
        }
        if (_containsTherapeuticFraming(response)) {
          violations.add('Analytical response uses therapeutic framing');
        }
        break;

      case EntryType.conversational:
        if (wordCount > 60) { // Strict for conversational
          violations.add('Conversational response too verbose: $wordCount words');
        }
        if (response.contains('✨')) {
          violations.add('Conversational response contains header');
        }
        break;

      case EntryType.reflective:
        if (responseMode.useReflectionHeader && !response.contains('✨')) {
          violations.add('Reflective response missing ✨ header');
        }
        break;

      case EntryType.metaAnalysis:
        if (responseMode.useReflectionHeader && !response.contains('✨')) {
          violations.add('Meta-analysis response missing ✨ header');
        }
        if (wordCount < 200) {
          violations.add('Meta-analysis response seems brief: $wordCount words');
        }
        break;
    }

    // Persona-specific validations
    switch (persona) {
      case "companion":
        // Check for Strategist structure bleeding through
        if (response.contains('**1.') ||
            response.contains('Signal Separation') ||
            response.contains('Phase Determination')) {
          violations.add('Companion using Strategist format');
        }

        // Check for excessive strategic language (personal content only)
        if (responseMode.isPersonalContent) {
          final strategicViolations = _detectExcessiveStrategicLanguage(response);
          violations.addAll(strategicViolations);
        }
        break;

      case "strategist":
        if (responseMode.useStructuredFormat) {
          if (!response.contains('**1.') && !response.contains('Signal Separation')) {
            violations.add('Structured Strategist missing required format');
          }
        }
        break;

      case "therapist":
        if (!response.contains('✨') && responseMode.useReflectionHeader) {
          violations.add('Therapist response missing ✨ header');
        }
        break;

      case "challenger":
        if (response.contains('✨')) {
          violations.add('Challenger using reflective header (should be direct)');
        }
        break;
    }

    final metrics = {
      'wordCount': wordCount,
      'maxWords': maxWords,
      'entryType': entryType.toString().split('.').last,
      'persona': persona,
      'isPersonalContent': responseMode.isPersonalContent,
      'referenceCount': persona == "companion" ? _countPastReferences(response) : 0,
      'maxReferencesAllowed': maxRefs,
      'datedExamplesCount': _countDatedExamples(response),
      'minPatternExamples': responseMode.minPatternExamples,
      'maxPatternExamples': responseMode.maxPatternExamples,
      'bannedPhrasesDetected': _detectBannedPhrases(response).length,
    };

    return ValidationResult(
      isValid: violations.isEmpty,
      violations: violations,
      metrics: metrics,
    );
  }

  /// Count words in response
  static int _countWords(String text) {
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  /// Count past references in response (for Companion mode)
  static int _countPastReferences(String response) {
    final referencePatterns = [
      r'\barc\b',
      r'\bepi\b',
      r'\bppi\b',
      r'learning space',
      r'adoption choke point',
      r'one thing per month',
      r'user sovereignty',
      r'market potential',
      r'strategic positioning',
      r'architecture',
      r'wispr flow',
      r'stripe integration',
      r'weight watchers',
      r'atomic habits',
    ];

    int count = 0;
    final lowerResponse = response.toLowerCase();

    for (var pattern in referencePatterns) {
      if (RegExp(pattern).hasMatch(lowerResponse)) {
        count++;
      }
    }

    return count;
  }

  /// Detect specific over-referencing patterns
  static List<String> _detectOverReferencing(String response, bool isPersonal) {
    final violations = <String>[];
    final lowerResponse = response.toLowerCase();

    // Forbidden patterns for personal content
    if (isPersonal) {
      final forbiddenPatterns = [
        r'this drives your arc journey',
        r'reflecting your conviction in epi',
        r'mirroring your work on the learning space',
        r'aligning with your goal to build one thing',
        r'addressing the ai adoption choke point',
        r'your strategic positioning of arc',
        r'demonstrates your commitment to sovereignty',
      ];

      for (var pattern in forbiddenPatterns) {
        if (RegExp(pattern).hasMatch(lowerResponse)) {
          violations.add('Over-referencing: "$pattern" in personal reflection');
        }
      }

      // Check for project enumeration
      final projectMentions = [
        'arc', 'epi', 'learning space', 'wispr flow', 'stripe'
      ].where((project) => lowerResponse.contains(project)).length;

      if (projectMentions >= 3) {
        violations.add('Over-referencing: Lists $projectMentions projects in personal reflection');
      }
    }

    return violations;
  }

  /// Detect excessive strategic language for personal content
  static List<String> _detectExcessiveStrategicLanguage(String response) {
    final violations = <String>[];
    final strategicPhrases = [
      'strategic vision',
      'market positioning',
      'user sovereignty',
      'choke point',
      'architectural',
      'fundamental breakthrough',
      'paradigm shift',
      'ecosystem',
      'leverage',
      'scalability',
    ];

    int strategicCount = 0;
    final lowerResponse = response.toLowerCase();

    for (var phrase in strategicPhrases) {
      if (lowerResponse.contains(phrase)) {
        strategicCount++;
      }
    }

    if (strategicCount > 2) {
      violations.add('Excessive strategic language: $strategicCount phrases in personal content');
    }

    return violations;
  }

  /// Check if response contains phase references (forbidden for factual)
  static bool _containsPhaseReferences(String response) {
    final phasePatterns = [
      r'\b(discovery|recovery|breakthrough|consolidation) phase\b',
      r'your journey',
      r'life arc',
      r'personal growth',
      r'development pattern',
    ];

    final lowerResponse = response.toLowerCase();
    return phasePatterns.any((pattern) => RegExp(pattern).hasMatch(lowerResponse));
  }

  /// Check for life arc synthesis language (forbidden for factual)
  static bool _containsLifeArcLanguage(String response) {
    final arcPatterns = [
      r'this reflects your',
      r'aligns with your',
      r'pattern of',
      r'your approach to',
      r'demonstrates how you',
    ];

    final lowerResponse = response.toLowerCase();
    return arcPatterns.any((pattern) => RegExp(pattern).hasMatch(lowerResponse));
  }

  /// Check for therapeutic framing (forbidden for analytical)
  static bool _containsTherapeuticFraming(String response) {
    final therapeuticPatterns = [
      r'this reflects your',
      r'aligns with your discovery phase',
      r'your pattern of',
      r'how you process',
      r'speaks to your',
    ];

    final lowerResponse = response.toLowerCase();
    return therapeuticPatterns.any((pattern) => RegExp(pattern).hasMatch(lowerResponse));
  }

  /// NEW: Detect banned melodramatic phrases
  static List<String> _detectBannedPhrases(String response) {
    final violations = <String>[];
    final bannedPhrases = [
      'significant moment in your journey',
      'shaping the contours of your identity',
      'expressions of commitment to',
      'integral steps in manifesting',
      'self-authorship',
      'transforming into foundational moments',
      'aligns with your .+ phase',
      'reflects your strategic vision',
      'demonstrates your commitment to',
      'ongoing commitment to',
      'as you continue to evolve',
      'expressions of your deepest commitments',
      'manifesting your vision',
    ];

    final lowerResponse = response.toLowerCase();

    for (var phrase in bannedPhrases) {
      if (RegExp(phrase).hasMatch(lowerResponse)) {
        violations.add('Banned melodramatic phrase detected: "$phrase"');
      }
    }

    return violations;
  }

  /// NEW: Count dated examples in response
  static int _countDatedExamples(String response) {
    // Look for date patterns
    final datePatterns = [
      r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}\b',  // "Aug 12"
      r'\b\d{1,2}\/\d{1,2}\b',  // "8/12"
      r'\b\d{4}-\d{2}-\d{2}\b',  // "2024-08-12"
      r'\blast (week|month|year)\b',  // "last week"
      r'\b\d+ (weeks|months|days) ago\b',  // "3 weeks ago"
      r'\b(yesterday|today|last night|this morning)\b',  // relative dates
      r'\b(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\b',  // day names
    ];

    int count = 0;
    for (var pattern in datePatterns) {
      count += RegExp(pattern, caseSensitive: false).allMatches(response).length;
    }

    return count;
  }
}

class ValidationLogger {

  /// Log validation results to Firebase for monitoring
  static Future<void> logValidation({
    required String userId,
    required ValidationResult validation,
    required EntryType entryType,
    required String persona,
    required String originalEntry,
    String? responseText,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('lumara_validation_logs')
          .add({
        'user_id': userId,
        'entry_type': entryType.toString().split('.').last,
        'persona': persona,
        'is_valid': validation.isValid,
        'violations': validation.violations,
        'metrics': validation.metrics,
        'entry_preview': originalEntry.length > 100
            ? originalEntry.substring(0, 100) + '...'
            : originalEntry,
        'response_preview': responseText != null && responseText.length > 100
            ? responseText.substring(0, 100) + '...'
            : responseText,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Warning: Failed to log validation: $e');
    }
  }

  /// Log persona distribution for monitoring
  static Future<void> logPersonaDistribution({
    required String userId,
    required EntryType entryType,
    required UserIntent userIntent,
    required String selectedPersona,
    required String selectionReason,
    required bool wasCompanionFirst,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('lumara_persona_distribution')
          .add({
        'user_id': userId,
        'entry_type': entryType.toString().split('.').last,
        'user_intent': userIntent.toString().split('.').last,
        'selected_persona': selectedPersona,
        'selection_reason': selectionReason,
        'was_companion_first': wasCompanionFirst,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String().split('T').first, // For daily aggregation
      });
    } catch (e) {
      print('Warning: Failed to log persona distribution: $e');
    }
  }

  /// Get daily persona distribution stats
  static Future<Map<String, double>> getPersonaDistributionStats({
    int daysBack = 7,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysBack));
      final snapshot = await FirebaseFirestore.instance
          .collection('lumara_persona_distribution')
          .where('timestamp', isGreaterThan: cutoffDate)
          .get();

      final personaCounts = <String, int>{};
      int total = 0;

      for (final doc in snapshot.docs) {
        final persona = doc.data()['selected_persona'] as String;
        personaCounts[persona] = (personaCounts[persona] ?? 0) + 1;
        total++;
      }

      final distribution = <String, double>{};
      for (final entry in personaCounts.entries) {
        distribution[entry.key] = (entry.value / total) * 100;
      }

      return distribution;
    } catch (e) {
      print('Warning: Failed to get distribution stats: $e');
      return {};
    }
  }

  /// Get validation violation summary
  static Future<Map<String, int>> getValidationViolationsSummary({
    int daysBack = 7,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysBack));
      final snapshot = await FirebaseFirestore.instance
          .collection('lumara_validation_logs')
          .where('timestamp', isGreaterThan: cutoffDate)
          .where('is_valid', isEqualTo: false)
          .get();

      final violationCounts = <String, int>{};

      for (final doc in snapshot.docs) {
        final violations = doc.data()['violations'] as List<dynamic>;
        for (final violation in violations) {
          final violationType = _categorizeViolation(violation.toString());
          violationCounts[violationType] = (violationCounts[violationType] ?? 0) + 1;
        }
      }

      return violationCounts;
    } catch (e) {
      print('Warning: Failed to get violation summary: $e');
      return {};
    }
  }

  /// Categorize violation for reporting
  static String _categorizeViolation(String violation) {
    if (violation.contains('word limit')) return 'Word Limit';
    if (violation.contains('reference limit')) return 'Reference Limit';
    if (violation.contains('over-referencing')) return 'Over-Referencing';
    if (violation.contains('strategic language')) return 'Strategic Language';
    if (violation.contains('factual')) return 'Factual Violations';
    if (violation.contains('header')) return 'Header Issues';
    if (violation.contains('format')) return 'Format Issues';
    if (violation.contains('Banned melodramatic phrase')) return 'Banned Phrases';
    if (violation.contains('dated examples')) return 'Pattern Examples';
    return 'Other';
  }
}