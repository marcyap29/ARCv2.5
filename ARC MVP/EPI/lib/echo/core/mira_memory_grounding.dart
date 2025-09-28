/// MIRA Memory Grounding for ECHO
///
/// Retrieves relevant memory nodes from the MIRA semantic graph to ground
/// LUMARA responses in the user's actual experiences and patterns.

// import '../../mira/mira_module.dart';
// import '../../mira/services/semantic_memory_service.dart';
import '../echo_service.dart';

class MiraMemoryGrounding {
  // TODO: Connect to actual MIRA semantic memory service when available
  // final SemanticMemoryService _memoryService;

  MiraMemoryGrounding(); // : _memoryService = SemanticMemoryService();

  /// Retrieve relevant memory nodes based on utterance and current phase
  Future<List<MemoryNode>> retrieveRelevantMemory(
    String utterance,
    String currentPhase,
  ) async {
    try {
      // Get phase-specific memory context
      final phaseContext = _getPhaseMemoryContext(currentPhase);

      // Extract key concepts from utterance for semantic search
      final concepts = _extractKeyConcepts(utterance);

      // TODO: Search for relevant memory nodes using MIRA semantic memory
      // For now, return simulated memory results
      final searchResults = await _simulateSemanticSearch(
        query: utterance,
        concepts: concepts,
        phaseContext: phaseContext,
        limit: 5,
      );

      // Convert to ECHO MemoryNode format
      return searchResults.map((result) => MemoryNode(
        id: result['id'] as String,
        content: result['content'] as String,
        relevance: result['relevance'] as double? ?? 0.0,
        type: result['type'] as String? ?? 'journal',
        timestamp: DateTime.tryParse(result['timestamp'] as String? ?? '') ?? DateTime.now(),
      )).toList();

    } catch (e) {
      // Graceful fallback when MIRA is unavailable
      print('ECHO: Memory grounding unavailable, falling back to pattern-based retrieval: $e');
      return await _fallbackPatternRetrieval(utterance, currentPhase);
    }
  }

  /// Extract key concepts from user utterance for semantic search
  List<String> _extractKeyConcepts(String utterance) {
    final concepts = <String>[];
    final words = utterance.toLowerCase().split(RegExp(r'[\s\.,\?!;:]+'));

    // Filter for meaningful concepts (simple approach)
    final meaningfulWords = words.where((word) =>
      word.length > 3 &&
      !_isStopWord(word) &&
      !_isCommonPhrase(word)
    ).toList();

    // Add emotion-related concepts
    concepts.addAll(_extractEmotionConcepts(utterance));

    // Add temporal concepts
    concepts.addAll(_extractTemporalConcepts(utterance));

    // Add meaningful content words
    concepts.addAll(meaningfulWords.take(5));

    return concepts.toSet().toList(); // Remove duplicates
  }

  /// Extract emotion-related concepts from utterance
  List<String> _extractEmotionConcepts(String utterance) {
    final emotions = <String>[];
    final lowerUtterance = utterance.toLowerCase();

    final emotionPatterns = {
      'joy': r'\b(happy|joy|excited|thrilled|wonderful|amazing|great)\b',
      'sadness': r'\b(sad|down|depressed|blue|hurt|disappointed)\b',
      'anxiety': r'\b(worried|anxious|nervous|scared|afraid|concerned)\b',
      'anger': r'\b(angry|mad|frustrated|annoyed|irritated|furious)\b',
      'curiosity': r'\b(curious|wondering|interested|explore|discover)\b',
      'exhaustion': r'\b(tired|exhausted|drained|overwhelmed|burnout)\b',
      'confusion': r'\b(confused|unclear|lost|uncertain|mixed)\b',
    };

    for (final entry in emotionPatterns.entries) {
      if (RegExp(entry.value).hasMatch(lowerUtterance)) {
        emotions.add(entry.key);
      }
    }

    return emotions;
  }

  /// Extract temporal concepts from utterance
  List<String> _extractTemporalConcepts(String utterance) {
    final temporal = <String>[];
    final lowerUtterance = utterance.toLowerCase();

    final temporalPatterns = [
      'today', 'yesterday', 'tomorrow', 'week', 'month', 'year',
      'recently', 'lately', 'past', 'future', 'now', 'current',
      'before', 'after', 'since', 'until', 'when', 'while'
    ];

    for (final pattern in temporalPatterns) {
      if (lowerUtterance.contains(pattern)) {
        temporal.add(pattern);
      }
    }

    return temporal;
  }

  /// Check if word is a stop word
  bool _isStopWord(String word) {
    const stopWords = {
      'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with',
      'by', 'a', 'an', 'as', 'is', 'was', 'are', 'were', 'be', 'been', 'have',
      'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should',
      'may', 'might', 'can', 'this', 'that', 'these', 'those', 'my', 'your',
      'his', 'her', 'its', 'our', 'their', 'me', 'you', 'him', 'us',
      'them', 'what', 'when', 'where', 'why', 'how', 'which', 'who', 'whom'
    };
    return stopWords.contains(word);
  }

  /// Check if word is a common conversational phrase
  bool _isCommonPhrase(String word) {
    const commonPhrases = {
      'like', 'know', 'think', 'feel', 'want', 'need', 'said', 'told',
      'asked', 'came', 'went', 'got', 'made', 'took', 'gave', 'found'
    };
    return commonPhrases.contains(word);
  }

