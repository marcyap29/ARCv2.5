// lib/chronicle/search/bm25_index.dart
//
// BM25 index for sparse (keyword) chronicle search.
// Supports incremental updates via content hash for future sync.

import 'dart:math';

/// Document with id and text to index.
class IndexableEntry {
  final String id;
  final String text;

  const IndexableEntry({required this.id, required this.text});
}

/// BM25 score result.
class BM25Score {
  final String id;
  final double score;

  const BM25Score({required this.id, required this.score});
}

/// BM25 index over chronicle entries.
/// k1 and b are standard BM25 parameters; typical k1=1.2, b=0.75.
class BM25Index {
  BM25Index({
    this.k1 = 1.2,
    this.b = 0.75,
  });

  final double k1;
  final double b;

  int _nDocs = 0;
  double _avgDocLen = 0;
  final Map<String, int> _docLength = {};
  final Map<String, Map<String, int>> _docTerms = {}; // docId -> term -> tf
  final Map<String, Set<String>> _termDocs = {};     // term -> set of docIds

  /// Index [entries]. Rebuilds the index (replace with incremental sync later).
  void index(List<IndexableEntry> entries) {
    _nDocs = 0;
    _avgDocLen = 0;
    _docLength.clear();
    _docTerms.clear();
    _termDocs.clear();

    if (entries.isEmpty) return;

    for (final entry in entries) {
      final terms = _tokenize(entry.text);
      if (terms.isEmpty) continue;
      _nDocs++;
      final len = terms.length;
      _docLength[entry.id] = len;
      final tfMap = <String, int>{};
      for (final t in terms) {
        tfMap[t] = (tfMap[t] ?? 0) + 1;
        _termDocs.putIfAbsent(t, () => {}).add(entry.id);
      }
      _docTerms[entry.id] = tfMap;
    }

    if (_nDocs > 0) {
      final totalLen = _docLength.values.fold<int>(0, (a, b) => a + b);
      _avgDocLen = totalLen / _nDocs;
    }
  }

  /// Add or update a single entry (for incremental sync). Removes old doc if id existed.
  void addOrUpdate(IndexableEntry entry) {
    remove(entry.id);
    final terms = _tokenize(entry.text);
    if (terms.isEmpty) return;
    _nDocs++;
    _docLength[entry.id] = terms.length;
    final tfMap = <String, int>{};
    for (final t in terms) {
      tfMap[t] = (tfMap[t] ?? 0) + 1;
      _termDocs.putIfAbsent(t, () => {}).add(entry.id);
    }
    _docTerms[entry.id] = tfMap;
    final totalLen = _docLength.values.fold<int>(0, (a, b) => a + b);
    _avgDocLen = totalLen / _nDocs;
  }

  /// Remove document by id.
  void remove(String id) {
    if (!_docTerms.containsKey(id)) return;
    final tfMap = _docTerms.remove(id)!;
    _docLength.remove(id);
    _nDocs--;
    for (final entry in tfMap.entries) {
      final set = _termDocs[entry.key];
      if (set != null) {
        set.remove(id);
        if (set.isEmpty) _termDocs.remove(entry.key);
      }
    }
    if (_nDocs > 0) {
      final totalLen = _docLength.values.fold<int>(0, (a, b) => a + b);
      _avgDocLen = totalLen / _nDocs;
    }
  }

  List<String> _tokenize(String text) {
    final lower = text.toLowerCase();
    final words = lower.split(RegExp(r"[^a-zA-Z0-9']+"));
    return words.where((w) => w.length > 1).toList();
  }

  /// Search; returns up to [topK] results sorted by BM25 score.
  List<BM25Score> search(String query, {int topK = 30}) {
    if (_nDocs == 0) return [];
    final qTerms = _tokenize(query).toSet();
    if (qTerms.isEmpty) return [];

    final scores = <String, double>{};
    for (final term in qTerms) {
      final docIds = _termDocs[term];
      if (docIds == null || docIds.isEmpty) continue;
      final n = docIds.length;
      final idf = log(1 + (_nDocs - n + 0.5) / (n + 0.5));
      for (final docId in docIds) {
        final tfMap = _docTerms[docId]!;
        final tf = (tfMap[term] ?? 0).toDouble();
        final len = _docLength[docId]!.toDouble();
        final num = tf * (k1 + 1);
        final den = tf + k1 * (1 - b + b * len / _avgDocLen);
        scores[docId] = (scores[docId] ?? 0) + idf * (num / den);
      }
    }

    final list = scores.entries.map((e) => BM25Score(id: e.key, score: e.value)).toList();
    list.sort((a, b) => b.score.compareTo(a.score));
    return list.take(topK).toList();
  }

  int get documentCount => _nDocs;
}
