// lib/chronicle/layer0_retrieval/chronicle_layer0_retrieval_service.dart
// CHRONICLE Layer 0 Retrieval: retrieves relevant past entries from Layer 0 for LUMARA context.
// Replaces MIRA-based retrieval for chat context; uses same scoring (lexical) and MemoryRetrievalResult shape.

import 'package:my_app/chronicle/storage/layer0_repository.dart';
import 'package:my_app/arc/chat/services/lumara_reflection_settings_service.dart';
import 'package:my_app/mira/memory/enhanced_memory_schema.dart';
import 'package:my_app/mira/memory/enhanced_mira_memory_service.dart';
import 'package:my_app/mira/memory/memory_mode_service.dart';
import 'package:my_app/mira/core/schema.dart';

/// CHRONICLE Layer 0 Retrieval service.
/// Fetches raw entries from Layer 0 within the user's lookback window, scores by query (lexical),
/// and returns a [MemoryRetrievalResult] compatible with the LUMARA cubit.
class ChronicleLayer0RetrievalService {
  final Layer0Repository _layer0Repo;
  final LumaraReflectionSettingsService _settingsService;

  ChronicleLayer0RetrievalService({
    required Layer0Repository layer0Repo,
    LumaraReflectionSettingsService? settingsService,
  })  : _layer0Repo = layer0Repo,
        _settingsService = settingsService ?? LumaraReflectionSettingsService.instance;

