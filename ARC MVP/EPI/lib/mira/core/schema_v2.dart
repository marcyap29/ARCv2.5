// lib/mira/core/schema_v2.dart
// MIRA Semantic Memory v0.2 Schema
// Implements ULIDs, provenance tracking, and enhanced metadata

import 'package:my_app/lumara/chat/ulid.dart';

/// MIRA v0.2 Version Constants
class MiraVersion {
  static const String MIRA_VERSION = "0.2.0";
  static const String MCP_SCHEMA = "1.1.0";
  static const int SCHEMA_VERSION = 2;
}

/// Provenance tracking for all MIRA objects
class Provenance {
  final String source;        // Where this object originated (ARC, LUMARA, etc.)
  final String agent;         // Which agent created it (user, system, etc.)
  final String operation;     // What operation created it (create, update, merge, etc.)
  final String traceId;       // Distributed tracing ID
  final DateTime timestamp;   // When this provenance was recorded
  final Map<String, dynamic> metadata; // Additional context

  const Provenance({
    required this.source,
    required this.agent,
    required this.operation,
    required this.traceId,
    required this.timestamp,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'source': source,
    'agent': agent,
    'operation': operation,
    'trace_id': traceId,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'metadata': metadata,
  };

  factory Provenance.fromJson(Map<String, dynamic> json) => Provenance(
    source: json['source'] as String,
    agent: json['agent'] as String,
    operation: json['operation'] as String,
    traceId: json['trace_id'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );

  /// Create provenance for a new object
  factory Provenance.create({
    required String source,
    required String operation,
    String? traceId,
    Map<String, dynamic>? metadata,
  }) => Provenance(
    source: source,
    agent: 'system',
    operation: operation,
    traceId: traceId ?? ULID.generate(),
    timestamp: DateTime.now().toUtc(),
    metadata: metadata ?? {},
  );
}

/// Enhanced node with v0.2 features
class MiraNodeV2 {
  final String id;                    // ULID
  final String schemaId;              // Schema identifier
  final NodeType type;                // Node type
  final int schemaVersion;            // Schema version
  final Map<String, dynamic> data;    // Node data
  final DateTime createdAt;
  final DateTime updatedAt;
  final Provenance provenance;        // Creation provenance
  final String? embeddingsVer;        // Embedding model version
  final List<String> embeddingRefs;   // References to embeddings
  final bool isTombstoned;            // Soft delete flag
  final DateTime? deletedAt;          // When tombstoned
  final Map<String, dynamic> metadata; // Additional metadata

  const MiraNodeV2({
    required this.id,
    required this.schemaId,
    required this.type,
    required this.schemaVersion,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
    required this.provenance,
    this.embeddingsVer,
    this.embeddingRefs = const [],
    this.isTombstoned = false,
    this.deletedAt,
    this.metadata = const {},
  });

  /// Create a new node with ULID and provenance
  factory MiraNodeV2.create({
    required NodeType type,
    required Map<String, dynamic> data,
    required String source,
    required String operation,
    String? traceId,
    String? embeddingsVer,
    List<String>? embeddingRefs,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now().toUtc();
    return MiraNodeV2(
      id: ULID.generate(),
      schemaId: 'mira.node@${MiraVersion.MIRA_VERSION}',
      type: type,
      schemaVersion: MiraVersion.SCHEMA_VERSION,
      data: data,
      createdAt: now,
      updatedAt: now,
      provenance: Provenance.create(
        source: source,
        operation: operation,
        traceId: traceId,
      ),
      embeddingsVer: embeddingsVer,
      embeddingRefs: embeddingRefs ?? [],
      metadata: metadata ?? {},
    );
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'schema_id': schemaId,
    'type': type.index,
    'schema_version': schemaVersion,
    'data': data,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'provenance': provenance.toJson(),
    if (embeddingsVer != null) 'embeddings_ver': embeddingsVer,
    'embedding_refs': embeddingRefs,
    'is_tombstoned': isTombstoned,
    if (deletedAt != null) 'deleted_at': deletedAt!.toUtc().toIso8601String(),
    'metadata': metadata,
  };

  /// Create from JSON
  factory MiraNodeV2.fromJson(Map<String, dynamic> json) => MiraNodeV2(
    id: json['id'] as String,
    schemaId: json['schema_id'] as String? ?? 'mira.node@0.1.0',
    type: NodeType.values[json['type'] as int],
    schemaVersion: json['schema_version'] as int? ?? 1,
    data: Map<String, dynamic>.from(json['data'] as Map),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    provenance: Provenance.fromJson(json['provenance'] as Map<String, dynamic>),
    embeddingsVer: json['embeddings_ver'] as String?,
    embeddingRefs: List<String>.from(json['embedding_refs'] ?? []),
    isTombstoned: json['is_tombstoned'] as bool? ?? false,
    deletedAt: json['deleted_at'] != null 
        ? DateTime.parse(json['deleted_at'] as String) 
        : null,
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );

  /// Create a copy with updated fields
  MiraNodeV2 copyWith({
    String? id,
    String? schemaId,
    NodeType? type,
    int? schemaVersion,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? updatedAt,
    Provenance? provenance,
    String? embeddingsVer,
    List<String>? embeddingRefs,
    bool? isTombstoned,
    DateTime? deletedAt,
    Map<String, dynamic>? metadata,
  }) => MiraNodeV2(
    id: id ?? this.id,
    schemaId: schemaId ?? this.schemaId,
    type: type ?? this.type,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    data: data ?? Map<String, dynamic>.from(this.data),
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? DateTime.now().toUtc(),
    provenance: provenance ?? this.provenance,
    embeddingsVer: embeddingsVer ?? this.embeddingsVer,
    embeddingRefs: embeddingRefs ?? this.embeddingRefs,
    isTombstoned: isTombstoned ?? this.isTombstoned,
    deletedAt: deletedAt ?? this.deletedAt,
    metadata: metadata ?? Map<String, dynamic>.from(this.metadata),
  );

  /// Soft delete this node
  MiraNodeV2 tombstone() => copyWith(
    isTombstoned: true,
    deletedAt: DateTime.now().toUtc(),
  );

  /// Check if node is active (not tombstoned)
  bool get isActive => !isTombstoned;

  /// Convenience properties for backward compatibility
  String get narrative => data['content'] ?? data['text'] ?? '';
  List<String> get keywords => List<String>.from(data['keywords'] ?? []);
  DateTime get timestamp => createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiraNodeV2 && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MiraNodeV2($id, $type)';
}

/// Enhanced edge with v0.2 features
class MiraEdgeV2 {
  final String id;                    // ULID
  final String schemaId;              // Schema identifier
  final String src;                   // Source node ID
  final String dst;                   // Destination node ID
  final EdgeType label;               // Edge type
  final int schemaVersion;            // Schema version
  final Map<String, dynamic> data;    // Edge data
  final DateTime createdAt;
  final DateTime updatedAt;
  final Provenance provenance;        // Creation provenance
  final bool isTombstoned;            // Soft delete flag
  final DateTime? deletedAt;          // When tombstoned
  final Map<String, dynamic> metadata; // Additional metadata

  const MiraEdgeV2({
    required this.id,
    required this.schemaId,
    required this.src,
    required this.dst,
    required this.label,
    required this.schemaVersion,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
    required this.provenance,
    this.isTombstoned = false,
    this.deletedAt,
    this.metadata = const {},
  });

  /// Create a new edge with ULID and provenance
  factory MiraEdgeV2.create({
    required String src,
    required String dst,
    required EdgeType label,
    required Map<String, dynamic> data,
    required String source,
    required String operation,
    String? traceId,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now().toUtc();
    return MiraEdgeV2(
      id: ULID.generate(),
      schemaId: 'mira.edge@${MiraVersion.MIRA_VERSION}',
      src: src,
      dst: dst,
      label: label,
      schemaVersion: MiraVersion.SCHEMA_VERSION,
      data: data,
      createdAt: now,
      updatedAt: now,
      provenance: Provenance.create(
        source: source,
        operation: operation,
        traceId: traceId,
      ),
      metadata: metadata ?? {},
    );
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'schema_id': schemaId,
    'src': src,
    'dst': dst,
    'label': label.index,
    'schema_version': schemaVersion,
    'data': data,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'provenance': provenance.toJson(),
    'is_tombstoned': isTombstoned,
    if (deletedAt != null) 'deleted_at': deletedAt!.toUtc().toIso8601String(),
    'metadata': metadata,
  };

  /// Create from JSON
  factory MiraEdgeV2.fromJson(Map<String, dynamic> json) => MiraEdgeV2(
    id: json['id'] as String,
    schemaId: json['schema_id'] as String? ?? 'mira.edge@0.1.0',
    src: json['src'] as String,
    dst: json['dst'] as String,
    label: EdgeType.values[json['label'] as int],
    schemaVersion: json['schema_version'] as int? ?? 1,
    data: Map<String, dynamic>.from(json['data'] as Map),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    provenance: Provenance.fromJson(json['provenance'] as Map<String, dynamic>),
    isTombstoned: json['is_tombstoned'] as bool? ?? false,
    deletedAt: json['deleted_at'] != null 
        ? DateTime.parse(json['deleted_at'] as String) 
        : null,
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );

  /// Create a copy with updated fields
  MiraEdgeV2 copyWith({
    String? id,
    String? schemaId,
    String? src,
    String? dst,
    EdgeType? label,
    int? schemaVersion,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? updatedAt,
    Provenance? provenance,
    bool? isTombstoned,
    DateTime? deletedAt,
    Map<String, dynamic>? metadata,
  }) => MiraEdgeV2(
    id: id ?? this.id,
    schemaId: schemaId ?? this.schemaId,
    src: src ?? this.src,
    dst: dst ?? this.dst,
    label: label ?? this.label,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    data: data ?? Map<String, dynamic>.from(this.data),
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? DateTime.now().toUtc(),
    provenance: provenance ?? this.provenance,
    isTombstoned: isTombstoned ?? this.isTombstoned,
    deletedAt: deletedAt ?? this.deletedAt,
    metadata: metadata ?? Map<String, dynamic>.from(this.metadata),
  );

  /// Soft delete this edge
  MiraEdgeV2 tombstone() => copyWith(
    isTombstoned: true,
    deletedAt: DateTime.now().toUtc(),
  );

  /// Check if edge is active (not tombstoned)
  bool get isActive => !isTombstoned;

  /// Convenience properties for backward compatibility
  EdgeType get relation => label;
  double get weight => (data['weight'] as num?)?.toDouble() ?? 1.0;
  DateTime get timestamp => createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiraEdgeV2 && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MiraEdgeV2($id, $src->$dst)';
}

/// Enhanced pointer with v0.2 features
class MiraPointerV2 {
  final String id;                    // ULID
  final String schemaId;              // Schema identifier
  final String kind;                  // Pointer type (media, document, etc.)
  final String ref;                   // Reference URI
  final int schemaVersion;            // Schema version
  final Map<String, dynamic> descriptor; // Pointer descriptor
  final Map<String, dynamic> integrity;  // Integrity information
  final Map<String, dynamic> privacy;    // Privacy settings
  final DateTime createdAt;
  final DateTime updatedAt;
  final Provenance provenance;        // Creation provenance
  final String? sha256;               // SHA-256 hash
  final int? bytes;                   // Size in bytes
  final String? mimeType;             // MIME type
  final List<String> embeddingRefs;   // References to embeddings
  final bool isTombstoned;            // Soft delete flag
  final DateTime? deletedAt;          // When tombstoned
  final Map<String, dynamic> metadata; // Additional metadata

  const MiraPointerV2({
    required this.id,
    required this.schemaId,
    required this.kind,
    required this.ref,
    required this.schemaVersion,
    required this.descriptor,
    required this.integrity,
    required this.privacy,
    required this.createdAt,
    required this.updatedAt,
    required this.provenance,
    this.sha256,
    this.bytes,
    this.mimeType,
    this.embeddingRefs = const [],
    this.isTombstoned = false,
    this.deletedAt,
    this.metadata = const {},
  });

  /// Create a new pointer with ULID and provenance
  factory MiraPointerV2.create({
    required String kind,
    required String ref,
    required Map<String, dynamic> descriptor,
    required Map<String, dynamic> integrity,
    required Map<String, dynamic> privacy,
    required String source,
    required String operation,
    String? traceId,
    String? sha256,
    int? bytes,
    String? mimeType,
    List<String>? embeddingRefs,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now().toUtc();
    return MiraPointerV2(
      id: ULID.generate(),
      schemaId: 'mira.pointer@${MiraVersion.MIRA_VERSION}',
      kind: kind,
      ref: ref,
      schemaVersion: MiraVersion.SCHEMA_VERSION,
      descriptor: descriptor,
      integrity: integrity,
      privacy: privacy,
      createdAt: now,
      updatedAt: now,
      provenance: Provenance.create(
        source: source,
        operation: operation,
        traceId: traceId,
      ),
      sha256: sha256,
      bytes: bytes,
      mimeType: mimeType,
      embeddingRefs: embeddingRefs ?? [],
      metadata: metadata ?? {},
    );
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'schema_id': schemaId,
    'kind': kind,
    'ref': ref,
    'schema_version': schemaVersion,
    'descriptor': descriptor,
    'integrity': integrity,
    'privacy': privacy,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'provenance': provenance.toJson(),
    if (sha256 != null) 'sha256': sha256,
    if (bytes != null) 'bytes': bytes,
    if (mimeType != null) 'mime_type': mimeType,
    'embedding_refs': embeddingRefs,
    'is_tombstoned': isTombstoned,
    if (deletedAt != null) 'deleted_at': deletedAt!.toUtc().toIso8601String(),
    'metadata': metadata,
  };

  /// Create from JSON
  factory MiraPointerV2.fromJson(Map<String, dynamic> json) => MiraPointerV2(
    id: json['id'] as String,
    schemaId: json['schema_id'] as String? ?? 'mira.pointer@0.1.0',
    kind: json['kind'] as String,
    ref: json['ref'] as String,
    schemaVersion: json['schema_version'] as int? ?? 1,
    descriptor: Map<String, dynamic>.from(json['descriptor'] as Map),
    integrity: Map<String, dynamic>.from(json['integrity'] as Map),
    privacy: Map<String, dynamic>.from(json['privacy'] as Map),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    provenance: Provenance.fromJson(json['provenance'] as Map<String, dynamic>),
    sha256: json['sha256'] as String?,
    bytes: json['bytes'] as int?,
    mimeType: json['mime_type'] as String?,
    embeddingRefs: List<String>.from(json['embedding_refs'] ?? []),
    isTombstoned: json['is_tombstoned'] as bool? ?? false,
    deletedAt: json['deleted_at'] != null 
        ? DateTime.parse(json['deleted_at'] as String) 
        : null,
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );

  /// Create a copy with updated fields
  MiraPointerV2 copyWith({
    String? id,
    String? schemaId,
    String? kind,
    String? ref,
    int? schemaVersion,
    Map<String, dynamic>? descriptor,
    Map<String, dynamic>? integrity,
    Map<String, dynamic>? privacy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Provenance? provenance,
    String? sha256,
    int? bytes,
    String? mimeType,
    List<String>? embeddingRefs,
    bool? isTombstoned,
    DateTime? deletedAt,
    Map<String, dynamic>? metadata,
  }) => MiraPointerV2(
    id: id ?? this.id,
    schemaId: schemaId ?? this.schemaId,
    kind: kind ?? this.kind,
    ref: ref ?? this.ref,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    descriptor: descriptor ?? Map<String, dynamic>.from(this.descriptor),
    integrity: integrity ?? Map<String, dynamic>.from(this.integrity),
    privacy: privacy ?? Map<String, dynamic>.from(this.privacy),
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? DateTime.now().toUtc(),
    provenance: provenance ?? this.provenance,
    sha256: sha256 ?? this.sha256,
    bytes: bytes ?? this.bytes,
    mimeType: mimeType ?? this.mimeType,
    embeddingRefs: embeddingRefs ?? this.embeddingRefs,
    isTombstoned: isTombstoned ?? this.isTombstoned,
    deletedAt: deletedAt ?? this.deletedAt,
    metadata: metadata ?? Map<String, dynamic>.from(this.metadata),
  );

  /// Soft delete this pointer
  MiraPointerV2 tombstone() => copyWith(
    isTombstoned: true,
    deletedAt: DateTime.now().toUtc(),
  );

  /// Check if pointer is active (not tombstoned)
  bool get isActive => !isTombstoned;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiraPointerV2 && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MiraPointerV2($id, $kind:$ref)';
}

/// Node types (re-exported from original schema for compatibility)
enum NodeType {
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
}

/// Edge types (re-exported from original schema for compatibility)
enum EdgeType {
  mentions,
  cooccurs,
  expresses,
  taggedAs,
  inPeriod,
  belongsTo,
  evidenceFor,
  partOf,
  precedes,
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
