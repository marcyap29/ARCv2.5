/// RIVET-lite Safety Validation for ECHO
///
/// Lightweight safety validation that ensures dignified, non-manipulative
/// responses while maintaining LUMARA's authentic voice
library;

class RivetLiteValidator {
  /// Safety validation thresholds
  static const double _contradictionThreshold = 0.3;
  static const double _hallucinationThreshold = 0.25;
  static const double _uncertaintyThreshold = 0.15;

  /// Validate response for safety and dignity before delivery
  static Future<ValidationResult> validateResponse({
    required String response,
    required String originalUtterance,
    required List<String> memoryNodeIds,
    required double groundingConfidence,
  }) async {
    final violations = <SafetyViolation>[];

    // Check for dignity violations
    violations.addAll(_checkDignityViolations(response));

    // Check for manipulation patterns
    violations.addAll(_checkManipulationPatterns(response));

    // Check for RIVET-lite metrics
    final rivetMetrics = _calculateRivetMetrics(
      response,
      memoryNodeIds,
      groundingConfidence,
    );

    violations.addAll(_checkRivetThresholds(rivetMetrics));

    // Check phase appropriateness
    violations.addAll(_checkPhaseAppropriateness(response));

    // Calculate overall safety score
    final safetyScore = _calculateSafetyScore(violations, rivetMetrics);

    return ValidationResult(
      isValid: violations.isEmpty,
      safetyScore: safetyScore,
      violations: violations,
      rivetMetrics: rivetMetrics,
      recommendedAction: _getRecommendedAction(violations, safetyScore),
    );
  }

  /// Check for dignity violations in response
  static List<SafetyViolation> _checkDignityViolations(String response) {
    final violations = <SafetyViolation>[];
    final lowerResponse = response.toLowerCase();

    // Dignity violation patterns
    final dignityRedFlags = [
      'you should feel',
      'you need to',
      'obviously',
      'just do',
      'simply',
      'you must',
      'clearly',
      'of course',
      'everyone knows',
      'it\'s obvious',
    ];

    for (final flag in dignityRedFlags) {
      if (lowerResponse.contains(flag)) {
        violations.add(SafetyViolation(
          type: ViolationType.dignity,
          severity: ViolationSeverity.medium,
          description: 'Potentially dismissive language: "$flag"',
          suggestedFix: 'Reframe with curiosity and respect for user\'s experience',
        ));
      }
    }

    // Check for shaming language
    final shamingPatterns = [
      'you always',
      'you never',
      'that\'s wrong',
      'you\'re being',
      'don\'t be',
      'stop feeling',
    ];

    for (final pattern in shamingPatterns) {
      if (lowerResponse.contains(pattern)) {
        violations.add(SafetyViolation(
          type: ViolationType.dignity,
          severity: ViolationSeverity.high,
          description: 'Potential shaming language: "$pattern"',
          suggestedFix: 'Remove judgmental language and replace with supportive reflection',
        ));
      }
    }

    return violations;
  }

  /// Check for manipulation patterns
  static List<SafetyViolation> _checkManipulationPatterns(String response) {
    final violations = <SafetyViolation>[];
    final lowerResponse = response.toLowerCase();

    // Manipulation red flags
    final manipulationPatterns = [
      'if you really wanted',
      'you claim to',
      'you say you want',
      'if you were serious',
      'prove that',
      'show me that',
      'you should be grateful',
      'others have it worse',
    ];

    for (final pattern in manipulationPatterns) {
      if (lowerResponse.contains(pattern)) {
        violations.add(SafetyViolation(
          type: ViolationType.manipulation,
          severity: ViolationSeverity.high,
          description: 'Manipulative language pattern: "$pattern"',
          suggestedFix: 'Replace with genuine curiosity and support',
        ));
      }
    }

    // Check for coercive language
    final coercionPatterns = [
      'you have to',
      'you must',
      'there\'s no choice',
      'the only way',
      'you can\'t',
      'it\'s impossible',
    ];

    for (final pattern in coercionPatterns) {
      if (lowerResponse.contains(pattern)) {
        violations.add(SafetyViolation(
          type: ViolationType.manipulation,
          severity: ViolationSeverity.medium,
          description: 'Coercive language: "$pattern"',
          suggestedFix: 'Offer options and respect user autonomy',
        ));
      }
    }

    return violations;
  }

  /// Calculate RIVET-lite metrics
  static RivetMetrics _calculateRivetMetrics(
    String response,
    List<String> memoryNodeIds,
    double groundingConfidence,
  ) {
    // Contradiction count: statements at odds with evidence
    final contradictions = _countContradictions(response, memoryNodeIds);

    // Hallucination hints: unsupported claims
    final hallucinations = _countHallucinations(response, groundingConfidence);

    // Uncertainty triggers: inappropriate hedging
    final uncertaintyTriggers = _countUncertaintyTriggers(response);

    // Calculate ALIGN score (higher is better)
    final alignScore = _calculateAlignScore(
      contradictions,
      hallucinations,
      uncertaintyTriggers,
    );

    // Calculate RISK score (lower is better)
    final riskScore = _calculateRiskScore(
      contradictions,
      hallucinations,
      uncertaintyTriggers,
    );

    return RivetMetrics(
      contradictions: contradictions,
      hallucinations: hallucinations,
      uncertaintyTriggers: uncertaintyTriggers,
      alignScore: alignScore,
      riskScore: riskScore,
    );
  }

  /// Count contradiction indicators
  static int _countContradictions(String response, List<String> memoryNodeIds) {
    // For now, simple heuristic based on absolute statements when grounding is weak
    if (memoryNodeIds.isEmpty) {
      final absoluteStatements = RegExp(r'\b(always|never|definitely|certainly|absolutely)\b')
          .allMatches(response.toLowerCase())
          .length;
      return absoluteStatements;
    }
    return 0;
  }

