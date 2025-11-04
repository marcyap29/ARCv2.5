// lib/mira/memory/enhanced_memory_schema.dart
// Enhanced MIRA memory schema for EPI narrative infrastructure
// Implements domain scoping, attribution, lifecycle management, and ethical guardrails

import '../core/schema.dart';
import '../core/ids.dart';

/// Enhanced node types for EPI memory system
enum EnhancedNodeType {
  /// Original MIRA types
  entry,
  keyword,
  emotion,
  phase,
  period,
  topic,
  concept,
  episode,
  summary,
  evidence,

  /// New EPI memory types
  /// Conversation memory nodes
  conversation,
  message,
  thread,

  /// Attribution and provenance
  source,
  trace,
  citation,

  /// Memory lifecycle
  snapshot,
  conflict,
  resolution,

  /// Multi-agent federation
  agent,
  federation,
  namespace,
}

/// Enhanced edge types for memory relationships
enum EnhancedEdgeType {
  /// Original MIRA types
  mentions,
  cooccurs,
  expresses,
  taggedAs,
  inPeriod,
  belongsTo,
  evidenceFor,
  partOf,
  precedes,

  /// New EPI memory relationships
  /// Attribution and tracing
  cites,
  supports,
  contradicts,
  derives,
  traces,

  /// Lifecycle and decay
  decays,
  reinforces,
  merges,
  splits,
  prunes,

  /// Domain and scoping
  scopedTo,
  crossDomain,
  isolatedFrom,

  /// Federation
  federates,
  namespaces,
  inherits,
}

/// Memory domain classifications for scoped access
enum MemoryDomain {
  personal,
  work,
  health,
  creative,
  relationships,
  finance,
  learning,
  spiritual,
  meta, // for system/app-level memories
}

/// Privacy classification levels
enum PrivacyLevel {
  public,     // Shareable with agents/export
  personal,   // User-only, but can be processed
  private,    // User-only, minimal processing
  sensitive,  // Encrypted, limited access
  confidential, // Maximum protection
}

/// Enhanced MIRA node with EPI narrative infrastructure features
class EnhancedMiraNode extends MiraNode {
  /// Memory domain classification
  final MemoryDomain domain;

  /// Privacy level for access control
  final PrivacyLevel privacy;

  /// ATLAS phase context when created
  final String? phaseContext;

  /// AURORA rhythm alignment score
  final double? rhythmScore;

  /// Attribution trace for explainability
  final List<AttributionTrace> attributions;

  /// SAGE narrative structure (Situation, Action, Growth, Essence)
  final SAGEStructure? sage;

  /// Lifecycle metadata
  final LifecycleMetadata lifecycle;

  /// Provenance information
  final ProvenanceData provenance;

  /// PII detection flags
  final PIIFlags piiFlags;

  const EnhancedMiraNode({
    required String id,
    required NodeType type,
    required int schemaVersion,
    required Map<String, dynamic> data,
    required DateTime createdAt,
    required DateTime updatedAt,
    required this.domain,
    required this.privacy,
    this.phaseContext,
    this.rhythmScore,
    this.attributions = const [],
    this.sage,
    required this.lifecycle,
    required this.provenance,
    required this.piiFlags,
  }) : super(
    id: id,
    type: type,
    schemaVersion: schemaVersion,
    data: data,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  /// Get content from data map (backward compatibility)
  String get content => data['content'] ?? data['text'] ?? '';

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'domain': domain.name,
    'privacy': privacy.name,
    'phase_context': phaseContext,
    'rhythm_score': rhythmScore,
    'attributions': attributions.map((a) => a.toJson()).toList(),
    'sage': sage?.toJson(),
    'lifecycle': lifecycle.toJson(),
    'provenance': provenance.toJson(),
    'pii_flags': piiFlags.toJson(),
    'schema_version': 'enhanced_node.v1',
  };

