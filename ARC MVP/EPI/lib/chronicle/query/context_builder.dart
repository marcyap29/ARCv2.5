import '../storage/aggregation_repository.dart';
import '../models/chronicle_aggregation.dart';
import '../models/chronicle_layer.dart';
import '../models/query_plan.dart';

/// Context Builder for CHRONICLE
/// 
/// Formats aggregations for prompt injection.
/// Handles cross-layer navigation and builds drill-down paths.

class ChronicleContextBuilder {
  final AggregationRepository _aggregationRepo;

  ChronicleContextBuilder({
    required AggregationRepository aggregationRepo,
  }) : _aggregationRepo = aggregationRepo;

  /// Build context string from query plan
  Future<String?> buildContext({
    required String userId,
    required QueryPlan queryPlan,
  }) async {
    if (!queryPlan.usesChronicle || queryPlan.layers.isEmpty) {
      return null;
    }

    // Load aggregations for each layer
    final aggregations = <ChronicleAggregation>[];

    for (final layer in queryPlan.layers) {
      final period = _getPeriodForLayer(layer, queryPlan.dateFilter);
      if (period == null) continue;

      final agg = await _aggregationRepo.loadLayer(
        userId: userId,
        layer: layer,
        period: period,
      );

      if (agg != null) {
        aggregations.add(agg);
      }
    }

    if (aggregations.isEmpty) {
      return null;
    }

    // Format aggregations for prompt
    return _formatAggregationsForPrompt(aggregations, queryPlan);
  }

  /// Get period identifier for a layer based on date filter or current period
  String? _getPeriodForLayer(ChronicleLayer layer, DateTimeRange? dateFilter) {
    final now = DateTime.now();

    if (dateFilter != null) {
      // Use date filter to determine period
      switch (layer) {
        case ChronicleLayer.monthly:
          return '${dateFilter.start.year}-${dateFilter.start.month.toString().padLeft(2, '0')}';
        case ChronicleLayer.yearly:
          return '${dateFilter.start.year}';
        case ChronicleLayer.multiyear:
          return '${dateFilter.start.year}-${dateFilter.end.year}';
        default:
          return null;
      }
    }

    // Default to current period
    switch (layer) {
      case ChronicleLayer.monthly:
        return '${now.year}-${now.month.toString().padLeft(2, '0')}';
      case ChronicleLayer.yearly:
        return '${now.year}';
      case ChronicleLayer.multiyear:
        // Default to last 5 years
        return '${now.year - 4}-${now.year}';
      default:
        return null;
    }
  }

  /// Format aggregations for prompt injection
  String _formatAggregationsForPrompt(
    List<ChronicleAggregation> aggregations,
    QueryPlan queryPlan,
  ) {
    if (aggregations.isEmpty) return '';

    final buffer = StringBuffer();

    buffer.writeln('<chronicle_context>');
    buffer.writeln('CHRONICLE provides pre-synthesized temporal intelligence from journal history.');
    buffer.writeln('The following aggregation(s) have been selected as most relevant to this query:');
    buffer.writeln('');
    buffer.writeln('To link from a monthly summary to specific dated journal entries: use the "Linked entries (this month)" section in monthly aggregations (format: YYYY-MM-DD | entry_id), or use source_entry_ids in the aggregation metadata. You can retrieve or cite the exact entry by date or entry_id when the user asks for evidence or detail.');
    buffer.writeln('');

    for (final agg in aggregations) {
      buffer.writeln('## ${agg.layer.displayName}: ${agg.period}');
      buffer.writeln('');
      buffer.writeln(agg.content);
      buffer.writeln('');
      buffer.writeln('---');
      buffer.writeln('');
    }

    buffer.writeln('Source layers: ${aggregations.map((a) => a.layer.displayName).join(', ')}');
    buffer.writeln('</chronicle_context>');

    return buffer.toString();
  }

  /// Build mini-context for voice mode (50-100 tokens)
  Future<String?> buildMiniContext({
    required String userId,
    required ChronicleLayer layer,
    required String period,
  }) async {
    final agg = await _aggregationRepo.loadLayer(
      userId: userId,
      layer: layer,
      period: period,
    );

    if (agg == null) return null;

    // Extract key information (themes, phase, events)
    final themes = _extractTopThemes(agg.content, maxThemes: 3);
    final phase = _extractDominantPhase(agg.content);
    final events = _extractSignificantEvents(agg.content, maxEvents: 2);

    final buffer = StringBuffer();
    buffer.write('${layer.displayName} ($period): ');
    
    if (themes.isNotEmpty) {
      buffer.write('${themes.join(', ')}. ');
    }
    
    if (phase != null) {
      buffer.write('Phase: $phase. ');
    }
    
    if (events.isNotEmpty) {
      buffer.write('Key events: ${events.join('; ')}. ');
    }

    return buffer.toString().trim();
  }

  /// Extract top themes from aggregation content
  List<String> _extractTopThemes(String content, {int maxThemes = 3}) {
    final themeSection = RegExp(r'## Dominant [Tt]hemes(.*?)##', dotAll: true)
        .firstMatch(content);
    if (themeSection == null) return [];

    final themes = RegExp(r'\*\*(\w+(?:\s+\w+)?)\*\*')
        .allMatches(themeSection.group(1) ?? '')
        .map((m) => m.group(1) ?? '')
        .where((t) => t.isNotEmpty)
        .take(maxThemes)
        .toList();

    return themes;
  }

  /// Extract dominant phase from aggregation content
  String? _extractDominantPhase(String content) {
    final match = RegExp(r'Primary phase[:\*]+ (\w+)').firstMatch(content);
    return match?.group(1);
  }

  /// Extract significant events from aggregation content
  List<String> _extractSignificantEvents(String content, {int maxEvents = 2}) {
    final eventsSection = RegExp(r'## Significant Events(.*?)##', dotAll: true)
        .firstMatch(content);
    if (eventsSection == null) return [];

    final events = RegExp(r'- \*\*([^\*]+):\*\* ([^\n]+)')
        .allMatches(eventsSection.group(1) ?? '')
        .map((m) => '${m.group(1)}: ${m.group(2)}')
        .take(maxEvents)
        .toList();

    return events;
  }
}
