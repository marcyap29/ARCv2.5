// lib/lumara/memory/summary_service.dart
// Rolling summary generation with map-reduce abstraction

import 'mcp_memory_models.dart';

/// Summary generation service implementing map-reduce pattern
class SummaryService {
  static const int _maxSummaryLength = 400; // words
  static const int _minSummaryLength = 200; // words

  /// Generate a rolling summary for a window of messages
  static Future<ConversationSummary> generateSummary({
    required List<ConversationMessage> messages,
    required String sessionId,
    required int windowIndex,
  }) async {
    if (messages.isEmpty) {
      throw Exception('Cannot create summary from empty message list');
    }

    // Map phase: extract features from each message
    final mappedFeatures = messages.map(_mapMessage).toList();

    // Reduce phase: combine features into summary
    final reducedSummary = _reduceFeatures(mappedFeatures);

    // Generate abstractive summary content
    final summaryContent = _generateAbstractiveSummary(messages, reducedSummary);

    // Create summary record
    final summaryId = 'sum:$sessionId:w$windowIndex';

    return ConversationSummary(
      id: summaryId,
      timestamp: DateTime.now(),
      window: SummaryWindow(
        startMessageId: messages.first.id,
        endMessageId: messages.last.id,
      ),
      content: summaryContent,
      keyFacts: reducedSummary['key_facts'] ?? [],
      openLoops: reducedSummary['open_loops'] ?? [],
      phaseSignals: Map<String, String>.from(reducedSummary['phase_signals'] ?? {}),
      parent: 'sess:$sessionId',
    );
  }

  /// Map phase: extract features from individual message
  static Map<String, dynamic> _mapMessage(ConversationMessage message) {
    final content = message.content.toLowerCase();

    return {
      'role': message.role,
      'timestamp': message.timestamp,
      'word_count': content.split(' ').length,
      'topics': _extractTopics(content),
      'entities': _extractEntities(content),
      'questions': _extractQuestions(content),
      'decisions': _extractDecisions(content),
      'todos': _extractTodos(content),
      'emotions': _extractEmotions(content),
      'phase_signals': _extractPhaseSignals(content),
      'key_phrases': _extractKeyPhrases(content),
    };
  }

  /// Reduce phase: combine mapped features into consolidated summary
  static Map<String, dynamic> _reduceFeatures(List<Map<String, dynamic>> features) {
    Map<String, int> topicCounts = {};
    Map<String, int> entityCounts = {};
    List<String> allQuestions = [];
    List<String> allDecisions = [];
    List<String> allTodos = [];
    Map<String, int> emotionCounts = {};
    Map<String, List<String>> phaseSignals = {};
    List<String> keyPhrases = [];

    // Aggregate features across all messages
    for (final feature in features) {
      // Count topics
      for (final topic in feature['topics'] ?? []) {
        topicCounts[topic] = (topicCounts[topic] ?? 0) + 1;
      }

      // Count entities
      for (final entity in feature['entities'] ?? []) {
        entityCounts[entity] = (entityCounts[entity] ?? 0) + 1;
      }

      // Collect questions
      allQuestions.addAll(List<String>.from(feature['questions'] ?? []));

      // Collect decisions
      allDecisions.addAll(List<String>.from(feature['decisions'] ?? []));

      // Collect todos
      allTodos.addAll(List<String>.from(feature['todos'] ?? []));

      // Count emotions
      for (final emotion in feature['emotions'] ?? []) {
        emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1;
      }

      // Aggregate phase signals
      final signals = Map<String, dynamic>.from(feature['phase_signals'] ?? {});
      for (final entry in signals.entries) {
        phaseSignals.putIfAbsent(entry.key, () => []);
        phaseSignals[entry.key]!.add(entry.value.toString());
      }

      // Collect key phrases
      keyPhrases.addAll(List<String>.from(feature['key_phrases'] ?? []));
    }

    // Sort and filter results
    final topTopics = _getTopItems(topicCounts, 5);
    final topEntities = _getTopItems(entityCounts, 5);
    final topEmotions = _getTopItems(emotionCounts, 3);

    // Generate key facts
    final keyFacts = _generateKeyFacts({
      'topics': topTopics,
      'entities': topEntities,
      'emotions': topEmotions,
      'decisions': allDecisions,
    });

    // Generate open loops (unresolved questions and todos)
    final openLoops = _generateOpenLoops({
      'questions': allQuestions,
      'todos': allTodos,
    });

    // Determine dominant phase signals
    final dominantPhaseSignals = _determineDominantPhaseSignals(phaseSignals);

    return {
      'key_facts': keyFacts,
      'open_loops': openLoops,
      'phase_signals': dominantPhaseSignals,
      'top_topics': topTopics,
      'top_entities': topEntities,
      'key_phrases': keyPhrases.take(10).toList(),
    };
  }

