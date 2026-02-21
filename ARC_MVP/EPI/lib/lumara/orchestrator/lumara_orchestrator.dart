import '../models/command_intent.dart';
import '../models/orchestration_result.dart';
import '../models/subsystem_result.dart';
import '../subsystems/subsystem.dart';
import 'command_parser.dart';
import 'result_aggregator.dart';

/// Coordinates LUMARA subsystems: parse → route → parallel query → aggregate.
///
/// Does not call the LLM; produces [OrchestrationResult] for the prompt builder.
class LumaraOrchestrator {
  final List<Subsystem> _subsystems;
  final CommandParser _parser;
  final ResultAggregator _aggregator;

  LumaraOrchestrator({
    required List<Subsystem> subsystems,
    required CommandParser parser,
    required ResultAggregator aggregator,
  })  : _subsystems = List.unmodifiable(subsystems),
        _parser = parser,
        _aggregator = aggregator;

  /// Execute orchestration for [userInput].
  ///
  /// Optional [userId] is attached to the intent when querying subsystems
  /// (e.g. CHRONICLE needs it for context).
  /// Optional [entryId] is attached for ARC (exclude current entry from recent context).
  Future<OrchestrationResult> execute(
    String userInput, {
    String? userId,
    String? entryId,
  }) async {
    final intent = _parser.parse(userInput);
    var attached = _attachUserId(intent, userId);
    if (entryId != null && attached.entryId != entryId) {
      attached = CommandIntent(
        type: attached.type,
        rawQuery: attached.rawQuery,
        userId: attached.userId,
        maxResults: attached.maxResults,
        domain: attached.domain,
        entryId: entryId,
      );
    }
    final intentWithUserId = attached;

    final relevant = _subsystems
        .where((s) => s.canHandle(intentWithUserId))
        .toList();

    if (relevant.isEmpty) {
      return OrchestrationResult.error(
        intent: intentWithUserId,
        message: 'No subsystem can handle intent: ${intent.type}',
      );
    }

    final results = await Future.wait(
      relevant.map((s) => _querySafe(s, intentWithUserId)),
    );

    return _aggregator.aggregate(results, intentWithUserId);
  }

  CommandIntent _attachUserId(CommandIntent intent, String? userId) {
    if (userId == null || userId == intent.userId) return intent;
    return CommandIntent(
      type: intent.type,
      rawQuery: intent.rawQuery,
      userId: userId,
      maxResults: intent.maxResults,
      domain: intent.domain,
      entryId: intent.entryId,
    );
  }

  Future<SubsystemResult> _querySafe(Subsystem s, CommandIntent intent) async {
    try {
      return await s.query(intent);
    } catch (e) {
      return SubsystemResult.error(
        source: s.name,
        message: 'Query failed: $e',
      );
    }
  }
}
