// lib/services/patterns_data_service.dart
// Service for extracting keyword patterns from journal entries.
// Uses KeywordCorpusService as single source of truth for frequency and usage.

import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/prism/atlas/phase/your_patterns_view.dart';
import 'package:my_app/utils/text_processing.dart';
import 'package:my_app/utils/co_occurrence_calculator.dart';
import 'package:my_app/services/keyword_corpus_service.dart';
import 'package:my_app/prism/extractors/enhanced_keyword_extractor.dart';

/// Service for generating pattern analysis data from journal entries
class PatternsDataService {
  final JournalRepository _journalRepository;

  PatternsDataService({required JournalRepository journalRepository})
      : _journalRepository = journalRepository;

  /// Get patterns data for visualization
  /// Returns tuple of (nodes, edges) for the patterns view
  Future<(List<KeywordNode>, List<KeywordEdge>)> getPatternsData({
    DateTime? startDate,
    DateTime? endDate,
    int maxNodes = 50,
    double minCoOccurrenceWeight = 0.3,
  }) async {
    print('DEBUG: PatternsDataService - Getting patterns data...');

    final allEntries = _journalRepository.getAllJournalEntriesSync();
    print('DEBUG: Found ${allEntries.length} total entries');

    if (allEntries.isEmpty) {
      print('DEBUG: No entries found, returning empty patterns');
      return (<KeywordNode>[], <KeywordEdge>[]);
    }

    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 90));
    final end = endDate ?? now;

    final filteredEntries = allEntries.where((entry) {
      return entry.createdAt.isAfter(start) && entry.createdAt.isBefore(end);
    }).toList();

    print('DEBUG: ${filteredEntries.length} entries in date range');

    if (filteredEntries.isEmpty) {
      return (<KeywordNode>[], <KeywordEdge>[]);
    }

    final emotionKeywordSet =
        EnhancedKeywordExtractor.emotionAmplitudeMap.keys.toSet();

    // Single pass via KeywordCorpusService (canonical source for frequency and usage)
    KeywordCorpusStats stats = KeywordCorpusService.computeStats(
      entries: filteredEntries,
      keywordSet: emotionKeywordSet,
    );

    List<String> finalKeywordList;
    if (stats.frequencyByKeyword.isNotEmpty) {
      final sorted = stats.frequencyByKeyword.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      finalKeywordList =
          sorted.take(maxNodes).map((e) => e.key).toList();
      print('DEBUG: Using ${finalKeywordList.length} emotion keywords from corpus');
    } else {
      // Fallback: all words, then TF-IDF restricted to curated
      print('WARNING: No emotion keywords found in text, trying TF-IDF on curated keywords');
      final statsAll = KeywordCorpusService.computeStats(
        entries: filteredEntries,
        keywordSet: null,
      );
      final allDocuments = statsAll.documentKeywordSets
          .map((s) => s.toList())
          .toList();
      final tfidfScores = TextProcessing.extractKeywordsWithTfidf(
        allDocuments,
        topN: maxNodes * 2,
        minScore: 0.01,
      );
      final curatedSet = EnhancedKeywordExtractor.curatedKeywords.toSet();
      final curatedList = tfidfScores.keys
          .where((k) => curatedSet.contains(k))
          .take(maxNodes)
          .toList();
      finalKeywordList = curatedList;
      stats = statsAll;
      print('DEBUG: Using ${finalKeywordList.length} curated keywords from TF-IDF');
    }

    final targetKeywordSet = finalKeywordList.toSet();

    // Build nodes from stats (no second pass over entries for frequency/phase/recency)
    final nodes = <KeywordNode>[];
    for (final keyword in finalKeywordList) {
      final frequency = stats.frequencyByKeyword[keyword] ?? 0;
      if (frequency == 0) continue;

      final dates = stats.usageDatesByKeyword[keyword];
      final lastUsed = dates != null && dates.isNotEmpty ? dates.last : null;
      final recencyScore = lastUsed != null
          ? TextProcessing.calculateRecencyScore(lastUsed, now)
          : 0.5;

      final phase =
          KeywordCorpusService.dominantPhaseForKeyword(
              stats.phaseListByKeyword, keyword);
      final emotion = _getEmotionForKeyword(keyword);

      final excerpts = _extractExcerptsForKeyword(
          keyword, filteredEntries, maxExcerpts: 5);

      final series = _seriesFromUsageDates(
          stats.usageDatesByKeyword[keyword], periods: 7, now: now);

      print('DEBUG: Keyword "$keyword" -> emotion: $emotion, phase: $phase, freq: $frequency');

      nodes.add(KeywordNode(
        id: keyword,
        label: keyword,
        frequency: frequency,
        recencyScore: recencyScore,
        emotion: emotion,
        phase: phase,
        excerpts: excerpts,
        series: series,
      ));
    }

    print('DEBUG: Created ${nodes.length} keyword nodes');

    // Co-occurrence from same corpus stats
    final coOccurrences = CoOccurrenceCalculator.calculate(
      documentKeywords: stats.documentKeywordSets,
      targetKeywords: targetKeywordSet,
      minLift: 1.2,
      minCount: 2,
    );

    print('DEBUG: Found ${coOccurrences.length} co-occurrence relationships');

    final edges = coOccurrences
        .where((c) => c.weight >= minCoOccurrenceWeight)
        .map((c) => KeywordEdge(
              a: c.keywordA,
              b: c.keywordB,
              weight: c.weight,
            ))
        .toList();

    print('DEBUG: Created ${edges.length} edges (filtered by weight >= $minCoOccurrenceWeight)');

    return (nodes, edges);
  }

  List<String> _extractExcerptsForKeyword(
    String keyword,
    List<JournalEntry> entries, {
    int maxExcerpts = 5,
  }) {
    final excerpts = <String>[];
    final keywordLower = keyword.toLowerCase();
    for (final entry in entries) {
      if (excerpts.length >= maxExcerpts) break;
      if (!entry.content.toLowerCase().contains(keywordLower)) continue;
      final excerpt = TextProcessing.extractExcerpt(entry.content, keyword);
      if (excerpt.isNotEmpty) excerpts.add(excerpt);
    }
    return excerpts;
  }

  /// Time series: count of usages per period (last 7 weeks) from usage dates.
  List<int> _seriesFromUsageDates(
    List<DateTime>? usageDates, {
    int periods = 7,
    required DateTime now,
  }) {
    if (usageDates == null || usageDates.isEmpty) {
      return List.filled(periods, 0);
    }
    final series = <int>[];
    for (int i = periods - 1; i >= 0; i--) {
      final periodEnd = now.subtract(Duration(days: i * 7));
      final periodStart = periodEnd.subtract(const Duration(days: 7));
      final count = usageDates.where((d) {
        return !d.isBefore(periodStart) && d.isBefore(periodEnd);
      }).length;
      series.add(count);
    }
    return series;
  }

  String _getEmotionForKeyword(String keyword) {
    final amplitude =
        EnhancedKeywordExtractor.emotionAmplitudeMap[keyword.toLowerCase()] ??
            0.0;
    if (amplitude > 0.7) return 'positive';
    if (amplitude > 0.4) return 'reflective';
    return 'neutral';
  }
}
