// lib/mira/memory/attribution_service.dart
// Attribution and explainability service for EPI memory system
// Provides transparent memory usage tracking and explainable AI responses

import 'dart:collection';
import '../core/schema.dart';
import 'enhanced_memory_schema.dart';

/// Service for tracking memory attribution and providing explainable responses
class AttributionService {
  final Map<String, ResponseTrace> _responseTraces = {};
  final Map<String, List<AttributionTrace>> _nodeAttributions = {};
  final Queue<String> _recentResponses = Queue<String>();
  static const int _maxTraceHistory = 1000;

  /// Record memory usage for a response
  Future<String> recordMemoryUsage({
    required String responseId,
    required List<String> referencedNodes,
    required String model,
    required Map<String, dynamic> context,
    Map<String, String>? relationTypes,
    Map<String, double>? confidenceScores,
    Map<String, String>? reasoning,
  }) async {
    final traces = <AttributionTrace>[];
    final timestamp = DateTime.now().toUtc();

    for (int i = 0; i < referencedNodes.length; i++) {
      final nodeRef = referencedNodes[i];
      final relation = relationTypes?[nodeRef] ?? 'referenced';
      final confidence = confidenceScores?[nodeRef] ?? 1.0;
      final nodeReasoning = reasoning?[nodeRef];

      final trace = AttributionTrace(
        nodeRef: nodeRef,
        relation: relation,
        confidence: confidence,
        timestamp: timestamp,
        reasoning: nodeReasoning,
      );

      traces.add(trace);

      // Track per-node attributions
      _nodeAttributions.putIfAbsent(nodeRef, () => []);
      _nodeAttributions[nodeRef]!.add(trace);
    }

    final responseTrace = ResponseTrace(
      responseId: responseId,
      traces: traces,
      timestamp: timestamp,
      model: model,
      context: context,
    );

    _responseTraces[responseId] = responseTrace;
    _recentResponses.addLast(responseId);

    // Maintain trace history limit
    if (_recentResponses.length > _maxTraceHistory) {
      final oldResponseId = _recentResponses.removeFirst();
      _responseTraces.remove(oldResponseId);
    }

    return responseId;
  }

  /// Get attribution trace for a specific response
  ResponseTrace? getResponseTrace(String responseId) {
    return _responseTraces[responseId];
  }

  /// Get all attributions for a specific memory node
  List<AttributionTrace> getNodeAttributions(String nodeId) {
    return _nodeAttributions[nodeId] ?? [];
  }

  /// Generate explainable response with citations
  Map<String, dynamic> generateExplainableResponse({
    required String content,
    required String responseId,
    required List<AttributionTrace> traces,
    bool includeReasoningDetails = false,
  }) {
    final citationBlocks = <Map<String, dynamic>>[];
    final referenceSummary = <String, int>{};

    // Group traces by relation type
    final Map<String, List<AttributionTrace>> groupedTraces = {};
    for (final trace in traces) {
      groupedTraces.putIfAbsent(trace.relation, () => []);
      groupedTraces[trace.relation]!.add(trace);
      referenceSummary[trace.relation] = (referenceSummary[trace.relation] ?? 0) + 1;
    }

    // Generate citation blocks
    for (final entry in groupedTraces.entries) {
      final relation = entry.key;
      final relationTraces = entry.value;

      citationBlocks.add({
        'relation': relation,
        'count': relationTraces.length,
        'nodes': relationTraces.map((t) => {
          'node_ref': t.nodeRef,
          'confidence': t.confidence,
          if (includeReasoningDetails && t.reasoning != null) 'reasoning': t.reasoning,
        }).toList(),
        'avg_confidence': relationTraces.map((t) => t.confidence).reduce((a, b) => a + b) / relationTraces.length,
      });
    }

    return {
      'content': content,
      'response_id': responseId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'attribution': {
        'total_references': traces.length,
        'reference_summary': referenceSummary,
        'citation_blocks': citationBlocks,
        'overall_confidence': traces.isNotEmpty
            ? traces.map((t) => t.confidence).reduce((a, b) => a + b) / traces.length
            : 0.0,
      },
      'transparency': {
        'memory_usage_tracked': true,
        'explainable': true,
        'user_sovereign': true,
      },
    };
  }

  /// Create attribution trace for memory node usage
  AttributionTrace createTrace({
    required String nodeRef,
    required String relation,
    double confidence = 1.0,
    String? reasoning,
    String? phaseContext,
  }) {
    return AttributionTrace(
      nodeRef: nodeRef,
      relation: relation,
      confidence: confidence,
      timestamp: DateTime.now().toUtc(),
      reasoning: reasoning,
      phaseContext: phaseContext,
    );
  }

  /// Generate human-readable citation text
  String generateCitationText(List<AttributionTrace> traces) {
    if (traces.isEmpty) {
      return 'This response was generated without specific memory references.';
    }

    final groupedByRelation = <String, List<AttributionTrace>>{};
    for (final trace in traces) {
      groupedByRelation.putIfAbsent(trace.relation, () => []);
      groupedByRelation[trace.relation]!.add(trace);
    }

    final citationParts = <String>[];

    for (final entry in groupedByRelation.entries) {
      final relation = entry.key;
      final relationTraces = entry.value;
      final nodeCount = relationTraces.length;

      String relationDescription;
      switch (relation) {
        case 'supports':
          relationDescription = nodeCount == 1
              ? 'This draws from your journal entry'
              : 'This draws from $nodeCount of your journal entries';
          break;
        case 'contradicts':
          relationDescription = nodeCount == 1
              ? 'This addresses a tension with your previous reflection'
              : 'This addresses tensions with $nodeCount previous reflections';
          break;
        case 'referenced':
          relationDescription = nodeCount == 1
              ? 'This references your memory'
              : 'This references $nodeCount memories';
          break;
        case 'derives':
          relationDescription = nodeCount == 1
              ? 'This builds on your insight'
              : 'This builds on $nodeCount insights';
          break;
        default:
          relationDescription = nodeCount == 1
              ? 'This relates to your memory'
              : 'This relates to $nodeCount memories';
      }

      citationParts.add(relationDescription);
    }

    return citationParts.join(', ') + '.';
  }

