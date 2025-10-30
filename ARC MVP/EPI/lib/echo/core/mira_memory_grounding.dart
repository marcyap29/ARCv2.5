/// MIRA Memory Grounding for ECHO
///
/// Provides evidence-based response generation with proper citations
/// and uncertainty disclosure for dignified, traceable LUMARA responses
library;

import 'package:my_app/mira/mira_service.dart';

class MiraMemoryGrounding {
  final MiraService _miraService;

  MiraMemoryGrounding(this._miraService);

  /// Retrieve relevant memory nodes for grounding LUMARA responses
  Future<MemoryGroundingResult> retrieveGroundingMemory({
    required String userUtterance,
    required String atlasPhase,
    required String emotionalContext,
    int maxNodes = 5,
  }) async {
    try {
      // Query MIRA for relevant memory nodes
      final queryResults = await _queryMiraMemory(
        utterance: userUtterance,
        phase: atlasPhase,
        emotion: emotionalContext,
        limit: maxNodes,
      );

      // Process and validate retrieved nodes
      final groundingNodes = await _processRetrievedNodes(queryResults);

      // Generate citation block for ECHO prompt
      final citationBlock = _generateCitationBlock(groundingNodes);

      // Calculate grounding confidence
      final confidence = _calculateGroundingConfidence(groundingNodes);

      return MemoryGroundingResult(
        nodes: groundingNodes,
        citationBlock: citationBlock,
        confidence: confidence,
        uncertaintyDisclosure: _generateUncertaintyDisclosure(confidence),
      );
    } catch (e) {
      // Graceful degradation with uncertainty disclosure
      return MemoryGroundingResult.uncertain(
        error: e.toString(),
        uncertaintyDisclosure: 'I don\'t have enough memory context to ground this response fully. Let me share what I can offer based on general understanding.',
      );
    }
  }

  /// Query MIRA memory system for relevant nodes
  Future<List<Map<String, dynamic>>> _queryMiraMemory({
    required String utterance,
    required String phase,
    required String emotion,
    required int limit,
  }) async {
    // Create semantic query combining utterance, phase, and emotion
    final query = _constructSemanticQuery(utterance, phase, emotion);

    // Query MIRA's memory graph
    final results = await _miraService.searchNarratives(
      query,
      limit: limit,
    );

    // Convert List<String> to List<Map<String, dynamic>>
    return results.map((narrative) => {
      'content': narrative,
      'relevance': 0.8, // Default relevance score
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }).toList();
  }

  /// Construct semantic query for MIRA
  String _constructSemanticQuery(String utterance, String phase, String emotion) {
    final phaseContext = _getPhaseQueryContext(phase);
    final emotionContext = _getEmotionQueryContext(emotion);

    return '''
    User context: $utterance

    Phase context: $phaseContext

    Emotional context: $emotionContext

    Find relevant memories, experiences, and patterns that can inform a helpful response.
    ''';
  }

  /// Get phase-specific query context
  String _getPhaseQueryContext(String phase) {
    switch (phase) {
      case 'Discovery':
        return 'exploration, curiosity, beginning experiences, learning';
      case 'Expansion':
        return 'growth, building, achievement, progress, momentum';
      case 'Transition':
        return 'change, uncertainty, navigation, threshold experiences';
      case 'Consolidation':
        return 'integration, organization, structure, solidification';
      case 'Recovery':
        return 'rest, healing, restoration, self-care, renewal';
      case 'Breakthrough':
        return 'transformation, insight, significant shifts, integration';
      default:
        return 'life patterns, experiences, emotional resonance';
    }
  }

  /// Get emotion-specific query context
  String _getEmotionQueryContext(String emotion) {
    // Parse emotion context and create relevant search terms
    // This would typically parse structured emotion data
    return emotion.isNotEmpty ? emotion : 'general emotional context';
  }

  /// Process and validate retrieved memory nodes
  Future<List<GroundingNode>> _processRetrievedNodes(
    List<Map<String, dynamic>> queryResults,
  ) async {
    final processedNodes = <GroundingNode>[];

    for (final result in queryResults) {
      try {
        final node = GroundingNode(
          nodeId: result['id'] as String,
          content: result['content'] as String,
          relevanceScore: (result['score'] as num).toDouble(),
          nodeType: result['type'] as String? ?? 'memory',
          timestamp: DateTime.tryParse(result['timestamp'] as String? ?? ''),
          metadata: result['metadata'] as Map<String, dynamic>? ?? {},
        );

        // Validate node quality and relevance
        if (_validateNodeQuality(node)) {
          processedNodes.add(node);
        }
      } catch (e) {
        // Skip malformed nodes
        continue;
      }
    }

    // Sort by relevance score
    processedNodes.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    return processedNodes;
  }