  factory EnhancedMiraNode.fromJson(Map<String, dynamic> json) {
    return EnhancedMiraNode(
      id: json['id'],
      type: NodeType.values[json['type']],
      schemaVersion: json['schemaVersion'],
      data: Map<String, dynamic>.from(json['data']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      domain: MemoryDomain.values.firstWhere((d) => d.name == json['domain']),
      privacy: PrivacyLevel.values.firstWhere((p) => p.name == json['privacy']),
      phaseContext: json['phase_context'],
      rhythmScore: json['rhythm_score']?.toDouble(),
      attributions: (json['attributions'] as List<dynamic>? ?? [])
          .map((a) => AttributionTrace.fromJson(a))
          .toList(),
      sage: json['sage'] != null ? SAGEStructure.fromJson(json['sage']) : null,
      lifecycle: LifecycleMetadata.fromJson(json['lifecycle']),
      provenance: ProvenanceData.fromJson(json['provenance']),
      piiFlags: PIIFlags.fromJson(json['pii_flags']),
    );
  }
}

/// Attribution trace for explainable memory usage
class AttributionTrace {
  final String nodeRef;
  final String relation;
  final double confidence;
  final DateTime timestamp;
  final String? reasoning;

  const AttributionTrace({
    required this.nodeRef,
    required this.relation,
    required this.confidence,
    required this.timestamp,
    this.reasoning,
  });

  Map<String, dynamic> toJson() => {
    'node_ref': nodeRef,
    'relation': relation,
    'confidence': confidence,
    'timestamp': timestamp.toIso8601String(),
    'reasoning': reasoning,
  };

  factory AttributionTrace.fromJson(Map<String, dynamic> json) {
    return AttributionTrace(
      nodeRef: json['node_ref'],
      relation: json['relation'],
      confidence: json['confidence'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      reasoning: json['reasoning'],
    );
  }
}

/// SAGE narrative structure (Situation, Action, Growth, Essence)
class SAGEStructure {
  final String situation;  // Context and circumstances
  final String action;     // What happened or was done
  final String growth;     // Learning or development
  final String essence;    // Core meaning or significance

  const SAGEStructure({
    required this.situation,
    required this.action,
    required this.growth,
    required this.essence,
  });

  Map<String, dynamic> toJson() => {
    'situation': situation,
    'action': action,
    'growth': growth,
    'essence': essence,
  };

  factory SAGEStructure.fromJson(Map<String, dynamic> json) {
    return SAGEStructure(
      situation: json['situation'],
      action: json['action'],
      growth: json['growth'],
      essence: json['essence'],
    );
  }
}

/// Lifecycle management metadata
class LifecycleMetadata {
  final DateTime? lastAccessed;
  final int accessCount;
  final double reinforcementScore;
  final DateTime? scheduledDecay;
  final bool isArchived;
  final List<String> decayTriggers;
  final Map<String, dynamic> veilHooks;

  const LifecycleMetadata({
    this.lastAccessed,
    this.accessCount = 0,
    this.reinforcementScore = 1.0,
    this.scheduledDecay,
    this.isArchived = false,
    this.decayTriggers = const [],
    this.veilHooks = const {},
  });

  Map<String, dynamic> toJson() => {
    'last_accessed': lastAccessed?.toIso8601String(),
    'access_count': accessCount,
    'reinforcement_score': reinforcementScore,
    'scheduled_decay': scheduledDecay?.toIso8601String(),
    'is_archived': isArchived,
    'decay_triggers': decayTriggers,
    'veil_hooks': veilHooks,
  };

  factory LifecycleMetadata.fromJson(Map<String, dynamic> json) {
    return LifecycleMetadata(
      lastAccessed: json['last_accessed'] != null
          ? DateTime.parse(json['last_accessed']) : null,
      accessCount: json['access_count'] ?? 0,
      reinforcementScore: json['reinforcement_score']?.toDouble() ?? 1.0,
      scheduledDecay: json['scheduled_decay'] != null
          ? DateTime.parse(json['scheduled_decay']) : null,
      isArchived: json['is_archived'] ?? false,
      decayTriggers: List<String>.from(json['decay_triggers'] ?? []),
      veilHooks: Map<String, dynamic>.from(json['veil_hooks'] ?? {}),
    );
  }

