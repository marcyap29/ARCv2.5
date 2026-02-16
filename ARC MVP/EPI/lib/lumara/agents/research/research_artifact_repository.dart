// lib/lumara/agents/research/research_artifact_repository.dart
// Persists research artifacts and supports similarity search for Chronicle cross-reference.

import 'package:my_app/chronicle/embeddings/embedding_service.dart';
import 'package:my_app/chronicle/embeddings/create_embedding_service.dart';

import 'research_models.dart';

/// Stored entry: summary + embedding for similarity search.
class StoredResearchArtifact {
  final String sessionId;
  final String userId;
  final String query;
  final String summary;
  final DateTime timestamp;
  final String phaseName;
  final List<double> embedding;

  const StoredResearchArtifact({
    required this.sessionId,
    required this.userId,
    required this.query,
    required this.summary,
    required this.timestamp,
    required this.phaseName,
    required this.embedding,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'userId': userId,
        'query': query,
        'summary': summary,
        'timestamp': timestamp.toIso8601String(),
        'phaseName': phaseName,
        'embedding': embedding,
      };

  static StoredResearchArtifact fromJson(Map<String, dynamic> json) {
    return StoredResearchArtifact(
      sessionId: json['sessionId'] as String,
      userId: json['userId'] as String,
      query: json['query'] as String,
      summary: json['summary'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      phaseName: json['phaseName'] as String,
      embedding: (json['embedding'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
    );
  }
}

/// In-memory repository for research artifacts with embedding-based similarity.
/// Can be backed by persistent storage later (e.g. Hive, Isar).
class ResearchArtifactRepository {
  final List<StoredResearchArtifact> _store = [];
  EmbeddingService? _embedder;
  static const double _similarityThreshold = 0.7;
  static const int _maxResults = 10;

  Future<EmbeddingService> _getEmbedder() async {
    _embedder ??= await createEmbeddingService();
    return _embedder!;
  }

  /// Store a research artifact and index it for similarity search.
  Future<void> storeArtifact({
    required String userId,
    required ResearchArtifact artifact,
  }) async {
    final embedder = await _getEmbedder();
    final textToEmbed = '${artifact.query}\n${artifact.report.summary}';
    final embedding = await embedder.embed(textToEmbed);

    final stored = StoredResearchArtifact(
      sessionId: artifact.sessionId,
      userId: userId,
      query: artifact.query,
      summary: artifact.report.summary,
      timestamp: artifact.timestamp,
      phaseName: artifact.phase.name,
      embedding: embedding,
    );
    _store.add(stored);
  }

  /// Find research sessions semantically similar to the query.
  Future<List<ResearchArtifactSummary>> findSimilar({
    required String userId,
    required String query,
    double threshold = _similarityThreshold,
    int limit = _maxResults,
  }) async {
    if (_store.isEmpty) return [];

    final embedder = await _getEmbedder();
    final queryEmbedding = await embedder.embed(query);
    final userArtifacts = _store.where((a) => a.userId == userId).toList();
    if (userArtifacts.isEmpty) return [];

    final scored = <StoredResearchArtifact, double>{};
    for (final a in userArtifacts) {
      final sim = embedder.cosineSimilarity(queryEmbedding, a.embedding);
      if (sim >= threshold) scored[a] = sim;
    }

    final sorted = scored.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) {
      final a = e.key;
      return ResearchArtifactSummary(
        sessionId: a.sessionId,
        query: a.query,
        summary: a.summary,
        timestamp: a.timestamp,
        phase: a.phaseName,
      );
    }).toList();
  }
}
