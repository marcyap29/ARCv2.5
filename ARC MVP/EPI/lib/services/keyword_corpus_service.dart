// lib/services/keyword_corpus_service.dart
// Canonical source for keyword frequency and usage from the journal corpus.
// Patterns, RIVET, and Sentinel must use this; do not compute keyword frequency
// from journal entries elsewhere.

import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/utils/text_processing.dart';

/// Result of a single corpus pass: word counts, usage over time, and document sets.
/// Use for Patterns (node frequency, list), RIVET (KeywordHistory from usageDatesByKeyword),
/// and co-occurrence (documentKeywordSets).
class KeywordCorpusStats {
  /// Total token count per keyword (same semantics as KeywordNode.frequency).
  final Map<String, int> frequencyByKeyword;

  /// For each keyword, sorted list of entry timestamps where it appeared.
  /// Use for recency, "usage in last N days", and building RIVET KeywordHistory.
  final Map<String, List<DateTime>> usageDatesByKeyword;

  /// For each keyword, phase of each occurrence (same order as usageDatesByKeyword).
  /// Use to derive dominant phase per keyword (e.g. mode of this list).
  final Map<String, List<String>> phaseListByKeyword;

  /// One set per entry: words from that entry (after extractWords, optionally restricted).
  /// Use for CoOccurrenceCalculator with same targetKeywords as frequencyByKeyword.keys.
  final List<Set<String>> documentKeywordSets;

  const KeywordCorpusStats({
    required this.frequencyByKeyword,
    required this.usageDatesByKeyword,
    required this.phaseListByKeyword,
    required this.documentKeywordSets,
  });
}

/// Single source of truth for keyword frequency and usage from journal entries.
class KeywordCorpusService {
  /// One pass over [entries]: extract words, optionally restrict to [keywordSet],
  /// aggregate frequency, usage dates, phase per occurrence, and document sets.
  ///
  /// [keywordSet] null = keep all words from extractWords; non-null = only words in set.
  static KeywordCorpusStats computeStats({
    required List<JournalEntry> entries,
    Set<String>? keywordSet,
    int minLength = 3,
    bool filterStopWords = true,
  }) {
    final frequencyByKeyword = <String, int>{};
    final usageDatesByKeyword = <String, List<DateTime>>{};
    final phaseListByKeyword = <String, List<String>>{};
    final documentKeywordSets = <Set<String>>[];

    for (final entry in entries) {
      final words = TextProcessing.extractWords(
        entry.content,
        minLength: minLength,
        filterStopWords: filterStopWords,
      );
      final restricted = keywordSet == null
          ? words
          : words.where((w) => keywordSet.contains(w)).toList();
      final wordSet = restricted.toSet();
      documentKeywordSets.add(wordSet);

      final phase = entry.autoPhase ?? 'Discovery';

      for (final word in restricted) {
        frequencyByKeyword[word] = (frequencyByKeyword[word] ?? 0) + 1;
        usageDatesByKeyword.putIfAbsent(word, () => []).add(entry.createdAt);
        phaseListByKeyword.putIfAbsent(word, () => []).add(phase);
      }
    }

    // Sort dates per keyword (and keep phase list in same order)
    for (final keyword in usageDatesByKeyword.keys) {
      final dates = usageDatesByKeyword[keyword]!;
      final phases = phaseListByKeyword[keyword]!;
      final pairs = List.generate(dates.length, (i) => (dates[i], phases[i]))
        ..sort((a, b) => a.$1.compareTo(b.$1));
      usageDatesByKeyword[keyword] = pairs.map((p) => p.$1).toList();
      phaseListByKeyword[keyword] = pairs.map((p) => p.$2).toList();
    }

    return KeywordCorpusStats(
      frequencyByKeyword: frequencyByKeyword,
      usageDatesByKeyword: usageDatesByKeyword,
      phaseListByKeyword: phaseListByKeyword,
      documentKeywordSets: documentKeywordSets,
    );
  }

  /// Returns the dominant phase for a keyword (mode of phaseListByKeyword[keyword]).
  static String dominantPhaseForKeyword(
    Map<String, List<String>> phaseListByKeyword,
    String keyword,
  ) {
    final list = phaseListByKeyword[keyword];
    if (list == null || list.isEmpty) return 'Discovery';
    final counts = <String, int>{};
    for (final p in list) {
      counts[p] = (counts[p] ?? 0) + 1;
    }
    String best = 'Discovery';
    int maxCount = 0;
    for (final e in counts.entries) {
      if (e.value > maxCount) {
        maxCount = e.value;
        best = e.key;
      }
    }
    return best;
  }
}
