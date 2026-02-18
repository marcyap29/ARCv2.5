// lib/chronicle/search/chronicle_rerank_service.dart
//
// Optional reranking for chronicle search results.
// When [enableReranking] is true, RRF results are reranked using FeatureBasedReranker.
// Backed by UserChronicleRepository for entry lookup.

import '../dual/repositories/user_chronicle_repository.dart';
import 'chronicle_search_models.dart';
import 'feature_based_reranker.dart';
import 'rerank_context_builder.dart';

/// Service to optionally rerank chronicle search results using biographical features.
/// Pass [HybridSearchResult] list from RRF fusion (or from a simple scored list); returns [RerankResult]s.
class ChronicleRerankService {
  ChronicleRerankService({UserChronicleRepository? userRepo})
      : _userRepo = userRepo ?? UserChronicleRepository();

  final UserChronicleRepository _userRepo;

  /// Rerank [rrfResults] for [userId] and [query].
  /// If [enableReranking] is false or [rrfResults] is empty, returns results as [RerankResult]s with rerankScore = rrfScore.
  /// Otherwise runs [FeatureBasedReranker] with context built from [query] and optional [queryEntities]/[queryThemes].
  Future<List<RerankResult>> rerank({
    required String userId,
    required String query,
    required List<HybridSearchResult> rrfResults,
    bool enableReranking = true,
    List<String>? queryEntities,
    List<String>? queryThemes,
  }) async {
    if (rrfResults.isEmpty) return [];

    if (!enableReranking) {
      return rrfResults.map((r) => RerankResult(
            id: r.id,
            rrfScore: r.rrfScore,
            rerankScore: r.rrfScore,
            features: const RerankingFeatures(
              exactEntityMatch: 0,
              exactTemporalMatch: false,
              themeOverlap: 0,
              hasContext: false,
              contentLength: 0,
              recencyScore: 0,
            ),
          )).toList();
    }

    final getEntry = _buildGetEntry(userId);
    final reranker = FeatureBasedReranker(getEntry: getEntry);
    final context = RerankContextBuilder.fromQuery(
      query,
      queryEntities: queryEntities,
      queryThemes: queryThemes,
    );
    return reranker.rerank(query, rrfResults, context);
  }

  Future<ChronicleEntryForRerank?> _getEntry(String userId, String id) async {
    final entries = await _userRepo.loadEntries(userId);
    for (final e in entries) {
      if (e.id == id) return ChronicleEntryForRerank.fromUserEntry(e);
    }
    return null;
  }

  Future<ChronicleEntryForRerank?> Function(String id) _buildGetEntry(String userId) {
    return (String id) => _getEntry(userId, id);
  }
}
