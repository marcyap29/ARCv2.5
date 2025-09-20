// lib/mira/core/schema.dart
// Core MIRA schema definitions for nodes and edges
// Follows additive-only evolution policy - never change field meanings

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
    required String id,
    required String text,
    int frequency = 1,
    double confidence = 1.0,
  }) {
    return MiraNode(
      id: id,
      type: NodeType.keyword,
      schemaVersion: 1,
      data: {
        'text': text,
        'frequency': frequency,
        'confidence': confidence,
        'normalized': text.toLowerCase().trim(),
      },
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// Create entry node with SAGE narrative
  factory MiraNode.entry({
    required String id,
    required String content,
    Map<String, dynamic>? sage,
    List<String>? keywords,
    Map<String, dynamic>? emotions,
    String? phaseHint,
  }) {
    return MiraNode(
      id: id,
      type: NodeType.entry,
      schemaVersion: 1,
      data: {
        'content': content,
        'sage': sage ?? {},
        'keywords': keywords ?? [],
        'emotions': emotions ?? {},
        'phase_hint': phaseHint,
        'word_count': content.split(RegExp(r'\s+')).length,
      },
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// Create phase node
  factory MiraNode.phase({
    required String id,
    required String name,
    double confidence = 1.0,
  }) {
    return MiraNode(
      id: id,
      type: NodeType.phase,
      schemaVersion: 1,
      data: {
        'name': name,
        'confidence': confidence,
        'normalized': name.toLowerCase().trim(),
      },
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// Create emotion node
  factory MiraNode.emotion({
    required String id,
    required String name,
    double intensity = 1.0,
  }) {
    return MiraNode(
      id: id,
      type: NodeType.emotion,
      schemaVersion: 1,
      data: {
        'name': name,
        'intensity': intensity,
        'normalized': name.toLowerCase().trim(),
      },
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
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

  /// Create edge with automatic ID generation
  factory MiraEdge.create({
    required String src,
    required String dst,
    required EdgeType label,
    Map<String, dynamic>? data,
    String? id,
  }) {
    final edgeId = id ?? '${src}_${label.name}_${dst}';
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
    required String entryId,
    required String keywordId,
    double weight = 1.0,
    double confidence = 1.0,
  }) {
    return MiraEdge.create(
      src: entryId,
      dst: keywordId,
      label: EdgeType.mentions,
      data: {
        'weight': weight,
        'confidence': confidence,
      },
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
    required String entryId,
    required String emotionId,
    double intensity = 1.0,
  }) {
    return MiraEdge.create(
      src: entryId,
      dst: emotionId,
      label: EdgeType.expresses,
      data: {
        'intensity': intensity,
      },
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
}