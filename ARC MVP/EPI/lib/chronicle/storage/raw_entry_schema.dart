/// Raw Entry Schema for Layer 0
/// 
/// Defines the structure of raw entries stored in Layer 0.
/// This matches the specification from the CHRONICLE architecture document.

class RawEntrySchema {
  /// Entry ID (UUID string)
  final String entryId;

  /// Timestamp of the entry
  final DateTime timestamp;

  /// Full journal entry text
  final String content;

  /// Metadata about the entry
  final RawEntryMetadata metadata;

  /// Analysis data (SENTINEL, ATLAS, RIVET)
  final RawEntryAnalysis analysis;

  const RawEntrySchema({
    required this.entryId,
    required this.timestamp,
    required this.content,
    required this.metadata,
    required this.analysis,
  });

  Map<String, dynamic> toJson() {
    return {
      'entry_id': entryId,
      'timestamp': timestamp.toIso8601String(),
      'content': content,
      'metadata': metadata.toJson(),
      'analysis': analysis.toJson(),
    };
  }

  factory RawEntrySchema.fromJson(Map<String, dynamic> json) {
    return RawEntrySchema(
      entryId: json['entry_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      content: json['content'] as String,
      metadata: RawEntryMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      analysis: RawEntryAnalysis.fromJson(json['analysis'] as Map<String, dynamic>),
    );
  }
}

class RawEntryMetadata {
  final int wordCount;
  final bool voiceTranscribed;
  final List<String> mediaAttachments;

  const RawEntryMetadata({
    required this.wordCount,
    this.voiceTranscribed = false,
    this.mediaAttachments = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'word_count': wordCount,
      'voice_transcribed': voiceTranscribed,
      'media_attachments': mediaAttachments,
    };
  }

  factory RawEntryMetadata.fromJson(Map<String, dynamic> json) {
    return RawEntryMetadata(
      wordCount: json['word_count'] as int,
      voiceTranscribed: json['voice_transcribed'] as bool? ?? false,
      mediaAttachments: List<String>.from(json['media_attachments'] as List? ?? []),
    );
  }
}

class RawEntryAnalysis {
  final SentinelScore? sentinelScore;
  final String? atlasPhase;
  final Map<String, double>? atlasScores;
  final List<String>? rivetTransitions;
  final List<String> extractedThemes;
  final List<String> keywords;

  const RawEntryAnalysis({
    this.sentinelScore,
    this.atlasPhase,
    this.atlasScores,
    this.rivetTransitions,
    this.extractedThemes = const [],
    this.keywords = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'sentinel_score': sentinelScore?.toJson(),
      'atlas_phase': atlasPhase,
      'atlas_scores': atlasScores,
      'rivet_transitions': rivetTransitions,
      'extracted_themes': extractedThemes,
      'keywords': keywords,
    };
  }

  factory RawEntryAnalysis.fromJson(Map<String, dynamic> json) {
    return RawEntryAnalysis(
      sentinelScore: json['sentinel_score'] != null
          ? SentinelScore.fromJson(json['sentinel_score'] as Map<String, dynamic>)
          : null,
      atlasPhase: json['atlas_phase'] as String?,
      atlasScores: json['atlas_scores'] != null
          ? Map<String, double>.from(json['atlas_scores'] as Map)
          : null,
      rivetTransitions: json['rivet_transitions'] != null
          ? List<String>.from(json['rivet_transitions'] as List)
          : null,
      extractedThemes: List<String>.from(json['extracted_themes'] as List? ?? []),
      keywords: List<String>.from(json['keywords'] as List? ?? []),
    );
  }
}

class SentinelScore {
  final double emotionalIntensity;
  final double frequency;
  final double density;

  const SentinelScore({
    required this.emotionalIntensity,
    required this.frequency,
    required this.density,
  });

  Map<String, dynamic> toJson() {
    return {
      'emotional_intensity': emotionalIntensity,
      'frequency': frequency,
      'density': density,
    };
  }

  factory SentinelScore.fromJson(Map<String, dynamic> json) {
    return SentinelScore(
      emotionalIntensity: (json['emotional_intensity'] as num).toDouble(),
      frequency: (json['frequency'] as num).toDouble(),
      density: (json['density'] as num).toDouble(),
    );
  }
}
