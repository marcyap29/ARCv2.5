// lib/arcform/layouts/layouts_3d.dart
// Phase-aware 3D layouts for constellation nodes

import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vm;
import '../util/seeded.dart';
import '../models/arcform_models.dart';

/// Get optimal node count for each phase shape
int _getOptimalNodeCount(String phase) {
  switch (phase.toLowerCase()) {
    case 'discovery':
      return 10; // Perfect for 1.5 turns of helix
    case 'exploration':
    case 'expansion':
      return 12; // 2 layers × 6 nodes for clear ring structure
    case 'transition':
      return 12; // 3 branches × 4 nodes to show forking
    case 'consolidation':
      return 20; // More nodes for denser geodesic lattice (4 rings × 5 nodes)
    case 'recovery':
      return 8; // Tight cluster is clear with fewer nodes
    case 'breakthrough':
      return 10; // Show explosive radial pattern
    default:
      return 10; // Balanced sphere
  }
}

/// Layout a list of keywords into 3D positions based on phase
List<ArcNode3D> layout3D({
  required List<String> keywords,
  required String phase,
  required ArcformSkin skin,
  Map<String, double>? keywordWeights,
  Map<String, double>? keywordValences,
  int? maxNodes, // Optional override, otherwise use phase-optimized count
}) {
  final rng = Seeded('${skin.seed}:layout');

  // Default weights and valences if not provided
  keywordWeights ??= {for (var kw in keywords) kw: 0.5 + rng.nextDouble() * 0.5};
  keywordValences ??= {for (var kw in keywords) kw: rng.nextRange(-0.5, 0.5)};

  // Use phase-optimized node count if not overridden
  final optimalCount = maxNodes ?? _getOptimalNodeCount(phase);

  // LIMIT: Select top N keywords by weight (most important)
  List<String> selectedKeywords = keywords;
  if (keywords.length > optimalCount) {
    // Sort by weight descending, take top optimalCount
    selectedKeywords = keywords.toList()
      ..sort((a, b) {
        final weightA = keywordWeights![a] ?? 0.5;
        final weightB = keywordWeights![b] ?? 0.5;
        return weightB.compareTo(weightA);
      });
    selectedKeywords = selectedKeywords.take(optimalCount).toList();
    print('🌟 Limited $phase constellation to $optimalCount nodes (from ${keywords.length})');
  }

  switch (phase.toLowerCase()) {
    case 'discovery':
      return _layoutHelix(selectedKeywords, keywordWeights, keywordValences, rng);
    case 'exploration':
    case 'expansion':
      return _layoutPetalRings(selectedKeywords, keywordWeights, keywordValences, rng);
    case 'transition':
      return _layoutBranches(selectedKeywords, keywordWeights, keywordValences, rng);
    case 'consolidation':
      return _layoutLattice(selectedKeywords, keywordWeights, keywordValences, rng);
    case 'recovery':
      return _layoutCluster(selectedKeywords, keywordWeights, keywordValences, rng);
    case 'breakthrough':
      return _layoutBurst(selectedKeywords, keywordWeights, keywordValences, rng);
    default:
      return _layoutSpherical(selectedKeywords, keywordWeights, keywordValences, rng);
  }
}

/// Discovery: Spiral helix with z increasing along angle
/// SIMPLIFIED: Clear helix shape with 10 nodes, visible spiral structure
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

    // HELIX PARAMETERS: Clean spiral ascending vertically
    // With 10 nodes, this creates 1.5 full turns of the helix
    final angle = t * 1.5 * 2 * math.pi; // 1.5 complete turns
    final radius = 0.8;  // Constant radius for clean cylinder shape

    // Helix coordinates - perfect cylinder spiral
    final x = radius * math.cos(angle);
    final y = radius * math.sin(angle);
    final z = (t - 0.5) * 3.0; // INCREASED Z-SPREAD: Vertical ascent from -1.5 to +1.5 (was -1.0 to +1.0)

    // NO JITTER: Keep helix perfectly smooth and visible
    // final childRng = rng.derive(keyword);
    // final jx = childRng.nextRange(-0.1, 0.1);

    nodes.add(ArcNode3D(
      id: keyword,
      label: keyword,
      x: x,  // No jitter
      y: y,  // No jitter
      z: z,  // No jitter
      weight: weights[keyword] ?? 0.5,
      valence: valences[keyword] ?? 0.0,
    ));

    // DEBUG: Log first, middle, and last node positions to verify helix
    if (i == 0 || i == count ~/ 2 || i == count - 1) {
      print('🧬 Helix node $i ($keyword): x=${x.toStringAsFixed(2)}, y=${y.toStringAsFixed(2)}, z=${z.toStringAsFixed(2)}');
    }
  }

  print('🧬 Created Discovery helix: $count nodes, 1.5 turns, radius 0.8, Z-spread=3.0');
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
    final z = (layer / (layers - 1) - 0.5) * 2.5; // Increased vertical spread (was 1.2)
    final layerRadius = 1.2 + (layer % 2) * 0.5; // Increased radii (was 0.6 + 0.2)
    
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