  /// Generate abstractive summary content
  static String _generateAbstractiveSummary(
    List<ConversationMessage> messages,
    Map<String, dynamic> reducedFeatures,
  ) {
    final buffer = StringBuffer();

    // Overview
    buffer.writeln('Conversation summary covering ${messages.length} messages over ${_calculateDuration(messages)}.');

    // Key topics
    final topics = reducedFeatures['top_topics'] as List<String>? ?? [];
    if (topics.isNotEmpty) {
      buffer.writeln('Main topics discussed: ${topics.join(", ")}.');
    }

    // Key facts
    final keyFacts = reducedFeatures['key_facts'] as List<String>? ?? [];
    if (keyFacts.isNotEmpty) {
      buffer.writeln('Key points:');
      for (final fact in keyFacts.take(3)) {
        buffer.writeln('• $fact');
      }
    }

    // Open loops
    final openLoops = reducedFeatures['open_loops'] as List<String>? ?? [];
    if (openLoops.isNotEmpty) {
      buffer.writeln('Unresolved items:');
      for (final loop in openLoops.take(3)) {
        buffer.writeln('• $loop');
      }
    }

    // Phase signals
    final phaseSignals = reducedFeatures['phase_signals'] as Map<String, String>? ?? {};
    if (phaseSignals.isNotEmpty) {
      final tone = phaseSignals['tone'] ?? 'neutral';
      final atlasPhase = phaseSignals['atlas'] ?? 'Discovery';
      buffer.writeln('Conversation tone: $tone. ATLAS phase: $atlasPhase.');
    }

    final summary = buffer.toString().trim();

    // Ensure summary is within word limits
    return _truncateToWordLimit(summary, _maxSummaryLength);
  }

  // Feature extraction methods

  static List<String> _extractTopics(String content) {
    // Simple keyword-based topic extraction
    final topics = <String>[];

    // Technical topics
    if (content.contains(RegExp(r'\b(api|server|database|code|bug|feature)\b'))) {
      topics.add('technical_discussion');
    }

    // Project management
    if (content.contains(RegExp(r'\b(deadline|milestone|task|project|plan)\b'))) {
      topics.add('project_management');
    }

    // Personal topics
    if (content.contains(RegExp(r'\b(feel|emotion|stress|happy|sad|worry)\b'))) {
      topics.add('personal_wellbeing');
    }

    return topics;
  }

  static List<String> _extractEntities(String content) {
    final entities = <String>[];

    // Extract potential names (capitalized words)
    final namePattern = RegExp(r'\b[A-Z][a-z]+\b');
    final matches = namePattern.allMatches(content);

    for (final match in matches) {
      final word = match.group(0)!;
      if (!_isCommonWord(word)) {
        entities.add(word);
      }
    }

    return entities.toSet().toList(); // Remove duplicates
  }

  static List<String> _extractQuestions(String content) {
    final questions = <String>[];

    // Extract sentences ending with ?
    final questionPattern = RegExp(r'[^.!?]*\?');
    final matches = questionPattern.allMatches(content);

    for (final match in matches) {
      final question = match.group(0)!.trim();
      if (question.length > 10) { // Filter out very short questions
        questions.add(question);
      }
    }

    return questions;
  }

  static List<String> _extractDecisions(String content) {
    final decisions = <String>[];

    // Look for decision keywords
    final decisionPatterns = [
      RegExp(r'\b(decided|choose|pick|select|go with)\b.*?[.!]'),
      RegExp(r'\b(will|shall|going to)\b.*?[.!]'),
    ];

    for (final pattern in decisionPatterns) {
      final matches = pattern.allMatches(content);
      for (final match in matches) {
        decisions.add(match.group(0)!.trim());
      }
    }

    return decisions;
  }

  static List<String> _extractTodos(String content) {
    final todos = <String>[];

    // Look for todo keywords
    final todoPatterns = [
      RegExp(r'\b(need to|should|must|have to|todo|task)\b.*?[.!]'),
      RegExp(r'\b(remind|remember|follow up)\b.*?[.!]'),
    ];

    for (final pattern in todoPatterns) {
      final matches = pattern.allMatches(content);
      for (final match in matches) {
        todos.add(match.group(0)!.trim());
      }
    }

    return todos;
  }

  static List<String> _extractEmotions(String content) {
    final emotions = <String>[];

    final emotionWords = {
      'happy': ['happy', 'joy', 'excited', 'pleased', 'glad'],
      'sad': ['sad', 'down', 'depressed', 'upset', 'disappointed'],
      'angry': ['angry', 'mad', 'frustrated', 'annoyed', 'irritated'],
      'anxious': ['anxious', 'worried', 'nervous', 'stressed', 'concerned'],
      'confident': ['confident', 'sure', 'certain', 'positive'],
    };

    for (final entry in emotionWords.entries) {
      for (final word in entry.value) {
        if (content.contains(word)) {
          emotions.add(entry.key);
          break;
        }
      }
    }

    return emotions.toSet().toList();
  }

