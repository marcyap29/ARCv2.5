// l../mira/memory/enhanced_attribution_schema.dart
// Extended attribution system supporting multiple source types and cross-references

import 'enhanced_memory_schema.dart';

/// Enhanced source type taxonomy for multi-source attribution
enum SourceType {
  /// Journal entries and reflections
  journalEntry,

  /// Chat conversations and messages
  chatMessage,
  chatSession,

  /// Media content
  photo,
  photoOcr,
  audio,
  audioTranscript,
  video,
  videoTranscript,

  /// ARCFORM data
  phaseRegime,
  emotionTracking,
  keywordSubmission,

  /// System-generated content
  lumaraResponse,
  insight,
  summary,

  /// Cross-references and connections
  relatedContent,
  previousMention,

  /// External sources (future expansion)
  webReference,
  bookReference,
  documentUpload,
}

/// Attribution confidence levels for user understanding
enum ConfidenceLevel {
  veryHigh(0.9, 1.0, 'Very High', 'Strong connection'),
  high(0.7, 0.89, 'High', 'Clear relevance'),
  medium(0.5, 0.69, 'Medium', 'Moderate relevance'),
  low(0.3, 0.49, 'Low', 'Weak connection'),
  veryLow(0.0, 0.29, 'Very Low', 'Minimal relevance');

  const ConfidenceLevel(this.min, this.max, this.label, this.description);

  final double min;
  final double max;
  final String label;
  final String description;

  static ConfidenceLevel fromScore(double score) {
    for (final level in ConfidenceLevel.values) {
      if (score >= level.min && score <= level.max) return level;
    }
    return ConfidenceLevel.veryLow;
  }
}

/// Enhanced attribution trace with multi-source support
class EnhancedAttributionTrace {
  final String nodeRef;
  final SourceType sourceType;
  final String relation;
  final double confidence;
  final ConfidenceLevel confidenceLevel;
  final DateTime timestamp;
  final String? reasoning;
  final String? phaseContext;
  final String? excerpt;

  /// Source-specific metadata
  final Map<String, dynamic> sourceMetadata;

  /// Cross-references to related content
  final List<CrossReference> crossReferences;

  /// Response section this attribution influenced (optional)
  final String? responseSectionId;

  /// Attribution weight in final response (0.0-1.0)
  final double contributionWeight;

  EnhancedAttributionTrace({
    required this.nodeRef,
    required this.sourceType,
    required this.relation,
    required this.confidence,
    required this.timestamp,
    this.reasoning,
    this.phaseContext,
    this.excerpt,
    this.sourceMetadata = const {},
    this.crossReferences = const [],
    this.responseSectionId,
    this.contributionWeight = 1.0,
  }) : confidenceLevel = ConfidenceLevel.fromScore(confidence);

  Map<String, dynamic> toJson() => {
    'node_ref': nodeRef,
    'source_type': sourceType.name,
    'relation': relation,
    'confidence': confidence,
    'confidence_level': confidenceLevel.name,
    'timestamp': timestamp.toIso8601String(),
    'reasoning': reasoning,
    'phase_context': phaseContext,
    'excerpt': excerpt,
    'source_metadata': sourceMetadata,
    'cross_references': crossReferences.map((cr) => cr.toJson()).toList(),
    'response_section_id': responseSectionId,
    'contribution_weight': contributionWeight,
  };

