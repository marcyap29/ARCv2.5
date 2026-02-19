// lib/chronicle/dual/models/chronicle_models.dart
//
// LUMARA Dual-Chronicle Architecture - Data Models
//
// CRITICAL: User's Chronicle is sacred. System NEVER writes to User Chronicle
// without explicit user approval. See DOCS for full architecture.

// ============================================================================
// USER'S CHRONICLE - SACRED DATA
// ============================================================================

/// User-authored entry. ONLY user-authored content belongs in User Chronicle.
enum UserEntryType { chat, reflect, voice }

/// Modality of the entry
enum UserEntryModality { chat, reflect, voice }

class EmotionalSignals {
  final double? intensity;
  final List<String>? signals;

  const EmotionalSignals({this.intensity, this.signals});

  Map<String, dynamic> toJson() => {
        if (intensity != null) 'intensity': intensity,
        if (signals != null) 'signals': signals,
      };

  factory EmotionalSignals.fromJson(Map<String, dynamic> json) {
    return EmotionalSignals(
      intensity: (json['intensity'] as num?)?.toDouble(),
      signals: json['signals'] != null ? List<String>.from(json['signals'] as List) : null,
    );
  }
}

class UserEntry {
  final String id;
  final DateTime timestamp;
  final UserEntryType type;
  final String content;
  final UserEntryModality modality;
  final EmotionalSignals? emotionalSignals;
  final List<String>? extractedKeywords;
  final List<String>? thematicTags;
  /// ALWAYS 'user' - no synthetic entries allowed
  final String authoredBy;

  const UserEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.content,
    required this.modality,
    this.emotionalSignals,
    this.extractedKeywords,
    this.thematicTags,
    this.authoredBy = 'user',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'content': content,
        'modality': modality.name,
        if (emotionalSignals != null) 'emotional_signals': emotionalSignals!.toJson(),
        if (extractedKeywords != null) 'extracted_keywords': extractedKeywords,
        if (thematicTags != null) 'thematic_tags': thematicTags,
        'authored_by': authoredBy,
      };

  factory UserEntry.fromJson(Map<String, dynamic> json) {
    return UserEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: UserEntryType.values.byName(json['type'] as String? ?? 'reflect'),
      content: json['content'] as String,
      modality: UserEntryModality.values.byName(json['modality'] as String? ?? 'reflect'),
      emotionalSignals: json['emotional_signals'] != null
          ? EmotionalSignals.fromJson(json['emotional_signals'] as Map<String, dynamic>)
          : null,
      extractedKeywords: json['extracted_keywords'] != null
          ? List<String>.from(json['extracted_keywords'] as List)
          : null,
      thematicTags: json['thematic_tags'] != null
          ? List<String>.from(json['thematic_tags'] as List)
          : null,
      authoredBy: json['authored_by'] as String? ?? 'user',
    );
  }
}

/// Source of an annotation (always from LUMARA learning)
enum AnnotationSource { lumara_gap_fill, lumara_inference, lumara_pattern }

class UserAnnotationProvenance {
  final String? gapFillEventId;
  final String? inferenceId;
  /// Must be true - explicit user approval required
  final bool userApproved;
  final DateTime approvedAt;

  const UserAnnotationProvenance({
    this.gapFillEventId,
    this.inferenceId,
    required this.userApproved,
    required this.approvedAt,
  });

  Map<String, dynamic> toJson() => {
        if (gapFillEventId != null) 'gap_fill_event_id': gapFillEventId,
        if (inferenceId != null) 'inference_id': inferenceId,
        'user_approved': userApproved,
        'approved_at': approvedAt.toIso8601String(),
      };

  factory UserAnnotationProvenance.fromJson(Map<String, dynamic> json) {
    return UserAnnotationProvenance(
      gapFillEventId: json['gap_fill_event_id'] as String?,
      inferenceId: json['inference_id'] as String?,
      userApproved: json['user_approved'] as bool? ?? false,
      approvedAt: DateTime.parse(json['approved_at'] as String),
    );
  }
}

