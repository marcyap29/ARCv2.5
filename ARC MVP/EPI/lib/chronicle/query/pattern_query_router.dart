import '../index/chronicle_index_builder.dart';
import '../matching/three_stage_matcher.dart';
import '../models/chronicle_index.dart';
import '../models/dominant_theme.dart';
import '../models/theme_cluster.dart';
import '../models/pattern_insights.dart';
import '../embeddings/local_embedding_service.dart';

/// Routes queries to appropriate response type.
/// Pattern queries use cross-temporal index; temporal queries use CHRONICLE aggregations.
class PatternQueryRouter {
  final ChronicleIndexBuilder _indexBuilder;
  final ThreeStagePatternMatcher _matcher;
  final LocalEmbeddingService _embedder;

  PatternQueryRouter({
    required ChronicleIndexBuilder indexBuilder,
    required ThreeStagePatternMatcher matcher,
    required LocalEmbeddingService embedder,
  })  : _indexBuilder = indexBuilder,
        _matcher = matcher,
        _embedder = embedder;

  Future<QueryResponse> routeQuery({
    required String userId,
    required String query,
  }) async {
    final index = await _indexBuilder.loadIndex(userId);
    final intent = _classifyIntent(query);

    // ignore: avoid_print
    print('🔍 Query: "$query"');
    // ignore: avoid_print
    print('   Intent: ${intent.type}');

    switch (intent.type) {
      case QueryType.patternRecognition:
        return await _handlePatternQuery(userId, query, index, intent);

      case QueryType.arcTracking:
        return await _handleArcQuery(userId, query, index, intent);

      case QueryType.resolutionGuidance:
        return await _handleResolutionQuery(userId, query, index, intent);

      default:
        return QueryResponse.needsStandardChronicle(query);
    }
  }

  Future<QueryResponse> _handlePatternQuery(
    String userId,
    String query,
    ChronicleIndex index,
    QueryIntent intent,
  ) async {
    final theme = intent.extractedTheme ?? _extractTheme(query);

    // ignore: avoid_print
    print('   Searching for pattern: "$theme"');

    final embedding = await _embedder.embed(theme);
    final queryTheme = DominantTheme(
      themeLabel: theme,
      themeSummary: theme,
      embedding: embedding,
      confidence: 1.0,
      evidenceRefs: [],
    );

    final matchResult = await _matcher.findMatch(
      queryTheme: queryTheme,
      index: index,
    );

    if (matchResult.confidence == MatchConfidence.none) {
      // ignore: avoid_print
      print('   ✗ No pattern found');
      return QueryResponse.noPattern(theme);
    }

    final cluster = matchResult.match!.cluster;

    // ignore: avoid_print
    print('   ✓ Pattern found: "${cluster.canonicalLabel}"');
    // ignore: avoid_print
    print('     Appearances: ${cluster.totalAppearances}');

    final response = _buildPatternResponse(theme, cluster);

    return QueryResponse.pattern(
      theme: theme,
      cluster: cluster,
      response: response,
    );
  }

  String _buildPatternResponse(String theme, ThemeCluster cluster) {
    final insights = cluster.insights;

    return '''
**Pattern Recognition: "$theme"**

This is a recurring pattern in your history. You've experienced this ${cluster.totalAppearances} times:

${cluster.appearances.map((a) => '• ${a.period}: ${a.context.isNotEmpty ? a.context.first : "General occurrence"}').join('\n')}

**Pattern Analysis:**
• Type: ${insights.recurrenceType}
• Trigger: ${insights.trigger ?? "Not identified"}
• Phase correlation: ${insights.phaseCorrelation ?? "None"} (${((insights.phaseCorrelationStrength ?? 0) * 100).toStringAsFixed(0)}% consistent)
• Typical duration: ${insights.typicalDurationDays ?? "Variable"} days
• Resolution: ${insights.primaryResolution ?? "Inconsistent"}
• Confidence: ${(insights.confidence * 100).toStringAsFixed(0)}%

**Theme variations you've used:**
${cluster.aliases.map((a) => '  - "$a"').join('\n')}

**Based on your history:**
${_generatePrediction(insights)}
''';
  }

  String _generatePrediction(PatternInsights insights) {
    if (insights.resolutionConsistency == 'high') {
      return "This pattern typically resolves through ${insights.primaryResolution} "
          "in about ${insights.typicalDurationDays} days. Every previous instance "
          "followed this pattern—you can expect similar resolution this time.";
    } else if (insights.resolutionConsistency == 'medium') {
      return "${insights.primaryResolution} has worked in some cases. "
          "Worth examining what was different in successful attempts.";
    } else {
      return "No consistent resolution pattern found. This may require strategic "
          "attention or a different approach than you've tried before.";
    }
  }

  Future<QueryResponse> _handleArcQuery(
    String userId,
    String query,
    ChronicleIndex index,
    QueryIntent intent,
  ) async {
    return QueryResponse.needsStandardChronicle(query);
  }

  Future<QueryResponse> _handleResolutionQuery(
    String userId,
    String query,
    ChronicleIndex index,
    QueryIntent intent,
  ) async {
    return QueryResponse.needsStandardChronicle(query);
  }

  QueryIntent _classifyIntent(String query) {
    final lower = query.toLowerCase();

    if (lower.contains('before') ||
        lower.contains('pattern') ||
        lower.contains('always') ||
        lower.contains('every time')) {
      return QueryIntent(
        type: QueryType.patternRecognition,
        extractedTheme: _extractTheme(query),
      );
    }

    if (lower.contains('still') ||
        lower.contains('keep') ||
        lower.contains('why do i')) {
      return QueryIntent(
        type: QueryType.arcTracking,
        extractedTheme: _extractTheme(query),
      );
    }

    if (lower.contains('resolve') ||
        lower.contains('get over') ||
        lower.contains('how do i')) {
      return QueryIntent(
        type: QueryType.resolutionGuidance,
        extractedTheme: _extractTheme(query),
      );
    }

    return QueryIntent(type: QueryType.needsStandardChronicle);
  }

  String _extractTheme(String query) {
    const stopWords = [
      'why', 'do', 'i', 'am', 'is', 'the', 'a', 'how', 'what',
    ];
    final words = query.toLowerCase().split(RegExp(r'\s+'));
    final themeWords = words.where((w) => !stopWords.contains(w)).toList();
    return themeWords.take(5).join(' ');
  }
}

enum QueryType {
  patternRecognition,
  arcTracking,
  resolutionGuidance,
  needsStandardChronicle,
}

class QueryIntent {
  final QueryType type;
  final String? extractedTheme;

  QueryIntent({
    required this.type,
    this.extractedTheme,
  });
}

class QueryResponse {
  final QueryType type;
  final String response;
  final ThemeCluster? cluster;

  QueryResponse({
    required this.type,
    required this.response,
    this.cluster,
  });

  factory QueryResponse.pattern({
    required String theme,
    required ThemeCluster cluster,
    required String response,
  }) =>
      QueryResponse(
        type: QueryType.patternRecognition,
        response: response,
        cluster: cluster,
      );

  factory QueryResponse.noPattern(String theme) => QueryResponse(
        type: QueryType.patternRecognition,
        response:
            'This appears to be new—no previous instances of "$theme" found in your history.',
      );

  factory QueryResponse.needsStandardChronicle(String query) => QueryResponse(
        type: QueryType.needsStandardChronicle,
        response: 'Using standard CHRONICLE aggregations for: $query',
      );
}
