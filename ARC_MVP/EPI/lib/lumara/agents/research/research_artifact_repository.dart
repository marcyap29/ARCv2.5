// lib/lumara/agents/research/research_artifact_repository.dart
// Persists research artifacts and supports similarity search for Chronicle cross-reference.

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:my_app/chronicle/embeddings/embedding_service.dart';
import 'package:my_app/chronicle/embeddings/create_embedding_service.dart';

import 'research_models.dart';

/// Stored entry: summary + embedding for similarity search.
/// [detailedFindings] optional full report body for edit/save.
/// [abstractBullets] short bullets shown at top of report.
/// [tags] help LUMARA add this research to CHRONICLE.
class StoredResearchArtifact {
  final String sessionId;
  final String userId;
  final String query;
  final String summary;
  final String detailedFindings;
  final List<String> abstractBullets;
  final List<String> tags;
  final DateTime timestamp;
  final String phaseName;
  final List<double> embedding;
  final bool archived;
  final DateTime? archivedAt;

  const StoredResearchArtifact({
    required this.sessionId,
    required this.userId,
    required this.query,
    required this.summary,
    this.detailedFindings = '',
    this.abstractBullets = const [],
    this.tags = const [],
    required this.timestamp,
    required this.phaseName,
    required this.embedding,
    this.archived = false,
    this.archivedAt,
  });

  StoredResearchArtifact copyWith({
    String? query,
    String? summary,
    String? detailedFindings,
    List<String>? abstractBullets,
    List<String>? tags,
    List<double>? embedding,
    bool? archived,
    DateTime? archivedAt,
  }) {
    return StoredResearchArtifact(
      sessionId: sessionId,
      userId: userId,
      query: query ?? this.query,
      summary: summary ?? this.summary,
      detailedFindings: detailedFindings ?? this.detailedFindings,
      abstractBullets: abstractBullets ?? this.abstractBullets,
      tags: tags ?? this.tags,
      timestamp: timestamp,
      phaseName: phaseName,
      embedding: embedding ?? this.embedding,
      archived: archived ?? this.archived,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'userId': userId,
        'query': query,
        'summary': summary,
        'detailedFindings': detailedFindings,
        'abstractBullets': abstractBullets,
        'tags': tags,
        'timestamp': timestamp.toIso8601String(),
        'phaseName': phaseName,
        'embedding': embedding,
        'archived': archived,
        'archivedAt': archivedAt?.toIso8601String(),
      };

  static StoredResearchArtifact fromJson(Map<String, dynamic> json) {
    final bulletsRaw = json['abstractBullets'];
    List<String> bullets = const [];
    if (bulletsRaw is List<dynamic>) {
      bullets = bulletsRaw.map((e) => e.toString()).toList();
    }
    final tagsRaw = json['tags'];
    List<String> tagList = const [];
    if (tagsRaw is List<dynamic>) {
      tagList = tagsRaw.map((e) => e.toString()).toList();
    }
    return StoredResearchArtifact(
      sessionId: json['sessionId'] as String,
      userId: json['userId'] as String,
      query: json['query'] as String,
      summary: json['summary'] as String,
      detailedFindings: json['detailedFindings'] as String? ?? '',
      abstractBullets: bullets,
      tags: tagList,
      timestamp: DateTime.parse(json['timestamp'] as String),
      phaseName: json['phaseName'] as String,
      embedding: (json['embedding'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
      archived: json['archived'] as bool? ?? false,
      archivedAt: json['archivedAt'] != null ? DateTime.tryParse(json['archivedAt'] as String) : null,
    );
  }
}

/// Persisted repository for research artifacts with embedding-based similarity.
class ResearchArtifactRepository {
  ResearchArtifactRepository._();
  static final ResearchArtifactRepository instance = ResearchArtifactRepository._();

  /// Returns the singleton instance. Use [instance] or this factory.
  factory ResearchArtifactRepository() => instance;

  final List<StoredResearchArtifact> _store = [];
  bool _loaded = false;
  EmbeddingService? _embedder;
  static const double _similarityThreshold = 0.7;
  static const int _maxResults = 10;
  static const String _fileName = 'research_artifacts.json';

  Future<String> _getFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return path.join(dir.path, _fileName);
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);
      if (!await file.exists()) return;
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>?;
      if (list == null) return;
      _store.clear();
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          _store.add(StoredResearchArtifact.fromJson(e));
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('ResearchArtifactRepository: load failed: $e');
    }
  }