  factory EnhancedAttributionTrace.fromJson(Map<String, dynamic> json) {
    return EnhancedAttributionTrace(
      nodeRef: json['node_ref'],
      sourceType: SourceType.values.firstWhere((st) => st.name == json['source_type']),
      relation: json['relation'],
      confidence: json['confidence'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      reasoning: json['reasoning'],
      phaseContext: json['phase_context'],
      excerpt: json['excerpt'],
      sourceMetadata: Map<String, dynamic>.from(json['source_metadata'] ?? {}),
      crossReferences: (json['cross_references'] as List<dynamic>? ?? [])
          .map((cr) => CrossReference.fromJson(cr))
          .toList(),
      responseSectionId: json['response_section_id'],
      contributionWeight: json['contribution_weight']?.toDouble() ?? 1.0,
    );
  }

  /// Create a legacy AttributionTrace for backward compatibility
  AttributionTrace toLegacyTrace() {
    return AttributionTrace(
      nodeRef: nodeRef,
      relation: relation,
      confidence: confidence,
      timestamp: timestamp,
      reasoning: reasoning,
      phaseContext: phaseContext,
      excerpt: excerpt,
    );
  }

  /// Get human-readable source type description
  String getSourceTypeDescription() {
    switch (sourceType) {
      case SourceType.journalEntry:
        return 'Journal Entry';
      case SourceType.chatMessage:
        return 'Chat Message';
      case SourceType.chatSession:
        return 'Chat Conversation';
      case SourceType.photo:
        return 'Photo';
      case SourceType.photoOcr:
        return 'Text from Photo';
      case SourceType.audio:
        return 'Audio Recording';
      case SourceType.audioTranscript:
        return 'Audio Transcript';
      case SourceType.video:
        return 'Video';
      case SourceType.videoTranscript:
        return 'Video Transcript';
      case SourceType.phaseRegime:
        return 'Phase Tracking';
      case SourceType.emotionTracking:
        return 'Emotion Data';
      case SourceType.keywordSubmission:
        return 'Keywords';
      case SourceType.lumaraResponse:
        return 'Previous LUMARA Response';
      case SourceType.insight:
        return 'Generated Insight';
      case SourceType.summary:
        return 'Summary';
      case SourceType.relatedContent:
        return 'Related Content';
      case SourceType.previousMention:
        return 'Previous Mention';
      case SourceType.webReference:
        return 'Web Reference';
      case SourceType.bookReference:
        return 'Book Reference';
      case SourceType.documentUpload:
        return 'Uploaded Document';
    }
  }

  /// Get icon for source type
  String getSourceTypeIcon() {
    switch (sourceType) {
      case SourceType.journalEntry:
        return '📝';
      case SourceType.chatMessage:
      case SourceType.chatSession:
        return '💬';
      case SourceType.photo:
      case SourceType.photoOcr:
        return '📷';
      case SourceType.audio:
      case SourceType.audioTranscript:
        return '🎵';
      case SourceType.video:
      case SourceType.videoTranscript:
        return '🎥';
      case SourceType.phaseRegime:
        return '📊';
      case SourceType.emotionTracking:
        return '😊';
      case SourceType.keywordSubmission:
        return '🏷️';
      case SourceType.lumaraResponse:
        return '🤖';
      case SourceType.insight:
        return '💡';
      case SourceType.summary:
        return '📋';
      case SourceType.relatedContent:
        return '🔗';
      case SourceType.previousMention:
        return '👁️';
      case SourceType.webReference:
        return '🌐';
      case SourceType.bookReference:
        return '📚';
      case SourceType.documentUpload:
        return '📄';
    }
  }
}

/// Cross-reference to related content
class CrossReference {
  final String targetId;
  final SourceType targetType;
  final String relation;
  final double strength;
  final String? description;
  final DateTime timestamp;

