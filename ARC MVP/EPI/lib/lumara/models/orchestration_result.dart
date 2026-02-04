import 'command_intent.dart';
import 'subsystem_result.dart';

/// Result of a LUMARA orchestrator run: intent, subsystem results, and aggregated context.
///
/// [toContextMap] produces a map suitable for Master Prompt / prompt builder
/// (e.g. keys 'CHRONICLE', 'ARC', 'ATLAS' with string values for injection).
class OrchestrationResult {
  /// The parsed intent that was executed.
  final CommandIntent intent;

  /// Results from each subsystem that was queried.
  final List<SubsystemResult> subsystemResults;

  /// When the orchestration ran.
  final DateTime timestamp;

  const OrchestrationResult({
    required this.intent,
    required this.subsystemResults,
    required this.timestamp,
  });

  /// Build a map for prompt context: source name → string content.
  ///
  /// Used by Master Prompt / prompt builder to inject subsystem context.
  /// Error results are omitted; successful results contribute their main content.
  Map<String, String> toContextMap() {
    final map = <String, String>{};
    for (final r in subsystemResults) {
      if (r.isError) continue;
      final content = _formatResultForPrompt(r);
      if (content.isNotEmpty) {
        map[r.source] = content;
      }
    }
    return map;
  }

  /// Get the first successful result from a subsystem by name.
  SubsystemResult? getSubsystemResult(String source) {
    try {
      return subsystemResults.firstWhere((r) => r.source == source && !r.isError);
    } catch (_) {
      return null;
    }
  }

  /// Get raw data from a subsystem by name (convenience).
  Map<String, dynamic>? getSubsystemData(String source) {
    final r = getSubsystemResult(source);
    return r?.data;
  }

  static String _formatResultForPrompt(SubsystemResult r) {
    if (r.data.containsKey('aggregations') && r.data['aggregations'] != null) {
      return r.data['aggregations'] as String;
    }
    if (r.data.containsKey('entries') && r.data['entries'] != null) {
      final entries = r.data['entries'];
      if (entries is List) {
        return entries.map((e) => e.toString()).join('\n');
      }
    }
    // Fallback: serialize data for prompt
    final buf = StringBuffer();
    for (final entry in r.data.entries) {
      if (entry.value != null && entry.value.toString().isNotEmpty) {
        buf.writeln('${entry.key}: ${entry.value}');
      }
    }
    return buf.toString().trim();
  }

  /// Create an error result when orchestration fails before subsystems run.
  factory OrchestrationResult.error({
    required CommandIntent intent,
    required String message,
  }) {
    return OrchestrationResult(
      intent: intent,
      subsystemResults: [
        SubsystemResult.error(source: 'ORCHESTRATOR', message: message),
      ],
      timestamp: DateTime.now(),
    );
  }

  bool get isError =>
      subsystemResults.length == 1 &&
      subsystemResults.single.source == 'ORCHESTRATOR' &&
      subsystemResults.single.isError;
}
