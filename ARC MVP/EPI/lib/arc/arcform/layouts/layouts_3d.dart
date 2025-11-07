// lib/arcform/layouts/layouts_3d.dart
// Phase-aware 3D layouts for constellation nodes

import 'dart:math' as math;
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
      return 11; // Perfect 3-ring star: 1 center + 5 middle + 5 outer
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
  final weights = keywordWeights ?? {for (var kw in keywords) kw: 0.5 + rng.nextDouble() * 0.5};
  final valences = keywordValences ?? {for (var kw in keywords) kw: rng.nextRange(-0.5, 0.5)};

  // Use phase-optimized node count if not overridden
  final optimalCount = maxNodes ?? _getOptimalNodeCount(phase);

  // LIMIT: Select top N keywords by weight (most important)
  List<String> selectedKeywords = keywords;
  if (keywords.length > optimalCount) {
    // Sort by weight descending, take top optimalCount
    selectedKeywords = keywords.toList()
      ..sort((a, b) {
        final weightA = weights[a] ?? 0.5;
        final weightB = weights[b] ?? 0.5;
        return weightB.compareTo(weightA);
      });
    selectedKeywords = selectedKeywords.take(optimalCount).toList();
    print('🌟 Limited $phase constellation to $optimalCount nodes (from ${keywords.length})');
  }

  switch (phase.toLowerCase()) {
    case 'discovery':
      return _layoutHelix(selectedKeywords, weights, valences, rng);
    case 'exploration':
    case 'expansion':
      return _layoutPetalRings(selectedKeywords, weights, valences, rng);
    case 'transition':
      return _layoutBridge(selectedKeywords, weights, valences, rng);
    case 'consolidation':
      return _layoutLattice(selectedKeywords, weights, valences, rng);
    case 'recovery':
      return _layoutAscendingSpiral(selectedKeywords, weights, valences, rng);
    case 'breakthrough':
      return _layoutSupernova(selectedKeywords, weights, valences, rng);
    default:
      return _layoutSpherical(selectedKeywords, weights, valences, rng);
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

/// Transition: Gateway/Bridge Pattern - Two clusters (departure/destination) connected by a bridge
/// Visual metaphor: Moving from one life state to another through a liminal space
List<ArcNode3D> _layoutBridge(
  List<String> keywords,
  Map<String, double> weights,
  Map<String, double> valences,
  Seeded rng,
) {
  final nodes = <ArcNode3D>[];
  final count = keywords.length;

  // Cylinder structure: 9 rings × 3 nodes per stack = 27 nodes ideal
  // Each "stack" represents a vertical column, each with 3 nodes (one per ring)
  // Total stacks: 9 stacks × 3 nodes = 27 nodes, expanded horizontally for more cylindrical appearance
  const stacks = 9; // 9 vertical stacks (columns)
  const nodesPerStack = 3; // 3 nodes per stack (one for each ring level)
  const cylinderRadius = 2.0; // Increased radius for more cylindrical spacing
  const cylinderHeight = 3.0; // Increased height for better stack visibility

  int idx = 0;
  
  // Create stacks: each stack has 3 nodes vertically aligned
  for (int stack = 0; stack < stacks && idx < count; stack++) {
    final stackAngle = (stack / stacks) * 2 * math.pi; // Angle around cylinder (0 to 2π)
    
    // Create 3 nodes for this stack (top, middle, bottom)
    for (int nodeInStack = 0; nodeInStack < nodesPerStack && idx < count; nodeInStack++) {
      final keyword = keywords[idx++];
      final nodeT = nodesPerStack > 1 ? nodeInStack / (nodesPerStack - 1) : 0.5;
      final y = -cylinderHeight / 2 + nodeT * cylinderHeight; // Vertical position
      
      // Horizontal position: place nodes around cylinder at this stack's angle
      // Add slight variation in radius for visual interest
      final radiusVariation = (stack % 3) * 0.1 - 0.1; // Slight variation
      final x = (cylinderRadius + radiusVariation) * math.cos(stackAngle);
      final z = (cylinderRadius + radiusVariation) * math.sin(stackAngle);
      
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
  
  // Additional nodes: distribute along stacks or add to existing stacks
  while (idx < count) {
    final keyword = keywords[idx++];
    final stackIndex = (idx - stacks * nodesPerStack) % stacks; // Distribute across stacks
    final stackAngle = (stackIndex / stacks) * 2 * math.pi;
    
    // Add to a random level in this stack
    final level = (rng.nextDouble() * nodesPerStack).floor();
    final nodeT = nodesPerStack > 1 ? level / (nodesPerStack - 1) : 0.5;
    final y = -cylinderHeight / 2 + nodeT * cylinderHeight;
    
    final radiusVariation = rng.nextRange(-0.15, 0.15);
    final x = (cylinderRadius + radiusVariation) * math.cos(stackAngle);
    final z = (cylinderRadius + radiusVariation) * math.sin(stackAngle);
    
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

  print('🔄 Created Transition cylinder (9 stacks × 3 nodes): $count nodes, expanded spacing');
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

/// Recovery: Simple Pyramid - Base square (4 nodes) + Apex (1 node)
/// Visual metaphor: Gradual healing, rising toward wholeness
/// Structure: 4 base nodes forming square + 1 apex node, additional nodes along edges
List<ArcNode3D> _layoutAscendingSpiral(
  List<String> keywords,
  Map<String, double> weights,
  Map<String, double> valences,
  Seeded rng,
) {
  final nodes = <ArcNode3D>[];
  final count = keywords.length;
  
  // Pyramid structure: base (4 nodes) + middle ring (4 nodes) + apex (1 node) = 9 nodes minimum
  // FLIPPED: Apex at top, base at bottom
  const baseRadius = 1.2;
  const apexY = 2.0; // Apex at top
  const middleY = 0.5; // Middle ring
  const baseY = -0.5; // Base at bottom
  
  int idx = 0;
  
  // 1. Pyramid base (4 nodes) - form a square at bottom
  for (int i = 0; i < 4 && idx < count; i++) {
    final keyword = keywords[idx++];
    final angle = (i / 4.0) * 2 * math.pi; // 0°, 90°, 180°, 270°
    
    final x = baseRadius * math.cos(angle);
    final z = baseRadius * math.sin(angle);
    final y = baseY; // Base at bottom
    
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
  
  // 2. Middle ring (4 nodes) - smaller square in the middle
  const middleRadius = baseRadius * 0.6;
  for (int i = 0; i < 4 && idx < count; i++) {
    final keyword = keywords[idx++];
    final angle = (i / 4.0) * 2 * math.pi + math.pi / 4; // Offset 45° for visual distinction
    
    final x = middleRadius * math.cos(angle);
    final z = middleRadius * math.sin(angle);
    final y = middleY;
    
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
  
  // 3. Pyramid apex (1 node) - at top
  if (idx < count) {
    final keyword = keywords[idx++];
    nodes.add(ArcNode3D(
      id: keyword,
      label: keyword,
      x: 0,
      y: apexY, // Apex at top
      z: 0,
      weight: weights[keyword] ?? 0.5,
      valence: valences[keyword] ?? 0.0,
    ));
  }
  
  // 4. Additional nodes: distribute along edges (from base to apex)
  while (idx < count) {
    final keyword = keywords[idx++];
    final edge = (idx - 9) % 4; // Which base edge (0-3)
    final t = rng.nextDouble() * 0.8 + 0.1; // Position along edge (10% to 90%)
    
    final baseAngle = (edge / 4.0) * 2 * math.pi;
    final baseX = baseRadius * math.cos(baseAngle);
    final baseZ = baseRadius * math.sin(baseAngle);
    
    // Position along edge from base (bottom) to apex (top)
    final x = baseX * (1 - t);
    final z = baseZ * (1 - t);
    final y = baseY + t * (apexY - baseY); // From baseY (bottom) to apexY (top)
    
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

  print('🔺 Created Recovery simple pyramid (flipped): $count nodes (base: 4, middle: 4, apex: 1, additional: ${count > 9 ? count - 9 : 0})');
  return nodes;
}

/// Breakthrough: Perfect 3-Ring Star Structure
/// Visual metaphor: Sudden explosive clarity, the "ah-ha!" moment
/// Structure: 1 center + 5 middle ring + 5 outer ring = 11 nodes total
/// Center at origin, middle at radius 1.0, outer at radius 2.0, all 72° apart
List<ArcNode3D> _layoutSupernova(
  List<String> keywords,
  Map<String, double> weights,
  Map<String, double> valences,
  Seeded rng,
) {
  final nodes = <ArcNode3D>[];
  final count = math.min(keywords.length, 11); // Force exactly 11 nodes
  
  print('⭐ Breakthrough: Creating 3-ring star with $count nodes');
  
  // 3-ring star structure parameters
  const middleRadius = 1.0; // Middle ring radius
  const outerRadius = 2.0;   // Outer ring radius
  const angleStep = 2 * math.pi / 5; // 72 degrees between nodes
  const startAngle = -math.pi / 2; // Start at top (12 o'clock)
  
  int idx = 0;
  
  // 1. Center node (index 0) - at origin
  if (idx < count) {
    final keyword = keywords[idx++];
    nodes.add(ArcNode3D(
      id: keyword,
      label: keyword,
      x: 0.0,
      y: 0.0,
      z: 0.0,
      weight: (weights[keyword] ?? 0.5) * 1.3, // Larger center node
      valence: valences[keyword] ?? 0.0,
    ));
    print('⭐ Center node: $keyword at (0, 0, 0)');
  }
  
  // 2. Middle ring: 5 nodes at radius 1.0, 72° apart (indices 1-5)
  for (int i = 0; i < 5 && idx < count; i++) {
    final keyword = keywords[idx++];
    final angle = startAngle + (i * angleStep);
    final x = middleRadius * math.cos(angle);
    final y = middleRadius * math.sin(angle);
    final z = rng.nextRange(-0.05, 0.05); // Small z variation
    
    nodes.add(ArcNode3D(
      id: keyword,
      label: keyword,
      x: x,
      y: y,
      z: z,
      weight: weights[keyword] ?? 0.5,
      valence: valences[keyword] ?? 0.0,
    ));
    print('⭐ Middle[$i]: $keyword at angle ${(angle * 180 / math.pi).toStringAsFixed(1)}°, pos=(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})');
  }
  
  // 3. Outer ring: 5 nodes at radius 2.0, 72° apart, aligned with middle (indices 6-10)
  for (int i = 0; i < 5 && idx < count; i++) {
    final keyword = keywords[idx++];
    final angle = startAngle + (i * angleStep); // Same angle as middle ring
    final x = outerRadius * math.cos(angle);
    final y = outerRadius * math.sin(angle);
    final z = rng.nextRange(-0.05, 0.05); // Small z variation
    
    nodes.add(ArcNode3D(
      id: keyword,
      label: keyword,
      x: x,
      y: y,
      z: z,
      weight: weights[keyword] ?? 0.5,
      valence: valences[keyword] ?? 0.0,
    ));
    print('⭐ Outer[$i]: $keyword at angle ${(angle * 180 / math.pi).toStringAsFixed(1)}°, pos=(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})');
  }

  print('⭐ Breakthrough: Created perfect 3-ring star with ${nodes.length} nodes');
  print('⭐ Structure: 1 center + ${nodes.length > 1 ? 5 : 0} middle + ${nodes.length > 6 ? 5 : 0} outer');
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

/// Generate phase-specific edges that respect the intended shape patterns
List<ArcEdge3D> generateEdges({
  required List<ArcNode3D> nodes,
  required Seeded rng,
  required String phase,
  int maxEdgesPerNode = 3,
  double maxDistance = 1.2,
}) {
  switch (phase.toLowerCase()) {
    case 'transition':
      return _generateBridgeEdges(nodes);
    case 'recovery':
      return _generateAscendingSpiralEdges(nodes);
    case 'breakthrough':
      return _generateSupernovaEdges(nodes);
    case 'discovery':
      return _generateHelixEdges(nodes);
    case 'exploration':
    case 'expansion':
      return _generatePetalRingsEdges(nodes);
    case 'consolidation':
      return _generateLatticeEdges(nodes);
    default:
      return _generateDefaultEdges(nodes, maxEdgesPerNode, maxDistance);
  }
}

/// Transition: Cylinder - REDUCED connectors, connect only within stacks and skip some vertical connections
/// Structure: Connect nodes in each stack (vertical), and connect adjacent stacks horizontally
List<ArcEdge3D> _generateBridgeEdges(List<ArcNode3D> nodes) {
  final edges = <ArcEdge3D>[];
  if (nodes.length < 2) return edges;
  
  // Cylinder structure: 9 stacks × 3 nodes per stack
  // REDUCED CONNECTIONS: Connect nodes within each stack (vertical), connect adjacent stacks
  const stacks = 9;
  const nodesPerStack = 3;
  
  // 1. Connect nodes within each stack (vertical connections)
  for (int stack = 0; stack < stacks; stack++) {
    final stackStart = stack * nodesPerStack;
    if (stackStart >= nodes.length) break;
    
    // Connect nodes sequentially within the stack (top to middle to bottom)
    for (int i = 0; i < nodesPerStack - 1; i++) {
      final currentIdx = stackStart + i;
      final nextIdx = stackStart + i + 1;
      
      if (currentIdx < nodes.length && nextIdx < nodes.length) {
        edges.add(ArcEdge3D(
          sourceId: nodes[currentIdx].id,
          targetId: nodes[nextIdx].id,
          weight: 0.9, // Strong vertical stack connections
        ));
      }
    }
  }
  
  // 2. Connect adjacent stacks horizontally (form cylinder rings)
  // Connect each level (top, middle, bottom) between adjacent stacks
  for (int level = 0; level < nodesPerStack; level++) {
    for (int stack = 0; stack < stacks; stack++) {
      final currentIdx = stack * nodesPerStack + level;
      final nextStackIdx = ((stack + 1) % stacks) * nodesPerStack + level;
      
      if (currentIdx < nodes.length && nextStackIdx < nodes.length) {
        edges.add(ArcEdge3D(
          sourceId: nodes[currentIdx].id,
          targetId: nodes[nextStackIdx].id,
          weight: 0.8, // Strong horizontal ring connections
        ));
      }
    }
  }
  
  // 3. Connect additional nodes (beyond 27) to nearest stack node
  if (nodes.length > stacks * nodesPerStack) {
    for (int i = stacks * nodesPerStack; i < nodes.length; i++) {
      // Find nearest node in existing structure
      int nearestIdx = -1;
      double minDist = double.infinity;
      
      for (int j = 0; j < math.min(stacks * nodesPerStack, nodes.length); j++) {
        final dx = nodes[i].x - nodes[j].x;
        final dy = nodes[i].y - nodes[j].y;
        final dz = nodes[i].z - nodes[j].z;
        final dist = math.sqrt(dx * dx + dy * dy + dz * dz);
        if (dist < minDist) {
          minDist = dist;
          nearestIdx = j;
        }
      }
      
      if (nearestIdx >= 0 && nearestIdx < nodes.length) {
        edges.add(ArcEdge3D(
          sourceId: nodes[i].id,
          targetId: nodes[nearestIdx].id,
          weight: 0.5, // Light connection
        ));
      }
    }
  }
  
  return edges;
}

/// Recovery: Simple Pyramid - connect base square and edges to apex
/// Structure: Base square connections + each base node to apex + additional nodes along edges
List<ArcEdge3D> _generateAscendingSpiralEdges(List<ArcNode3D> nodes) {
  final edges = <ArcEdge3D>[];
  if (nodes.length < 2) return edges;
  
  // Node structure:
  // 0-3: Pyramid base (4 nodes) at bottom
  // 4-7: Middle ring (4 nodes)
  // 8: Pyramid apex at top
  // 9+: Additional nodes along edges
  
  // 1. Connect base nodes in square (bottom)
  for (int i = 0; i < 3 && i < nodes.length - 1; i++) {
    edges.add(ArcEdge3D(
      sourceId: nodes[i].id,
      targetId: nodes[i + 1].id,
      weight: 0.9, // Strong base connections
    ));
  }
  // Close the base square
  if (nodes.length > 3) {
    edges.add(ArcEdge3D(
      sourceId: nodes[0].id,
      targetId: nodes[3].id,
      weight: 0.9,
    ));
  }
  
  // 2. Connect middle ring nodes in square
  for (int i = 4; i < 7 && i < nodes.length - 1; i++) {
    edges.add(ArcEdge3D(
      sourceId: nodes[i].id,
      targetId: nodes[i + 1].id,
      weight: 0.9, // Strong middle ring connections
    ));
  }
  // Close the middle ring square
  if (nodes.length > 7) {
    edges.add(ArcEdge3D(
      sourceId: nodes[4].id,
      targetId: nodes[7].id,
      weight: 0.9,
    ));
  }
  
  // 3. Connect base nodes to middle ring nodes
  if (nodes.length > 7) {
    for (int i = 0; i < 4 && i < nodes.length; i++) {
      final middleIdx = 4 + i;
      if (middleIdx < nodes.length) {
        edges.add(ArcEdge3D(
          sourceId: nodes[i].id,
          targetId: nodes[middleIdx].id,
          weight: 0.8, // Strong base-to-middle connections
        ));
      }
    }
  }
  
  // 3a. Ensure connection between "Letting Go" and "Gentleness" (if present)
  int lettingGoIdx = -1;
  int gentlenessIdx = -1;
  for (int i = 0; i < nodes.length; i++) {
    final lowerLabel = nodes[i].label.toLowerCase();
    if (lowerLabel.contains('letting go') || lowerLabel.contains('lettinggo')) {
      lettingGoIdx = i;
    }
    if (lowerLabel.contains('gentleness') || lowerLabel.contains('gentle')) {
      gentlenessIdx = i;
    }
  }
  if (lettingGoIdx >= 0 && gentlenessIdx >= 0 && lettingGoIdx < nodes.length && gentlenessIdx < nodes.length) {
    // Check if edge already exists
    final exists = edges.any((e) =>
      (e.sourceId == nodes[lettingGoIdx].id && e.targetId == nodes[gentlenessIdx].id) ||
      (e.sourceId == nodes[gentlenessIdx].id && e.targetId == nodes[lettingGoIdx].id));
    if (!exists) {
      edges.add(ArcEdge3D(
        sourceId: nodes[lettingGoIdx].id,
        targetId: nodes[gentlenessIdx].id,
        weight: 0.85, // Strong connection between Letting Go and Gentleness
      ));
    }
  }
  
  // 4. Connect middle ring nodes to apex (top)
  if (nodes.length > 8) {
    for (int i = 4; i < 8 && i < nodes.length; i++) {
      edges.add(ArcEdge3D(
        sourceId: nodes[i].id,
        targetId: nodes[8].id,
        weight: 1.0, // Very strong middle-to-apex connections
      ));
    }
  }
  
  // 5. Connect base nodes to apex (skipping middle for some)
  if (nodes.length > 8) {
    // Connect diagonal base nodes to apex (reduce connections)
    edges.add(ArcEdge3D(
      sourceId: nodes[0].id,
      targetId: nodes[8].id,
      weight: 0.8,
    ));
    if (nodes.length > 2) {
      edges.add(ArcEdge3D(
        sourceId: nodes[2].id,
        targetId: nodes[8].id,
        weight: 0.8,
      ));
    }
  }
  
  // 6. Connect additional nodes along edges (from base to apex)
  if (nodes.length > 9) {
    for (int i = 9; i < nodes.length; i++) {
      // Find nearest base node
      int nearestBase = -1;
      double minDist = double.infinity;
      
      for (int j = 0; j < 4 && j < nodes.length; j++) {
        final dx = nodes[i].x - nodes[j].x;
        final dy = nodes[i].y - nodes[j].y;
        final dz = nodes[i].z - nodes[j].z;
        final dist = math.sqrt(dx * dx + dy * dy + dz * dz);
        if (dist < minDist) {
          minDist = dist;
          nearestBase = j;
        }
      }
      
      if (nearestBase >= 0 && nearestBase < nodes.length) {
        // Connect to nearest base node and apex
        edges.add(ArcEdge3D(
          sourceId: nodes[i].id,
          targetId: nodes[nearestBase].id,
          weight: 0.7,
        ));
        if (nodes.length > 8) {
          edges.add(ArcEdge3D(
            sourceId: nodes[i].id,
            targetId: nodes[8].id,
            weight: 0.6,
          ));
        }
      }
    }
  }
  
  return edges;
}

/// Breakthrough: 5-Pointed Star - connect center to points, points to form star shape
/// Helper to check if we should skip an edge between two nodes
/// Returns true if the edge should be skipped (e.g., awakening-evolution)
bool _shouldSkipEdge(ArcNode3D node1, ArcNode3D node2) {
  final label1 = node1.label.toLowerCase().trim();
  final label2 = node2.label.toLowerCase().trim();
  
  // Skip connection between "awakening" and "evolution"
  // Check for exact matches and partial matches (including word boundaries)
  final hasAwakening1 = label1.contains('awakening') || label1.contains('awake');
  final hasAwakening2 = label2.contains('awakening') || label2.contains('awake');
  final hasEvolution1 = label1.contains('evolution') || label1.contains('evol');
  final hasEvolution2 = label2.contains('evolution') || label2.contains('evol');
  
  // If one node has awakening and the other has evolution, skip
  if ((hasAwakening1 && hasEvolution2) || (hasAwakening2 && hasEvolution1)) {
    print('🚫 Skipping edge: "$label1" <-> "$label2"');
    return true;
  }
  
  return false;
}

/// Structure: Center → all points, connect outer points and valleys to form star outline
List<ArcEdge3D> _generateSupernovaEdges(List<ArcNode3D> nodes) {
  final edges = <ArcEdge3D>[];
  if (nodes.length < 2) return edges;
  
  // Helper to safely add an edge only if it's not the forbidden connection
  void addEdgeIfValid(ArcNode3D source, ArcNode3D target, double weight) {
    if (!_shouldSkipEdge(source, target)) {
      edges.add(ArcEdge3D(
        sourceId: source.id,
        targetId: target.id,
        weight: weight,
      ));
    }
  }
  
  // Simplified structure: 12 nodes total
  // 0 = center
  // 1-10 = star points (alternating: outer point, valley, outer point, valley...)
  // 11 = circled area node (enso center)
  
  final center = nodes[0];
  
  // 1. Connect center to all star points (outer points only, for clarity)
  for (int i = 1; i <= 10 && i < nodes.length; i += 2) { // Outer points are at odd indices (1, 3, 5, 7, 9)
    addEdgeIfValid(center, nodes[i], 1.0);
  }
  
  // 2. Connect star outline: connect points in sequence to form star
  // Connect outer point → valley → next outer point
  for (int i = 1; i < 10 && i + 1 < nodes.length; i++) {
    addEdgeIfValid(nodes[i], nodes[i + 1], 0.9);
  }
  // Close the star (connect last point back to first)
  if (nodes.length > 10) {
    addEdgeIfValid(nodes[9], nodes[1], 0.9);
  }
  
  // 3. Connect center to valleys as well (creates full star structure)
  for (int i = 2; i <= 10 && i < nodes.length; i += 2) { // Valleys are at even indices (2, 4, 6, 8, 10)
    addEdgeIfValid(center, nodes[i], 0.8);
  }
  
  // 4. Connect circled area node (index 11) to center and nearby star points
  if (nodes.length > 11) {
    final circledNode = nodes[11]; // The circled area node (enso center)
    
    // Connect to center
    addEdgeIfValid(center, circledNode, 0.9);
    
    // Connect to nearby star points (Awakening index 1, Liberation index 2, Transcendence index 6)
    // Also connect to adjacent points in the star pattern
    final nearbyIndices = [1, 2, 6, 3, 5]; // Awakening, Liberation, Transcendence, and adjacent points
    for (final i in nearbyIndices) {
      if (i < nodes.length && i <= 10) {
        addEdgeIfValid(circledNode, nodes[i], 0.85);
      }
    }
  }
  
  // Final safety check: Remove any edges that connect awakening and evolution
  // This catches any edges that might have been created despite the filters
  edges.removeWhere((edge) {
    final sourceNode = nodes.firstWhere((n) => n.id == edge.sourceId, orElse: () => nodes[0]);
    final targetNode = nodes.firstWhere((n) => n.id == edge.targetId, orElse: () => nodes[0]);
    if (_shouldSkipEdge(sourceNode, targetNode)) {
      print('🚫 Removing forbidden edge: ${sourceNode.label} -> ${targetNode.label}');
      return true;
    }
    return false;
  });
  
  print('✅ Generated ${edges.length} edges for Breakthrough phase');
  
  return edges;
}

/// Discovery: Helix - connect sequentially along helix
List<ArcEdge3D> _generateHelixEdges(List<ArcNode3D> nodes) {
  final edges = <ArcEdge3D>[];
  for (int i = 0; i < nodes.length - 1; i++) {
    edges.add(ArcEdge3D(
      sourceId: nodes[i].id,
      targetId: nodes[i + 1].id,
      weight: 0.8,
    ));
  }
  return edges;
}

/// Expansion: Petal Rings - connect within rings and to adjacent rings
List<ArcEdge3D> _generatePetalRingsEdges(List<ArcNode3D> nodes) {
  final edges = <ArcEdge3D>[];
  // Dense connections - k-NN approach
  final maxEdgesPerNode = 3;
  final maxDist = 1.5;
  
  for (int i = 0; i < nodes.length; i++) {
    final distances = <({int idx, double dist})>[];
    for (int j = 0; j < nodes.length; j++) {
      if (i == j) continue;
      final dx = nodes[i].x - nodes[j].x;
      final dy = nodes[i].y - nodes[j].y;
      final dz = nodes[i].z - nodes[j].z;
      final dist = math.sqrt(dx * dx + dy * dy + dz * dz);
      if (dist <= maxDist) {
        distances.add((idx: j, dist: dist));
      }
    }
    distances.sort((a, b) => a.dist.compareTo(b.dist));
    
    final connectCount = math.min(maxEdgesPerNode, distances.length);
    for (int k = 0; k < connectCount; k++) {
      final targetIdx = distances[k].idx;
      final exists = edges.any((e) =>
        (e.sourceId == nodes[i].id && e.targetId == nodes[targetIdx].id) ||
        (e.sourceId == nodes[targetIdx].id && e.targetId == nodes[i].id));
      if (!exists) {
        final weight = (1.0 - distances[k].dist / maxDist).clamp(0.4, 1.0);
        edges.add(ArcEdge3D(
          sourceId: nodes[i].id,
          targetId: nodes[targetIdx].id,
          weight: weight,
        ));
      }
    }
  }
  return edges;
}

/// Consolidation: Lattice - connect in geodesic pattern
List<ArcEdge3D> _generateLatticeEdges(List<ArcNode3D> nodes) {
  final edges = <ArcEdge3D>[];
  final maxDist = 1.8; // Larger distance for lattice connections
  final maxEdgesPerNode = 4;
  
  for (int i = 0; i < nodes.length; i++) {
    final distances = <({int idx, double dist})>[];
    for (int j = 0; j < nodes.length; j++) {
      if (i == j) continue;
      final dx = nodes[i].x - nodes[j].x;
      final dy = nodes[i].y - nodes[j].y;
      final dz = nodes[i].z - nodes[j].z;
      final dist = math.sqrt(dx * dx + dy * dy + dz * dz);
      if (dist <= maxDist) {
        distances.add((idx: j, dist: dist));
      }
    }
    distances.sort((a, b) => a.dist.compareTo(b.dist));
    
    final connectCount = math.min(maxEdgesPerNode, distances.length);
    for (int k = 0; k < connectCount; k++) {
      final targetIdx = distances[k].idx;
      final exists = edges.any((e) =>
        (e.sourceId == nodes[i].id && e.targetId == nodes[targetIdx].id) ||
        (e.sourceId == nodes[targetIdx].id && e.targetId == nodes[i].id));
      if (!exists) {
        final weight = (1.0 - distances[k].dist / maxDist).clamp(0.5, 1.0);
        edges.add(ArcEdge3D(
          sourceId: nodes[i].id,
          targetId: nodes[targetIdx].id,
          weight: weight,
        ));
      }
    }
  }
  return edges;
}

/// Default: Generic proximity-based connections
List<ArcEdge3D> _generateDefaultEdges(List<ArcNode3D> nodes, int maxEdgesPerNode, double maxDistance) {
  final edges = <ArcEdge3D>[];
  
  for (int i = 0; i < nodes.length; i++) {
    final distances = <({int idx, double dist})>[];
    for (int j = 0; j < nodes.length; j++) {
      if (i == j) continue;
      final dx = nodes[i].x - nodes[j].x;
      final dy = nodes[i].y - nodes[j].y;
      final dz = nodes[i].z - nodes[j].z;
      final dist = math.sqrt(dx * dx + dy * dy + dz * dz);
      if (dist <= maxDistance) {
        distances.add((idx: j, dist: dist));
      }
    }
    distances.sort((a, b) => a.dist.compareTo(b.dist));
    
    final connectCount = math.min(maxEdgesPerNode, distances.length);
    for (int k = 0; k < connectCount; k++) {
      final targetIdx = distances[k].idx;
      final exists = edges.any((e) =>
        (e.sourceId == nodes[i].id && e.targetId == nodes[targetIdx].id) ||
        (e.sourceId == nodes[targetIdx].id && e.targetId == nodes[i].id));
      if (!exists) {
        final weight = (1.0 - distances[k].dist / maxDistance).clamp(0.3, 1.0);
        edges.add(ArcEdge3D(
          sourceId: nodes[i].id,
          targetId: nodes[targetIdx].id,
          weight: weight,
        ));
      }
    }
  }
  
  return edges;
}