class UserAnnotation {
  final String id;
  final DateTime timestamp;
  final String content;
  final AnnotationSource source;
  final UserAnnotationProvenance provenance;
  final bool editable;

  const UserAnnotation({
    required this.id,
    required this.timestamp,
    required this.content,
    required this.source,
    required this.provenance,
    this.editable = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'type': 'annotation',
        'content': content,
        'source': source.name,
        'provenance': provenance.toJson(),
        'editable': editable,
      };

  factory UserAnnotation.fromJson(Map<String, dynamic> json) {
    return UserAnnotation(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      content: json['content'] as String,
      source: AnnotationSource.values.byName(json['source'] as String? ?? 'lumara_gap_fill'),
      provenance: UserAnnotationProvenance.fromJson(json['provenance'] as Map<String, dynamic>),
      editable: json['editable'] as bool? ?? true,
    );
  }
}

/// Result of querying user's CHRONICLE Layer 0 + promoted annotations (from LUMARA CHRONICLE).
/// Used by agentic loop, gap analyzer, and intelligence summary.
class UserChronicleLayer0Result {
  final List<UserEntry> entries;
  final List<UserAnnotation> annotations;

  UserChronicleLayer0Result({
    required this.entries,
    required this.annotations,
  });
}

// ============================================================================
// LUMARA'S CHRONICLE - LEARNING SPACE
// ============================================================================

enum GapType {
  context_gap,
  causal_gap,
  temporal_gap,
  relationship_gap,
  historical_gap,
  motivation_gap,
}

enum GapSeverity { high, medium, low }

enum GapFillStrategy { search, clarify, infer }

class Gap {
  final String id;
  final GapType type;
  final GapSeverity severity;
  final String description;
  final String topic;
  final String requiredFor;
  final GapFillStrategy fillStrategy;
  final int priority;
  final DateTime identifiedAt;
  final String status; // 'open' | 'filled' | 'abandoned'

  const Gap({
    required this.id,
    required this.type,
    required this.severity,
    required this.description,
    required this.topic,
    required this.requiredFor,
    required this.fillStrategy,
    required this.priority,
    required this.identifiedAt,
    this.status = 'open',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'severity': severity.name,
        'description': description,
        'topic': topic,
        'required_for': requiredFor,
        'fill_strategy': fillStrategy.name,
        'priority': priority,
        'identified_at': identifiedAt.toIso8601String(),
        'status': status,
      };

  factory Gap.fromJson(Map<String, dynamic> json) {
    return Gap(
      id: json['id'] as String,
      type: GapType.values.byName(json['type'] as String? ?? 'context_gap'),
      severity: GapSeverity.values.byName(json['severity'] as String? ?? 'medium'),
      description: json['description'] as String,
      topic: json['topic'] as String,
      requiredFor: json['required_for'] as String,
      fillStrategy: GapFillStrategy.values.byName(json['fill_strategy'] as String? ?? 'clarify'),
      priority: json['priority'] as int? ?? 5,
      identifiedAt: DateTime.parse(json['identified_at'] as String),
      status: json['status'] as String? ?? 'open',
    );
  }

  Gap copyWith({String? status}) => Gap(
        id: id,
        type: type,
        severity: severity,
        description: description,
        topic: topic,
        requiredFor: requiredFor,
        fillStrategy: fillStrategy,
        priority: priority,
        identifiedAt: identifiedAt,
        status: status ?? this.status,
      );
}

class ProvenanceSourceEntry {
  final String entryId;
  final String excerpt;
  final double weight;

  const ProvenanceSourceEntry({
    required this.entryId,
    required this.excerpt,
    required this.weight,
  });

  Map<String, dynamic> toJson() => {
        'entry_id': entryId,
        'excerpt': excerpt,
        'weight': weight,
      };

