import '../models/command_intent.dart';
import '../models/subsystem_result.dart';
import '../models/orchestration_result.dart';

/// Combines subsystem results into an [OrchestrationResult] for the orchestrator.
///
/// Used by [LumaraOrchestrator] after parallel subsystem queries.
/// Does not call the LLM; only aggregates results for the prompt builder.
class ResultAggregator {
  /// Build an [OrchestrationResult] from [results] and [intent].
  ///
  /// All [results] are included; [OrchestrationResult.toContextMap] and
  /// prompt builder will skip error results when building context.
  OrchestrationResult aggregate(
    List<SubsystemResult> results,
    CommandIntent intent,
  ) {
    return OrchestrationResult(
      intent: intent,
      subsystemResults: List.unmodifiable(results),
      timestamp: DateTime.now(),
    );
  }
}
