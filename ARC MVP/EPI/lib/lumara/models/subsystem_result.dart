/// Standardized result from a LUMARA subsystem.
///
/// Returned by [Subsystem.query]; aggregated by
/// [ResultAggregator] for the orchestrator.
class SubsystemResult {
  /// Subsystem name (e.g. 'CHRONICLE', 'ARC').
  final String source;

  /// Payload for prompt/aggregation (e.g. aggregations text, entries list).
  final Map<String, dynamic> data;

  /// Optional metadata (layers used, compression ratio, etc.).
  final Map<String, dynamic> metadata;

  /// If non-null, query failed and [message] describes why.
  final String? errorMessage;

  const SubsystemResult({
    required this.source,
    required this.data,
    this.metadata = const {},
    this.errorMessage,
  });

  bool get isError => errorMessage != null;

  /// Create an error result (e.g. subsystem threw).
  factory SubsystemResult.error({
    required String source,
    required String message,
  }) {
    return SubsystemResult(
      source: source,
      data: {},
      errorMessage: message,
    );
  }
}
