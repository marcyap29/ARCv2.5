// lib/arcform/layouts/layouts_3d.dart
// Phase-aware 3D layouts for constellation nodes

import 'dart:math' as math;
import '../util/seeded.dart';
import '../models/arcform_models.dart';

/// Layout a list of keywords into 3D positions based on phase
List<ArcNode3D> layout3D({
  required List<String> keywords,
  required String phase,
  required ArcformSkin skin,
  Map<String, double>? keywordWeights,
  Map<String, double>? keywordValences,
}) {
  final rng = Seeded('${skin.seed}:layout');

  // Default weights and valences if not provided
  keywordWeights ??= {for (var kw in keywords) kw: 0.5 + rng.nextDouble() * 0.5};
  keywordValences ??= {for (var kw in keywords) kw: rng.nextRange(-0.5, 0.5)};

  switch (phase.toLowerCase()) {
    case 'discovery':
      return _layoutHelix(keywords, keywordWeights, keywordValences, rng);
    case 'exploration':
    case 'expansion':
      return _layoutPetalRings(keywords, keywordWeights, keywordValences, rng);
    case 'transition':
      return _layoutBranches(keywords, keywordWeights, keywordValences, rng);
    case 'consolidation':
      return _layoutLattice(keywords, keywordWeights, keywordValences, rng);
    case 'recovery':
      return _layoutCluster(keywords, keywordWeights, keywordValences, rng);
    case 'breakthrough':
      return _layoutBurst(keywords, keywordWeights, keywordValences, rng);
    default:
      return _layoutSpherical(keywords, keywordWeights, keywordValences, rng);
  }
}

/// Discovery: Spiral helix with z increasing along angle
List<ArcNode3D> _layoutHelix(
  List<String> keywords,
  Map<String, double> weights,
  Map<String, double> valences,
  Seeded rng,
) {
  final nodes = <ArcNode3D>[];
  final count = keywords.length;

  for (int i = 0; i < count; i++) {
    final keyword = keywords[i];
    final t = i / math.max(1, count - 1);
    
    // Spiral parameters
    final angle = t * 2.5 * 2 * math.pi; // 2.5 turns
    final radius = 0.5 + t * 0.3; // Expand outward
    
    // Helix coordinates
    final x = radius * math.cos(angle);
    final y = radius * math.sin(angle);
    final z = (t - 0.5) * 1.5; // Vertical spread
    
    // Add slight jitter
    final childRng = rng.derive(keyword);
    final jx = childRng.nextRange(-0.1, 0.1);
    final jy = childRng.nextRange(-0.1, 0.1);
    final jz = childRng.nextRange(-0.05, 0.05);
    
    nodes.add(ArcNode3D(
      id: keyword,
      label: keyword,
      x: x + jx,
      y: y + jy,
      z: z + jz,
      weight: weights[keyword] ?? 0.5,
      valence: valences[keyword] ?? 0.0,
    ));
  }

  return nodes;
}

/// Exploration/Expansion: Petal rings on multiple z-layers
List<ArcNode3D> _layoutPetalRings(
  List<String> keywords,
  Map<String, double> weights,
  Map<String, double> valences,
  Seeded rng,
) {
  final nodes = <ArcNode3D>[];
  final count = keywords.length;
  final layers = (count / 6).ceil().clamp(2, 5);
  final perLayer = (count / layers).ceil();
  
  int idx = 0;
  for (int layer = 0; layer < layers && idx < count; layer++) {
    final z = (layer / (layers - 1) - 0.5) * 1.2;
    final layerRadius = 0.6 + (layer % 2) * 0.2; // Alternating radii
    
    final itemsInLayer = math.min(perLayer, count - idx);
    for (int i = 0; i < itemsInLayer; i++) {
      final keyword = keywords[idx++];
      final angle = (i / itemsInLayer) * 2 * math.pi;
      
      final x = layerRadius * math.cos(angle);
      final y = layerRadius * math.sin(angle);
      
      nodes.add(ArcNode3D(
        id: keyword,
        label: keyword,
        x: x,
        y: y,
        z: z,
        weight: weights[keyword] ?? 0.5,
        valence: valences[keyword] ?? 0.0,
      ));
    }
  }

  return nodes;
}

/// Transition: Forked branches with z offsets
List<ArcNode3D> _layoutBranches(
  List<String> keywords,
  Map<String, double> weights,
  Map<String, double> valences,
  Seeded rng,
) {
  final nodes = <ArcNode3D>[];
  final count = keywords.length;
  final branches = (count / 5).ceil().clamp(2, 4);
  final perBranch = (count / branches).ceil();
  
  int idx = 0;
  for (int branch = 0; branch < branches && idx < count; branch++) {
    final branchAngle = (branch / branches) * 2 * math.pi;
    final branchDir = (x: math.cos(branchAngle), y: math.sin(branchAngle));
    
    final itemsInBranch = math.min(perBranch, count - idx);
    for (int i = 0; i < itemsInBranch; i++) {
      final keyword = keywords[idx++];
      final t = i / itemsInBranch;
      final dist = 0.2 + t * 0.7;
      
      final x = branchDir.x * dist;
      final y = branchDir.y * dist;
      final z = (t - 0.5) * 0.6;
      
      nodes.add(ArcNode3D(
        id: keyword,
        label: keyword,
        x: x,
        y: y,
        z: z,
        weight: weights[keyword] ?? 0.5,
        valence: valences[keyword] ?? 0.0,
      ));
    }
  }

  return nodes;
}

