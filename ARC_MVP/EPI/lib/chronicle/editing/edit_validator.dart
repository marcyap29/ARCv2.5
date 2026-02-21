import '../storage/layer0_repository.dart';
import 'edit_validation_models.dart';

/// Validates user edits to CHRONICLE content (e.g. monthly summary) against
/// source entries to detect pattern suppression and factual contradictions.
class EditValidator {
  /// Minimum fraction of entries (0.0–1.0) that must contain a pattern
  /// for its removal to count as suppression. Default 0.25 (25%).
  static const double defaultSuppressionThreshold = 0.25;

  /// Minimum excerpt length for contradiction display.
  static const int minExcerptLength = 40;

  /// Maximum excerpt length for contradiction display.
  static const int maxExcerptLength = 120;

  /// Detect patterns that appear in source entries (or original text) but are
  /// removed or significantly reduced in the edited content.
  ///
  /// Returns patterns that meet [suppressionThreshold] (frequency) and that
  /// appear in [original] or in entries but are absent or rare in [edited].
  List<SuppressedPattern> detectSuppressedPatterns({
    required String original,
    required String edited,
    required List<ChronicleRawEntry> entries,
    double suppressionThreshold = defaultSuppressionThreshold,
  }) {
    if (entries.isEmpty) return [];

    final editedLower = edited.toLowerCase();
    final originalLower = original.toLowerCase();

    // Build pattern -> (count, entryIds) from entries (themes from analysis + notable phrases from content).
    final patternCounts = <String, List<String>>{};
    for (final entry in entries) {
      final themes = _getThemesFromEntry(entry);
      for (final t in themes) {
        patternCounts.putIfAbsent(t, () => []).add(entry.entryId);
      }
      // Also treat repeated phrases in content as patterns (simple: words that appear in multiple entries).
      final words = _significantWords(entry.content);
      for (final w in words) {
        if (w.length >= 4 && !_isStopword(w)) {
          patternCounts.putIfAbsent(w, () => []).add(entry.entryId);
        }
      }
    }

    // Dedupe entry IDs per pattern and compute frequency.
    final patternFreq = <String, SuppressedPattern>{};
    for (final entry in patternCounts.entries) {
      final ids = entry.value.toSet().toList();
      final freq = ids.length / entries.length;
      if (freq >= suppressionThreshold) {
        final pattern = entry.key;
        final inOriginal = originalLower.contains(pattern.toLowerCase());
        final inEdited = editedLower.contains(pattern.toLowerCase());
        if ((inOriginal || freq >= 0.3) && !inEdited) {
          patternFreq[pattern] = SuppressedPattern(
            pattern: pattern,
            frequency: freq,
            entryIds: ids,
          );
        }
      }
    }

    return patternFreq.values.toList();
  }

  /// Detect claims in [edited] that contradict specific journal entries.
  ///
  /// Uses heuristics: negations like "never", "haven't", "didn't" + keyword
  /// overlap with entry content. Returns list of contradictions with date and excerpt.
  List<EditContradiction> detectContradictions({
    required String edited,
    required List<ChronicleRawEntry> entries,
  }) {
    if (entries.isEmpty) return [];

    final contradictions = <EditContradiction>[];
    final editedLower = edited.toLowerCase();

    // Simple negation phrases that often introduce a claim we can check.
    const negationPhrases = [
      "never wrote",
      "never wrote about",
      "haven't written",
      "haven't thought about",
      "didn't mention",
      "didn't write about",
      "don't think i",
      "no entries about",
      "not in my journal",
      "not in my entries",
    ];

    for (final phrase in negationPhrases) {
      if (!editedLower.contains(phrase)) continue;
      // Extract topic: text after the phrase (rough).
      final idx = editedLower.indexOf(phrase);
      final after = edited.substring(idx + phrase.length).trim();
      final topicWords = _significantWords(after).take(5).toList();
      if (topicWords.isEmpty) continue;

      for (final entry in entries) {
        final contentLower = entry.content.toLowerCase();
        final hasTopic = topicWords.any((w) => contentLower.contains(w));
        if (!hasTopic) continue;
        final excerpt = _excerpt(entry.content, topicWords.first);
        contradictions.add(EditContradiction(
          claim: 'Never/haven\'t written about ${topicWords.take(3).join(' ')}',
          date: entry.timestamp,
          excerpt: excerpt,
          entryId: entry.entryId,
        ));
        break; // One contradiction per negation phrase is enough.
      }
    }

    return contradictions;
  }

  List<String> _getThemesFromEntry(ChronicleRawEntry entry) {
    final analysis = entry.analysis;
    if (analysis.isEmpty) return [];
    final themes = analysis['extracted_themes'];
    if (themes is! List) return [];
    return List<String>.from(themes).map((e) => e.toString().trim()).where((s) => s.length >= 2).toList();
  }

  List<String> _significantWords(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3)
        .toList();
  }

  bool _isStopword(String w) {
    const stop = {'that', 'this', 'with', 'from', 'have', 'been', 'were', 'about', 'when', 'what', 'which'};
    return stop.contains(w.toLowerCase());
  }

  String _excerpt(String content, String anchor) {
    final lower = content.toLowerCase();
    final idx = lower.indexOf(anchor.toLowerCase());
    if (idx < 0) return content.length <= maxExcerptLength ? content : '${content.substring(0, maxExcerptLength)}...';
    final start = (idx - 20).clamp(0, content.length);
    final end = (start + maxExcerptLength).clamp(0, content.length);
    var slice = content.substring(start, end);
    if (start > 0) slice = '...$slice';
    if (end < content.length) slice = '$slice...';
    return slice.length >= minExcerptLength ? slice : content.substring(0, maxExcerptLength.clamp(0, content.length));
  }
}
