// lib/chronicle/search/chronicle_search_models.dart
//
// Models for LUMARA hybrid search and feature-based reranking.
// Used by FeatureBasedReranker and future HybridSearchEngine integration.

import '../dual/models/chronicle_models.dart';

/// Result from RRF fusion (BM25 + semantic). Used as input to reranking.
class HybridSearchResult {
  final String id;
  final double rrfScore;

  const HybridSearchResult({
    required this.id,
    required this.rrfScore,
  });
}

/// Temporal context extracted from the query (e.g. "March 2024" -> yearMonth).
class TemporalContext {
  final String? yearMonth;

  const TemporalContext({this.yearMonth});

  /// Format: "YYYY-MM" for exact month match, or null if not specified.
  static String? yearMonthFromDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
  }
}

/// Biographical features used to rerank chronicle entries.
class RerankingFeatures {
  /// Query "Sarah" → doc has "Sarah" (exact match count, not semantic).
  final double exactEntityMatch;

  /// Query "March 2024" → doc yearMonth == "2024-03".
  final bool exactTemporalMatch;

  /// Query themes vs doc themes overlap [0, 1].
  final double themeOverlap;

  /// Has causal chains, patterns, or thematic metadata.
  final bool hasContext;

  /// Entry content length (longer often more informative).
  final int contentLength;

  /// Slight recency bias [0, 1].
  final double recencyScore;

  const RerankingFeatures({
    required this.exactEntityMatch,
    required this.exactTemporalMatch,
    required this.themeOverlap,
    required this.hasContext,
    required this.contentLength,
    required this.recencyScore,
  });
}

/// Result after feature-based reranking (includes original RRF score and features).
class RerankResult {
  final String id;
  final double rrfScore;
  final double rerankScore;
  final RerankingFeatures features;

  const RerankResult({
    required this.id,
    required this.rrfScore,
    required this.rerankScore,
    required this.features,
  });
}

/// Context passed to the reranker (temporal + query-derived entities/themes).
class RerankContext {
  final TemporalContext temporalContext;
  final List<String> queryEntities;
  final List<String> queryThemes;

  const RerankContext({
    required this.temporalContext,
    this.queryEntities = const [],
    this.queryThemes = const [],
  });
}

/// Abstraction of a chronicle entry for reranking.
/// Can be built from UserEntry or from future search metadata.
class ChronicleEntryForRerank {
  final String id;
  final String content;
  final DateTime timestamp;
  /// Optional; if null, entity matching is skipped.
  final List<String>? people;
  /// Optional; format "YYYY-MM" for exact temporal match.
  final String? yearMonth;
  /// Optional; for theme overlap (e.g. thematicTags).
  final List<String>? dominantThemes;

  const ChronicleEntryForRerank({
    required this.id,
    required this.content,
    required this.timestamp,
    this.people,
    this.yearMonth,
    this.dominantThemes,
  });

  /// Build from UserEntry (dual chronicle).
  factory ChronicleEntryForRerank.fromUserEntry(UserEntry userEntry) {
    final yearMonth = TemporalContext.yearMonthFromDateTime(userEntry.timestamp);
    // Use extractedKeywords as proxy for "people" / entity-like terms when no dedicated people field.
    return ChronicleEntryForRerank(
      id: userEntry.id,
      content: userEntry.content,
      timestamp: userEntry.timestamp,
      people: userEntry.extractedKeywords,
      yearMonth: yearMonth,
      dominantThemes: userEntry.thematicTags,
    );
  }
}
