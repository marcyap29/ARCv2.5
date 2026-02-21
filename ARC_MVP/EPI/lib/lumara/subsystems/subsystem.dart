import '../models/command_intent.dart';
import '../models/subsystem_result.dart';

/// Interface for LUMARA subsystems (ARC, ATLAS, CHRONICLE, AURORA).
///
/// The orchestrator routes [CommandIntent]s to subsystems
/// that [canHandle] the intent and calls [query] to get
/// a [SubsystemResult].
abstract class Subsystem {
  /// Display name (e.g. 'CHRONICLE', 'ARC').
  String get name;

  /// Execute a query for this intent. Call only when [canHandle] is true.
  Future<SubsystemResult> query(CommandIntent intent);

  /// Whether this subsystem can handle the given intent.
  bool canHandle(CommandIntent intent);
}
