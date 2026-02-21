import '../storage/aggregation_repository.dart';
import '../models/chronicle_aggregation.dart';
import '../models/chronicle_layer.dart';
import '../models/query_plan.dart';
import 'chronicle_context_cache.dart';

/// Context Builder for CHRONICLE
/// 
/// Formats aggregations for prompt injection.
/// Handles cross-layer navigation and builds drill-down paths.
/// Speed tiers: instant (mini only), fast (single layer compressed), normal/deep (full).
/// Optional [ChronicleContextCache] speeds up repeated queries on the same period.
class ChronicleContextBuilder {
  final AggregationRepository _aggregationRepo;
  final ChronicleContextCache? _cache;

  ChronicleContextBuilder({
    required AggregationRepository aggregationRepo,
    ChronicleContextCache? cache,
  })  : _aggregationRepo = aggregationRepo,
        _cache = cache;

  /// Build context string from query plan.
  /// Uses [queryPlan.speedTarget]: fast → single layer compressed; normal/deep → full.
  /// Uses cache when available (except for deep mode).
  Future<String?> buildContext({
    required String userId,
    required QueryPlan queryPlan,
  }) async {
    if (!queryPlan.usesChronicle || queryPlan.layers.isEmpty) {
      return null;
    }

    final periodKey = _periodKeyForPlan(queryPlan);
    if (periodKey == null) return null;

    if (_cache != null && queryPlan.speedTarget != ResponseSpeed.deep) {
      final cached = _cache!.get(userId: userId, layers: queryPlan.layers, period: periodKey);
      if (cached != null) return cached;
    }

    String? context;
    switch (queryPlan.speedTarget) {
      case ResponseSpeed.instant:
        final layer = queryPlan.layers.first;
        final periods = _getPeriodsForLayer(queryPlan, layer);
        final period = periods != null && periods.isNotEmpty ? periods.first : _getPeriodForLayer(layer, queryPlan.dateFilter);
        if (period == null) return null;
        context = await buildMiniContext(userId: userId, layer: layer, period: period);
        break;
      case ResponseSpeed.fast:
        context = await _buildSingleLayerContext(userId, queryPlan);
        break;
      case ResponseSpeed.normal:
      case ResponseSpeed.deep:
        context = await _buildMultiLayerContext(userId, queryPlan);
    }

    if (_cache != null && context != null && queryPlan.speedTarget != ResponseSpeed.deep) {
      _cache!.put(
        userId: userId,
        layers: queryPlan.layers,
        period: periodKey,
        context: context,
      );
    }
    return context;
  }

  String? _periodKeyForPlan(QueryPlan plan) {
    final parts = <String>[];
    for (final layer in plan.layers) {
      final periods = _getPeriodsForLayer(plan, layer);
      if (periods == null || periods.isEmpty) return null;
      parts.add(periods.join(','));
    }
    return parts.join('|');
  }

  /// Returns one or more period strings for a layer. Uses explicitPeriodsByLayer when set.
  List<String>? _getPeriodsForLayer(QueryPlan plan, ChronicleLayer layer) {
    final explicit = plan.explicitPeriodsByLayer;
    if (explicit != null) {
      String? key;
      switch (layer) {
        case ChronicleLayer.monthly:
          key = 'monthly';
          break;
        case ChronicleLayer.yearly:
          key = 'yearly';
          break;
        case ChronicleLayer.multiyear:
          key = 'multiyear';
          break;
        default:
          break;
      }
      if (key != null) {
        final list = explicit[key];
        if (list != null && list.isNotEmpty) return list;
      }
    }
    final single = _getPeriodForLayer(layer, plan.dateFilter);
    return single != null ? [single] : null;
  }

  /// Single-layer context for fast responses (~2–5k tokens). Supports multiple periods (e.g. compare January vs February).
  Future<String?> _buildSingleLayerContext(String userId, QueryPlan plan) async {
    final layer = plan.layers.first;
    final periods = _getPeriodsForLayer(plan, layer);
    if (periods == null || periods.isEmpty) return null;

    final buffer = StringBuffer();
    buffer.writeln('<chronicle_context>');
    for (final period in periods) {
      final agg = await _aggregationRepo.loadLayer(
        userId: userId,
        layer: layer,
        period: period,
      );
      if (agg == null) continue;
      final compressed = _compressForSpeed(agg, targetTokens: periods.length > 1 ? 1200 : 2000);
      buffer.writeln('Source: ${layer.displayName} aggregation for $period');
      buffer.writeln('User edited: ${agg.userEdited}');
      buffer.writeln('');
      buffer.writeln(compressed);
      buffer.writeln('');
      buffer.writeln('---');
      buffer.writeln('');
    }
    if (plan.drillDown) {
      buffer.writeln('Drill-down available: Can access specific entries on request.');
    }
    buffer.writeln('Source layers: ${layer.displayName}');
    buffer.writeln('</chronicle_context>');
    return buffer.toString();
  }

  /// Multi-layer context (full load and format). Supports multiple periods per layer via explicitPeriodsByLayer.
  Future<String?> _buildMultiLayerContext(String userId, QueryPlan queryPlan) async {
    final aggregations = <ChronicleAggregation>[];

    for (final layer in queryPlan.layers) {
      final periods = _getPeriodsForLayer(queryPlan, layer);
      if (periods == null || periods.isEmpty) continue;

      for (final period in periods) {
        final agg = await _aggregationRepo.loadLayer(
          userId: userId,
          layer: layer,
          period: period,
        );
        if (agg != null) {
          aggregations.add(agg);
        }
      }
    }

    if (aggregations.isEmpty) return null;
    return _formatAggregationsForPrompt(aggregations, queryPlan);
  }

  /// Compress aggregation to target token count while preserving structure.
  /// Headers and bullets are included in priority order but ALL contribute to the token budget.
  String _compressForSpeed(ChronicleAggregation agg, {required int targetTokens}) {
    final lines = agg.content.split('\n');
    final result = <String>[];
    var tokenEstimate = 0;

    for (final line in lines) {
      if (tokenEstimate >= targetTokens) {
        result.add('\n[Additional details available on request]');
        break;
      }
      if (line.startsWith('#')) {
        result.add(line);
        tokenEstimate += line.length ~/ 4;
        continue;
      }
      if (line.trim().startsWith('-') || line.trim().startsWith('*')) {
        result.add(line);
        tokenEstimate += line.length ~/ 4;
        continue;
      }
      if (line.trim().isNotEmpty && !line.startsWith('  ')) {
        final firstSentence = line.split(RegExp(r'[.!?]')).first.trim();
        if (firstSentence.length > 20) {
          result.add('$firstSentence.');
          tokenEstimate += firstSentence.length ~/ 4;
        }
      }
    }
    return result.join('\n');
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

  /// Build mini-context for voice mode (50-100 tokens).
  /// Uses cache when builder was constructed with [ChronicleContextCache].
  Future<String?> buildMiniContext({
    required String userId,
    required ChronicleLayer layer,
    required String period,
  }) async {
    if (_cache != null) {
      final cached = _cache!.get(
        userId: userId,
        layers: [layer],
        period: period,
      );
      if (cached != null) return cached;
    }

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

    final result = buffer.toString().trim();
    if (_cache != null) {
      _cache!.put(
        userId: userId,
        layers: [layer],
        period: period,
        context: result,
      );
    }
    return result;
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
