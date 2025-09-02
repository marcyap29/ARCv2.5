import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:my_app/features/arcforms/arcform_mvp_implementation.dart';
import 'package:my_app/features/arcforms/widgets/spherical_node_widget.dart';

/// 3D Geometry layouts for Arcforms with true depth and dimensional positioning
class Geometry3DLayouts {
  /// Get 3D positions for a specific geometry with given nodes
  static List<Node3D> getPositions3D({
    required ArcformGeometry geometry,
    required int nodeCount,
    required Size canvasSize,
  }) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    List<Node3D> positions;
    
    switch (geometry) {
      case ArcformGeometry.spiral: // Discovery - DNA-like double helix
        positions = _createDNASpiral(nodeCount);
        break;
      case ArcformGeometry.flower: // Expansion - 3D flower with layered petals
        positions = _create3DFlower(nodeCount);
        break;
      case ArcformGeometry.branch: // Transition - 3D tree structure
        positions = _create3DBranch(nodeCount);
        break;
      case ArcformGeometry.weave: // Consolidation - 3D lattice weave
        positions = _create3DWeave(nodeCount);
        break;
      case ArcformGeometry.glowCore: // Recovery - Spherical shell layers
        positions = _create3DGlowCore(nodeCount);
        break;
      case ArcformGeometry.fractal: // Breakthrough - 3D fractal tree
        positions = _create3DFractal(nodeCount);
        break;
    }
    