  /// Retrieve relevant past entries from Layer 0 for the given [userId] and [query].
  /// Uses reflection settings for time window, similarity threshold, and max matches.
  /// Returns [MemoryRetrievalResult] so the cubit can consume nodes and attributions unchanged.
  Future<MemoryRetrievalResult> retrieveMemories({
    required String userId,
    String? query,
    List<MemoryDomain>? domains,
    int? limit,
    double? similarityThreshold,
    int? lookbackYears,
    int? maxMatches,
    bool? crossModalEnabled,
  }) async {
    try {
      await _layer0Repo.initialize();
    } catch (e) {
      print('CHRONICLE Layer 0 Retrieval: Layer0 init error: $e');
      return _emptyResult();
    }

    final timeWindowDays = await _settingsService.getEffectiveTimeWindowDays();
    final effectiveThreshold = similarityThreshold ?? await _settingsService.getSimilarityThreshold();
    final effectiveMax = maxMatches ?? limit ?? await _settingsService.getEffectiveMaxMatches();
    final crossModal = crossModalEnabled ?? await _settingsService.isCrossModalEnabled();

    final end = DateTime.now();
    final start = end.subtract(Duration(days: timeWindowDays));

    List<ChronicleRawEntry> entries;
    try {
      entries = await _layer0Repo.getEntriesInRange(userId, start, end);
    } catch (e) {
      print('CHRONICLE Layer 0 Retrieval: getEntriesInRange error: $e');
      return _emptyResult();
    }

    if (entries.isEmpty) {
      print('CHRONICLE Layer 0 Retrieval: No entries in range (last $timeWindowDays days)');
      return _emptyResult();
    }

    // Score and filter by query if provided
    List<ChronicleRawEntry> scored = entries;
    if (query != null && query.trim().isNotEmpty) {
      final queryLower = query.toLowerCase();
      final queryWords = queryLower.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
      final withScores = <_ScoredEntry>[];
      for (final entry in entries) {
        final score = _scoreEntry(entry, query, queryLower, queryWords, crossModal);
        if (effectiveThreshold > 0) {
          if (score >= effectiveThreshold) withScores.add(_ScoredEntry(entry, score));
        } else {
          if (score > 0) withScores.add(_ScoredEntry(entry, score));
        }
      }
      withScores.sort((a, b) => b.score.compareTo(a.score));
      scored = withScores.map((e) => e.entry).toList();
      print('CHRONICLE Layer 0 Retrieval: ${scored.length} entries match query (threshold: $effectiveThreshold)');
    } else {
      // No query: use recency only (newest first)
      scored = List.from(entries)..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    final takeCount = effectiveMax.clamp(1, 50);
    final selected = scored.take(takeCount).toList();
    final nodes = selected.map((e) => _rawToNode(e)).toList();
    final attributions = nodes.map((n) => AttributionTrace(
          nodeRef: n.id,
          relation: 'layer0_retrieval',
          confidence: 0.85,
          timestamp: DateTime.now(),
          phaseContext: n.phaseContext,
          excerpt: n.narrative.length > 200 ? '${n.narrative.substring(0, 200)}...' : n.narrative,
        )).toList();

    print('CHRONICLE Layer 0 Retrieval: Returning ${nodes.length} nodes');
    return MemoryRetrievalResult(
      nodes: nodes,
      attributions: attributions,
      totalFound: scored.length,
      domainsAccessed: [MemoryDomain.personal],
      privacyLevelsAccessed: [PrivacyLevel.personal],
      crossDomainSynthesisUsed: false,
      memoryMode: MemoryMode.alwaysOn,
      requiresUserPrompt: false,
    );
  }

  double _scoreEntry(
    ChronicleRawEntry entry,
    String query,
    String queryLower,
    List<String> queryWords,
    bool crossModalEnabled,
  ) {
    double score = 0.0;
    final contentLower = entry.content.toLowerCase();
    final keywords = _keywordsFromAnalysis(entry);
    final themes = _themesFromAnalysis(entry);
    final phase = entry.analysis['atlas_phase'] as String?;

    // Content match
    int matches = 0;
    for (final word in queryWords) {
      if (contentLower.contains(word)) matches++;
    }
    if (matches > 0) score += (matches / queryWords.length) * 0.5;

    // Keywords
    final exactCase = keywords.any((k) => k == query);
    final exactKeyword = !exactCase && keywords.any((k) => k.toLowerCase() == queryLower);
    final containsMatch = !exactCase && !exactKeyword && keywords.any((k) =>
        queryLower.contains(k.toLowerCase()) || k.toLowerCase().contains(queryLower));
    if (exactCase) {
      score += 0.7;
    } else if (exactKeyword) {
      score += 0.5;
    } else if (containsMatch) {
      score += 0.4;
    } else {
      final keywordMatches = keywords.where((k) =>
          queryWords.any((w) => k.toLowerCase().contains(w) || w.contains(k.toLowerCase()))).length;
      if (keywordMatches > 0) score += (keywordMatches / keywords.length.clamp(1, 10)) * 0.5;
    }

    // Themes (same as keywords for scoring)
    for (final t in themes) {
      if (queryWords.any((w) => t.toLowerCase().contains(w) || w.contains(t.toLowerCase()))) {
        score += 0.3;
        break;
      }
    }

    // Phase
    if (phase != null && phase.isNotEmpty &&
        queryWords.any((w) => phase.toLowerCase().contains(w))) {
      score += 0.2;
    }

    // Cross-modal: metadata media (captions, etc.) if present
    if (crossModalEnabled && entry.metadata['media_attachments'] != null) {
      // Layer 0 doesn't store captions in raw entry; keep for future expansion
    }

    return score;
  }

  List<String> _keywordsFromAnalysis(ChronicleRawEntry entry) {
    final k = entry.analysis['keywords'];
    if (k is List) return List<String>.from(k.whereType<String>());
    final t = entry.analysis['extracted_themes'];
    if (t is List) return List<String>.from(t.whereType<String>());
    return [];
  }

  List<String> _themesFromAnalysis(ChronicleRawEntry entry) {
    final t = entry.analysis['extracted_themes'];
    if (t is List) return List<String>.from(t.whereType<String>());
    return [];
  }

  EnhancedMiraNode _rawToNode(ChronicleRawEntry raw) {
    final keywords = _keywordsFromAnalysis(raw);
    final phase = raw.analysis['atlas_phase'] as String?;
    final id = 'entry:${raw.entryId}';
    final data = <String, dynamic>{
      'content': raw.content,
      'text': raw.content,
      'original_entry_id': raw.entryId,
      'keywords': keywords,
      'word_count': raw.content.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length,
    };
    return EnhancedMiraNode(
      id: id,
      type: NodeType.entry,
      schemaVersion: 1,
      data: data,
      createdAt: raw.timestamp,
      updatedAt: raw.timestamp,
      domain: MemoryDomain.personal,
      privacy: PrivacyLevel.personal,
      phaseContext: phase,
      lifecycle: const LifecycleMetadata(
        accessCount: 0,
        reinforcementScore: 1.0,
      ),
      provenance: const ProvenanceData(
        source: 'CHRONICLE_Layer0',
        device: 'unknown',
        version: '1.0',
      ),
      piiFlags: const PIIFlags(),
    );
  }

  MemoryRetrievalResult _emptyResult() {
    return MemoryRetrievalResult(
      nodes: [],
      attributions: [],
      totalFound: 0,
      domainsAccessed: [],
      privacyLevelsAccessed: [],
      crossDomainSynthesisUsed: false,
      memoryMode: MemoryMode.alwaysOn,
      requiresUserPrompt: false,
    );
  }
}

class _ScoredEntry {
  final ChronicleRawEntry entry;
  final double score;
  _ScoredEntry(this.entry, this.score);
}
