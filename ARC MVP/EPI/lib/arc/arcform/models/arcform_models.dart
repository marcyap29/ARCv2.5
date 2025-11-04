// lib/arcform/models/arcform_models.dart
// Data models for 3D Constellation ARCForms

/// A node in 3D space representing a keyword or concept
class ArcNode3D {
  final String id;
  final String label; // "Growth", "Insight", ...
  final double x, y, z; // normalized -1..1
  final double weight; // 0..1 (size/intensity)
  final double valence; // -1..1 (cool↔warm color)

  const ArcNode3D({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.z,
    required this.weight,
    required this.valence,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'x': x,
    'y': y,
    'z': z,
    'weight': weight,
    'valence': valence,
  };

  factory ArcNode3D.fromJson(Map<String, dynamic> json) => ArcNode3D(
    id: json['id'] as String,
    label: json['label'] as String,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    z: (json['z'] as num).toDouble(),
    weight: (json['weight'] as num).toDouble(),
    valence: (json['valence'] as num).toDouble(),
  );
}

/// An edge connecting two nodes in the constellation
class ArcEdge3D {
  final String sourceId;
  final String targetId;
  final double weight; // 0..1 (thickness/opacity)

  const ArcEdge3D({
    required this.sourceId,
    required this.targetId,
    required this.weight,
  });

  Map<String, dynamic> toJson() => {
    'sourceId': sourceId,
    'targetId': targetId,
    'weight': weight,
  };

  factory ArcEdge3D.fromJson(Map<String, dynamic> json) => ArcEdge3D(
    sourceId: json['sourceId'] as String,
    targetId: json['targetId'] as String,
    weight: (json['weight'] as num).toDouble(),
  );
}

/// Visual skin parameters for deterministic user-specific variations
class ArcformSkin {
  final int seed; // persisted for reproducibility
  final double glowJitter; // 0..1 per-node halo variance
  final double nebulaJitter; // 0..1 per-sprite size/alpha var
  final double hueJitter; // 0..2π mapped to 0..1 hue
  final double lineHueJitter; // small hue shift per edge
  final double lineAlphaBase; // 0..1
  final double warmBias; // hue bias for warm band
  final double coolBias; // hue bias for cool band

  const ArcformSkin({
    required this.seed,
    this.glowJitter = 0.25,
    this.nebulaJitter = 0.35,
    this.hueJitter = 0.08,
    this.lineHueJitter = 0.05,
    this.lineAlphaBase = 0.55,
    this.warmBias = 0.06,
    this.coolBias = -0.04,
  });

  Map<String, dynamic> toJson() => {
    'seed': seed,
    'glowJitter': glowJitter,
    'nebulaJitter': nebulaJitter,
    'hueJitter': hueJitter,
    'lineHueJitter': lineHueJitter,
    'lineAlphaBase': lineAlphaBase,
    'warmBias': warmBias,
    'coolBias': coolBias,
  };

  factory ArcformSkin.fromJson(Map<String, dynamic> json) => ArcformSkin(
    seed: json['seed'] as int,
    glowJitter: (json['glowJitter'] as num?)?.toDouble() ?? 0.25,
    nebulaJitter: (json['nebulaJitter'] as num?)?.toDouble() ?? 0.35,
    hueJitter: (json['hueJitter'] as num?)?.toDouble() ?? 0.08,
    lineHueJitter: (json['lineHueJitter'] as num?)?.toDouble() ?? 0.05,
    lineAlphaBase: (json['lineAlphaBase'] as num?)?.toDouble() ?? 0.55,
    warmBias: (json['warmBias'] as num?)?.toDouble() ?? 0.06,
    coolBias: (json['coolBias'] as num?)?.toDouble() ?? -0.04,
  );

  /// Generate a default skin with user-specific seed
  factory ArcformSkin.forUser(String userId, String snapshotId) {
    final seed = ('$userId:$snapshotId').hashCode;
    return ArcformSkin(seed: seed);
  }
}

/// Complete 3D Arcform data structure
class Arcform3DData {
  final List<ArcNode3D> nodes;
  final List<ArcEdge3D> edges;
  final String phase;
  final ArcformSkin skin;
  final String title;
  final String? content;
  final DateTime createdAt;
  final String id;

  const Arcform3DData({
    required this.nodes,
    required this.edges,
    required this.phase,
    required this.skin,
    required this.title,
    this.content,
    required this.createdAt,
    required this.id,
  });

  Map<String, dynamic> toJson() => {
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'edges': edges.map((e) => e.toJson()).toList(),
    'phase': phase,
    'skin': skin.toJson(),
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'id': id,
  };

  factory Arcform3DData.fromJson(Map<String, dynamic> json) => Arcform3DData(
    nodes: (json['nodes'] as List).map((n) => ArcNode3D.fromJson(n as Map<String, dynamic>)).toList(),
    edges: (json['edges'] as List).map((e) => ArcEdge3D.fromJson(e as Map<String, dynamic>)).toList(),
    phase: json['phase'] as String,
    skin: ArcformSkin.fromJson(json['skin'] as Map<String, dynamic>),
    title: json['title'] as String,
    content: json['content'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    id: json['id'] as String,
  );
}