  /// Count hallucination indicators
  static int _countHallucinations(String response, double groundingConfidence) {
    // If grounding confidence is low but response makes specific claims
    if (groundingConfidence < 0.5) {
      final specificClaims = RegExp(r'\b(you told me|you mentioned|last time|you said)\b')
          .allMatches(response.toLowerCase())
          .length;
      return specificClaims;
    }
    return 0;
  }

  /// Count inappropriate uncertainty triggers
  static int _countUncertaintyTriggers(String response) {
    // Count excessive hedging that might undermine helpful response
    final hedgeWords = RegExp(r'\b(maybe|perhaps|might|could|possibly|potentially)\b')
        .allMatches(response.toLowerCase())
        .length;

    // Too much hedging (>3 per 100 words) may indicate uncertainty issues
    final wordCount = response.split(' ').length;
    return hedgeWords > (wordCount / 100) * 3 ? 1 : 0;
  }

  /// Calculate ALIGN score (alignment with evidence and dignity)
  static double _calculateAlignScore(int contradictions, int hallucinations, int uncertaintyTriggers) {
    final totalViolations = contradictions + hallucinations + uncertaintyTriggers;
    return 1.0 - (totalViolations * 0.2).clamp(0.0, 1.0);
  }

  /// Calculate RISK score (risk of harm or manipulation)
  static double _calculateRiskScore(int contradictions, int hallucinations, int uncertaintyTriggers) {
    return (contradictions * 0.3 + hallucinations * 0.4 + uncertaintyTriggers * 0.1).clamp(0.0, 1.0);
  }

  /// Check RIVET threshold violations
  static List<SafetyViolation> _checkRivetThresholds(RivetMetrics metrics) {
    final violations = <SafetyViolation>[];

    if (metrics.riskScore > _contradictionThreshold) {
      violations.add(SafetyViolation(
        type: ViolationType.rivet,
        severity: ViolationSeverity.medium,
        description: 'High contradiction risk (${metrics.riskScore.toStringAsFixed(2)})',
        suggestedFix: 'Reduce absolute statements and add appropriate hedging',
      ));
    }

    if (metrics.hallucinations > 0) {
      violations.add(SafetyViolation(
        type: ViolationType.rivet,
        severity: ViolationSeverity.high,
        description: 'Potential hallucination detected (${metrics.hallucinations} instances)',
        suggestedFix: 'Remove specific claims not supported by memory evidence',
      ));
    }

    if (metrics.alignScore < 0.7) {
      violations.add(SafetyViolation(
        type: ViolationType.rivet,
        severity: ViolationSeverity.medium,
        description: 'Low alignment score (${metrics.alignScore.toStringAsFixed(2)})',
        suggestedFix: 'Improve response grounding and reduce unsupported claims',
      ));
    }

    return violations;
  }

  /// Check phase appropriateness
  static List<SafetyViolation> _checkPhaseAppropriateness(String response) {
    // TODO: Implement phase-specific validation based on ATLAS context
    return [];
  }

  /// Calculate overall safety score
  static double _calculateSafetyScore(List<SafetyViolation> violations, RivetMetrics metrics) {
    if (violations.isEmpty) return 1.0;

    final violationPenalty = violations.fold<double>(0.0, (sum, violation) {
      switch (violation.severity) {
        case ViolationSeverity.low:
          return sum + 0.1;
        case ViolationSeverity.medium:
          return sum + 0.2;
        case ViolationSeverity.high:
          return sum + 0.4;
      }
    });

    final safetyScore = (1.0 - violationPenalty).clamp(0.0, 1.0);
    return safetyScore * metrics.alignScore;
  }

  /// Get recommended action based on validation results
  static ValidationAction _getRecommendedAction(List<SafetyViolation> violations, double safetyScore) {
    if (violations.any((v) => v.severity == ViolationSeverity.high)) {
      return ValidationAction.reject;
    }

    if (safetyScore < 0.6) {
      return ValidationAction.revise;
    }

    if (violations.isNotEmpty) {
      return ValidationAction.warn;
    }

    return ValidationAction.approve;
  }
}

/// Validation result for ECHO responses
class ValidationResult {
  final bool isValid;
  final double safetyScore;
  final List<SafetyViolation> violations;
  final RivetMetrics rivetMetrics;
  final ValidationAction recommendedAction;

  ValidationResult({
    required this.isValid,
    required this.safetyScore,
    required this.violations,
    required this.rivetMetrics,
    required this.recommendedAction,
  });

  bool get requiresRevision => recommendedAction == ValidationAction.revise || recommendedAction == ValidationAction.reject;
  bool get hasHighSeverityViolations => violations.any((v) => v.severity == ViolationSeverity.high);
}

/// Individual safety violation
class SafetyViolation {
  final ViolationType type;
  final ViolationSeverity severity;
  final String description;
  final String suggestedFix;

  SafetyViolation({
    required this.type,
    required this.severity,
    required this.description,
    required this.suggestedFix,
  });
}

/// RIVET-lite metrics
class RivetMetrics {
  final int contradictions;
  final int hallucinations;
  final int uncertaintyTriggers;
  final double alignScore;
  final double riskScore;

  RivetMetrics({
    required this.contradictions,
    required this.hallucinations,
    required this.uncertaintyTriggers,
    required this.alignScore,
    required this.riskScore,
  });
}

/// Types of safety violations
enum ViolationType {
  dignity,
  manipulation,
  rivet,
  phase,
}

/// Severity levels for violations
enum ViolationSeverity {
  low,
  medium,
  high,
}

/// Recommended actions after validation
enum ValidationAction {
  approve,
  warn,
  revise,
  reject,
}