  Future<void> _save() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);
      final list = _store.map((a) => a.toJson()).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (e) {
      // ignore: avoid_print
      print('ResearchArtifactRepository: save failed: $e');
    }
  }

  Future<EmbeddingService> _getEmbedder() async {
    _embedder ??= await createEmbeddingService();
    return _embedder!;
  }

  /// All artifacts (for export). Loads from disk if needed.
  Future<List<StoredResearchArtifact>> listAllForExport() async {
    await _ensureLoaded();
    return List.from(_store);
  }

  /// Replace store with imported list (for import). Clears and saves.
  Future<void> replaceAllForImport(List<StoredResearchArtifact> artifacts) async {
    _store.clear();
    _store.addAll(artifacts);
    _loaded = true;
    await _save();
  }

  /// List artifacts for user. If [includeArchived] is false, only active ones are returned.
  Future<List<StoredResearchArtifact>> listForUser(String userId, {bool includeArchived = true}) async {
    await _ensureLoaded();
    var list = _store.where((a) => a.userId == userId).toList();
    if (!includeArchived) list = list.where((a) => !a.archived).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  /// Archive an artifact.
  Future<void> archiveArtifact(String userId, String sessionId) async {
    await _ensureLoaded();
    final i = _store.indexWhere((a) => a.userId == userId && a.sessionId == sessionId);
    if (i < 0) return;
    _store[i] = _store[i].copyWith(archived: true, archivedAt: DateTime.now());
    await _save();
  }

  /// Unarchive an artifact.
  Future<void> unarchiveArtifact(String userId, String sessionId) async {
    await _ensureLoaded();
    final i = _store.indexWhere((a) => a.userId == userId && a.sessionId == sessionId);
    if (i < 0) return;
    _store[i] = _store[i].copyWith(archived: false, archivedAt: null);
    await _save();
  }

  /// Permanently delete all artifacts for this report (removes every duplicate with same userId + sessionId).
  Future<void> deleteArtifact(String userId, String sessionId) async {
    await _ensureLoaded();
    _store.removeWhere((a) => a.userId == userId && a.sessionId == sessionId);
    await _save();
  }

  /// Store a research artifact and index it for similarity search.
  /// Replaces any existing artifact with the same [userId] and [artifact.sessionId]
  /// so the same research run never appears twice in the timeline.
  Future<void> storeArtifact({
    required String userId,
    required ResearchArtifact artifact,
  }) async {
    await _ensureLoaded();
    _store.removeWhere((a) => a.userId == userId && a.sessionId == artifact.sessionId);

    final embedder = await _getEmbedder();
    final textToEmbed = '${artifact.query}\n${artifact.report.summary}';
    final embedding = await embedder.embed(textToEmbed);

    final stored = StoredResearchArtifact(
      sessionId: artifact.sessionId,
      userId: userId,
      query: artifact.query,
      summary: artifact.report.summary,
      detailedFindings: artifact.report.detailedFindings,
      abstractBullets: artifact.report.abstractBullets,
      timestamp: artifact.timestamp,
      phaseName: artifact.phase.name,
      embedding: embedding,
    );
    _store.add(stored);
    await _save();
  }

  /// Update artifact content (query, summary, detailedFindings, tags). Re-embeds for similarity search.
  Future<void> updateArtifactContent({
    required String userId,
    required String sessionId,
    String? query,
    String? summary,
    String? detailedFindings,
    List<String>? tags,
  }) async {
    await _ensureLoaded();
    final i = _store.indexWhere((a) => a.userId == userId && a.sessionId == sessionId);
    if (i < 0) return;
    final existing = _store[i];
    final newQuery = query ?? existing.query;
    final newSummary = summary ?? existing.summary;
    final newDetailed = detailedFindings ?? existing.detailedFindings;
    final newTags = tags ?? existing.tags;

    final embedder = await _getEmbedder();
    final textToEmbed = '$newQuery\n$newSummary';
    final embedding = await embedder.embed(textToEmbed);

    _store[i] = existing.copyWith(
      query: newQuery,
      summary: newSummary,
      detailedFindings: newDetailed,
      tags: newTags,
      embedding: embedding,
    );
    await _save();
  }

  /// Get artifact by id (for loading full content for edit).
  Future<StoredResearchArtifact?> getArtifact(String userId, String sessionId) async {
    await _ensureLoaded();
    try {
      return _store.firstWhere((a) => a.userId == userId && a.sessionId == sessionId);
    } catch (_) {
      return null;
    }
  }

  /// Find research sessions semantically similar to the query.
  Future<List<ResearchArtifactSummary>> findSimilar({
    required String userId,
    required String query,
    double threshold = _similarityThreshold,
    int limit = _maxResults,
  }) async {
    await _ensureLoaded();
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
