// lib/chronicle/search/feature_based_reranker.dart
//
// Feature-based reranker for LUMARA chronicle search.
// Reranks top-N RRF results using biographical features (entity, temporal, theme, recency).
// Optional enhancement: enable when complex/ambiguous queries need better precision.

import 'dart:math';

import 'chronicle_search_models.dart';

/// Reranks RRF fusion results using entity match, temporal precision, theme overlap, and recency.
/// Use when: complex pattern queries, ambiguous entity queries, temporal + thematic queries.
/// Skip when: simple entity/temporal/thematic queries (RRF is sufficient).
class FeatureBasedReranker {
  /// Fetches full entry by id for feature extraction. Return null if not found.
  final Future<ChronicleEntryForRerank?> Function(String id) getEntry;

  FeatureBasedReranker({
    required this.getEntry,
  });

  /// Rerank [rrfResults] using [query] and [context]. Returns results sorted by rerank score.
  Future<List<RerankResult>> rerank(
    String query,
    List<HybridSearchResult> rrfResults,
    RerankContext context,
  ) async {
    if (rrfResults.isEmpty) return [];

    final scored = await Future.wait(
      rrfResults.map((result) async {
        final entry = await getEntry(result.id);
        if (entry == null) {
          return RerankResult(
            id: result.id,
            rrfScore: result.rrfScore,
            rerankScore: result.rrfScore,
            features: const RerankingFeatures(
              exactEntityMatch: 0,
              exactTemporalMatch: false,
              themeOverlap: 0,
              hasContext: false,
              contentLength: 0,
              recencyScore: 0,
            ),
          );
        }
        final features = _extractFeatures(query, entry, context);
        final finalScore = _computeRerankScore(result.rrfScore, features);
        return RerankResult(
          id: result.id,
          rrfScore: result.rrfScore,
          rerankScore: finalScore,
          features: features,
        );
      }),
    );

    scored.sort((a, b) => b.rerankScore.compareTo(a.rerankScore));
    return scored;
  }

  RerankingFeatures _extractFeatures(
    String query,
    ChronicleEntryForRerank entry,
    RerankContext context,
  ) {
    final exactEntityMatch = _countExactEntityMatches(
      context.queryEntities,
      entry.people ?? [],
    ).toDouble();
    final exactTemporalMatch = context.temporalContext.yearMonth != null &&
        context.temporalContext.yearMonth == entry.yearMonth;
    final themeOverlap = _calculateThemeOverlap(
      context.queryThemes,
      entry.dominantThemes ?? [],
    );
    final hasContext = (entry.dominantThemes?.isNotEmpty ?? false);
    final contentLength = entry.content.length;
    final recencyScore = _calculateRecency(entry.timestamp);

    return RerankingFeatures(
      exactEntityMatch: exactEntityMatch,
      exactTemporalMatch: exactTemporalMatch,
      themeOverlap: themeOverlap,
      hasContext: hasContext,
      contentLength: contentLength,
      recencyScore: recencyScore,
    );
  }

  double _computeRerankScore(double rrfScore, RerankingFeatures features) {
    double score = rrfScore * 0.7; // RRF base contributes 70%

    // Entity precision boost (15%)
    if (features.exactEntityMatch > 0) {
      score += 0.15 * (features.exactEntityMatch / 3).clamp(0.0, 1.0);
    }

    // Temporal precision boost (10%)
    if (features.exactTemporalMatch) {
      score += 0.1;
    }

    // Theme alignment (5%)
    score += features.themeOverlap * 0.05;

    // Context quality (5%)
    if (features.hasContext) {
      score += 0.05;
    }

    // Recency bias (2%)
    score += features.recencyScore * 0.02;

    return score;
  }

  int _countExactEntityMatches(List<String> queryEntities, List<String> docPeople) {
    if (queryEntities.isEmpty || docPeople.isEmpty) return 0;
    final docLower = docPeople.map((p) => p.toLowerCase()).toSet();
    return queryEntities.where((e) => docLower.contains(e.toLowerCase())).length;
  }

  double _calculateThemeOverlap(List<String> queryThemes, List<String> docThemes) {
    if (queryThemes.isEmpty || docThemes.isEmpty) return 0.0;
    final docSet = docThemes.map((t) => t.toLowerCase()).toSet();
    final overlap = queryThemes.where((t) => docSet.contains(t.toLowerCase())).length;
    return overlap / queryThemes.length;
  }

  double _calculateRecency(DateTime timestamp) {
    final now = DateTime.now();
    final ageInDays = now.difference(timestamp).inDays;
    // Exponential decay: recent entries get slight boost (half-life 90 days)
    return (ageInDays <= 0) ? 1.0 : exp(-ageInDays / 90);
  }
}
