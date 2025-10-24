// lib/services/keyword_aggregator.dart
// Service for aggregating phrases into higher-level concept keywords

/// Aggregates phrase patterns from journal text into higher-level concept keywords
///
/// Examples:
/// - "I did this", "I created this" → Innovation
/// - "I just discovered", "I just learned" → Breakthrough
/// - "I'm feeling", "I noticed" → Awareness
class KeywordAggregator {

  /// Phrase patterns mapped to aggregated concept keywords
  static const Map<String, List<String>> phrasePatterns = {
    // Innovation & Creation
    'Innovation': [
      'i did',
      'i created',
      'i made',
      'i built',
      'i designed',
      'i developed',
      'i invented',
      'i crafted',
      'i produced',
      'i implemented',
    ],

    // Breakthrough & Discovery
    'Breakthrough': [
      'i just discovered',
      'i just learned',
      'i just realized',
      'i just understood',
      'i figured out',
      'it clicked',
      'i finally get',
      'i see now',
      'aha',
      'eureka',
    ],

    // Awareness & Reflection
    'Awareness': [
      'i\'m feeling',
      'i noticed',
      'i observed',
      'i sense',
      'i became aware',
      'i realize',
      'i recognize',
      'i see that',
      'i understand',
      'i perceive',
    ],

    // Growth & Progress
    'Growth': [
      'i\'m growing',
      'i\'m improving',
      'i\'m getting better',
      'i\'m developing',
      'i\'m evolving',
      'i\'m progressing',
      'i\'m advancing',
      'i\'m expanding',
      'i\'ve improved',
      'i\'ve grown',
    ],

    // Struggle & Challenge
    'Challenge': [
      'i\'m struggling',
      'i\'m having trouble',
      'i can\'t seem',
      'i\'m finding it hard',
      'it\'s difficult',
      'i\'m challenged',
      'i\'m stuck',
      'i don\'t know',
      'i\'m unsure',
      'i\'m confused',
    ],

    // Achievement & Success
    'Achievement': [
      'i accomplished',
      'i achieved',
      'i succeeded',
      'i completed',
      'i finished',
      'i did it',
      'i made it',
      'i reached',
      'i attained',
      'i won',
    ],

    // Connection & Relationship
    'Connection': [
      'i connected',
      'i bonded',
      'i related',
      'i shared',
      'i talked',
      'i opened up',
      'i listened',
      'we discussed',
      'we connected',
      'i felt close',
    ],

    // Transformation & Change
    'Transformation': [
      'i changed',
      'i transformed',
      'i shifted',
      'i transitioned',
      'i\'m different',
      'i\'ve become',
      'i\'m turning into',
      'i\'m moving',
      'i\'m shifting',
      'i\'m evolving',
    ],

    // Rest & Recovery
    'Recovery': [
      'i rested',
      'i relaxed',
      'i recovered',
      'i recharged',
      'i took a break',
      'i slowed down',
      'i paused',
      'i needed rest',
      'i felt tired',
      'i slept',
    ],

    // Exploration & Curiosity
    'Exploration': [
      'i explored',
      'i tried',
      'i experimented',
      'i investigated',
      'i\'m curious',
      'i wonder',
      'what if',
      'i\'m interested',
      'i want to try',
      'i\'m learning',
    ],
  };

  /// Extract aggregated concept keywords from journal text
  /// Returns a map of concept keywords to their frequency counts
  static Map<String, int> extractAggregatedKeywords(List<String> journalTexts) {
    final aggregatedKeywords = <String, int>{};

    for (final text in journalTexts) {
      final lowerText = text.toLowerCase();

      // Check each concept pattern
      for (final entry in phrasePatterns.entries) {
        final concept = entry.key;
        final patterns = entry.value;

        // Count how many times patterns for this concept appear
        int conceptCount = 0;
        for (final pattern in patterns) {
          // Count occurrences of this phrase pattern
          final matches = pattern.allMatches(lowerText).length;
          conceptCount += matches;
        }

        if (conceptCount > 0) {
          aggregatedKeywords[concept] = (aggregatedKeywords[concept] ?? 0) + conceptCount;
        }
      }
    }

    print('DEBUG: KeywordAggregator extracted ${aggregatedKeywords.length} concept keywords');
    return aggregatedKeywords;
  }

  /// Get top N aggregated keywords sorted by frequency
  static List<String> getTopAggregatedKeywords(
    List<String> journalTexts, {
    int topN = 10,
  }) {
    final aggregated = extractAggregatedKeywords(journalTexts);

    // Sort by frequency descending
    final sorted = aggregated.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(topN).map((e) => e.key).toList();
  }

  /// Check if a specific concept appears in journal texts
  static bool hasConceptKeyword(List<String> journalTexts, String concept) {
    final aggregated = extractAggregatedKeywords(journalTexts);
    return aggregated.containsKey(concept) && aggregated[concept]! > 0;
  }

  /// Get frequency count for a specific concept
  static int getConceptFrequency(List<String> journalTexts, String concept) {
    final aggregated = extractAggregatedKeywords(journalTexts);
    return aggregated[concept] ?? 0;
  }
}
