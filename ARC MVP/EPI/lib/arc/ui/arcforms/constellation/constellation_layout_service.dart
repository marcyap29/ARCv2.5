import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/emotional_valence_service.dart';
import 'constellation_arcform_renderer.dart';
import 'graph_utils.dart';

/// Service for generating constellation layouts based on ATLAS phases
class ConstellationLayoutService {
  static const double _minNodeSize = 4.0;
  static const double _maxNodeSize = 12.0;
  static const double _collisionThreshold = 40.0;

  /// Place stars in constellation pattern based on phase
  List<ConstellationNode> placeStars(
    AtlasPhase phase,
    List<KeywordScore> keywords,
    int seed,
    EmotionPalette palette,
    EmotionalValenceService emotionalService,
  ) {
    if (keywords.isEmpty) return [];

    // Sort keywords by score (highest first)
    final sortedKeywords = List<KeywordScore>.from(keywords)
      ..sort((a, b) => b.score.compareTo(a.score));

    // Take top keywords as primaries
    // For breakthrough phase, use exactly 11 nodes (1 center + 5 middle + 5 outer)
    final keywordCount = phase == AtlasPhase.breakthrough ? 11 : 10;
    final primaryKeywords = sortedKeywords.take(keywordCount).toList();
    final remainingKeywords = sortedKeywords.skip(10).take(10).toList();

    final nodes = <ConstellationNode>[];

    // Generate primary star positions using phase-specific polar mask
    final primaryPositions = _generatePrimaryPositions(
      phase,
      primaryKeywords.length,
      seed,
    );

    // Create primary nodes
    for (int i = 0; i < primaryKeywords.length; i++) {
      final keyword = primaryKeywords[i];
      final pos = primaryPositions[i];
      
      // For breakthrough phase, skip collision avoidance to preserve perfect star shape
      final finalPos = (phase == AtlasPhase.breakthrough) ? pos : _avoidCollisions(pos, nodes, math.Random(seed + i));
      
      // Calculate node properties
      final normalizedScore = _normalizeScore(keyword.score);
      final radius = _minNodeSize + (normalizedScore * (_maxNodeSize - _minNodeSize));
      final color = _getNodeColor(keyword, palette, emotionalService);
      
      nodes.add(ConstellationNode(
        pos: finalPos,
        data: keyword,
        radius: radius,
        color: color,
        id: 'primary_$i',
      ));
    }

    // Generate satellite positions for remaining keywords
    final satellitePositions = _generateSatellitePositions(
      phase,
      remainingKeywords.length,
      primaryPositions,
      seed + 1000, // Different seed for satellites
    );

    // Create satellite nodes
    for (int i = 0; i < remainingKeywords.length; i++) {
      final keyword = remainingKeywords[i];
      final pos = satellitePositions[i];
      
      // Apply collision avoidance
      final random = math.Random(seed + 1000 + i);
      final finalPos = _avoidCollisions(pos, nodes, random);
      
      // Calculate node properties (smaller and dimmer)
      final normalizedScore = _normalizeScore(keyword.score);
      final radius = _minNodeSize + (normalizedScore * (_maxNodeSize - _minNodeSize)) * 0.6;
      final color = _getNodeColor(keyword, palette, emotionalService).withOpacity(0.7);
      
      nodes.add(ConstellationNode(
        pos: finalPos,
        data: keyword,
        radius: radius,
        color: color,
        id: 'satellite_$i',
      ));
    }

    return nodes;
  }

  /// Generate edges between nodes using k-NN algorithm
  List<ConstellationEdge> weaveConstellation(
    List<ConstellationNode> nodes,
    AtlasPhase phase,
    int seed,
  ) {
    if (nodes.length < 2) return [];

    final edges = <ConstellationEdge>[];

    // For breakthrough phase, use star pattern connections instead of k-NN
    List<Connection> connections;
    if (phase == AtlasPhase.breakthrough) {
      connections = GraphUtils.generatePhaseConnections(nodes, phase);
    } else {
      // Use k-NN to find connections for other phases
      final k = _getKForPhase(phase, nodes.length);
      connections = GraphUtils.findKNearestNeighbors(nodes, k);
    }

    // Create edges with weights based on distance and phase rules
    for (final connection in connections) {
      final nodeA = nodes[connection.a];
      final nodeB = nodes[connection.b];
      final distance = (nodeA.pos - nodeB.pos).distance;
      
      // Calculate weight based on distance and phase-specific rules
      final weight = _calculateEdgeWeight(distance, phase, nodeA, nodeB);
      
      // Apply phase-specific edge filtering
      if (_shouldCreateEdge(phase, nodeA, nodeB, weight)) {
        edges.add(ConstellationEdge(
          a: connection.a,
          b: connection.b,
          weight: weight,
        ));
      }
    }

    return edges;
  }