  /// Validate node quality for grounding
  bool _validateNodeQuality(GroundingNode node) {
    // Require minimum relevance score
    if (node.relevanceScore < 0.6) return false;

    // Require non-empty content
    if (node.content.trim().isEmpty) return false;

    // Require valid node ID for citations
    if (node.nodeId.isEmpty) return false;

    return true;
  }

  /// Generate citation block for ECHO prompt
  String _generateCitationBlock(List<GroundingNode> nodes) {
    if (nodes.isEmpty) {
      return 'No relevant memory nodes retrieved. Response will be based on general guidance.';
    }

    final buffer = StringBuffer();
    buffer.writeln('Relevant memory context:');
    buffer.writeln();

    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      buffer.writeln('Node ${node.nodeId} (relevance: ${node.relevanceScore.toStringAsFixed(2)}):');
      buffer.writeln(node.content);
      buffer.writeln();
    }

    buffer.writeln('Citation format: Reference nodes using [${nodes.map((n) => n.nodeId).join(', ')}]');

    return buffer.toString();
  }

  /// Calculate overall grounding confidence
  double _calculateGroundingConfidence(List<GroundingNode> nodes) {
    if (nodes.isEmpty) return 0.0;

    // Weighted average of relevance scores with diminishing returns
    double totalWeight = 0.0;
    double weightedSum = 0.0;

    for (int i = 0; i < nodes.length; i++) {
      final weight = 1.0 / (i + 1); // Diminishing weight for lower-ranked nodes
      totalWeight += weight;
      weightedSum += nodes[i].relevanceScore * weight;
    }

    return weightedSum / totalWeight;
  }

  /// Generate uncertainty disclosure based on confidence
  String _generateUncertaintyDisclosure(double confidence) {
    if (confidence > 0.8) {
      return 'Response is well-grounded in your memory patterns.';
    } else if (confidence > 0.6) {
      return 'Response draws from some relevant memory context, though connections may be partial.';
    } else if (confidence > 0.3) {
      return 'Limited memory context available. Response includes general guidance.';
    } else {
      return 'Very limited memory context. Response is primarily based on general understanding.';
    }
  }
}

/// Result of memory grounding operation
class MemoryGroundingResult {
  final List<GroundingNode> nodes;
  final String citationBlock;
  final double confidence;
  final String uncertaintyDisclosure;
  final String? error;

  MemoryGroundingResult({
    required this.nodes,
    required this.citationBlock,
    required this.confidence,
    required this.uncertaintyDisclosure,
    this.error,
  });

  /// Create result for uncertain/error cases
  MemoryGroundingResult.uncertain({
    String? error,
    required String uncertaintyDisclosure,
  }) : this(
          nodes: [],
          citationBlock: 'No memory context available.',
          confidence: 0.0,
          uncertaintyDisclosure: uncertaintyDisclosure,
          error: error,
        );

  bool get hasError => error != null;
  bool get isWellGrounded => confidence > 0.7;
  bool get hasMemoryContext => nodes.isNotEmpty;
}

/// Individual memory node for grounding
class GroundingNode {
  final String nodeId;
  final String content;
  final double relevanceScore;
  final String nodeType;
  final DateTime? timestamp;
  final Map<String, dynamic> metadata;

  GroundingNode({
    required this.nodeId,
    required this.content,
    required this.relevanceScore,
    required this.nodeType,
    this.timestamp,
    required this.metadata,
  });

  /// Generate citation reference for this node
  String get citationRef => '[$nodeId]';

  /// Get human-readable timestamp
  String get formattedTimestamp {
    if (timestamp == null) return 'Unknown time';

    final now = DateTime.now();
    final diff = now.difference(timestamp!);

    if (diff.inDays > 7) {
      return '${timestamp!.month}/${timestamp!.day}/${timestamp!.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} days ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hours ago';
    } else {
      return 'Recently';
    }
  }
}