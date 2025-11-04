// lpackage:my_app/polymeta/core/schema.dart
// Core MIRA schema definitions for nodes and edges
// Follows additive-only evolution policy - never change field meanings
import 'ids.dart';

/// Types of nodes in the MIRA semantic memory graph
enum NodeType {
  /// Journal entry nodes containing user narratives
  entry,
  /// Keyword nodes for semantic concepts
  keyword,
  /// Emotion nodes for emotional states
  emotion,
  /// Phase nodes for life phase detection
  phase,
  /// Period nodes for temporal grouping (days, weeks)
  period,
  /// Topic cluster nodes for advanced analytics
  topic,
  /// Concept nodes for abstract ideas
  concept,
  /// Episode nodes for temporal story arcs
  episode,
  /// Summary nodes for episode condensation
  summary,
  /// Evidence nodes for supporting data
  evidence,
}

/// Types of edges connecting MIRA nodes
enum EdgeType {
  /// Entry mentions keyword
  mentions,
  /// Keywords co-occur in entries
  cooccurs,
  /// Entry expresses emotion
  expresses,
  /// Entry tagged with phase
  taggedAs,
  /// Entry occurs in time period
  inPeriod,
  /// Item belongs to group/cluster
  belongsTo,
  /// Evidence supports claim/topic
  evidenceFor,
  /// Part of larger whole (entry → episode)
  partOf,
  /// Temporal precedence (episode A → episode B)
  precedes,
}

/// A node in the MIRA semantic memory graph
class MiraNode {
  /// Unique identifier for this node
  final String id;

  /// Type classification of this node
  final NodeType type;

  /// Schema version for additive evolution
  final int schemaVersion;

  /// Flexible data storage for type-specific fields
  /// Examples: frequency, recency, confidence, SAGE narrative, provenance
  final Map<String, dynamic> data;

  /// When this node was first created
  final DateTime createdAt;

  /// When this node was last updated
  final DateTime updatedAt;

