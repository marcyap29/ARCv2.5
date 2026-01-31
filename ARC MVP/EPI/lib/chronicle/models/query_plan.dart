import 'chronicle_layer.dart';

/// Query Intent Classification
/// 
/// Represents the type of query the user is making, which determines
/// which CHRONICLE layers should be accessed.

enum QueryIntent {
  /// User wants specific recall: "What did I write last Tuesday?"
  specificRecall,

  /// User wants pattern identification: "What themes keep recurring?"
  patternIdentification,

  /// User wants developmental trajectory: "How have I changed since 2020?"
  developmentalTrajectory,

  /// User wants historical parallel: "Have I dealt with this before?"
  historicalParallel,

  /// User wants inflection point: "When did this shift start?"
  inflectionPoint,

  /// User wants temporal query: "Tell me about my month/year"
  temporalQuery,
}

/// Query Plan
/// 
/// Output from the query router that determines:
/// - Which layers to access
/// - Whether to use CHRONICLE or raw entries
/// - Whether drill-down is needed
/// - Date filters to apply

class QueryPlan {
  /// Classified intent of the query
  final QueryIntent intent;

  /// Which CHRONICLE layers to access (empty if using raw entries)
  final List<ChronicleLayer> layers;

  /// Strategy description for logging/debugging
  final String strategy;

  /// Whether this query should use CHRONICLE aggregations
  final bool usesChronicle;

  /// Whether user may request drill-down to specific entries
  final bool drillDown;

  /// Optional date filter to narrow the query
  final DateTimeRange? dateFilter;

  /// Instructions specific to this query plan
  final String? instructions;

  /// Voice mode specific instructions (shorter)
  final String? voiceInstructions;

  const QueryPlan({
    required this.intent,
    required this.layers,
    required this.strategy,
    required this.usesChronicle,
    this.drillDown = false,
    this.dateFilter,
    this.instructions,
    this.voiceInstructions,
  });

  /// Create a query plan for raw entry mode (no CHRONICLE)
  factory QueryPlan.rawEntry({
    required QueryIntent intent,
    DateTimeRange? dateFilter,
  }) {
    return QueryPlan(
      intent: intent,
      layers: [],
      strategy: 'Use raw journal entries (CHRONICLE not applicable)',
      usesChronicle: false,
      drillDown: false,
      dateFilter: dateFilter,
    );
  }

  /// Create a query plan for CHRONICLE mode
  factory QueryPlan.chronicle({
    required QueryIntent intent,
    required List<ChronicleLayer> layers,
    required String strategy,
    bool drillDown = false,
    DateTimeRange? dateFilter,
    String? instructions,
    String? voiceInstructions,
  }) {
    return QueryPlan(
      intent: intent,
      layers: layers,
      strategy: strategy,
      usesChronicle: true,
      drillDown: drillDown,
      dateFilter: dateFilter,
      instructions: instructions,
      voiceInstructions: voiceInstructions,
    );
  }

  @override
  String toString() {
    final layerNames = layers.map((l) {
      switch (l) {
        case ChronicleLayer.layer0:
          return 'Raw Entries';
        case ChronicleLayer.monthly:
          return 'Monthly';
        case ChronicleLayer.yearly:
          return 'Yearly';
        case ChronicleLayer.multiyear:
          return 'Multi-Year';
      }
    }).join(", ");
    return 'QueryPlan(intent: $intent, layers: $layerNames, usesChronicle: $usesChronicle)';
  }
}

/// Date range helper for query filtering
class DateTimeRange {
  final DateTime start;
  final DateTime end;

  const DateTimeRange({
    required this.start,
    required this.end,
  });

  bool contains(DateTime date) {
    return date.isAfter(start) && date.isBefore(end);
  }

  Duration get duration => end.difference(start);
}