  /// Generate primary star positions using phase-specific polar masks
  List<Offset> _generatePrimaryPositions(
    AtlasPhase phase,
    int count,
    int seed,
  ) {
    final random = math.Random(seed);
    final positions = <Offset>[];

    switch (phase) {
      case AtlasPhase.discovery:
        return _generateSpiralPositions(count, random);
      case AtlasPhase.expansion:
        return _generateFlowerPositions(count, random);
      case AtlasPhase.transition:
        print('🌟 Constellation: Generating BRIDGE positions for Transition phase');
        return _generateBridgePositions(count, random);
      case AtlasPhase.consolidation:
        return _generateWeavePositions(count, random);
      case AtlasPhase.recovery:
        print('🌟 Constellation: Generating ASCENDING SPIRAL positions for Recovery phase');
        return _generateAscendingSpiralPositions(count, random);
      case AtlasPhase.breakthrough:
        print('🌟 Constellation: Generating SUPERNOVA positions for Breakthrough phase');
        return _generateSupernovaPositions(count, random);
    }
  }

  /// Generate satellite positions around primary stars
  List<Offset> _generateSatellitePositions(
    AtlasPhase phase,
    int count,
    List<Offset> primaryPositions,
    int seed,
  ) {
    if (primaryPositions.isEmpty) return [];
    
    final random = math.Random(seed);

    for (int i = 0; i < count; i++) {
      // Choose a random primary position as base
      final basePos = primaryPositions[random.nextInt(primaryPositions.length)];
      
      // Add random offset within phase-specific range
      final offset = _getSatelliteOffset(phase, random);
      // positions.add(basePos + offset);
    }

    return <Offset>[];
  }

  /// Generate spiral positions for Discovery phase
  List<Offset> _generateSpiralPositions(int count, math.Random random) {
    final positions = <Offset>[];
    const goldenAngle = 2.39996322972865332; // Golden angle in radians
    const maxRadius = 150.0;
    
    for (int i = 0; i < count; i++) {
      final angle = i * goldenAngle;
      final radius = (i / (count - 1)) * maxRadius;
      
      final x = radius * math.cos(angle);
      final y = radius * math.sin(angle);
      
      // Add gentle outward drift
      final drift = random.nextDouble() * 20.0 - 10.0;
      positions.add(Offset(x + drift, y + drift));
    }
    
    return positions;
  }

  /// Generate flower positions for Expansion phase
  List<Offset> _generateFlowerPositions(int count, math.Random random) {
    final positions = <Offset>[];
    const petals = 6;
    const maxRadius = 120.0;
    
    for (int i = 0; i < count; i++) {
      final petalIndex = i % petals;
      final petalAngle = (petalIndex / petals) * 2 * math.pi;
      
      // Vary radius within petal
      final radius = (random.nextDouble() * 0.7 + 0.3) * maxRadius;
      
      // Add some randomness to petal shape
      final angleOffset = (random.nextDouble() - 0.5) * 0.5;
      final angle = petalAngle + angleOffset;
      
      final x = radius * math.cos(angle);
      final y = radius * math.sin(angle);
      
      positions.add(Offset(x, y));
    }
    
    return positions;
  }

  /// Generate gateway/bridge positions for Transition phase
  /// Creates two clusters (departure/destination) connected by a bridge
  List<Offset> _generateBridgePositions(int count, math.Random random) {
    print('🌉 Generating BRIDGE pattern: $count nodes');
    final positions = <Offset>[];
    const leftClusterCenter = Offset(-80.0, 0.0);
    const rightClusterCenter = Offset(80.0, 0.0);
    const clusterRadius = 50.0;
    const bridgeWidth = 30.0;
    const bridgeHeight = 40.0;
    
    // Split nodes: 40% left cluster, 40% right cluster, 20% bridge
    final leftCount = (count * 0.4).round();
    final rightCount = (count * 0.4).round();
    final bridgeCount = count - leftCount - rightCount;
    
    // Left cluster (departure state) - semicircle on left
    for (int i = 0; i < leftCount; i++) {
      final angle = (i / leftCount) * math.pi + math.pi / 2; // Semicircle (90° to 270°)
      final radius = (random.nextDouble() * 0.7 + 0.3) * clusterRadius;
      final x = leftClusterCenter.dx + radius * math.cos(angle);
      final y = leftClusterCenter.dy + radius * math.sin(angle);
      positions.add(Offset(x, y));
    }
    
    // Bridge nodes - arch connecting the two clusters
    for (int i = 0; i < bridgeCount; i++) {
      final t = bridgeCount > 1 ? i / (bridgeCount - 1) : 0.5; // 0 to 1, or 0.5 if only one node
      // Create arch shape: x varies linearly, y follows parabolic arch
      final x = -bridgeWidth + t * (bridgeWidth * 2);
      final y = -bridgeHeight * (t * (1 - t)) * 4; // Parabolic arch (inverted)
      positions.add(Offset(x, y));
    }
    
    // Right cluster (destination state) - semicircle on right
    for (int i = 0; i < rightCount; i++) {
      final angle = (i / rightCount) * math.pi - math.pi / 2; // Semicircle (-90° to 90°)
      final radius = (random.nextDouble() * 0.7 + 0.3) * clusterRadius;
      final x = rightClusterCenter.dx + radius * math.cos(angle);
      final y = rightClusterCenter.dy + radius * math.sin(angle);
      positions.add(Offset(x, y));
    }
    
    return positions;
  }