  const MiraNode({
    required this.id,
    required this.type,
    required this.schemaVersion,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convenience properties for backward compatibility
  String get narrative => data['content'] ?? data['text'] ?? '';
  List<String> get keywords => List<String>.from(data['keywords'] ?? []);
  DateTime get timestamp => createdAt;
  Map<String, dynamic> get metadata => Map<String, dynamic>.from(data);

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'schemaVersion': schemaVersion,
    'data': data,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  /// Create a new node with updated timestamp
  MiraNode copyWith({
    String? id,
    NodeType? type,
    int? schemaVersion,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MiraNode(
      id: id ?? this.id,
      type: type ?? this.type,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      data: data ?? Map<String, dynamic>.from(this.data),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  /// Create keyword node
  factory MiraNode.keyword({
    required String text,
    DateTime? timestamp,
    int frequency = 1,
    double confidence = 1.0,
  }) {
    final now = timestamp ?? DateTime.now().toUtc();
    return MiraNode(
      id: stableKeywordId(text),
      type: NodeType.keyword,
      schemaVersion: 1,
      data: {
        'text': text,
        'content': text,
        'frequency': frequency,
        'confidence': confidence,
        'normalized': text.toLowerCase().trim(),
      },
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create entry node with SAGE narrative
  factory MiraNode.entry({
    required String narrative,
    required List<String> keywords,
    required DateTime timestamp,
    required Map<String, dynamic> metadata,
    String? id,
  }) {
    final entryId = id ?? deterministicEntryId(narrative, timestamp);
    return MiraNode(
      id: entryId,
      type: NodeType.entry,
      schemaVersion: 1,
      data: {
        'content': narrative,
        'keywords': keywords,
        ...metadata,
        'word_count': narrative.split(RegExp(r'\s+')).length,
      },
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  /// Create phase node
  factory MiraNode.phase({
    required String text,
    required DateTime timestamp,
    required Map<String, dynamic> metadata,
    double confidence = 1.0,
  }) {
    return MiraNode(
      id: stableKeywordId('phase_$text'),
      type: NodeType.phase,
      schemaVersion: 1,
      data: {
        'text': text,
        'content': text,
        'name': text,
        'confidence': confidence,
        'normalized': text.toLowerCase().trim(),
        ...metadata,
      },
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  /// Create emotion node
  factory MiraNode.emotion({
    required String text,
    required DateTime timestamp,
    double intensity = 1.0,
  }) {
    return MiraNode(
      id: stableKeywordId('emotion_$text'),
      type: NodeType.emotion,
      schemaVersion: 1,
      data: {
        'text': text,
        'content': text,
        'name': text,
        'intensity': intensity,
        'normalized': text.toLowerCase().trim(),
      },
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiraNode && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MiraNode($id, $type)';

  /// Create from JSON
  factory MiraNode.fromJson(Map<String, dynamic> json) => MiraNode(
    id: json['id'] as String,
    type: NodeType.values[json['type'] as int],
    schemaVersion: json['schemaVersion'] as int,
    data: Map<String, dynamic>.from(json['data'] as Map),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}

/// An edge connecting two nodes in the MIRA graph
class MiraEdge {
  /// Unique identifier for this edge
  final String id;

  /// Source node ID
  final String src;

  /// Destination node ID
  final String dst;

  /// Edge type/relationship label
  final EdgeType label;

  /// Schema version for additive evolution
  final int schemaVersion;

  /// Flexible data storage for edge-specific fields
  /// Examples: weights, provenance, temporal/emotion statistics
  final Map<String, dynamic> data;

  /// When this edge was created
  final DateTime createdAt;

  const MiraEdge({
    required this.id,
    required this.src,
    required this.dst,
    required this.label,
    required this.schemaVersion,
    required this.data,
    required this.createdAt,
  });

  /// Convenience properties for backward compatibility
  EdgeType get relation => label;
  double get weight => (data['weight'] as num?)?.toDouble() ?? 1.0;
  DateTime get timestamp => createdAt;
  Map<String, dynamic> get metadata => Map<String, dynamic>.from(data);

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'src': src,
    'dst': dst,
    'label': label.index,
    'schemaVersion': schemaVersion,
    'data': data,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  /// Create edge with automatic ID generation
  factory MiraEdge.create({
    required String src,
    required String dst,
    required EdgeType label,
    Map<String, dynamic>? data,
    String? id,
  }) {
    final edgeId = id ?? '${src}_${label.name}_$dst';
    return MiraEdge(
      id: edgeId,
      src: src,
      dst: dst,
      label: label,
      schemaVersion: 1,
      data: data ?? {},
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// Create mentions edge (entry → keyword)
  factory MiraEdge.mentions({
    required String src,
    required String dst,
    required DateTime timestamp,
    double weight = 1.0,
    double confidence = 1.0,
  }) {
    return MiraEdge(
      id: deterministicEdgeId(src, 'mentions', dst),
      src: src,
      dst: dst,
      label: EdgeType.mentions,
      schemaVersion: 1,
      data: {
        'weight': weight,
        'confidence': confidence,
      },
      createdAt: timestamp,
    );
  }

  /// Create co-occurrence edge (keyword ↔ keyword)
  factory MiraEdge.cooccurs({
    required String keyword1Id,
    required String keyword2Id,
    int count = 1,
    double lift = 1.0,
  }) {
    return MiraEdge.create(
      src: keyword1Id,
      dst: keyword2Id,
      label: EdgeType.cooccurs,
      data: {
        'count': count,
        'lift': lift,
      },
    );
  }

  /// Create expression edge (entry → emotion)
  factory MiraEdge.expresses({
    required String src,
    required String dst,
    required DateTime timestamp,
    double intensity = 1.0,
  }) {
    return MiraEdge(
      id: deterministicEdgeId(src, 'expresses', dst),
      src: src,
      dst: dst,
      label: EdgeType.expresses,
      schemaVersion: 1,
      data: {
        'intensity': intensity,
      },
      createdAt: timestamp,
    );
  }

  /// Create tagged-as edge (entry → phase)
  factory MiraEdge.taggedAs({
    required String src,
    required String dst,
    required DateTime timestamp,
    double confidence = 1.0,
  }) {
    return MiraEdge(
      id: deterministicEdgeId(src, 'taggedAs', dst),
      src: src,
      dst: dst,
      label: EdgeType.taggedAs,
      schemaVersion: 1,
      data: {
        'confidence': confidence,
      },
      createdAt: timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiraEdge && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MiraEdge($src -[$label]-> $dst)';

  /// Create from JSON
  factory MiraEdge.fromJson(Map<String, dynamic> json) => MiraEdge(
    id: json['id'] as String,
    src: json['src'] as String,
    dst: json['dst'] as String,
    label: EdgeType.values[json['label'] as int],
    schemaVersion: json['schemaVersion'] as int,
    data: Map<String, dynamic>.from(json['data'] as Map),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}