    // Translate all positions to canvas center
    return positions.map((node) => Node3D(
      id: node.id,
      label: node.label,
      x: node.x + center.dx,
      y: node.y + center.dy,
      z: node.z,
      size: node.size,
      color: node.color,
    )).toList();
  }

  /// DNA-like double helix spiral for Discovery phase
  static List<Node3D> _createDNASpiral(int nodeCount) {
    final nodes = <Node3D>[];
    const radius = 80.0;
    const height = 200.0;
    const helixTurns = 2.0; // Number of complete turns
    
    for (int i = 0; i < nodeCount; i++) {
      final t = i / (nodeCount - 1); // Parameter from 0 to 1
      final angle = t * helixTurns * 2 * math.pi;
      
      // Create double helix with alternating strands
      final isFirstStrand = i % 2 == 0;
      final strandRadius = isFirstStrand ? radius : radius * 0.8;
      final phaseOffset = isFirstStrand ? 0 : math.pi;
      
      final x = strandRadius * math.cos(angle + phaseOffset);
      final z = strandRadius * math.sin(angle + phaseOffset);
      final y = -height / 2 + t * height; // Vertical progression
      
      nodes.add(Node3D(
        id: 'spiral_$i',
        label: 'Node $i',
        x: x,
        y: y,
        z: z,
        size: 20.0 + (math.sin(angle) * 5), // Variable size for visual interest
      ));
    }
    
    return nodes;
  }

  /// 3D flower with layered petals for Expansion phase
  static List<Node3D> _create3DFlower(int nodeCount) {
    final nodes = <Node3D>[];
    const maxRadius = 100.0;
    const layers = 3;
    final nodesPerLayer = nodeCount ~/ layers;
    
    // Center node
    nodes.add(Node3D(
      id: 'flower_center',
      label: 'Center',
      x: 0,
      y: 0,
      z: 0,
      size: 25.0,
    ));
    
    int nodeIndex = 1;
    for (int layer = 0; layer < layers && nodeIndex < nodeCount; layer++) {
      final layerRadius = maxRadius * (layer + 1) / layers;
      final layerHeight = layer * 30.0 - 45.0; // Stagger heights
      final nodesInThisLayer = math.min(nodesPerLayer, nodeCount - nodeIndex);
      
      for (int i = 0; i < nodesInThisLayer; i++) {
        final angle = (2 * math.pi * i) / nodesInThisLayer;
        
        // Create petal shape with curves
        final petalCurve = 1.0 + 0.3 * math.cos(angle * 5); // Petal undulation
        final radius = layerRadius * petalCurve;
        
        final x = radius * math.cos(angle);
        final z = radius * math.sin(angle);
        final y = layerHeight + 10 * math.sin(angle * 3); // Vertical wave
        
        nodes.add(Node3D(
          id: 'flower_${layer}_$i',
          label: 'Petal $nodeIndex',
          x: x,
          y: y,
          z: z,
          size: 20.0 - layer * 2,
        ));
        
        nodeIndex++;
      }
    }
    
    return nodes;
  }

  /// 3D tree structure for Transition phase
  static List<Node3D> _create3DBranch(int nodeCount) {
    final nodes = <Node3D>[];
    
    // Root node
    nodes.add(Node3D(
      id: 'branch_root',
      label: 'Root',
      x: 0,
      y: 0,
      z: 0,
      size: 25.0,
    ));
    
    if (nodeCount > 1) {
      _addBranchRecursive(
        nodes,
        parent: nodes[0],
        remainingNodes: nodeCount - 1,
        depth: 0,
        maxDepth: 3,
        branchAngle: 0,
      );
    }
    
    return nodes;
  }

  static void _addBranchRecursive(
    List<Node3D> nodes,
    {required Node3D parent,
    required int remainingNodes,
    required int depth,
    required int maxDepth,
    required double branchAngle,
  }) {
    if (remainingNodes <= 0 || depth >= maxDepth) return;
    
    final branchCount = math.min(3, remainingNodes); // Up to 3 branches per node
    final branchLength = 60.0 * math.pow(0.7, depth); // Shorter branches at higher depths
    
    for (int i = 0; i < branchCount; i++) {
      final angle = branchAngle + (i - 1) * (math.pi / 3); // Spread branches
      final elevationAngle = math.pi / 6 + (depth * math.pi / 12); // Upward angle
      
      final x = parent.x + branchLength * math.cos(angle) * math.cos(elevationAngle);
      final z = parent.z + branchLength * math.sin(angle) * math.cos(elevationAngle);
      final y = parent.y - branchLength * math.sin(elevationAngle); // Grow upward (negative Y)
      
      final branchNode = Node3D(
        id: 'branch_${depth}_$i',
        label: 'Branch ${nodes.length}',
        x: x,
        y: y,
        z: z,
        size: 20.0 - depth * 3,
      );
      
      nodes.add(branchNode);
      
      // Recursively add sub-branches
      _addBranchRecursive(
        nodes,
        parent: branchNode,
        remainingNodes: remainingNodes - 1,
        depth: depth + 1,
        maxDepth: maxDepth,
        branchAngle: angle,
      );
    }
  }

  /// 3D lattice weave for Consolidation phase
  static List<Node3D> _create3DWeave(int nodeCount) {
    final nodes = <Node3D>[];
    final gridSize = math.pow(nodeCount, 1/3).ceil(); // Cubic root for 3D grid
    const spacing = 60.0;
    
    int nodeIndex = 0;
    for (int x = 0; x < gridSize && nodeIndex < nodeCount; x++) {
      for (int y = 0; y < gridSize && nodeIndex < nodeCount; y++) {
        for (int z = 0; z < gridSize && nodeIndex < nodeCount; z++) {
          // Create weaving pattern by offsetting alternate layers
          final offsetX = (y % 2) * (spacing / 3);
          final offsetZ = (x % 2) * (spacing / 3);
          
          final posX = (x - gridSize / 2) * spacing + offsetX;
          final posY = (y - gridSize / 2) * spacing;
          final posZ = (z - gridSize / 2) * spacing + offsetZ;
          
          nodes.add(Node3D(
            id: 'weave_${x}_${y}_$z',
            label: 'Weave $nodeIndex',
            x: posX,
            y: posY,
            z: posZ,
            size: 18.0,
          ));
          
          nodeIndex++;
        }
      }
    }
    
    return nodes;
  }

  /// Spherical shell layers for Recovery phase
  static List<Node3D> _create3DGlowCore(int nodeCount) {
    final nodes = <Node3D>[];
    const maxRadius = 120.0;
    const shells = 3;
    
    // Core node
    nodes.add(Node3D(
      id: 'glow_core',
      label: 'Core',
      x: 0,
      y: 0,
      z: 0,
      size: 30.0,
    ));
    
    int nodeIndex = 1;
    for (int shell = 0; shell < shells && nodeIndex < nodeCount; shell++) {
      final shellRadius = maxRadius * (shell + 1) / shells;
      final nodesInShell = (nodeCount - 1) ~/ shells;
      
      for (int i = 0; i < nodesInShell && nodeIndex < nodeCount; i++) {
        // Use Fibonacci spiral for even distribution on sphere
        final phi = math.acos(1 - 2 * (i + 0.5) / nodesInShell);
        final theta = math.pi * (1 + math.sqrt(5)) * (i + 0.5);
        
        final x = shellRadius * math.sin(phi) * math.cos(theta);
        final y = shellRadius * math.sin(phi) * math.sin(theta);
        final z = shellRadius * math.cos(phi);
        
        nodes.add(Node3D(
          id: 'glow_${shell}_$i',
          label: 'Shell $nodeIndex',
          x: x,
          y: y,
          z: z,
          size: 20.0 - shell * 2,
        ));
        
        nodeIndex++;
      }
    }
    
    return nodes;
  }

  /// 3D fractal tree for Breakthrough phase
  static List<Node3D> _create3DFractal(int nodeCount) {
    final nodes = <Node3D>[];
    
    // Root node
    nodes.add(Node3D(
      id: 'fractal_root',
      label: 'Root',
      x: 0,
      y: 0,
      z: 0,
      size: 25.0,
    ));
    
    if (nodeCount > 1) {
      _addFractalBranches3D(
        nodes,
        center: nodes[0],
        initialRadius: 80.0,
        remainingNodes: nodeCount - 1,
        depth: 0,
      );
    }
    
    return nodes;
  }

  static void _addFractalBranches3D(
    List<Node3D> nodes,
    {required Node3D center,
    required double initialRadius,
    required int remainingNodes,
    required int depth,
  }) {
    if (remainingNodes <= 0 || depth > 3) return;
    
    const branchAngles = [
      [0, math.pi/4], // Forward-up
      [math.pi/2, math.pi/4], // Right-up
      [math.pi, math.pi/4], // Back-up
      [3*math.pi/2, math.pi/4], // Left-up
      [math.pi/4, -math.pi/6], // Forward-right-down
      [3*math.pi/4, -math.pi/6], // Back-right-down
    ];
    
    final branchCount = math.min(branchAngles.length, remainingNodes);
    final radius = initialRadius * math.pow(0.6, depth);
    
    for (int i = 0; i < branchCount; i++) {
      final azimuth = branchAngles[i][0];
      final elevation = branchAngles[i][1];
      
      final x = center.x + radius * math.cos(elevation) * math.cos(azimuth);
      final y = center.y - radius * math.sin(elevation); // Negative Y for upward growth
      final z = center.z + radius * math.cos(elevation) * math.sin(azimuth);
      
      final branchNode = Node3D(
        id: 'fractal_${depth}_$i',
        label: 'Fractal ${nodes.length}',
        x: x,
        y: y,
        z: z,
        size: 20.0 - depth * 2,
      );
      
      nodes.add(branchNode);
      
      // Recursive fractal branching
      _addFractalBranches3D(
        nodes,
        center: branchNode,
        initialRadius: radius,
        remainingNodes: remainingNodes - 1,
        depth: depth + 1,
      );
    }
  }
}