  /// Generate weave positions for Consolidation phase
  List<Offset> _generateWeavePositions(int count, math.Random random) {
    final positions = <Offset>[];
    const innerRadius = 40.0;
    const outerRadius = 100.0;
    
    for (int i = 0; i < count; i++) {
      // Create inner lattice bias with tighter radii
      final t = random.nextDouble();
      final radius = innerRadius + t * (outerRadius - innerRadius);
      
      // Add lattice-like angular distribution
      final angle = (i * 2 * math.pi / count) + (random.nextDouble() - 0.5) * 0.5;
      
      final x = radius * math.cos(angle);
      final y = radius * math.sin(angle);
      
      positions.add(Offset(x, y));
    }
    
    return positions;
  }

  /// Generate ascending spiral positions for Recovery phase
  /// Creates upward-winding spiral suggesting gradual healing and restoration
  List<Offset> _generateAscendingSpiralPositions(int count, math.Random random) {
    print('🌀 Generating ASCENDING SPIRAL pattern: $count nodes');
    final positions = <Offset>[];
    const maxRadius = 120.0;
    const verticalSpread = 80.0; // How much upward movement
    const turns = 1.8; // Number of spiral turns
    
    for (int i = 0; i < count; i++) {
      final t = i / (count - 1); // Normalized position (0 to 1)
      
      // Spiral angle - winds multiple times
      final angle = t * turns * 2 * math.pi;
      
      // Radius expands as spiral winds upward
      final radius = t * maxRadius;
      
      // Horizontal position from spiral
      final x = radius * math.cos(angle);
      
      // Vertical position: moves upward as spiral expands (healing progression)
      // Start at base, move upward
      final y = -verticalSpread * (1 - t) + t * verticalSpread * 0.3;
      
      // Add small random variation for organic feel
      final jitterX = (random.nextDouble() - 0.5) * 8.0;
      final jitterY = (random.nextDouble() - 0.5) * 8.0;
      
      positions.add(Offset(x + jitterX, y + jitterY));
    }
    
    return positions;
  }

  /// Generate supernova/starburst positions for Breakthrough phase
  /// Creates perfect 3-ring star structure: 1 center + 5 middle + 5 outer = 11 nodes
  /// Center at origin, middle ring at radius 80, outer ring at radius 160
  List<Offset> _generateSupernovaPositions(int count, math.Random random) {
    print('⭐ Generating SUPERNOVA pattern: $count nodes (3-ring star)');
    final positions = <Offset>[];
    
    // Force exactly 11 nodes for breakthrough star structure
    final nodeCount = math.min(count, 11);
    
    // 1. Center node (index 0) - at origin
    positions.add(Offset.zero);
    
    if (nodeCount < 2) return positions;
    
    // 2. Middle ring: 5 nodes at radius 80, separated by exactly 72 degrees
    // Starting angle offset by -90 degrees so first node is at top (12 o'clock)
    const middleRadius = 80.0;
    const angleStep = 2 * math.pi / 5; // 72 degrees
    const startAngle = -math.pi / 2; // Start at top (-90 degrees)
    
    for (int i = 0; i < 5 && positions.length < nodeCount; i++) {
      final angle = startAngle + (i * angleStep);
      final x = middleRadius * math.cos(angle);
      final y = middleRadius * math.sin(angle);
      positions.add(Offset(x, y));
      print('⭐ Middle ring node $i: angle=${(angle * 180 / math.pi).toStringAsFixed(1)}°, pos=(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})');
    }
    
    if (positions.length >= nodeCount) return positions;
    
    // 3. Outer ring: 5 nodes at radius 160, separated by exactly 72 degrees (aligned with middle ring)
    const outerRadius = 160.0;
    
    for (int i = 0; i < 5 && positions.length < nodeCount; i++) {
      final angle = startAngle + (i * angleStep); // Same 72-degree spacing, aligned with middle
      final x = outerRadius * math.cos(angle);
      final y = outerRadius * math.sin(angle);
      positions.add(Offset(x, y));
      print('⭐ Outer ring node $i: angle=${(angle * 180 / math.pi).toStringAsFixed(1)}°, pos=(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})');
    }
    
    print('⭐ SUPERNOVA: Generated ${positions.length} positions (expected 11)');
    return positions;
  }