/// Consolidation: Woven lattice/shell
List<ArcNode3D> _layoutLattice(
  List<String> keywords,
  Map<String, double> weights,
  Map<String, double> valences,
  Seeded rng,
) {
  final nodes = <ArcNode3D>[];
  
  for (int i = 0; i < keywords.length; i++) {
    final keyword = keywords[i];
    final childRng = rng.derive(keyword);
    
    // Distribute on sphere surface
    final point = childRng.nextUnitSphere();
    final radius = 0.7 + childRng.nextDouble() * 0.2;
    
    nodes.add(ArcNode3D(
      id: keyword,
      label: keyword,
      x: point.x * radius,
      y: point.y * radius,
      z: point.z * radius,
      weight: weights[keyword] ?? 0.5,
      valence: valences[keyword] ?? 0.0,
    ));
  }

  return nodes;
}

/// Recovery: Compact cluster near origin
List<ArcNode3D> _layoutCluster(
  List<String> keywords,
  Map<String, double> weights,
  Map<String, double> valences,
  Seeded rng,
) {
  final nodes = <ArcNode3D>[];
  
  for (int i = 0; i < keywords.length; i++) {
    final keyword = keywords[i];
    final childRng = rng.derive(keyword);
    
    // Gaussian distribution for tight cluster
    final x = childRng.nextGaussian() * 0.3;
    final y = childRng.nextGaussian() * 0.3;
    final z = childRng.nextGaussian() * 0.3;
    
    nodes.add(ArcNode3D(
      id: keyword,
      label: keyword,
      x: x,
      y: y,
      z: z,
      weight: weights[keyword] ?? 0.5,
      valence: valences[keyword] ?? 0.0,
    ));
  }

  return nodes;
}

/// Breakthrough: Sparse bursts (radial with z spikes)
List<ArcNode3D> _layoutBurst(
  List<String> keywords,
  Map<String, double> weights,
  Map<String, double> valences,
  Seeded rng,
) {
  final nodes = <ArcNode3D>[];
  
  for (int i = 0; i < keywords.length; i++) {
    final keyword = keywords[i];
    final childRng = rng.derive(keyword);
    
    // Radial burst pattern
    final point = childRng.nextUnitSphere();
    final t = childRng.nextDouble();
    final radius = 0.5 + math.pow(t, 0.4) * 0.7; // Bias toward outer
    
    nodes.add(ArcNode3D(
      id: keyword,
      label: keyword,
      x: point.x * radius,
      y: point.y * radius,
      z: point.z * radius,
      weight: weights[keyword] ?? 0.5,
      valence: valences[keyword] ?? 0.0,
    ));
  }

  return nodes;
}

/// Default: Spherical distribution
List<ArcNode3D> _layoutSpherical(
  List<String> keywords,
  Map<String, double> weights,
  Map<String, double> valences,
  Seeded rng,
) {
  final nodes = <ArcNode3D>[];
  
  for (int i = 0; i < keywords.length; i++) {
    final keyword = keywords[i];
    final childRng = rng.derive(keyword);
    
    // Fibonacci sphere for even distribution
    final goldenAngle = math.pi * (3.0 - math.sqrt(5.0));
    final theta = i * goldenAngle;
    final y = 1.0 - (i / (keywords.length - 1)) * 2.0;
    final radius = math.sqrt(1.0 - y * y);
    
    final x = radius * math.cos(theta);
    final z = radius * math.sin(theta);
    
    // Scale to desired size
    final scale = 0.7 + childRng.nextDouble() * 0.2;
    
    nodes.add(ArcNode3D(
      id: keyword,
      label: keyword,
      x: x * scale,
      y: y * scale,
      z: z * scale,
      weight: weights[keyword] ?? 0.5,
      valence: valences[keyword] ?? 0.0,
    ));
  }

  return nodes;
}

/// Generate edges based on proximity and keyword similarity
List<ArcEdge3D> generateEdges({
  required List<ArcNode3D> nodes,
  required Seeded rng,
  int maxEdgesPerNode = 3,
  double maxDistance = 1.2,
}) {
  final edges = <ArcEdge3D>[];
  
  for (int i = 0; i < nodes.length; i++) {
    final nodeA = nodes[i];
    final distances = <({int index, double dist})>[];
    
    // Calculate distances to all other nodes
    for (int j = 0; j < nodes.length; j++) {
      if (i == j) continue;
      
      final nodeB = nodes[j];
      final dx = nodeA.x - nodeB.x;
      final dy = nodeA.y - nodeB.y;
      final dz = nodeA.z - nodeB.z;
      final dist = math.sqrt(dx * dx + dy * dy + dz * dz);
      
      if (dist <= maxDistance) {
        distances.add((index: j, dist: dist));
      }
    }
    
    // Sort by distance
    distances.sort((a, b) => a.dist.compareTo(b.dist));
    
    // Connect to nearest neighbors
    final connectCount = math.min(maxEdgesPerNode, distances.length);
    for (int k = 0; k < connectCount; k++) {
      final target = nodes[distances[k].index];
      
      // Avoid duplicate edges
      final edgeExists = edges.any((e) =>
        (e.sourceId == nodeA.id && e.targetId == target.id) ||
        (e.sourceId == target.id && e.targetId == nodeA.id));
      
      if (!edgeExists) {
        // Weight based on distance (closer = stronger)
        final weight = (1.0 - distances[k].dist / maxDistance).clamp(0.3, 1.0);
        
        edges.add(ArcEdge3D(
          sourceId: nodeA.id,
          targetId: target.id,
          weight: weight,
        ));
      }
    }
  }
  
  return edges;
}

