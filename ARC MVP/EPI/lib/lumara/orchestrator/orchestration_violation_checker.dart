// lib/lumara/orchestrator/orchestration_violation_checker.dart
// Validates agent output for orchestration violations (e.g. agent trying to invoke
// another agent or access timeline directly). Used by LumaraChatOrchestrator.

/// Result of checking agent output for orchestration violations.
class OrchestrationViolationResult {
  final bool hasViolation;
  final String sanitized;
  final List<String> violations;

  const OrchestrationViolationResult({
    required this.hasViolation,
    required this.sanitized,
    required this.violations,
  });
}

/// Patterns that indicate an agent attempted to bypass LUMARA orchestration.
final List<RegExp> _violationPatterns = [
  RegExp(r'invoke\s+(?:the\s+)?Research\s+Agent', caseSensitive: false),
  RegExp(r'invoke\s+(?:the\s+)?Writing\s+Agent', caseSensitive: false),
  RegExp(r'call\s+(?:the\s+)?(?:Research|Writing)\s+Agent', caseSensitive: false),
  RegExp(r"access\s+(?:user'?s?|your)\s+timeline\s+directly", caseSensitive: false),
  RegExp(r"access\s+(?:user'?s?|your)\s+timeline\s+to", caseSensitive: false),
  RegExp(r'let\s+me\s+invoke', caseSensitive: false),
  RegExp(r"I'll\s+invoke", caseSensitive: false),
  RegExp(r'I\s+will\s+invoke', caseSensitive: false),
  RegExp(r'calling\s+(?:the\s+)?(?:Research|Writing)\s+Agent', caseSensitive: false),
  RegExp(r'send\s+results\s+to\s+user\s+without\s+LUMARA', caseSensitive: false),
];

/// Checks [agentOutput] for orchestration violations, returns sanitized text and any violations.
OrchestrationViolationResult checkAndSanitize({
  required String agentOutput,
  required String agentName,
  void Function(String agent, String violation, String snippet)? onViolation,
}) {
  final violations = <String>[];
  String sanitized = agentOutput;

  for (final pattern in _violationPatterns) {
    final matches = pattern.allMatches(sanitized);
    for (final m in matches) {
      final snippet = m.group(0) ?? '';
      if (snippet.isEmpty) continue;
      violations.add(snippet);
      if (onViolation != null) {
        onViolation(agentName, 'Attempted to bypass LUMARA orchestration', snippet);
      }
    }
  }

  if (violations.isEmpty) {
    return OrchestrationViolationResult(
      hasViolation: false,
      sanitized: agentOutput,
      violations: const [],
    );
  }

  // Strip sentences that contain any violation phrase.
  final lines = agentOutput.split('\n');
  final kept = <String>[];
  for (final line in lines) {
    bool drop = false;
    for (final pattern in _violationPatterns) {
      if (pattern.hasMatch(line)) {
        drop = true;
        break;
      }
    }
    if (!drop) kept.add(line);
  }
  sanitized = kept.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

  return OrchestrationViolationResult(
    hasViolation: true,
    sanitized: sanitized,
    violations: violations,
  );
}

/// Logs an orchestration violation (e.g. for monitoring). Override or replace with analytics later.
void logOrchestrationViolation({
  required String agent,
  required String violation,
  required String responseSnippet,
}) {
  // ignore: avoid_print
  print('LUMARA Orchestration: violation detected from $agent: $violation — "$responseSnippet"');
}
