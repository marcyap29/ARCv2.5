// lib/chronicle/search/adaptive_fusion_engine.dart
//
// Reciprocal Rank Fusion (RRF) to combine BM25 and semantic rankings.
// Optional per-channel weights for adaptive fusion (e.g. boost BM25 for entity queries).

import 'chronicle_search_models.dart';

/// Fuses two ranked lists (BM25 and semantic) using RRF.
/// score(doc) = wB * 1/(k + rankB) + wS * 1/(k + rankS); default k=60, wB=wS=1.
class AdaptiveFusionEngine {
  AdaptiveFusionEngine({
    this.k = 60,
    this.weightBM25 = 1.0,
    this.weightSemantic = 1.0,
  });

  final int k;
  final double weightBM25;
  final double weightSemantic;

  /// [bm25] and [semantic] are ordered lists (id, score); scores are ignored for RRF, only rank matters.
  /// Returns list of HybridSearchResult sorted by fused RRF score.
  List<HybridSearchResult> fuse({
    required List<String> bm25Ids,
    required List<String> semanticIds,
  }) {
    final rrfScores = <String, double>{};
    for (var r = 0; r < bm25Ids.length; r++) {
      final id = bm25Ids[r];
      rrfScores[id] = (rrfScores[id] ?? 0) + weightBM25 / (k + r + 1);
    }
    for (var r = 0; r < semanticIds.length; r++) {
      final id = semanticIds[r];
      rrfScores[id] = (rrfScores[id] ?? 0) + weightSemantic / (k + r + 1);
    }
    final list = rrfScores.entries
        .map((e) => HybridSearchResult(id: e.key, rrfScore: e.value))
        .toList();
    list.sort((a, b) => b.rrfScore.compareTo(a.rrfScore));
    return list;
  }
}
