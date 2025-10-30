// lib/services/patterns_data_service.dart
// Service for extracting keyword patterns from journal entries

import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/atlas/phase_detection/your_patterns_view.dart';
import 'package:my_app/utils/text_processing.dart';
import 'package:my_app/utils/co_occurrence_calculator.dart';
import 'package:my_app/services/user_phase_service.dart';
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

    // 1. Get all journal entries
    final allEntries = _journalRepository.getAllJournalEntriesSync();
    print('DEBUG: Found ${allEntries.length} total entries');

    if (allEntries.isEmpty) {
      print('DEBUG: No entries found, returning empty patterns');
      return (<KeywordNode>[], <KeywordEdge>[]);
    }

    // 2. Filter by date range if specified
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

    // 3. Extract words from all entries and build word frequency map
    final allDocuments = <List<String>>[];
    final entryKeywords = <Set<String>>[];
    final wordFrequencyAcrossEntries = <String, int>{};

    for (final entry in filteredEntries) {
      final words = TextProcessing.extractWords(entry.content);
      allDocuments.add(words);
      entryKeywords.add(words.toSet());

      // Track frequency of each word across all entries
      for (final word in words) {
        wordFrequencyAcrossEntries[word] = (wordFrequencyAcrossEntries[word] ?? 0) + 1;
      }
    }

    // 4. NEW APPROACH: Directly search for emotion keywords in the text
    // Instead of relying on TF-IDF, we scan the journal text for emotion keywords
    final emotionKeywordSet = EnhancedKeywordExtractor.emotionAmplitudeMap.keys.toSet();
    final foundEmotionKeywords = <String, int>{};

    print('DEBUG: Scanning ${filteredEntries.length} entries for ${emotionKeywordSet.length} emotion keywords');

    // Count how many times each emotion keyword appears
    for (final emotionKeyword in emotionKeywordSet) {
      final frequency = wordFrequencyAcrossEntries[emotionKeyword] ?? 0;
      if (frequency > 0) {
        foundEmotionKeywords[emotionKeyword] = frequency;
        print('DEBUG: ✓ Found emotion keyword: "$emotionKeyword" (frequency: $frequency)');
      }
    }

    print('DEBUG: Found ${foundEmotionKeywords.length} emotion keywords in journal entries');

    // If we found emotion keywords, use them
    final Map<String, double> topKeywords;
    if (foundEmotionKeywords.isNotEmpty) {
      // Sort by frequency and take top N
      final sortedByFrequency = foundEmotionKeywords.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Convert to double scores for consistency
      topKeywords = Map.fromEntries(
        sortedByFrequency.take(maxNodes).map((e) => MapEntry(e.key, e.value.toDouble()))
      );
    } else {
      // Fallback: use TF-IDF on curated keywords
      print('WARNING: No emotion keywords found in text, trying TF-IDF on curated keywords');
      final allKeywordScores = TextProcessing.extractKeywordsWithTfidf(
        allDocuments,
        topN: maxNodes * 2,
        minScore: 0.01,
      );

      final curatedKeywordSet = EnhancedKeywordExtractor.curatedKeywords.toSet();
      final curatedFound = <String, double>{};

      for (final entry in allKeywordScores.entries) {
        if (curatedKeywordSet.contains(entry.key)) {
          curatedFound[entry.key] = entry.value;
        }
      }

      topKeywords = curatedFound;
    }

    final finalKeywords = topKeywords;
    print('DEBUG: Extracted ${finalKeywords.length} keywords total');

    // 5. Calculate additional metrics for each keyword
    final keywordFrequency = TextProcessing.calculateWordFrequency(allDocuments);
    final nodes = <KeywordNode>[];

    for (final entry in finalKeywords.entries) {
      final keyword = entry.key;
      // final tfidfScore = entry.value; // Reserved for future use
      final frequency = keywordFrequency[keyword] ?? 0;

      // Calculate recency score
      DateTime? lastUsed;
      for (final journalEntry in filteredEntries.reversed) {
        if (journalEntry.content.toLowerCase().contains(keyword)) {
          lastUsed = journalEntry.createdAt;
          break;
        }
      }

      final recencyScore = lastUsed != null
          ? TextProcessing.calculateRecencyScore(lastUsed, now)
          : 0.5;

      // Extract excerpts
      final excerpts = <String>[];
      for (final journalEntry in filteredEntries) {
        if (excerpts.length >= 5) break;
        if (journalEntry.content.toLowerCase().contains(keyword)) {
          final excerpt = TextProcessing.extractExcerpt(
            journalEntry.content,
            keyword,
          );
          if (excerpt.isNotEmpty) {
            excerpts.add(excerpt);
          }
        }
      }

      // Determine phase and emotion associations
      final phase = await _getPhaseForKeyword(keyword, filteredEntries);
      final emotion = _getEmotionForKeyword(keyword);

      // Generate time series (simplified - last 7 periods)
      final series = _generateTimeSeries(keyword, filteredEntries, periods: 7);

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

    // 6. Calculate co-occurrence relationships
    final coOccurrences = CoOccurrenceCalculator.calculate(
      documentKeywords: entryKeywords,
      targetKeywords: finalKeywords.keys.toSet(),
      minLift: 1.2,
      minCount: 2,
    );

    print('DEBUG: Found ${coOccurrences.length} co-occurrence relationships');

    // 7. Convert to edges
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

  /// Determine which phase a keyword is most associated with using EnhancedKeywordExtractor
  Future<String> _getPhaseForKeyword(
    String keyword,
    List<JournalEntry> entries,
  ) async {
    // Use EnhancedKeywordExtractor's phaseKeywordMap for semantic matching
    final keywordLower = keyword.toLowerCase();

    // Check each phase to see if keyword matches
    double bestMatch = 0.0;
    String bestPhase = 'Discovery';

    for (final phase in EnhancedKeywordExtractor.phaseKeywordMap.keys) {
      final phaseKeywords = EnhancedKeywordExtractor.phaseKeywordMap[phase]!;

      // Check for exact match
      if (phaseKeywords.contains(keywordLower)) {
        bestMatch = 1.0;
        bestPhase = phase;
        break;
      }

      // Check for partial match
      for (final phaseKeyword in phaseKeywords) {
        if (keywordLower.contains(phaseKeyword) || phaseKeyword.contains(keywordLower)) {
          final matchStrength = 0.6;
          if (matchStrength > bestMatch) {
            bestMatch = matchStrength;
            bestPhase = phase;
          }
        }
      }
    }

    // If we found a good match, use it
    if (bestMatch > 0.5) {
      return bestPhase;
    }

    // Otherwise, try to use current phase for recent keywords
    final keywordEntries = entries
        .where((e) => e.content.toLowerCase().contains(keywordLower))
        .toList();

    if (keywordEntries.isNotEmpty) {
      try {
        final currentPhase = await UserPhaseService.getCurrentPhase();
        if (currentPhase != null) {
          final recentEntries = keywordEntries
              .where((e) => e.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 14))))
              .toList();

          if (recentEntries.length >= keywordEntries.length * 0.5) {
            return currentPhase;
          }
        }
      } catch (e) {
        print('DEBUG: Error getting current phase: $e');
      }
    }

    // Default fallback
    return bestPhase;
  }

  /// Determine emotional tone for a keyword using EnhancedKeywordExtractor
  String _getEmotionForKeyword(String keyword) {
    final amplitude = EnhancedKeywordExtractor.emotionAmplitudeMap[keyword.toLowerCase()] ?? 0.0;

    // Map amplitude to emotion categories that match the UI
    if (amplitude > 0.7) {
      return 'positive'; // High amplitude emotions
    } else if (amplitude > 0.4) {
      return 'reflective'; // Medium amplitude emotions
    } else {
      return 'neutral'; // Low or no amplitude
    }
  }

  /// Generate time series data for a keyword
  List<int> _generateTimeSeries(
    String keyword,
    List<JournalEntry> entries, {
    int periods = 7,
  }) {
    final now = DateTime.now();
    final series = <int>[];

    for (int i = periods - 1; i >= 0; i--) {
      final periodEnd = now.subtract(Duration(days: i * 7));
      final periodStart = periodEnd.subtract(const Duration(days: 7));

      final count = entries.where((entry) {
        return entry.createdAt.isAfter(periodStart) &&
            entry.createdAt.isBefore(periodEnd) &&
            entry.content.toLowerCase().contains(keyword);
      }).length;

      series.add(count);
    }

    return series;
  }
}
