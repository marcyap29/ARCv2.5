// lib/chronicle/search/rerank_context_builder.dart
//
// Builds RerankContext from a query for feature-based reranking.
// Extracts temporal context (yearMonth) and optional entity/theme lists.

import 'chronicle_search_models.dart';

/// Builds [RerankContext] from a raw query.
/// Use when calling [FeatureBasedReranker.rerank].
class RerankContextBuilder {
  /// Build context from [query]. Optionally pass [queryEntities] and [queryThemes]
  /// if you have an extractor (e.g. NER / theme classifier); otherwise they default to [].
  static RerankContext fromQuery(
    String query, {
    List<String>? queryEntities,
    List<String>? queryThemes,
  }) {
    final yearMonth = _extractYearMonth(query);
    return RerankContext(
      temporalContext: TemporalContext(yearMonth: yearMonth),
      queryEntities: queryEntities ?? const [],
      queryThemes: queryThemes ?? const [],
    );
  }

  /// Extract "YYYY-MM" from query if present (e.g. "March 2024", "2024-03").
  static String? _extractYearMonth(String query) {
    final lower = query.trim().toLowerCase();
    final now = DateTime.now();

    // Explicit "YYYY-MM"
    final isoMatch = RegExp(r'\b(20\d{2})-(\d{1,2})\b').firstMatch(lower);
    if (isoMatch != null) {
      final y = int.tryParse(isoMatch.group(1)!);
      final m = int.tryParse(isoMatch.group(2)!);
      if (y != null && m != null && m >= 1 && m <= 12) {
        final mPadded = m.toString().padLeft(2, '0');
        return '$y-$mPadded';
      }
    }

    // "March 2024" / "Mar 2024"
    const monthNames = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december',
    ];
    const shortMonths = [
      'jan', 'feb', 'mar', 'apr', 'may', 'jun',
      'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
    ];
    for (var i = 0; i < monthNames.length; i++) {
      if (lower.contains(monthNames[i]) || lower.contains(shortMonths[i])) {
        final yearMatch = RegExp(r'\b(20\d{2})\b').firstMatch(lower);
        final year = yearMatch != null ? int.tryParse(yearMatch.group(1)!) : now.year;
        if (year != null) {
          final month = (i + 1).toString().padLeft(2, '0');
          return '$year-$month';
        }
      }
    }

    // Year only -> no single month; return null (no exact temporal match boost).
    return null;
  }
}