/// Transition: "Reaching Fingers" - Two centers with branches reaching toward each other
/// Like "Creation of Adam" - fingers extending from opposite sides toward connection
List<ArcNode3D> _layoutBranches(
  List<String> keywords,
  Map<String, double> weights,
  Map<String, double> valences,
  Seeded rng,
) {
  final nodes = <ArcNode3D>[];
  final count = keywords.length;

  // Create TWO main centers reaching toward each other (WIDER SPREAD)
  final center1 = vm.Vector3(-2.0, 0.0, 0.0);  // Left center (was -1.2, now further)
  final center2 = vm.Vector3(2.0, 0.0, 0.0);   // Right center (was 1.2, now further)
  final midpoint = vm.Vector3(0.0, 0.0, 0.0);  // Connection point

  // Split nodes between two centers
  final half = count ~/ 2;

  // First center - fingers reaching right
  for (int i = 0; i < half; i++) {
    final keyword = keywords[i];
    final t = i / math.max(1, half - 1);

    // Create "finger" branches reaching from left to center
    final fingerIndex = i % 3;  // 3 fingers per hand
    final fingerOffset = (fingerIndex - 1) * 0.8;  // WIDER vertical spread (was 0.4)

    // Reach from center1 toward midpoint
    final reach = 0.5 + t * 1.5;  // LONGER reach (was 0.3 + t * 0.9)
    final x = center1.x + reach;
    final y = fingerOffset + (t * 0.3);  // More curve
    final z = fingerOffset * 0.6;  // More Z-depth

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

  // Second center - fingers reaching left
  for (int i = half; i < count; i++) {
    final keyword = keywords[i];
    final idx = i - half;
    final t = idx / math.max(1, (count - half) - 1);

    // Create "finger" branches reaching from right to center
    final fingerIndex = idx % 3;  // 3 fingers per hand
    final fingerOffset = (fingerIndex - 1) * 0.8;  // WIDER vertical spread (was 0.4)

    // Reach from center2 toward midpoint
    final reach = 0.5 + t * 1.5;  // LONGER reach (was 0.3 + t * 0.9)
    final x = center2.x - reach;  // Negative to reach left
    final y = fingerOffset + (t * 0.3);  // More curve
    final z = fingerOffset * 0.6;  // More Z-depth

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

  print('🤝 Created Transition reaching fingers: $count nodes, 3 fingers per side, spread from -2.0 to +2.0');
  return nodes;
}

/// Consolidation: Geodesic lattice - nodes arranged in clear grid pattern on sphere
/// Creates visible "meridians and parallels" like a geodesic dome
/// ENHANCED: More latitude rings, denser pattern, better visualization
List<ArcNode3D> _layoutLattice(
  List<String> keywords,
  Map<String, double> weights,
  Map<String, double> valences,
  Seeded rng,
) {
  final nodes = <ArcNode3D>[];
  final count = keywords.length;

  // Create a geodesic pattern with MORE rings for better visibility
  final latitudes = 4;  // Increased from 3 to 4 rings for denser lattice
  final longitudesPerLat = (count / latitudes).ceil();

  int idx = 0;
  for (int lat = 0; lat < latitudes && idx < count; lat++) {
    // Latitude angle from -π/2 (bottom) to +π/2 (top)
    final latAngle = (lat / (latitudes - 1) - 0.5) * math.pi;
    final latRadius = math.cos(latAngle);  // Radius at this latitude
    final z = math.sin(latAngle) * 2.0;     // INCREASED height for more dramatic sphere (was 1.5)

    final itemsInRing = math.min(longitudesPerLat, count - idx);

    for (int lon = 0; lon < itemsInRing; lon++) {
      final keyword = keywords[idx++];
      final lonAngle = (lon / longitudesPerLat) * 2 * math.pi;

      // Position on sphere surface - LARGER radius for more visible lattice
      final x = latRadius * math.cos(lonAngle) * 2.0;  // Increased from 1.5
      final y = latRadius * math.sin(lonAngle) * 2.0;  // Increased from 1.5

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

  print('🌐 Created Consolidation geodesic lattice: $count nodes, $latitudes latitude rings, radius 2.0');
  return nodes;
}

/// Recovery: Compact cluster near origin
/// ENHANCED: Creates a dense "healing ball" with core-shell structure
/// Inner core of tightly packed nodes with outer shell for depth
List<ArcNode3D> _layoutCluster(
  List<String> keywords,
  Map<String, double> weights,
  Map<String, double> valences,
  Seeded rng,
) {
  final nodes = <ArcNode3D>[];
  final count = keywords.length;

  for (int i = 0; i < count; i++) {
    final keyword = keywords[i];
    final childRng = rng.derive(keyword);

    // Create two-layer structure: tight core + slightly dispersed shell
    final isCore = i < count * 0.6; // 60% in core, 40% in shell

    if (isCore) {
      // VERY tight core - nodes close together (healing huddle)
      final x = childRng.nextGaussian() * 0.4;  // Tight cluster
      final y = childRng.nextGaussian() * 0.4;  // Tight cluster
      final z = childRng.nextGaussian() * 0.4;  // Tight cluster

      nodes.add(ArcNode3D(
        id: keyword,
        label: keyword,
        x: x,
        y: y,
        z: z,
        weight: (weights[keyword] ?? 0.5) * 1.2, // Slightly larger nodes in core
        valence: valences[keyword] ?? 0.0,
      ));
    } else {
      // Outer shell - creates depth perception
      final x = childRng.nextGaussian() * 0.9;  // Wider shell
      final y = childRng.nextGaussian() * 0.9;  // Wider shell
      final z = childRng.nextGaussian() * 0.9;  // Wider shell

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

  print('🔮 Created Recovery cluster: $count nodes, core-shell structure (60/40 split)');
  return nodes;
}

/// Breakthrough: Dramatic explosive burst radiating from center like a supernova
/// ENHANCED: Creates visible rays/arms with concentrated nodes along radial lines
/// Some nodes VERY far for dramatic effect, creating clear "explosion" pattern
List<ArcNode3D> _layoutBurst(
  List<String> keywords,
  Map<String, double> weights,
  Map<String, double> valences,
  Seeded rng,
) {
  final nodes = <ArcNode3D>[];
  final count = keywords.length;

  // Create 6-8 main "rays" shooting out from center
  final numRays = 6 + (count % 3); // 6-8 rays depending on node count
  final nodesPerRay = count ~/ numRays;
  final remainder = count % numRays;

  int idx = 0;

  // Create main rays
  for (int ray = 0; ray < numRays && idx < count; ray++) {
    final childRng = rng.derive('ray_$ray');

    // Random direction for this ray
    final rayDirection = childRng.nextUnitSphere();

    // Number of nodes along this ray
    final nodesInRay = nodesPerRay + (ray < remainder ? 1 : 0);

    for (int n = 0; n < nodesInRay && idx < count; n++) {
      final keyword = keywords[idx++];

      // Distance along ray - HEAVILY weighted toward far distances
      // Power of 0.2 creates more nodes far from center (explosive effect)
      final t = n / math.max(1, nodesInRay - 1);
      final baseRadius = 0.8 + math.pow(t, 0.2) * 3.2; // Range: 0.8 to 4.0 - VERY dramatic

      // Add slight perpendicular jitter for volume (but keep on ray)
      final jitterAmount = childRng.nextRange(-0.2, 0.2);
      final perpJitter = childRng.nextUnitSphere();

      // Final position: along ray + tiny perpendicular jitter
      final x = rayDirection.x * baseRadius + perpJitter.x * jitterAmount;
      final y = rayDirection.y * baseRadius + perpJitter.y * jitterAmount;
      final z = rayDirection.z * baseRadius + perpJitter.z * jitterAmount;

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

  print('💥 Created Breakthrough supernova: $count nodes, $numRays rays, radius 0.8-4.0');
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
    
    // Scale to desired size - increased for galaxy spread
    final scale = 1.5 + childRng.nextDouble() * 0.8; // Increased from 0.7 + 0.2
    
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