  /// Get satellite offset based on phase
  Offset _getSatelliteOffset(AtlasPhase phase, math.Random random) {
    const baseDistance = 40.0;
    final distance = baseDistance + random.nextDouble() * 30.0;
    final angle = random.nextDouble() * 2 * math.pi;
    
    return Offset(
      distance * math.cos(angle),
      distance * math.sin(angle),
    );
  }

  /// Apply collision avoidance to position
  Offset _avoidCollisions(Offset pos, List<ConstellationNode> existingNodes, math.Random random) {
    Offset finalPos = pos;
    int attempts = 0;
    const maxAttempts = 10;
    
    while (attempts < maxAttempts) {
      bool hasCollision = false;
      
      for (final node in existingNodes) {
        final distance = (finalPos - node.pos).distance;
        if (distance < _collisionThreshold) {
          hasCollision = true;
          break;
        }
      }
      
      if (!hasCollision) break;
      
      // Nudge position
      final offset = Offset(
        (random.nextDouble() - 0.5) * 20.0,
        (random.nextDouble() - 0.5) * 20.0,
      );
      finalPos = pos + offset;
      attempts++;
    }
    
    return finalPos;
  }

  /// Normalize score to 0-1 range
  double _normalizeScore(double score) {
    // Assuming scores are already in reasonable range, just clamp
    return score.clamp(0.0, 1.0);
  }

  /// Get node color based on keyword and emotional valence
  Color _getNodeColor(KeywordScore keyword, EmotionPalette palette, EmotionalValenceService emotionalService) {
    final valence = emotionalService.getEmotionalValence(keyword.text);
    
    if (valence > 0.3) {
      // Positive - use warm colors
      return palette.primaryColors[0]; // Blue
    } else if (valence < -0.3) {
      // Negative - use cool colors
      return palette.primaryColors[2]; // Light purple
    } else {
      // Neutral - use neutral color
      return palette.neutralColor;
    }
  }

  /// Get k value for k-NN based on phase
  int _getKForPhase(AtlasPhase phase, int nodeCount) {
    switch (phase) {
      case AtlasPhase.discovery:
        return math.min(2, nodeCount - 1);
      case AtlasPhase.expansion:
        return math.min(3, nodeCount - 1);
      case AtlasPhase.transition:
        return math.min(2, nodeCount - 1);
      case AtlasPhase.consolidation:
        return math.min(4, nodeCount - 1);
      case AtlasPhase.recovery:
        return math.min(1, nodeCount - 1);
      case AtlasPhase.breakthrough:
        return math.min(3, nodeCount - 1);
    }
  }

  /// Calculate edge weight based on distance and phase
  double _calculateEdgeWeight(double distance, AtlasPhase phase, ConstellationNode nodeA, ConstellationNode nodeB) {
    // Base weight inversely proportional to distance
    final baseWeight = 1.0 / (1.0 + distance / 50.0);
    
    // Phase-specific adjustments
    switch (phase) {
      case AtlasPhase.discovery:
        return baseWeight * 0.8; // Lighter connections
      case AtlasPhase.expansion:
        return baseWeight * 1.2; // Stronger connections
      case AtlasPhase.transition:
        return baseWeight * 0.6; // Weaker connections
      case AtlasPhase.consolidation:
        return baseWeight * 1.4; // Strongest connections
      case AtlasPhase.recovery:
        return baseWeight * 0.4; // Very light connections
      case AtlasPhase.breakthrough:
        return baseWeight * 1.0; // Balanced connections
    }
  }

  /// Determine if edge should be created based on phase rules
  bool _shouldCreateEdge(AtlasPhase phase, ConstellationNode nodeA, ConstellationNode nodeB, double weight) {
    // Base threshold
    const baseThreshold = 0.3;
    
    // Phase-specific thresholds
    switch (phase) {
      case AtlasPhase.discovery:
        return weight > baseThreshold * 0.8;
      case AtlasPhase.expansion:
        return weight > baseThreshold * 0.6;
      case AtlasPhase.transition:
        return weight > baseThreshold * 1.2;
      case AtlasPhase.consolidation:
        return weight > baseThreshold * 0.5;
      case AtlasPhase.recovery:
        return weight > baseThreshold * 1.5;
      case AtlasPhase.breakthrough:
        return weight > baseThreshold * 0.7;
    }
  }
}