  static Map<String, String> _extractPhaseSignals(String content) {
    final signals = <String, String>{};

    // Tone detection
    if (content.contains(RegExp(r'\b(urgent|asap|immediately|critical)\b'))) {
      signals['tone'] = 'urgent';
    } else if (content.contains(RegExp(r'\b(calm|relax|slow|patient)\b'))) {
      signals['tone'] = 'calm';
    } else {
      signals['tone'] = 'neutral';
    }

    // ATLAS phase detection (simplified)
    if (content.contains(RegExp(r'\b(explore|discover|learn|new)\b'))) {
      signals['atlas'] = 'Discovery';
    } else if (content.contains(RegExp(r'\b(grow|expand|develop|progress)\b'))) {
      signals['atlas'] = 'Expansion';
    } else if (content.contains(RegExp(r'\b(change|transition|shift|move)\b'))) {
      signals['atlas'] = 'Transition';
    } else if (content.contains(RegExp(r'\b(consolidate|stabilize|organize)\b'))) {
      signals['atlas'] = 'Consolidation';
    } else if (content.contains(RegExp(r'\b(recover|rest|heal|restore)\b'))) {
      signals['atlas'] = 'Recovery';
    } else if (content.contains(RegExp(r'\b(breakthrough|achieve|breakthrough|major)\b'))) {
      signals['atlas'] = 'Breakthrough';
    } else {
      signals['atlas'] = 'Discovery';
    }

    return signals;
  }

  static List<String> _extractKeyPhrases(String content) {
    // Simple n-gram extraction for key phrases
    final words = content.split(' ');
    final phrases = <String>[];

    // Extract 2-grams and 3-grams
    for (int i = 0; i < words.length - 1; i++) {
      if (words[i].length > 3 && words[i + 1].length > 3) {
        phrases.add('${words[i]} ${words[i + 1]}');
      }

      if (i < words.length - 2 && words[i + 2].length > 3) {
        phrases.add('${words[i]} ${words[i + 1]} ${words[i + 2]}');
      }
    }

    return phrases;
  }

  // Helper methods

  static List<String> _getTopItems(Map<String, int> counts, int limit) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => e.key).toList();
  }

  static List<String> _generateKeyFacts(Map<String, dynamic> data) {
    final facts = <String>[];

    final topics = data['topics'] as List<String>? ?? [];
    final entities = data['entities'] as List<String>? ?? [];
    final emotions = data['emotions'] as List<String>? ?? [];
    final decisions = data['decisions'] as List<String>? ?? [];

    if (topics.isNotEmpty) {
      facts.add('Primary focus areas: ${topics.join(", ")}');
    }

    if (entities.isNotEmpty) {
      facts.add('Key people/entities mentioned: ${entities.join(", ")}');
    }

    if (emotions.isNotEmpty) {
      facts.add('Emotional tone: ${emotions.join(", ")}');
    }

    facts.addAll(decisions.take(2));

    return facts.take(5).toList();
  }

  static List<String> _generateOpenLoops(Map<String, dynamic> data) {
    final loops = <String>[];

    final questions = data['questions'] as List<String>? ?? [];
    final todos = data['todos'] as List<String>? ?? [];

    loops.addAll(questions.take(3));
    loops.addAll(todos.take(3));

    return loops.take(5).toList();
  }

  static Map<String, String> _determineDominantPhaseSignals(
    Map<String, List<String>> signals,
  ) {
    final result = <String, String>{};

    for (final entry in signals.entries) {
      // Find most common value for each signal type
      final counts = <String, int>{};
      for (final value in entry.value) {
        counts[value] = (counts[value] ?? 0) + 1;
      }

      if (counts.isNotEmpty) {
        final dominant = counts.entries
            .reduce((a, b) => a.value > b.value ? a : b);
        result[entry.key] = dominant.key;
      }
    }

    return result;
  }

  static bool _isCommonWord(String word) {
    const commonWords = {
      'The', 'This', 'That', 'And', 'But', 'Or', 'So', 'If', 'When', 'Where',
      'Who', 'What', 'How', 'Why', 'Can', 'Will', 'Should', 'Could', 'Would',
      'Have', 'Has', 'Had', 'Do', 'Does', 'Did', 'Get', 'Got', 'Make', 'Made',
    };

    return commonWords.contains(word);
  }

  static String _calculateDuration(List<ConversationMessage> messages) {
    if (messages.length < 2) return 'a few moments';

    final start = messages.first.timestamp;
    final end = messages.last.timestamp;
    final duration = end.difference(start);

    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'a few moments';
    }
  }

  static String _truncateToWordLimit(String text, int wordLimit) {
    final words = text.split(' ');
    if (words.length <= wordLimit) return text;

    return words.take(wordLimit).join(' ') + '...';
  }
}