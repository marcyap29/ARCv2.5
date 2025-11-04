import 'package:equatable/equatable.dart';
import '../../prism/atlas/rivet/rivet_models.dart';

/// Unified data model for reflective analysis across all input sources
/// Supports journal entries, drafts, and LUMARA chat conversations
class ReflectiveEntryData extends Equatable {
  final DateTime timestamp;
  final List<String> keywords;
  final String phase;
  final String? mood;
  final EvidenceSource source;
  final String? context;       // Optional context string (e.g., "source:chat", "context:lens:luma")
  final double confidence;     // Confidence weight for this entry (0.0-1.0)
  final Map<String, dynamic> metadata; // Additional metadata specific to source

  const ReflectiveEntryData({
    required this.timestamp,
    required this.keywords,
    required this.phase,
    this.mood,
    required this.source,
    this.context,
    this.confidence = 1.0,
    this.metadata = const {},
  });

  @override
  List<Object?> get props => [
    timestamp,
    keywords,
    phase,
    mood,
    source,
    context,
    confidence,
    metadata,
  ];

  /// Create from journal entry data
  factory ReflectiveEntryData.fromJournalEntry({
    required DateTime timestamp,
    required List<String> keywords,
    required String phase,
    String? mood,
    double confidence = 1.0,
    Map<String, dynamic> metadata = const {},
  }) {
    return ReflectiveEntryData(
      timestamp: timestamp,
      keywords: keywords,
      phase: phase,
      mood: mood,
      source: EvidenceSource.text,
      confidence: confidence,
      metadata: metadata,
    );
  }

  /// Create from draft entry data
  factory ReflectiveEntryData.fromDraftEntry({
    required DateTime timestamp,
    required List<String> keywords,
    required String phase,
    String? mood,
    String? context,
    double confidence = 0.6, // Lower confidence for drafts
    Map<String, dynamic> metadata = const {},
  }) {
    return ReflectiveEntryData(
      timestamp: timestamp,
      keywords: keywords,
      phase: phase,
      mood: mood,
      source: EvidenceSource.draft,
      context: context,
      confidence: confidence,
      metadata: metadata,
    );
  }

  /// Create from LUMARA chat data
  factory ReflectiveEntryData.fromLumaraChat({
    required DateTime timestamp,
    required List<String> keywords,
    required String phase,
    String? mood,
    String? context,
    double confidence = 0.8, // Medium confidence for chat
    Map<String, dynamic> metadata = const {},
  }) {
    return ReflectiveEntryData(
      timestamp: timestamp,
      keywords: keywords,
      phase: phase,
      mood: mood,
      source: EvidenceSource.lumaraChat,
      context: context ?? "source:chat",
      confidence: confidence,
      metadata: metadata,
    );
  }

  /// Get source weight for analysis
  double get sourceWeight {
    switch (source) {
      case EvidenceSource.journal:
      case EvidenceSource.text:
      case EvidenceSource.voice:
      case EvidenceSource.therapistTag:
        return 1.0; // Full weight for journal entries
      case EvidenceSource.draft:
        return 0.6; // Reduced weight for drafts
      case EvidenceSource.lumaraChat:
        return 0.8; // Medium weight for chat
      case EvidenceSource.other:
        return 0.5; // Lowest weight for other sources
      case EvidenceSource.chat:
      case EvidenceSource.media:
      case EvidenceSource.arcform:
      case EvidenceSource.phase:
      case EvidenceSource.system:
        return 0.7; // Medium weight for other system sources
    }
  }

  /// Get effective confidence (source weight * entry confidence)
  double get effectiveConfidence => sourceWeight * confidence;

  /// Check if this is a high-confidence entry
  bool get isHighConfidence => effectiveConfidence >= 0.8;

  /// Check if this is a draft entry
  bool get isDraft => source == EvidenceSource.draft;

  /// Check if this is a chat entry
  bool get isChat => source == EvidenceSource.lumaraChat;

  /// Check if this is a journal entry
  bool get isJournal => source == EvidenceSource.text || source == EvidenceSource.voice;

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'keywords': keywords,
      'phase': phase,
      'mood': mood,
      'source': source.toString(),
      'context': context,
      'confidence': confidence,
      'metadata': metadata,
    };
  }

  factory ReflectiveEntryData.fromJson(Map<String, dynamic> json) {
    return ReflectiveEntryData(
      timestamp: DateTime.parse(json['timestamp'] as String),
      keywords: List<String>.from(json['keywords'] as List),
      phase: json['phase'] as String,
      mood: json['mood'] as String?,
      source: EvidenceSource.values.firstWhere(
        (e) => e.toString() == json['source'],
        orElse: () => EvidenceSource.other,
      ),
      context: json['context'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }

  ReflectiveEntryData copyWith({
    DateTime? timestamp,
    List<String>? keywords,
    String? phase,
    String? mood,
    EvidenceSource? source,
    String? context,
    double? confidence,
    Map<String, dynamic>? metadata,
  }) {
    return ReflectiveEntryData(
      timestamp: timestamp ?? this.timestamp,
      keywords: keywords ?? this.keywords,
      phase: phase ?? this.phase,
      mood: mood ?? this.mood,
      source: source ?? this.source,
      context: context ?? this.context,
      confidence: confidence ?? this.confidence,
      metadata: metadata ?? this.metadata,
    );
  }
}
