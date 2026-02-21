// lib/chronicle/search/hybrid_search_engine.dart
//
// LUMARA hybrid search: BM25 + semantic in parallel, adaptive RRF fusion,
// optional feature-based reranking. Two-step pattern: Search (ids/scores) then Get (full entries).
//
// Example with reranking:
//   final results = await engine.search(userId, query, options: HybridSearchOptions(
//     topK: 10,
//     enableReranking: true,
//   ));
//   // Then fetch full entries for results.map((r) => r.id) via ChronicleQueryAdapter.

import '../dual/models/chronicle_models.dart';
import '../dual/services/chronicle_query_adapter.dart';
import '../embeddings/embedding_service.dart';
import 'bm25_index.dart';
import 'chronicle_search_models.dart';
import 'adaptive_fusion_engine.dart';
import 'chronicle_rerank_service.dart';
import 'semantic_index.dart';

/// Options for hybrid search.
class HybridSearchOptions {
  /// Number of final results to return (after fusion and optional rerank).
  final int topK;
  /// Minimum RRF score to keep (before rerank).
  final double minScore;
  /// Candidate expansion multiplier: fetch topK * [candidateMultiplier] from each channel before fusion.
  final int candidateMultiplier;
  /// Whether to run feature-based reranking after RRF.
  final bool enableReranking;

  const HybridSearchOptions({
    this.topK = 10,
    this.minScore = 0.0,
    this.candidateMultiplier = 3,
    this.enableReranking = false,
  });
}

/// Hybrid search engine: BM25 + semantic + RRF, optional rerank.
class HybridSearchEngine {
  HybridSearchEngine({
    required ChronicleQueryAdapter chronicleAdapter,
    required EmbeddingService embeddingService,
    ChronicleRerankService? rerankService,
    AdaptiveFusionEngine? fusionEngine,
  })  : _chronicleAdapter = chronicleAdapter,
        _embedding = embeddingService,
        _rerankService = rerankService ?? ChronicleRerankService(chronicleAdapter: chronicleAdapter),
        _fusionEngine = fusionEngine ?? AdaptiveFusionEngine();

  final ChronicleQueryAdapter _chronicleAdapter;
  final EmbeddingService _embedding;
  final ChronicleRerankService _rerankService;
  final AdaptiveFusionEngine _fusionEngine;

  final BM25Index _bm25Index = BM25Index();
  SemanticIndex? _semanticIndex;
  String? _cachedUserId;
  List<String>? _cachedEntryIds;

  /// Ensure semantic index is built for [userId] and [entries]; reuse cache if same entry set.
  Future<SemanticIndex> _getOrBuildSemanticIndex(String userId, List<UserEntry> entries) async {
    final ids = entries.map((e) => e.id).toList()..sort();
    final key = ids.join(',');
    if (_cachedUserId == userId && _cachedEntryIds != null && _cachedEntryIds!.join(',') == key) {
      return _semanticIndex!;
    }
    _semanticIndex = SemanticIndex(embeddingService: _embedding);
    final indexable = entries.map((e) => IndexableEntry(id: e.id, text: e.content)).toList();
    await _semanticIndex!.index(indexable);
    _cachedUserId = userId;
    _cachedEntryIds = ids;
    return _semanticIndex!;
  }

  /// Run hybrid search for [userId] and [query]. Returns [RerankResult]s (with rerankScore = rrfScore when reranking off).
  Future<List<RerankResult>> search(
    String userId,
    String query, {
    HybridSearchOptions options = const HybridSearchOptions(),
  }) async {
    final entries = await _chronicleAdapter.loadEntries(userId);
    if (entries.isEmpty) return [];

    final indexable = entries.map((e) => IndexableEntry(id: e.id, text: e.content)).toList();
    _bm25Index.index(indexable);
    final semantic = await _getOrBuildSemanticIndex(userId, entries);

    final candidateK = options.topK * options.candidateMultiplier;
    final bm25Results = _bm25Index.search(query, topK: candidateK);
    final semanticResults = await semantic.search(query, topK: candidateK);

    final fused = _fusionEngine.fuse(
      bm25Ids: bm25Results.map((r) => r.id).toList(),
      semanticIds: semanticResults.map((r) => r.id).toList(),
    );

    final filtered = options.minScore > 0
        ? fused.where((r) => r.rrfScore >= options.minScore).toList()
        : fused;
    final top = filtered.take(options.topK).toList();

    if (options.enableReranking && top.isNotEmpty) {
      return _rerankService.rerank(
        userId: userId,
        query: query,
        rrfResults: top,
        enableReranking: true,
      );
    }

    return top.map((r) => RerankResult(
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

  /// Invalidate semantic cache for [userId] (call when entries change).
  void invalidateCache([String? userId]) {
    if (userId == null || _cachedUserId == userId) {
      _cachedUserId = null;
      _cachedEntryIds = null;
      _semanticIndex = null;
    }
  }
}