  factory ProvenanceSourceEntry.fromJson(Map<String, dynamic> json) {
    return ProvenanceSourceEntry(
      entryId: json['entry_id'] as String,
      excerpt: json['excerpt'] as String,
      weight: (json['weight'] as num).toDouble(),
    );
  }
}

class Provenance {
  final List<ProvenanceSourceEntry> sourceEntries;
  final List<String>? gapFillEvents;
  final DateTime generatedAt;
  final DateTime lastUpdated;
  final String algorithm;

  const Provenance({
    required this.sourceEntries,
    this.gapFillEvents,
    required this.generatedAt,
    required this.lastUpdated,
    required this.algorithm,
  });

  Map<String, dynamic> toJson() => {
        'source_entries': sourceEntries.map((e) => e.toJson()).toList(),
        if (gapFillEvents != null) 'gap_fill_events': gapFillEvents,
        'generated_at': generatedAt.toIso8601String(),
        'last_updated': lastUpdated.toIso8601String(),
        'algorithm': algorithm,
      };

  factory Provenance.fromJson(Map<String, dynamic> json) {
    return Provenance(
      sourceEntries: (json['source_entries'] as List?)
              ?.map((e) => ProvenanceSourceEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      gapFillEvents: json['gap_fill_events'] != null
          ? List<String>.from(json['gap_fill_events'] as List)
          : null,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      lastUpdated: DateTime.parse(json['last_updated'] as String),
      algorithm: json['algorithm'] as String? ?? 'unknown',
    );
  }
}

enum InferenceStatus { active, corrected, refined, rejected }

class CausalChain {
  final String id;
  final String trigger;
  final String response;
  final String? resolution;
  final double confidence;
  final List<String> evidence;
  final String frequency;
  final DateTime lastObserved;
  final Provenance provenance;
  final InferenceStatus status;
  final bool? userValidated;

