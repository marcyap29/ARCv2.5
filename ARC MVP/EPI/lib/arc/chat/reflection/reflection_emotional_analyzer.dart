import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/models/reflection_session.dart';
import 'package:my_app/services/adaptive/adaptive_sentinel_calculator.dart';

/// Analyzes reflection sessions for validation-seeking and avoidance.
/// Uses existing AdaptiveSentinelCalculator for emotional density.
class ReflectionEmotionalAnalyzer {
  final AdaptiveSentinelCalculator _sentinelCalculator;

  ReflectionEmotionalAnalyzer(this._sentinelCalculator);

  /// Calculate ratio of validation-seeking vs analytical queries.
  double calculateValidationRatio(ReflectionSession session) {
    if (session.exchanges.isEmpty) return 0.0;

    final validationPatterns = [
      'am i',
      'do you think',
      'is this okay',
      'should i',
      'tell me',
      'is it bad',
      'is it wrong',
      'reassure',
    ];

    final analysisPatterns = [
      'pattern',
      'chronicle',
      'compare',
      'when did',
      'show me',
      'analyze',
      'what does the data',
    ];

    int validationCount = 0;
    int analysisCount = 0;

    for (final exchange in session.exchanges) {
      final query = exchange.userQuery.toLowerCase();

      if (validationPatterns.any((p) => query.contains(p))) {
        validationCount++;
      }

      if (analysisPatterns.any((p) => query.contains(p))) {
        analysisCount++;
      }
    }

    final totalCategorized = validationCount + analysisCount;
    if (totalCategorized == 0) return 0.0;

    return validationCount / totalCategorized;
  }

  /// Detect if user is avoiding a conversation they mentioned.
  bool detectAvoidancePattern(
    JournalEntry entry,
    ReflectionSession session,
  ) {
    final conversationIntentMarkers = [
      'need to talk',
      'should discuss',
      'going to tell',
      'planning to',
      'have to say',
      'should ask',
    ];

    final entryText = entry.content.toLowerCase();
    final hasConversationIntent = conversationIntentMarkers.any(
      (marker) => entryText.contains(marker),
    );

    if (!hasConversationIntent) return false;
    if (session.exchanges.length < 2) return false;

    final actionMarkers = [
      'talked to',
      'spoke with',
      'told',
      'discussed with',
      'had the conversation',
      'brought it up',
    ];

    final mentionedAction = session.exchanges.any((exchange) {
      final query = exchange.userQuery.toLowerCase();
      return actionMarkers.any((marker) => query.contains(marker));
    });

    return !mentionedAction;
  }

  /// Calculate emotional density for entire session using a synthetic entry.
  Future<double> calculateSessionEmotionalDensity(
    JournalEntry entry,
    ReflectionSession session,
  ) async {
    final combinedContent = [
      entry.content,
      ...session.exchanges.map((e) => e.userQuery),
    ].join('\n\n');

    final syntheticEntry = JournalEntry(
      id: '${entry.id}_session',
      title: entry.title,
      content: combinedContent,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      tags: entry.tags,
      mood: entry.mood,
    );

    return _sentinelCalculator.calculateEmotionalDensity(syntheticEntry);
  }
}
