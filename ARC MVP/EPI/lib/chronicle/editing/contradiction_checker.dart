import 'package:intl/intl.dart';
import '../storage/layer0_repository.dart';

/// Result of checking a user claim against CHRONICLE entries.
/// Injected into the prompt so LUMARA can push back per intellectual_honesty guidelines.
class ContradictionResult {
  final String aggregationSummary;
  final List<String> entryExcerpts;

  const ContradictionResult({
    required this.aggregationSummary,
    required this.entryExcerpts,
  });

  /// Build the <truth_check> block for the prompt.
  String toTruthCheckBlock(String userClaim) {
    final excerpts = entryExcerpts.map((e) => '- $e').join('\n');
    return '''
<truth_check>
User just claimed: "$userClaim"

But CHRONICLE shows:
- $aggregationSummary
- Specific entries:
$excerpts

This might be:
1. Evolution (their perspective changed - honor it)
2. Reframing (different language for same thing - accept it)
3. Denial (avoiding uncomfortable truth - gently surface it)
4. Forgetting (they genuinely don't remember - remind them)

Determine which and respond accordingly per intellectual_honesty guidelines.
</truth_check>''';
  }
}

/// Checks if a user message looks like a claim that we can verify against CHRONICLE
/// (e.g. "I never wrote about X", "I'm totally fine with Y").
class ChronicleContradictionChecker {
  final Layer0Repository _layer0;

  ChronicleContradictionChecker({required Layer0Repository layer0}) : _layer0 = layer0;

  /// Phrases that suggest the user is making a claim about their journal record.
  static const _claimPhrases = [
    "i never wrote",
    "i never wrote about",
    "i haven't written",
    "i haven't thought about",
    "i didn't mention",
    "i didn't write",
    "i don't think i wrote",
    "i'm totally fine with",
    "i haven't thought about leaving",
    "i haven't considered",
    "no entries about",
    "not in my journal",
    "never mentioned",
    "didn't write about",
  ];

  /// Returns true if [userMessage] looks like a verifiable claim about the journal.
  bool detectsUserClaim(String userMessage) {
    if (userMessage.isEmpty) return false;
    final lower = userMessage.toLowerCase().trim();
    return _claimPhrases.any((p) => lower.contains(p));
  }

  /// Check [claim] (e.g. the user message) against recent CHRONICLE entries for [userId].
  /// Returns a [ContradictionResult] if entries suggest otherwise, so the prompt can push back gently.
  Future<ContradictionResult?> checkAgainstChronicle({
    required String claim,
    required String userId,
    int lookbackDays = 30,
    int maxEntries = 15,
  }) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: lookbackDays));
    List<ChronicleRawEntry> entries;
    try {
      entries = await _layer0.getEntriesInRange(userId, start, now);
    } catch (_) {
      return null;
    }
    if (entries.isEmpty) return null;

    // Extract topic words from the claim (skip negation and common words).
    final topicWords = _topicWordsFromClaim(claim);
    if (topicWords.isEmpty) return null;

    // Find entries that mention any of these topics.
    final matching = <ChronicleRawEntry>[];
    for (final entry in entries) {
      final contentLower = entry.content.toLowerCase();
      final themes = _getThemesFromEntry(entry);
      final contentHasTopic = topicWords.any((w) => contentLower.contains(w));
      final themeHasTopic = topicWords.any((w) => themes.any((t) => t.toLowerCase().contains(w)));
      if (contentHasTopic || themeHasTopic) matching.add(entry);
    }

    if (matching.isEmpty) return null;

    final dateFormat = DateFormat('MMM d');
    final excerptLines = matching.take(5).map((e) {
      final excerpt = _excerpt(e.content, topicWords.first);
      return '${dateFormat.format(e.timestamp)}: $excerpt';
    }).toList();

    final aggregationSummary = '${matching.length} entries in the last $lookbackDays days touch on this.';
    return ContradictionResult(
      aggregationSummary: aggregationSummary,
      entryExcerpts: excerptLines,
    );
  }

  List<String> _topicWordsFromClaim(String claim) {
    final lower = claim.toLowerCase();
    final words = lower
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3 && !_isStopword(w))
        .toList();
    const negations = {'never', 'haven', 'didn', 'don', 'not', 'no', 'nothing', 'hasn', 'wasn', 'weren'};
    return words.where((w) => !negations.contains(w)).toList();
  }

  bool _isStopword(String w) {
    const stop = {'the', 'that', 'this', 'with', 'from', 'have', 'been', 'were', 'about', 'when', 'what', 'which', 'your', 'they', 'them'};
    return stop.contains(w);
  }

  List<String> _getThemesFromEntry(ChronicleRawEntry entry) {
    final analysis = entry.analysis;
    if (analysis.isEmpty) return [];
    final themes = analysis['extracted_themes'];
    if (themes is! List) return [];
    return List<String>.from(themes).map((e) => e.toString().trim()).where((s) => s.length >= 2).toList();
  }

  String _excerpt(String content, String anchor) {
    const maxLen = 100;
    final lower = content.toLowerCase();
    final idx = lower.indexOf(anchor.toLowerCase());
    if (idx < 0) return content.length <= maxLen ? content : '${content.substring(0, maxLen)}...';
    final start = (idx - 15).clamp(0, content.length);
    final end = (start + maxLen).clamp(0, content.length);
    var slice = content.substring(start, end);
    if (start > 0) slice = '...$slice';
    if (end < content.length) slice = '$slice...';
    return slice;
  }
}