  const CausalChain({
    required this.id,
    required this.trigger,
    required this.response,
    this.resolution,
    required this.confidence,
    required this.evidence,
    required this.frequency,
    required this.lastObserved,
    required this.provenance,
    this.status = InferenceStatus.active,
    this.userValidated,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'trigger': trigger,
        'response': response,
        if (resolution != null) 'resolution': resolution,
        'confidence': confidence,
        'evidence': evidence,
        'frequency': frequency,
        'last_observed': lastObserved.toIso8601String(),
        'provenance': provenance.toJson(),
        'status': status.name,
        if (userValidated != null) 'user_validated': userValidated,
      };

  factory CausalChain.fromJson(Map<String, dynamic> json) {
    return CausalChain(
      id: json['id'] as String,
      trigger: json['trigger'] as String,
      response: json['response'] as String,
      resolution: json['resolution'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
      evidence: List<String>.from(json['evidence'] as List? ?? []),
      frequency: json['frequency'] as String? ?? '',
      lastObserved: DateTime.parse(json['last_observed'] as String),
      provenance: Provenance.fromJson(json['provenance'] as Map<String, dynamic>),
      status: InferenceStatus.values.byName(json['status'] as String? ?? 'active'),
      userValidated: json['user_validated'] as bool?,
    );
  }
}

class Pattern {
  final String id;
  final String description;
  final String category; // behavioral | emotional | cognitive | social
  final String recurrence;
  final double confidence;
  final List<String> evidence;
  final Provenance provenance;
  final List<String> relatedPatterns;
  final InferenceStatus status;

  const Pattern({
    required this.id,
    required this.description,
    required this.category,
    required this.recurrence,
    required this.confidence,
    required this.evidence,
    required this.provenance,
    this.relatedPatterns = const [],
    this.status = InferenceStatus.active,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'category': category,
        'recurrence': recurrence,
        'confidence': confidence,
        'evidence': evidence,
        'provenance': provenance.toJson(),
        'related_patterns': relatedPatterns,
        'status': status.name,
      };

  factory Pattern.fromJson(Map<String, dynamic> json) {
    return Pattern(
      id: json['id'] as String,
      description: json['description'] as String,
      category: json['category'] as String? ?? 'behavioral',
      recurrence: json['recurrence'] as String? ?? '',
      confidence: (json['confidence'] as num).toDouble(),
      evidence: List<String>.from(json['evidence'] as List? ?? []),
      provenance: Provenance.fromJson(json['provenance'] as Map<String, dynamic>),
      relatedPatterns: List<String>.from(json['related_patterns'] as List? ?? []),
      status: InferenceStatus.values.byName(json['status'] as String? ?? 'active'),
    );
  }
}

class RelationshipModel {
  final String entityId;
  final String entityName;
  final String role;
  final String interactionPattern;
  final double confidence;
  final List<String> evidence;
  final Provenance provenance;
  final DateTime firstMentioned;
  final DateTime lastMentioned;
  final InferenceStatus status;

  const RelationshipModel({
    required this.entityId,
    required this.entityName,
    required this.role,
    required this.interactionPattern,
    required this.confidence,
    required this.evidence,
    required this.provenance,
    required this.firstMentioned,
    required this.lastMentioned,
    this.status = InferenceStatus.active,
  });

  Map<String, dynamic> toJson() => {
        'entity_id': entityId,
        'entity_name': entityName,
        'role': role,
        'interaction_pattern': interactionPattern,
        'confidence': confidence,
        'evidence': evidence,
        'provenance': provenance.toJson(),
        'first_mentioned': firstMentioned.toIso8601String(),
        'last_mentioned': lastMentioned.toIso8601String(),
        'status': status.name,
      };

  factory RelationshipModel.fromJson(Map<String, dynamic> json) {
    return RelationshipModel(
      entityId: json['entity_id'] as String,
      entityName: json['entity_name'] as String,
      role: json['role'] as String,
      interactionPattern: json['interaction_pattern'] as String? ?? '',
      confidence: (json['confidence'] as num).toDouble(),
      evidence: List<String>.from(json['evidence'] as List? ?? []),
      provenance: Provenance.fromJson(json['provenance'] as Map<String, dynamic>),
      firstMentioned: DateTime.parse(json['first_mentioned'] as String),
      lastMentioned: DateTime.parse(json['last_mentioned'] as String),
      status: InferenceStatus.values.byName(json['status'] as String? ?? 'active'),
    );
  }
}

class BiographicalSignal {
  final List<String> concepts;
  final CausalChainSignal? causalChain;
  final PatternSignal? pattern;
  final RelationshipSignal? relationship;
  final ValueSignal? value;

  const BiographicalSignal({
    required this.concepts,
    this.causalChain,
    this.pattern,
    this.relationship,
    this.value,
  });

  Map<String, dynamic> toJson() => {
        'concepts': concepts,
        if (causalChain != null) 'causal_chain': causalChain!.toJson(),
        if (pattern != null) 'pattern': pattern!.toJson(),
        if (relationship != null) 'relationship': relationship!.toJson(),
        if (value != null) 'value': value!.toJson(),
      };

  factory BiographicalSignal.fromJson(Map<String, dynamic> json) {
    return BiographicalSignal(
      concepts: List<String>.from(json['concepts'] as List? ?? []),
      causalChain: json['causal_chain'] != null
          ? CausalChainSignal.fromJson(json['causal_chain'] as Map<String, dynamic>)
          : null,
      pattern: json['pattern'] != null
          ? PatternSignal.fromJson(json['pattern'] as Map<String, dynamic>)
          : null,
      relationship: json['relationship'] != null
          ? RelationshipSignal.fromJson(json['relationship'] as Map<String, dynamic>)
          : null,
      value: json['value'] != null
          ? ValueSignal.fromJson(json['value'] as Map<String, dynamic>)
          : null,
    );
  }
}

class CausalChainSignal {
  final String trigger;
  final String response;
  final String? resolution;

  const CausalChainSignal({
    required this.trigger,
    required this.response,
    this.resolution,
  });

  Map<String, dynamic> toJson() => {
        'trigger': trigger,
        'response': response,
        if (resolution != null) 'resolution': resolution,
      };

  factory CausalChainSignal.fromJson(Map<String, dynamic> json) {
    return CausalChainSignal(
      trigger: json['trigger'] as String,
      response: json['response'] as String,
      resolution: json['resolution'] as String?,
    );
  }
}

class PatternSignal {
  final String description;
  final String category;

  const PatternSignal({required this.description, required this.category});

  Map<String, dynamic> toJson() => {'description': description, 'category': category};

  factory PatternSignal.fromJson(Map<String, dynamic> json) {
    return PatternSignal(
      description: json['description'] as String,
      category: json['category'] as String? ?? 'behavioral',
    );
  }
}

class RelationshipSignal {
  final String entity;
  final String role;

  const RelationshipSignal({required this.entity, required this.role});

  Map<String, dynamic> toJson() => {'entity': entity, 'role': role};

  factory RelationshipSignal.fromJson(Map<String, dynamic> json) {
    return RelationshipSignal(
      entity: json['entity'] as String,
      role: json['role'] as String,
    );
  }
}

class ValueSignal {
  final String value;
  final String importance; // core | significant | emerging

  const ValueSignal({required this.value, required this.importance});

  Map<String, dynamic> toJson() => {'value': value, 'importance': importance};

  factory ValueSignal.fromJson(Map<String, dynamic> json) {
    return ValueSignal(
      value: json['value'] as String,
      importance: json['importance'] as String? ?? 'significant',
    );
  }
}

enum GapFillEventType { clarification, search_discovery, inference }

class GapFillEventTrigger {
  final String originalQuery;
  final Gap identifiedGap;

  const GapFillEventTrigger({required this.originalQuery, required this.identifiedGap});

  Map<String, dynamic> toJson() => {
        'original_query': originalQuery,
        'identified_gap': identifiedGap.toJson(),
      };

  factory GapFillEventTrigger.fromJson(Map<String, dynamic> json) {
    return GapFillEventTrigger(
      originalQuery: json['original_query'] as String,
      identifiedGap: Gap.fromJson(json['identified_gap'] as Map<String, dynamic>),
    );
  }
}

class GapFillEventProcess {
  final String? clarifyingQuestion;
  final String? userResponse;
  final List<Map<String, dynamic>>? searchResults;
  final Map<String, dynamic>? inferenceGenerated;

  const GapFillEventProcess({
    this.clarifyingQuestion,
    this.userResponse,
    this.searchResults,
    this.inferenceGenerated,
  });

  Map<String, dynamic> toJson() => {
        if (clarifyingQuestion != null) 'clarifying_question': clarifyingQuestion,
        if (userResponse != null) 'user_response': userResponse,
        if (searchResults != null) 'search_results': searchResults,
        if (inferenceGenerated != null) 'inference_generated': inferenceGenerated,
      };

  factory GapFillEventProcess.fromJson(Map<String, dynamic> json) {
    return GapFillEventProcess(
      clarifyingQuestion: json['clarifying_question'] as String?,
      userResponse: json['user_response'] as String?,
      searchResults: json['search_results'] != null
          ? List<Map<String, dynamic>>.from(
              (json['search_results'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
          : null,
      inferenceGenerated: json['inference_generated'] != null
          ? Map<String, dynamic>.from(json['inference_generated'] as Map)
          : null,
    );
  }
}

class GapFillEventUpdates {
  final List<String> newInferences;
  final List<String> updatedInferences;
  final List<String> gapsFilled;

  const GapFillEventUpdates({
    this.newInferences = const [],
    this.updatedInferences = const [],
    this.gapsFilled = const [],
  });

  Map<String, dynamic> toJson() => {
        'new_inferences': newInferences,
        'updated_inferences': updatedInferences,
        'gaps_filled': gapsFilled,
      };

  factory GapFillEventUpdates.fromJson(Map<String, dynamic> json) {
    return GapFillEventUpdates(
      newInferences: List<String>.from(json['new_inferences'] as List? ?? []),
      updatedInferences: List<String>.from(json['updated_inferences'] as List? ?? []),
      gapsFilled: List<String>.from(json['gaps_filled'] as List? ?? []),
    );
  }
}

class PromotedToAnnotation {
  final String annotationId;
  final DateTime promotedAt;

  const PromotedToAnnotation({required this.annotationId, required this.promotedAt});

  Map<String, dynamic> toJson() => {
        'annotation_id': annotationId,
        'promoted_at': promotedAt.toIso8601String(),
      };

  factory PromotedToAnnotation.fromJson(Map<String, dynamic> json) {
    return PromotedToAnnotation(
      annotationId: json['annotation_id'] as String,
      promotedAt: DateTime.parse(json['promoted_at'] as String),
    );
  }
}

class GapFillEvent {
  final String id;
  final GapFillEventType type;
  final GapFillEventTrigger trigger;
  final GapFillEventProcess process;
  final BiographicalSignal extractedSignal;
  final GapFillEventUpdates updates;
  final DateTime recordedAt;
  final bool promotableToAnnotation;
  final PromotedToAnnotation? promotedToAnnotation;

  const GapFillEvent({
    required this.id,
    required this.type,
    required this.trigger,
    required this.process,
    required this.extractedSignal,
    required this.updates,
    required this.recordedAt,
    required this.promotableToAnnotation,
    this.promotedToAnnotation,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'trigger': trigger.toJson(),
        'process': process.toJson(),
        'extracted_signal': extractedSignal.toJson(),
        'updates': updates.toJson(),
        'recorded_at': recordedAt.toIso8601String(),
        'promotable_to_annotation': promotableToAnnotation,
        if (promotedToAnnotation != null) 'promoted_to_annotation': promotedToAnnotation!.toJson(),
      };

  factory GapFillEvent.fromJson(Map<String, dynamic> json) {
    return GapFillEvent(
      id: json['id'] as String,
      type: GapFillEventType.values.byName(json['type'] as String? ?? 'clarification'),
      trigger: GapFillEventTrigger.fromJson(json['trigger'] as Map<String, dynamic>),
      process: GapFillEventProcess.fromJson(json['process'] as Map<String, dynamic>),
      extractedSignal: BiographicalSignal.fromJson(json['extracted_signal'] as Map<String, dynamic>),
      updates: GapFillEventUpdates.fromJson(json['updates'] as Map<String, dynamic>),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      promotableToAnnotation: json['promotable_to_annotation'] as bool? ?? false,
      promotedToAnnotation: json['promoted_to_annotation'] != null
          ? PromotedToAnnotation.fromJson(json['promoted_to_annotation'] as Map<String, dynamic>)
          : null,
    );
  }

  GapFillEvent copyWith({
    GapFillEventUpdates? updates,
    PromotedToAnnotation? promotedToAnnotation,
  }) =>
      GapFillEvent(
        id: id,
        type: type,
        trigger: trigger,
        process: process,
        extractedSignal: extractedSignal,
        updates: updates ?? this.updates,
        recordedAt: recordedAt,
        promotableToAnnotation: promotableToAnnotation,
        promotedToAnnotation: promotedToAnnotation ?? this.promotedToAnnotation,
      );
}

/// Record that the agentic loop ran (learning was triggered). Used for transparency in the UI.
class LearningTriggerRecord {
  final DateTime at;
  final String modality; // 'reflect' | 'chat'
  final String? sourceSummary;

  const LearningTriggerRecord({
    required this.at,
    required this.modality,
    this.sourceSummary,
  });

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'modality': modality,
        if (sourceSummary != null) 'source': sourceSummary,
      };

  factory LearningTriggerRecord.fromJson(Map<String, dynamic> json) {
    return LearningTriggerRecord(
      at: DateTime.parse(json['at'] as String),
      modality: json['modality'] as String,
      sourceSummary: json['source'] as String?,
    );
  }
}
