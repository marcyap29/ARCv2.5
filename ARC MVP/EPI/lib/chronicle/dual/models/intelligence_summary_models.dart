// lib/chronicle/dual/models/intelligence_summary_models.dart
//
// Intelligence Summary (Layer 3) - Readable synthesis of LUMARA's Chronicle.
// Generated from Layer 1 (User) + Layer 2 (LUMARA); version-controlled.

/// Readable synthesis of biographical intelligence. Generated nightly (or on demand).
class IntelligenceSummary {
  final String userId;
  final int version;
  final DateTime generatedAt;
  final String content;
  final String contentHash;
  final IntelligenceSummaryMetadata metadata;
  final Map<String, SectionMeta> sections;

  const IntelligenceSummary({
    required this.userId,
    required this.version,
    required this.generatedAt,
    required this.content,
    required this.contentHash,
    required this.metadata,
    required this.sections,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'version': version,
        'generated_at': generatedAt.toIso8601String(),
        'content': content,
        'content_hash': contentHash,
        'metadata': metadata.toJson(),
        'sections': sections.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory IntelligenceSummary.fromJson(Map<String, dynamic> json) {
    final sectionsJson = json['sections'] as Map<String, dynamic>? ?? {};
    return IntelligenceSummary(
      userId: json['user_id'] as String,
      version: json['version'] as int,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      content: json['content'] as String,
      contentHash: json['content_hash'] as String,
      metadata: IntelligenceSummaryMetadata.fromJson(
        json['metadata'] as Map<String, dynamic>,
      ),
      sections: sectionsJson.map(
        (k, v) => MapEntry(k, SectionMeta.fromJson(v as Map<String, dynamic>)),
      ),
    );
  }
}

class IntelligenceSummaryMetadata {
  final int totalEntries;
  final int totalPatterns;
  final int totalRelationships;
  final TemporalSpan temporalSpan;
  final String confidenceLevel;
  final List<String> sectionsIncluded;
  final int generationDurationMs;
  final String modelUsed;

  const IntelligenceSummaryMetadata({
    required this.totalEntries,
    required this.totalPatterns,
    required this.totalRelationships,
    required this.temporalSpan,
    required this.confidenceLevel,
    required this.sectionsIncluded,
    required this.generationDurationMs,
    required this.modelUsed,
  });

  Map<String, dynamic> toJson() => {
        'total_entries': totalEntries,
        'total_patterns': totalPatterns,
        'total_relationships': totalRelationships,
        'temporal_span': temporalSpan.toJson(),
        'confidence_level': confidenceLevel,
        'sections_included': sectionsIncluded,
        'generation_duration_ms': generationDurationMs,
        'model_used': modelUsed,
      };

  factory IntelligenceSummaryMetadata.fromJson(Map<String, dynamic> json) {
    return IntelligenceSummaryMetadata(
      totalEntries: json['total_entries'] as int? ?? 0,
      totalPatterns: json['total_patterns'] as int? ?? 0,
      totalRelationships: json['total_relationships'] as int? ?? 0,
      temporalSpan: TemporalSpan.fromJson(
        json['temporal_span'] as Map<String, dynamic>? ?? {},
      ),
      confidenceLevel: json['confidence_level'] as String? ?? 'low',
      sectionsIncluded:
          List<String>.from(json['sections_included'] as List? ?? []),
      generationDurationMs: json['generation_duration_ms'] as int? ?? 0,
      modelUsed: json['model_used'] as String? ?? 'unknown',
    );
  }
}

class TemporalSpan {
  final DateTime earliest;
  final DateTime latest;
  final int monthsCovered;

  const TemporalSpan({
    required this.earliest,
    required this.latest,
    required this.monthsCovered,
  });

  Map<String, dynamic> toJson() => {
        'earliest': earliest.toIso8601String(),
        'latest': latest.toIso8601String(),
        'months_covered': monthsCovered,
      };

  factory TemporalSpan.fromJson(Map<String, dynamic> json) {
    return TemporalSpan(
      earliest: json['earliest'] != null
          ? DateTime.parse(json['earliest'] as String)
          : DateTime.now(),
      latest: json['latest'] != null
          ? DateTime.parse(json['latest'] as String)
          : DateTime.now(),
      monthsCovered: json['months_covered'] as int? ?? 0,
    );
  }
}

class SectionMeta {
  final DateTime lastUpdated;
  final double confidence;

  const SectionMeta({
    required this.lastUpdated,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'last_updated': lastUpdated.toIso8601String(),
        'confidence': confidence,
      };

  factory SectionMeta.fromJson(Map<String, dynamic> json) {
    return SectionMeta(
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'] as String)
          : DateTime.now(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Archived historical version of the summary.
class IntelligenceSummaryVersion {
  final String userId;
  final int version;
  final String content;
  final DateTime generatedAt;
  final DateTime archivedAt;

  const IntelligenceSummaryVersion({
    required this.userId,
    required this.version,
    required this.content,
    required this.generatedAt,
    required this.archivedAt,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'version': version,
        'content': content,
        'generated_at': generatedAt.toIso8601String(),
        'archived_at': archivedAt.toIso8601String(),
      };

  factory IntelligenceSummaryVersion.fromJson(Map<String, dynamic> json) {
    return IntelligenceSummaryVersion(
      userId: json['user_id'] as String,
      version: json['version'] as int,
      content: json['content'] as String,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      archivedAt: DateTime.parse(json['archived_at'] as String),
    );
  }
}
