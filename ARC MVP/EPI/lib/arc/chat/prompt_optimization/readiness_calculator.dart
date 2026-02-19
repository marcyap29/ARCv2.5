// lib/arc/chat/prompt_optimization/readiness_calculator.dart
//
// Readiness score for prompt optimization context.
// Implementations can plug in phase_history or health readiness.

/// Returns current readiness score (0-100) for a user.
/// Used by UniversalPromptOptimizer to include state in context.
abstract class ReadinessCalculator {
  Future<int> getCurrent(String userId);
}

/// Default: returns a neutral score when no phase/readiness integration is available.
class DefaultReadinessCalculator implements ReadinessCalculator {
  @override
  Future<int> getCurrent(String userId) async => 50;
}
