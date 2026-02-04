import 'intent_type.dart';

/// Parsed user command for LUMARA orchestrator routing.
///
/// Built by [CommandParser]; consumed by subsystems
/// to execute queries.
class CommandIntent {
  /// Classified intent type (used for routing).
  final IntentType type;

  /// Raw user input (query or command text).
  final String rawQuery;

  /// Optional user ID for context that requires it (e.g. CHRONICLE).
  final String? userId;

  /// Optional max results (e.g. for ARC entry selection).
  final int? maxResults;

  /// Optional domain filter (e.g. Work, Personal - for CHRONICLE/domain filtering).
  final String? domain;

  /// Optional entry ID to exclude from context (e.g. current journal entry for ARC).
  final String? entryId;

  const CommandIntent({
    required this.type,
    required this.rawQuery,
    this.userId,
    this.maxResults,
    this.domain,
    this.entryId,
  });

  @override
  String toString() => 'CommandIntent($type, "${rawQuery.length > 40 ? "${rawQuery.substring(0, 40)}..." : rawQuery}")';
}
