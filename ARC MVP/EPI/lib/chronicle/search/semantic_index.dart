// lib/chronicle/search/semantic_index.dart
//
// Semantic index with embedding cache for chronicle entries.
// Uses EmbeddingService; caches embeddings by entry id.

import '../embeddings/embedding_service.dart';
import 'bm25_index.dart';

/// Semantic (dense) score result.
class SemanticScore {
  final String id;
  final double score;

  const SemanticScore({required this.id, required this.score});
}

/// Semantic index over chronicle entries with id->embedding cache.
class SemanticIndex {
  SemanticIndex({required EmbeddingService embeddingService})
      : _embedding = embeddingService;

  final EmbeddingService _embedding;
  final Map<String, List<double>> _cache = {};

  /// Index [entries]: embed each and fill cache. Existing cache entries for these ids are updated.
  Future<void> index(List<IndexableEntry> entries) async {
    if (entries.isEmpty) return;

    final texts = entries.map((e) => e.text).toList();
    final byText = await _embedding.embedBatch(texts);
    for (var i = 0; i < entries.length; i++) {
      final text = texts[i];
      final emb = byText[text];
      if (emb != null) _cache[entries[i].id] = emb;
    }
  }

  /// Add or update one entry (for incremental sync).
  Future<void> addOrUpdate(IndexableEntry entry) async {
    final emb = await _embedding.embed(entry.text);
    _cache[entry.id] = emb;
  }

  /// Remove from cache.
  void remove(String id) {
    _cache.remove(id);
  }

  /// Search: embed [query], return top [topK] by cosine similarity.
  Future<List<SemanticScore>> search(String query, {int topK = 30}) async {
    if (_cache.isEmpty) return [];
    final qEmb = await _embedding.embed(query);
    final scores = <String, double>{};
    for (final entry in _cache.entries) {
      final sim = _embedding.cosineSimilarity(qEmb, entry.value);
      scores[entry.key] = sim;
    }
    final list = scores.entries
        .map((e) => SemanticScore(id: e.key, score: e.value))
        .toList();
    list.sort((a, b) => b.score.compareTo(a.score));
    return list.take(topK).toList();
  }

  int get documentCount => _cache.length;
}