  LifecycleMetadata copyWith({
    DateTime? lastAccessed,
    int? accessCount,
    double? reinforcementScore,
    DateTime? scheduledDecay,
    bool? isArchived,
    List<String>? decayTriggers,
    Map<String, dynamic>? veilHooks,
  }) {
    return LifecycleMetadata(
      lastAccessed: lastAccessed ?? this.lastAccessed,
      accessCount: accessCount ?? this.accessCount,
      reinforcementScore: reinforcementScore ?? this.reinforcementScore,
      scheduledDecay: scheduledDecay ?? this.scheduledDecay,
      isArchived: isArchived ?? this.isArchived,
      decayTriggers: decayTriggers ?? this.decayTriggers,
      veilHooks: veilHooks ?? this.veilHooks,
    );
  }
}

/// Provenance tracking for sovereignty and auditability
class ProvenanceData {
  final String source;      // Which EPI module created this
  final String device;      // Device identifier
  final String version;     // App/module version
  final String? userId;     // User identifier
  final String? sessionId;  // Session context
  final Map<String, dynamic> metadata;

  const ProvenanceData({
    required this.source,
    required this.device,
    required this.version,
    this.userId,
    this.sessionId,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'source': source,
    'device': device,
    'version': version,
    'user_id': userId,
    'session_id': sessionId,
    'metadata': metadata,
  };

  factory ProvenanceData.fromJson(Map<String, dynamic> json) {
    return ProvenanceData(
      source: json['source'],
      device: json['device'],
      version: json['version'],
      userId: json['user_id'],
      sessionId: json['session_id'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}

/// PII detection and privacy flags
class PIIFlags {
  final bool containsPII;
  final bool facesDetected;
  final bool locationData;
  final bool sensitiveContent;
  final List<String> detectedTypes;
  final bool requiresRedaction;

  const PIIFlags({
    this.containsPII = false,
    this.facesDetected = false,
    this.locationData = false,
    this.sensitiveContent = false,
    this.detectedTypes = const [],
    this.requiresRedaction = false,
  });

  Map<String, dynamic> toJson() => {
    'contains_pii': containsPII,
    'faces_detected': facesDetected,
    'location_data': locationData,
    'sensitive_content': sensitiveContent,
    'detected_types': detectedTypes,
    'requires_redaction': requiresRedaction,
  };

  factory PIIFlags.fromJson(Map<String, dynamic> json) {
    return PIIFlags(
      containsPII: json['contains_pii'] ?? false,
      facesDetected: json['faces_detected'] ?? false,
      locationData: json['location_data'] ?? false,
      sensitiveContent: json['sensitive_content'] ?? false,
      detectedTypes: List<String>.from(json['detected_types'] ?? []),
      requiresRedaction: json['requires_redaction'] ?? false,
    );
  }
}

/// Enhanced edge with lifecycle and attribution support
class EnhancedMiraEdge {
  final String id;
  final String source;
  final String target;
  final EnhancedEdgeType relation;
  final double weight;
  final DateTime timestamp;
  final LifecycleMetadata lifecycle;
  final ProvenanceData provenance;
  final Map<String, dynamic> metadata;

  const EnhancedMiraEdge({
    required this.id,
    required this.source,
    required this.target,
    required this.relation,
    this.weight = 1.0,
    required this.timestamp,
    required this.lifecycle,
    required this.provenance,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'target': target,
    'relation': relation.name,
    'weight': weight,
    'timestamp': timestamp.toIso8601String(),
    'lifecycle': lifecycle.toJson(),
    'provenance': provenance.toJson(),
    'metadata': metadata,
    'schema_version': 'enhanced_edge.v1',
  };

  factory EnhancedMiraEdge.fromJson(Map<String, dynamic> json) {
    return EnhancedMiraEdge(
      id: json['id'],
      source: json['source'],
      target: json['target'],
      relation: EnhancedEdgeType.values.firstWhere((r) => r.name == json['relation']),
      weight: json['weight']?.toDouble() ?? 1.0,
      timestamp: DateTime.parse(json['timestamp']),
      lifecycle: LifecycleMetadata.fromJson(json['lifecycle']),
      provenance: ProvenanceData.fromJson(json['provenance']),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}

/// Memory conflict representation for resolution tracking
class MemoryConflict {
  final String id;
  final String nodeA;
  final String nodeB;
  final String conflictType;
  final String description;
  final double severity;
  final DateTime detected;
  final DateTime? resolved;
  final String? resolution;
  final Map<String, dynamic> context;

  const MemoryConflict({
    required this.id,
    required this.nodeA,
    required this.nodeB,
    required this.conflictType,
    required this.description,
    required this.severity,
    required this.detected,
    this.resolved,
    this.resolution,
    this.context = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'node_a': nodeA,
    'node_b': nodeB,
    'conflict_type': conflictType,
    'description': description,
    'severity': severity,
    'detected': detected.toIso8601String(),
    'resolved': resolved?.toIso8601String(),
    'resolution': resolution,
    'context': context,
  };

  factory MemoryConflict.fromJson(Map<String, dynamic> json) {
    return MemoryConflict(
      id: json['id'],
      nodeA: json['node_a'],
      nodeB: json['node_b'],
      conflictType: json['conflict_type'],
      description: json['description'],
      severity: json['severity'].toDouble(),
      detected: DateTime.parse(json['detected']),
      resolved: json['resolved'] != null ? DateTime.parse(json['resolved']) : null,
      resolution: json['resolution'],
      context: Map<String, dynamic>.from(json['context'] ?? {}),
    );
  }
}

/// Response trace for explainable AI responses
class ResponseTrace {
  final String responseId;
  final List<AttributionTrace> traces;
  final DateTime timestamp;
  final String model;
  final Map<String, dynamic> context;

  const ResponseTrace({
    required this.responseId,
    required this.traces,
    required this.timestamp,
    required this.model,
    this.context = const {},
  });

  Map<String, dynamic> toJson() => {
    'response_id': responseId,
    'traces': traces.map((t) => t.toJson()).toList(),
    'timestamp': timestamp.toIso8601String(),
    'model': model,
    'context': context,
  };

  factory ResponseTrace.fromJson(Map<String, dynamic> json) {
    return ResponseTrace(
      responseId: json['response_id'],
      traces: (json['traces'] as List<dynamic>)
          .map((t) => AttributionTrace.fromJson(t))
          .toList(),
      timestamp: DateTime.parse(json['timestamp']),
      model: json['model'],
      context: Map<String, dynamic>.from(json['context'] ?? {}),
    );
  }
}

/// Factory methods for creating common enhanced nodes
class EnhancedMiraNodeFactory {
  /// Create a journal entry node with full EPI metadata
  static EnhancedMiraNode createJournalEntry({
    required String content,
    required MemoryDomain domain,
    required String phaseContext,
    SAGEStructure? sage,
    List<String> keywords = const [],
    Map<String, double> emotions = const {},
    PrivacyLevel privacy = PrivacyLevel.personal,
    String source = 'ARC',
    String device = 'unknown',
    String version = '1.0.0',
  }) {
    final now = DateTime.now().toUtc();
    final id = generateEntryId(now);

    return EnhancedMiraNode(
      id: id,
      type: NodeType.entry,
      schemaVersion: 1,
      data: {
        'content': content,
        'keywords': keywords,
        'emotions': emotions,
        'word_count': content.split(' ').length,
      },
      createdAt: now,
      updatedAt: now,
      domain: domain,
      privacy: privacy,
      phaseContext: phaseContext,
      sage: sage,
      lifecycle: LifecycleMetadata(
        accessCount: 0,
        reinforcementScore: 1.0,
      ),
      provenance: ProvenanceData(
        source: source,
        device: device,
        version: version,
      ),
      piiFlags: PIIFlags(), // TODO: Implement PII detection
    );
  }

  /// Create a conversation message node
  static EnhancedMiraNode createConversationMessage({
    required String content,
    required String role,
    required String sessionId,
    MemoryDomain domain = MemoryDomain.personal,
    PrivacyLevel privacy = PrivacyLevel.personal,
    String source = 'LUMARA',
    String device = 'unknown',
    String version = '1.0.0',
  }) {
    final now = DateTime.now().toUtc();
    final id = generateMessageId(now, role);

    return EnhancedMiraNode(
      id: id,
      type: NodeType.entry, // Using entry type for now, could add message type
      schemaVersion: 1,
      data: {
        'content': content,
        'role': role,
        'session_id': sessionId,
        'word_count': content.split(' ').length,
      },
      createdAt: now,
      updatedAt: now,
      domain: domain,
      privacy: privacy,
      lifecycle: LifecycleMetadata(
        accessCount: 0,
        reinforcementScore: 1.0,
      ),
      provenance: ProvenanceData(
        source: source,
        device: device,
        version: version,
        sessionId: sessionId,
      ),
      piiFlags: PIIFlags(), // TODO: Implement PII detection
    );
  }
}