  /// Get memory usage statistics
  Map<String, dynamic> getUsageStatistics() {
    final totalTraces = _responseTraces.values
        .map((rt) => rt.traces.length)
        .fold(0, (a, b) => a + b);

    final relationCounts = <String, int>{};
    final nodeCounts = <String, int>{};

    for (final responseTrace in _responseTraces.values) {
      for (final trace in responseTrace.traces) {
        relationCounts[trace.relation] = (relationCounts[trace.relation] ?? 0) + 1;
        nodeCounts[trace.nodeRef] = (nodeCounts[trace.nodeRef] ?? 0) + 1;
      }
    }

    final topNodes = nodeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'total_responses': _responseTraces.length,
      'total_memory_references': totalTraces,
      'avg_references_per_response': _responseTraces.isNotEmpty
          ? totalTraces / _responseTraces.length
          : 0.0,
      'relation_distribution': relationCounts,
      'most_referenced_nodes': topNodes.take(10).map((e) => {
        'node_id': e.key,
        'reference_count': e.value,
      }).toList(),
      'memory_transparency_score': _calculateTransparencyScore(),
    };
  }

  /// Calculate transparency score based on attribution completeness
  double _calculateTransparencyScore() {
    if (_responseTraces.isEmpty) return 1.0;

    int trackedResponses = 0;
    int totalTraces = 0;
    int reasoningCount = 0;

    for (final responseTrace in _responseTraces.values) {
      if (responseTrace.traces.isNotEmpty) {
        trackedResponses++;
      }
      totalTraces += responseTrace.traces.length;
      reasoningCount += responseTrace.traces.where((t) => t.reasoning != null).length;
    }

    final trackingRatio = trackedResponses / _responseTraces.length;
    final reasoningRatio = totalTraces > 0 ? reasoningCount / totalTraces : 0.0;

    return (trackingRatio * 0.7) + (reasoningRatio * 0.3);
  }

  /// Export attribution data for audit
  Map<String, dynamic> exportAttributionData() {
    return {
      'export_timestamp': DateTime.now().toUtc().toIso8601String(),
      'response_traces': _responseTraces.values.map((rt) => rt.toJson()).toList(),
      'node_attributions': _nodeAttributions.map((nodeId, traces) =>
          MapEntry(nodeId, traces.map((t) => t.toJson()).toList())),
      'statistics': getUsageStatistics(),
      'schema_version': 'attribution_export.v1',
    };
  }

  /// Clear old attribution data (for privacy/storage management)
  void clearOldAttributions({Duration? olderThan}) {
    final cutoff = DateTime.now().toUtc().subtract(olderThan ?? const Duration(days: 90));

    // Remove old response traces
    _responseTraces.removeWhere((_, trace) => trace.timestamp.isBefore(cutoff));

    // Remove old node attributions
    for (final nodeId in _nodeAttributions.keys.toList()) {
      _nodeAttributions[nodeId]!.removeWhere((trace) => trace.timestamp.isBefore(cutoff));
      if (_nodeAttributions[nodeId]!.isEmpty) {
        _nodeAttributions.remove(nodeId);
      }
    }

    // Update recent responses queue
    _recentResponses.removeWhere((responseId) => !_responseTraces.containsKey(responseId));
  }

  /// Generate attribution summary for user review
  String generateAttributionSummary(String responseId) {
    final trace = getResponseTrace(responseId);
    if (trace == null) {
      return 'No attribution data available for this response.';
    }

    final citationText = generateCitationText(trace.traces);
    final confidenceScore = trace.traces.isNotEmpty
        ? trace.traces.map((t) => t.confidence).reduce((a, b) => a + b) / trace.traces.length
        : 0.0;

    return '''
Response Attribution Summary:
${citationText}

Memory Usage: ${trace.traces.length} references
Confidence: ${(confidenceScore * 100).toStringAsFixed(1)}%
Model: ${trace.model}
Timestamp: ${trace.timestamp.toLocal().toString()}

Your memory usage is fully tracked and transparent. You can review or export this data anytime.
''';
  }

  /// Clear all attribution traces
  void clearAllTraces() {
    _responseTraces.clear();
    _nodeAttributions.clear();
    _recentResponses.clear();
  }

  /// Restore response trace from backup
  void restoreResponseTrace(String responseId, ResponseTrace trace) {
    _responseTraces[responseId] = trace;
    _recentResponses.add(responseId);
    
    // Maintain max history
    while (_recentResponses.length > _maxTraceHistory) {
      final oldest = _recentResponses.removeFirst();
      _responseTraces.remove(oldest);
    }
  }

  /// Restore node attributions from backup
  void restoreNodeAttributions(String nodeRef, List<AttributionTrace> traces) {
    _nodeAttributions[nodeRef] = traces;
  }
}