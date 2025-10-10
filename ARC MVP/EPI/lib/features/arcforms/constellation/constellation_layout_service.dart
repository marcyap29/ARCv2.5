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

    // Take top 5-10 keywords as primaries
    final primaryKeywords = sortedKeywords.take(10).toList();
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
      
      // Apply collision avoidance
      final random = math.Random(seed + i);
      final finalPos = _avoidCollisions(pos, nodes, random);
      
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

    // Use k-NN to find connections
    final k = _getKForPhase(phase, nodes.length);
    final connections = GraphUtils.findKNearestNeighbors(nodes, k);

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
        return _generateBranchPositions(count, random);
      case AtlasPhase.consolidation:
        return _generateWeavePositions(count, random);
      case AtlasPhase.recovery:
        return _generateGlowCorePositions(count, random);
      case AtlasPhase.breakthrough:
        return _generateFractalPositions(count, random);
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

  /// Generate branch positions for Transition phase
  List<Offset> _generateBranchPositions(int count, math.Random random) {
    final positions = <Offset>[];
    const mainBranches = 3;
    const maxRadius = 140.0;
    
    for (int i = 0; i < count; i++) {
      final branchIndex = i % mainBranches;
      final branchAngle = (branchIndex / mainBranches) * 2 * math.pi;
      
      // Create longer arcs with side shoots
      final t = random.nextDouble();
      final radius = t * maxRadius;
      
      // Add side shoot variation
      final sideShoot = random.nextDouble() > 0.7;
      final angle = sideShoot 
          ? branchAngle + (random.nextDouble() - 0.5) * 1.0
          : branchAngle;
      
      final x = radius * math.cos(angle);
      final y = radius * math.sin(angle);
      
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

  /// Generate glow core positions for Recovery phase
  List<Offset> _generateGlowCorePositions(int count, math.Random random) {
    final positions = <Offset>[];
    const coreRadius = 30.0;
    const maxRadius = 120.0;
    
    for (int i = 0; i < count; i++) {
      if (i == 0) {
        // Bright centroid
        positions.add(Offset.zero);
      } else {
        // Sparse dim outliers
        final angle = random.nextDouble() * 2 * math.pi;
        final radius = coreRadius + random.nextDouble() * (maxRadius - coreRadius);
        
        final x = radius * math.cos(angle);
        final y = radius * math.sin(angle);
        
        positions.add(Offset(x, y));
      }
    }
    
    return positions;
  }

  /// Generate fractal positions for Breakthrough phase
  List<Offset> _generateFractalPositions(int count, math.Random random) {
    final positions = <Offset>[];
    const clusters = 3;
    const clusterRadius = 60.0;
    const maxRadius = 130.0;
    
    for (int i = 0; i < count; i++) {
      final clusterIndex = i % clusters;
      final clusterAngle = (clusterIndex / clusters) * 2 * math.pi;
      
      // Create clustered bursts
      final clusterCenter = Offset(
        clusterRadius * math.cos(clusterAngle),
        clusterRadius * math.sin(clusterAngle),
      );
      
      // Add short bridges between clusters
      final t = random.nextDouble();
      final radius = t * (maxRadius - clusterRadius);
      
      final angle = random.nextDouble() * 2 * math.pi;
      final offset = Offset(
        radius * math.cos(angle),
        radius * math.sin(angle),
      );
      
      positions.add(clusterCenter + offset);
    }
    
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