  /// Get phase-specific memory retrieval context
  String _getPhaseMemoryContext(String phase) {
    switch (phase) {
      case 'Discovery':
        return 'beginnings, exploration, curiosity, new experiences, learning';
      case 'Expansion':
        return 'growth, building, achievements, progress, momentum';
      case 'Transition':
        return 'change, uncertainty, navigation, transformation, adaptation';
      case 'Consolidation':
        return 'integration, organization, stability, structure, completion';
      case 'Recovery':
        return 'rest, healing, restoration, self-care, reflection';
      case 'Breakthrough':
        return 'insights, revelations, significant shifts, transformation';
      default:
        return 'patterns, experiences, emotions, growth, relationships';
    }
  }

  /// Fallback pattern-based retrieval when MIRA is unavailable
  Future<List<MemoryNode>> _fallbackPatternRetrieval(
    String utterance,
    String currentPhase,
  ) async {
    // Simple pattern-based memory simulation
    // In production, this could use local storage or cached memory

    final fallbackNodes = <MemoryNode>[];

    // Create contextual memory nodes based on utterance patterns
    if (utterance.toLowerCase().contains('feeling')) {
      fallbackNodes.add(MemoryNode(
        id: 'fallback_emotion_1',
        content: 'Previous reflection on emotional patterns and growth',
        relevance: 0.6,
        type: 'pattern',
        timestamp: DateTime.now().subtract(const Duration(days: 7)),
      ));
    }

    if (utterance.toLowerCase().contains(RegExp(r'\b(work|job|career)\b'))) {
      fallbackNodes.add(MemoryNode(
        id: 'fallback_work_1',
        content: 'Previous entries about work-life balance and professional growth',
        relevance: 0.7,
        type: 'theme',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
      ));
    }

    if (utterance.toLowerCase().contains(RegExp(r'\b(relationship|friend|family)\b'))) {
      fallbackNodes.add(MemoryNode(
        id: 'fallback_relationships_1',
        content: 'Previous reflections on relationships and connection',
        relevance: 0.8,
        type: 'relationship',
        timestamp: DateTime.now().subtract(const Duration(days: 5)),
      ));
    }

    // Phase-specific fallback
    fallbackNodes.add(MemoryNode(
      id: 'fallback_phase_$currentPhase',
      content: 'Previous experiences during $currentPhase phase',
      relevance: 0.5,
      type: 'phase_pattern',
      timestamp: DateTime.now().subtract(const Duration(days: 14)),
    ));

    return fallbackNodes;
  }

  /// Get memory grounding summary for validation
  Future<String> getGroundingSummary(List<MemoryNode> nodes) async {
    if (nodes.isEmpty) {
      return 'No memory grounding available';
    }

    final nodeTypes = nodes.map((n) => n.type).toSet();
    final avgRelevance = nodes.fold<double>(0.0, (sum, node) => sum + node.relevance) / nodes.length;
    final timeSpan = _calculateTimeSpan(nodes);

    return 'Grounded in ${nodes.length} memory nodes (types: ${nodeTypes.join(', ')}) '
           'with average relevance ${avgRelevance.toStringAsFixed(2)} spanning $timeSpan';
  }

  /// Calculate time span of memory nodes
  String _calculateTimeSpan(List<MemoryNode> nodes) {
    if (nodes.isEmpty) return 'no time range';

    final timestamps = nodes.map((n) => n.timestamp).toList()..sort();
    final earliest = timestamps.first;
    final latest = timestamps.last;
    final span = latest.difference(earliest).inDays;

    if (span == 0) return 'today';
    if (span == 1) return 'yesterday-today';
    if (span <= 7) return 'past week';
    if (span <= 30) return 'past month';
    return 'past ${(span / 30).round()} months';
  }

  /// Simulate semantic search for development purposes
  Future<List<Map<String, dynamic>>> _simulateSemanticSearch({
    required String query,
    required List<String> concepts,
    required String phaseContext,
    int limit = 5,
  }) async {
    // Simulate memory retrieval based on concepts and context
    final results = <Map<String, dynamic>>[];

    // Generate contextual memories based on query analysis
    if (concepts.contains('work') || query.toLowerCase().contains('work')) {
      results.add({
        'id': 'memory_work_1',
        'content': 'Reflection on work-life balance and finding meaning in professional activities',
        'relevance': 0.8,
        'type': 'theme',
        'timestamp': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      });
    }

    if (concepts.contains('joy') || concepts.contains('happiness')) {
      results.add({
        'id': 'memory_joy_1',
        'content': 'Moments of genuine happiness and connection with others',
        'relevance': 0.9,
        'type': 'emotion',
        'timestamp': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      });
    }

    if (concepts.contains('anxiety') || concepts.contains('worry')) {
      results.add({
        'id': 'memory_anxiety_1',
        'content': 'Previous experience with managing anxiety and finding calm',
        'relevance': 0.7,
        'type': 'coping',
        'timestamp': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
      });
    }

    // Add phase-specific context
    results.add({
      'id': 'memory_phase_context',
      'content': 'Pattern of experiences during similar life phases: $phaseContext',
      'relevance': 0.6,
      'type': 'phase_pattern',
      'timestamp': DateTime.now().subtract(const Duration(days: 14)).toIso8601String(),
    });

    return results.take(limit).toList();
  }
}