  const CrossReference({
    required this.targetId,
    required this.targetType,
    required this.relation,
    required this.strength,
    this.description,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'target_id': targetId,
    'target_type': targetType.name,
    'relation': relation,
    'strength': strength,
    'description': description,
    'timestamp': timestamp.toIso8601String(),
  };

  factory CrossReference.fromJson(Map<String, dynamic> json) {
    return CrossReference(
      targetId: json['target_id'],
      targetType: SourceType.values.firstWhere((st) => st.name == json['target_type']),
      relation: json['relation'],
      strength: json['strength'].toDouble(),
      description: json['description'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Enhanced response trace with sectioned attribution
class EnhancedResponseTrace {
  final String responseId;
  final List<EnhancedAttributionTrace> traces;
  final DateTime timestamp;
  final String model;
  final Map<String, dynamic> context;

  /// Response sections with their attributions
  final List<ResponseSection> sections;

  /// Overall attribution summary
  final AttributionSummary summary;

  const EnhancedResponseTrace({
    required this.responseId,
    required this.traces,
    required this.timestamp,
    required this.model,
    required this.context,
    required this.sections,
    required this.summary,
  });

  Map<String, dynamic> toJson() => {
    'response_id': responseId,
    'traces': traces.map((t) => t.toJson()).toList(),
    'timestamp': timestamp.toIso8601String(),
    'model': model,
    'context': context,
    'sections': sections.map((s) => s.toJson()).toList(),
    'summary': summary.toJson(),
  };

  factory EnhancedResponseTrace.fromJson(Map<String, dynamic> json) {
    return EnhancedResponseTrace(
      responseId: json['response_id'],
      traces: (json['traces'] as List<dynamic>)
          .map((t) => EnhancedAttributionTrace.fromJson(t))
          .toList(),
      timestamp: DateTime.parse(json['timestamp']),
      model: json['model'],
      context: Map<String, dynamic>.from(json['context'] ?? {}),
      sections: (json['sections'] as List<dynamic>)
          .map((s) => ResponseSection.fromJson(s))
          .toList(),
      summary: AttributionSummary.fromJson(json['summary']),
    );
  }

  /// Convert to legacy ResponseTrace for backward compatibility
  ResponseTrace toLegacyTrace() {
    return ResponseTrace(
      responseId: responseId,
      traces: traces.map((t) => t.toLegacyTrace()).toList(),
      timestamp: timestamp,
      model: model,
      context: context,
    );
  }
}

/// Response section with specific attributions
class ResponseSection {
  final String sectionId;
  final String content;
  final List<String> attributionTraceIds;
  final double confidenceScore;
  final SourceType primarySourceType;

  const ResponseSection({
    required this.sectionId,
    required this.content,
    required this.attributionTraceIds,
    required this.confidenceScore,
    required this.primarySourceType,
  });

  Map<String, dynamic> toJson() => {
    'section_id': sectionId,
    'content': content,
    'attribution_trace_ids': attributionTraceIds,
    'confidence_score': confidenceScore,
    'primary_source_type': primarySourceType.name,
  };

  factory ResponseSection.fromJson(Map<String, dynamic> json) {
    return ResponseSection(
      sectionId: json['section_id'],
      content: json['content'],
      attributionTraceIds: List<String>.from(json['attribution_trace_ids']),
      confidenceScore: json['confidence_score'].toDouble(),
      primarySourceType: SourceType.values.firstWhere(
        (st) => st.name == json['primary_source_type']
      ),
    );
  }
}

/// Attribution summary with source type breakdown
class AttributionSummary {
  final int totalAttributions;
  final Map<SourceType, int> sourceTypeBreakdown;
  final Map<String, int> relationBreakdown;
  final double overallConfidence;
  final List<String> primarySources;
  final List<CrossReference> crossReferences;

  const AttributionSummary({
    required this.totalAttributions,
    required this.sourceTypeBreakdown,
    required this.relationBreakdown,
    required this.overallConfidence,
    required this.primarySources,
    required this.crossReferences,
  });

  Map<String, dynamic> toJson() => {
    'total_attributions': totalAttributions,
    'source_type_breakdown': sourceTypeBreakdown.map(
      (key, value) => MapEntry(key.name, value)
    ),
    'relation_breakdown': relationBreakdown,
    'overall_confidence': overallConfidence,
    'primary_sources': primarySources,
    'cross_references': crossReferences.map((cr) => cr.toJson()).toList(),
  };

  factory AttributionSummary.fromJson(Map<String, dynamic> json) {
    return AttributionSummary(
      totalAttributions: json['total_attributions'],
      sourceTypeBreakdown: (json['source_type_breakdown'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(
            SourceType.values.firstWhere((st) => st.name == key),
            value as int
          )),
      relationBreakdown: Map<String, int>.from(json['relation_breakdown']),
      overallConfidence: json['overall_confidence'].toDouble(),
      primarySources: List<String>.from(json['primary_sources']),
      crossReferences: (json['cross_references'] as List<dynamic>? ?? [])
          .map((cr) => CrossReference.fromJson(cr))
          .toList(),
    );
  }

  /// Generate human-readable summary
  String generateDescription() {
    if (totalAttributions == 0) {
      return 'This response was generated without specific memory references.';
    }

    final sourceDescriptions = <String>[];
    for (final entry in sourceTypeBreakdown.entries) {
      final sourceType = entry.key;
      final count = entry.value;
      final description = _getSourceDescription(sourceType, count);
      sourceDescriptions.add(description);
    }

    final confidenceDesc = _getConfidenceDescription(overallConfidence);

    return '''
This response draws from ${sourceDescriptions.join(', ')}.

${crossReferences.isNotEmpty ? 'Cross-references: ${crossReferences.length} related items found.' : ''}

Confidence: $confidenceDesc (${(overallConfidence * 100).toStringAsFixed(1)}%)
''';
  }

  String _getSourceDescription(SourceType sourceType, int count) {
    final typeDesc = EnhancedAttributionTrace(
      nodeRef: '',
      sourceType: sourceType,
      relation: '',
      confidence: 0.0,
      timestamp: DateTime.now(),
    ).getSourceTypeDescription();

    return count == 1 ? '1 $typeDesc' : '$count ${typeDesc}s';
  }

  String _getConfidenceDescription(double confidence) {
    final level = ConfidenceLevel.fromScore(confidence);
    return '${level.label} - ${level.description}';
  }
}

/// Factory for creating enhanced attribution traces from different source types
class EnhancedAttributionFactory {
  /// Create attribution for journal entry
  static EnhancedAttributionTrace fromJournalEntry({
    required String entryId,
    required String relation,
    required double confidence,
    String? excerpt,
    String? reasoning,
    String? phaseContext,
    Map<String, dynamic> metadata = const {},
  }) {
    return EnhancedAttributionTrace(
      nodeRef: entryId,
      sourceType: SourceType.journalEntry,
      relation: relation,
      confidence: confidence,
      timestamp: DateTime.now(),
      excerpt: excerpt,
      reasoning: reasoning,
      phaseContext: phaseContext,
      sourceMetadata: metadata,
    );
  }

  /// Create attribution for chat message
  static EnhancedAttributionTrace fromChatMessage({
    required String messageId,
    required String relation,
    required double confidence,
    required String sessionId,
    required String role,
    String? excerpt,
    String? reasoning,
  }) {
    return EnhancedAttributionTrace(
      nodeRef: messageId,
      sourceType: role == 'assistant' ? SourceType.lumaraResponse : SourceType.chatMessage,
      relation: relation,
      confidence: confidence,
      timestamp: DateTime.now(),
      excerpt: excerpt,
      reasoning: reasoning,
      sourceMetadata: {
        'session_id': sessionId,
        'role': role,
      },
    );
  }

  /// Create attribution for media content
  static EnhancedAttributionTrace fromMediaContent({
    required String mediaId,
    required SourceType mediaType,
    required String relation,
    required double confidence,
    String? excerpt,
    String? reasoning,
    Map<String, dynamic> metadata = const {},
  }) {
    return EnhancedAttributionTrace(
      nodeRef: mediaId,
      sourceType: mediaType,
      relation: relation,
      confidence: confidence,
      timestamp: DateTime.now(),
      excerpt: excerpt,
      reasoning: reasoning,
      sourceMetadata: metadata,
    );
  }

  /// Create cross-reference
  static CrossReference createCrossReference({
    required String targetId,
    required SourceType targetType,
    required String relation,
    required double strength,
    String? description,
  }) {
    return CrossReference(
      targetId: targetId,
      targetType: targetType,
      relation: relation,
      strength: strength,
      description: description,
      timestamp: DateTime.now(),
    );
  }
}