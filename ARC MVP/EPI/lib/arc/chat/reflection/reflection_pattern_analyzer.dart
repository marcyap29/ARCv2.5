import 'package:my_app/models/reflection_session.dart';

/// Words to ignore when extracting themes from query text (pronouns, articles, fillers).
const _stopWords = {
  'that', 'what', 'this', 'it', 'the', 'a', 'an', 'and', 'or', 'but',
  'is', 'are', 'was', 'were', 'have', 'has', 'had', 'do', 'does', 'did',
  'will', 'would', 'could', 'should', 'may', 'might', 'can', 'something',
  'things', 'how', 'when', 'why', 'where', 'which', 'who', 'them', 'their',
  'there', 'then', 'than', 'just', 'only', 'even', 'also', 'very', 'really',
  'you', 'me', 'my', 'i', 'am', 'be', 'been', 'being', 'get', 'got',
};

/// Analyzes reflection sessions for rumination and progression patterns.
/// Uses text-based theme extraction (Chronicle's PatternDetector expects
/// RawEntrySchema, so we use simple word-frequency themes for query text).
class ReflectionPatternAnalyzer {
  /// Extract significant words (themes) from a query string.
  List<String> _extractThemesFromText(String text) {
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2 && !_stopWords.contains(w))
        .toList();
    return words.toSet().toList();
  }

  /// Detect if user is ruminating (asking similar questions without progression).
  Future<bool> detectRumination(ReflectionSession session) async {
    if (session.exchanges.length < 3) return false;

    final recentQueries = session.exchanges
        .toList()
        .reversed
        .take(3)
        .map((e) => e.userQuery)
        .toList()
        .reversed
        .toList();

    final themeSets = recentQueries.map(_extractThemesFromText).toList();
    final themeSimilarity = _calculateThemeSimilarity(themeSets);

    final usedChronicle = session.exchanges
        .toList()
        .reversed
        .take(3)
        .any((e) => e.citedChronicle);

    return themeSimilarity > 0.7 && !usedChronicle;
  }

  /// Detect if session shows progression (not stuck on same point).
  bool detectProgression(ReflectionSession session) {
    if (session.exchanges.length < 2) return true;

    final n = session.exchanges.length;
    final laterHalf = session.exchanges.skip(n ~/ 2);
    final earlyHalf = session.exchanges.take(n ~/ 2);

    final laterChronicleUse = laterHalf.where((e) => e.citedChronicle).length;
    final earlyChronicleUse = earlyHalf.where((e) => e.citedChronicle).length;

    return laterChronicleUse >= earlyChronicleUse;
  }

  double _calculateThemeSimilarity(List<List<String>> themeSets) {
    if (themeSets.length < 2) return 0.0;

    final allThemes = themeSets.expand((t) => t).toSet();
    if (allThemes.isEmpty) return 0.0;

    final commonThemes = themeSets
        .map((t) => t.toSet())
        .reduce((a, b) => a.intersection(b));

    return commonThemes.length / allThemes.length;
  }
}
