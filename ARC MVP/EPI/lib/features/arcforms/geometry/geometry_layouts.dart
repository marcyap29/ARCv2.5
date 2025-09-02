import 'package:flutter/material.dart';
import 'package:my_app/features/arcforms/arcform_mvp_implementation.dart';
import 'package:my_app/features/arcforms/geometry/spiral_layout.dart';
import 'dart:math' as math;

/// Registry for geometry layout algorithms
class GeometryLayouts {
  /// Get layout positions for a specific geometry with given nodes
  static List<Offset> getPositions({
    required ArcformGeometry geometry,
    required int nodeCount,
    required Size canvasSize,
  }) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    List<Offset> positions;
    
    switch (geometry) {
      case ArcformGeometry.spiral: // Discovery
        positions = SpiralLayout.positions(nodeCount, step: 25);
        break;
      case ArcformGeometry.flower: // Expansion
        positions = _flowerLayout(nodeCount);
        break;
      case ArcformGeometry.branch: // Transition
        positions = _branchLayout(nodeCount);
        break;
      case ArcformGeometry.weave: // Consolidation
        positions = _weaveLayout(nodeCount);
        break;
      case ArcformGeometry.glowCore: // Recovery
        positions = _glowCoreLayout(nodeCount);
        break;
      case ArcformGeometry.fractal: // Breakthrough
        positions = _fractalLayout(nodeCount);
        break;
    }
    
    // Translate all positions to canvas center
    return positions.map((pos) => pos + center).toList();
  }
  
  /// Validates that a layout produces good visual distribution
  static bool validateLayout({
    required ArcformGeometry geometry,
    required List<Offset> positions,
  }) {
    if (positions.length < 2) return true;
    
    // Check for clustering - ensure minimum distance between nodes
    const minDistance = 30.0;
    for (int i = 0; i < positions.length; i++) {
      for (int j = i + 1; j < positions.length; j++) {
        final distance = (positions[i] - positions[j]).distance;
        if (distance < minDistance) {
          return false;
        }
      }
    }
    
    // Special validation for spiral (Discovery)
    if (geometry == ArcformGeometry.spiral) {
      return SpiralLayout.isValidSpiral(
        positions.map((pos) => pos - positions.first).toList()
      );
    }
    
    return true;
  }
}

/// Flower layout - petals radiating outward (Expansion)
List<Offset> _flowerLayout(int nodeCount) {
  final positions = <Offset>[];
  final angleStep = (2 * math.pi) / nodeCount;
  
  for (int i = 0; i < nodeCount; i++) {
    final angle = i * angleStep;
    final radius = 60 + (i % 3) * 20; // Vary radius for petal effect
    final x = radius * math.cos(angle);
    final y = radius * math.sin(angle);
    positions.add(Offset(x, y));
  }
  
  return positions;
}

/// Branch layout - tree-like structure (Transition)
List<Offset> _branchLayout(int nodeCount) {
  final positions = <Offset>[];
  
  // Root node at center
  positions.add(Offset.zero);
  
  if (nodeCount > 1) {
    // Primary branches
    final branchCount = math.min(nodeCount - 1, 4);
    final angleStep = (2 * math.pi) / branchCount;
    
    for (int i = 0; i < branchCount; i++) {
      final angle = i * angleStep - math.pi / 2; // Start from top
      const radius = 80;
      final x = radius * math.cos(angle);
      final y = radius * math.sin(angle);
      positions.add(Offset(x, y));
    }
    
    // Secondary branches for remaining nodes
    final remaining = nodeCount - 1 - branchCount;
    for (int i = 0; i < remaining; i++) {
      final parentIndex = (i % branchCount) + 1;
      final parent = positions[parentIndex];
      final offset = Offset(
        (math.Random().nextDouble() - 0.5) * 40,
        (math.Random().nextDouble() - 0.5) * 40,
      );
      positions.add(parent + offset);
    }
  }
  
  return positions;
}

/// Weave layout - interlaced pattern (Consolidation)
List<Offset> _weaveLayout(int nodeCount) {
  final positions = <Offset>[];
  final gridSize = math.sqrt(nodeCount).ceil();
  const spacing = 60.0;
  
  for (int i = 0; i < nodeCount; i++) {
    final row = i ~/ gridSize;
    final col = i % gridSize;
    
    // Offset every other row for weaving effect
    final offsetX = (row % 2) * (spacing / 2);
    final x = (col * spacing) - ((gridSize - 1) * spacing / 2) + offsetX;
    final y = (row * spacing) - ((gridSize - 1) * spacing / 2);
    
    positions.add(Offset(x, y));
  }
  
  return positions;
}

/// Glow core layout - central cluster with emanating points (Recovery)
List<Offset> _glowCoreLayout(int nodeCount) {
  final positions = <Offset>[];
  
  // Central core
  positions.add(Offset.zero);
  
  if (nodeCount > 1) {
    // Inner ring
    final innerCount = math.min(nodeCount - 1, 6);
    const innerRadius = 40.0;
    final innerStep = (2 * math.pi) / innerCount;
    
    for (int i = 0; i < innerCount; i++) {
      final angle = i * innerStep;
      final x = innerRadius * math.cos(angle);
      final y = innerRadius * math.sin(angle);
      positions.add(Offset(x, y));
    }
    
    // Outer ring for remaining nodes
    final remaining = nodeCount - 1 - innerCount;
    const outerRadius = 80.0;
    final outerStep = (2 * math.pi) / math.max(remaining, 1);
    
    for (int i = 0; i < remaining; i++) {
      final angle = i * outerStep + math.pi / 4; // Offset from inner ring
      final x = outerRadius * math.cos(angle);
      final y = outerRadius * math.sin(angle);
      positions.add(Offset(x, y));
    }
  }
  
  return positions;
}

/// Fractal layout - self-similar branching (Breakthrough)
List<Offset> _fractalLayout(int nodeCount) {
  final positions = <Offset>[];
  
  // Start with central node
  positions.add(Offset.zero);
  
  if (nodeCount > 1) {
    // Create fractal branches using recursive division
    _addFractalBranches(
      positions,
      center: Offset.zero,
      radius: 100,
      angle: -math.pi / 2,
      depth: 0,
      maxNodes: nodeCount - 1,
    );
  }
  
  return positions;
}

void _addFractalBranches(
  List<Offset> positions,
  {required Offset center,
  required double radius,
  required double angle,
  required int depth,
  required int maxNodes,
}) {
  if (positions.length >= maxNodes + 1 || depth > 3) return;
  
  // Add main branch node
  final x = center.dx + radius * math.cos(angle);
  final y = center.dy + radius * math.sin(angle);
  final branchNode = Offset(x, y);
  positions.add(branchNode);
  
  if (positions.length >= maxNodes + 1) return;
  
  // Add sub-branches
  final subRadius = radius * 0.6;
  final leftAngle = angle - math.pi / 4;
  final rightAngle = angle + math.pi / 4;
  
  _addFractalBranches(
    positions,
    center: branchNode,
    radius: subRadius,
    angle: leftAngle,
    depth: depth + 1,
    maxNodes: maxNodes,
  );
  
  _addFractalBranches(
    positions,
    center: branchNode,
    radius: subRadius,
    angle: rightAngle,
    depth: depth + 1,
    maxNodes: maxNodes,
  );
}