import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:my_app/arc/arcform/layouts/layouts_3d.dart';
import 'package:my_app/arc/arcform/models/arcform_models.dart';
import 'package:my_app/arc/arcform/util/seeded.dart';

/// Animated 3D phase shape widget for splash screen
/// Uses authentic phase layouts from layouts_3d.dart
/// Renders as a spinning wireframe without labels
class AnimatedPhaseShape extends StatefulWidget {
  final String phase;
  final double size;
  final Duration rotationDuration;

  const AnimatedPhaseShape({
    super.key,
    required this.phase,
    this.size = 150,
    this.rotationDuration = const Duration(seconds: 10),
  });

  @override
  State<AnimatedPhaseShape> createState() => _AnimatedPhaseShapeState();
}

class _AnimatedPhaseShapeState extends State<AnimatedPhaseShape>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  List<ArcNode3D> _nodes = [];
  List<ArcEdge3D> _edges = [];

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: widget.rotationDuration,
      vsync: this,
    )..repeat();

    _generateShapeData();
  }

  @override
  void didUpdateWidget(AnimatedPhaseShape oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) {
      _generateShapeData();
    }
  }

  /// Generate authentic shape data using layouts_3d.dart
  void _generateShapeData() {
    // Generate dummy keywords - the layout functions use these for position calculations
    // We use the optimal node count for each phase to get the intended shape
    final optimalCount = _getOptimalNodeCount(widget.phase);
    final dummyKeywords = List.generate(optimalCount, (i) => 'node_$i');

    // Create a skin with consistent seed
    const skin = ArcformSkin(seed: 42);

    // Use the authentic layout function from layouts_3d.dart
    _nodes = layout3D(
      keywords: dummyKeywords,
      phase: widget.phase,
      skin: skin,
    );

    // Generate authentic edges using the phase-specific edge generator
    final rng = Seeded('42:edges');
    _edges = generateEdges(
      nodes: _nodes,
      rng: rng,
      phase: widget.phase,
      maxEdgesPerNode: 4,
      maxDistance: 1.5,
    );

    if (mounted) {
      setState(() {});
    }
  }

  int _getOptimalNodeCount(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return 10; // Helix
      case 'expansion':
        return 12; // Petal rings
      case 'transition':
        return 12; // Bridge/fork
      case 'consolidation':
        return 20; // Geodesic lattice
      case 'recovery':
        return 8; // Ascending spiral/pyramid
      case 'breakthrough':
        return 12; // Supernova star
      default:
        return 10;
    }
  }

  Color get _phaseColor {
    switch (widget.phase.toLowerCase()) {
      case 'discovery':
        return const Color(0xFF4F46E5); // Blue
      case 'expansion':
        return const Color(0xFF7C3AED); // Purple
      case 'transition':
        return const Color(0xFF059669); // Green
      case 'consolidation':
        return const Color(0xFFD97706); // Orange
      case 'recovery':
        return const Color(0xFFDC2626); // Red
      case 'breakthrough':
        return const Color(0xFFF59E0B); // Amber
      default:
        return const Color(0xFFD1B3FF); // Light purple default
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_nodes.isEmpty) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: CircularProgressIndicator(
            color: _phaseColor.withOpacity(0.5),
            strokeWidth: 2,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _AuthenticPhaseShapePainter(
            nodes: _nodes,
            edges: _edges,
            rotation: _rotationController.value * 2 * math.pi,
            color: _phaseColor,
          ),
        );
      },
    );
  }
}

/// Painter that renders authentic phase shapes as spinning wireframes
class _AuthenticPhaseShapePainter extends CustomPainter {
  final List<ArcNode3D> nodes;
  final List<ArcEdge3D> edges;
  final double rotation;
  final Color color;

  _AuthenticPhaseShapePainter({
    required this.nodes,
    required this.edges,
    required this.rotation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width * 0.18; // Scale factor for node positions

    // Build node ID to index mapping
    final nodeIdToIndex = <String, int>{};
    for (int i = 0; i < nodes.length; i++) {
      nodeIdToIndex[nodes[i].id] = i;
    }

    // Glow paint for depth effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Line paint for edges
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Project 3D nodes to 2D with rotation
    final projectedNodes = <int, Offset>{};
    final nodeDepths = <int, double>{};

    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];

      // Apply Y-axis rotation (horizontal spin)
      final cosR = math.cos(rotation);
      final sinR = math.sin(rotation);

      final rotatedX = node.x * cosR - node.z * sinR;
      final rotatedZ = node.x * sinR + node.z * cosR;
      final rotatedY = node.y;

      // Simple perspective projection
      final perspectiveFactor = 1.0 + rotatedZ * 0.15;
      final projectedX = center.dx + rotatedX * scale * perspectiveFactor;
      final projectedY = center.dy - rotatedY * scale * perspectiveFactor;

      projectedNodes[i] = Offset(projectedX, projectedY);
      nodeDepths[i] = rotatedZ;
    }

    // Sort edges by average depth (draw back-to-front)
    final sortedEdges = List<ArcEdge3D>.from(edges);
    sortedEdges.sort((a, b) {
      final idxA1 = nodeIdToIndex[a.sourceId] ?? 0;
      final idxA2 = nodeIdToIndex[a.targetId] ?? 0;
      final idxB1 = nodeIdToIndex[b.sourceId] ?? 0;
      final idxB2 = nodeIdToIndex[b.targetId] ?? 0;
      final depthA = (nodeDepths[idxA1] ?? 0) + (nodeDepths[idxA2] ?? 0);
      final depthB = (nodeDepths[idxB1] ?? 0) + (nodeDepths[idxB2] ?? 0);
      return depthA.compareTo(depthB);
    });

    // Draw edges as glowing lines
    for (final edge in sortedEdges) {
      final sourceIdx = nodeIdToIndex[edge.sourceId];
      final targetIdx = nodeIdToIndex[edge.targetId];
      
      if (sourceIdx == null || targetIdx == null) continue;
      
      final startPos = projectedNodes[sourceIdx];
      final endPos = projectedNodes[targetIdx];

      if (startPos == null || endPos == null) continue;

      // Calculate depth-based opacity
      final avgDepth = ((nodeDepths[sourceIdx] ?? 0) + (nodeDepths[targetIdx] ?? 0)) / 2;
      final depthFactor = (avgDepth + 2) / 4; // Normalize to 0-1 range
      final opacity = 0.3 + depthFactor.clamp(0.0, 1.0) * 0.7;

      // Draw glow
      canvas.drawLine(startPos, endPos, glowPaint..color = color.withOpacity(opacity * 0.3));

      // Draw line
      canvas.drawLine(startPos, endPos, linePaint..color = color.withOpacity(opacity));
    }

    // Draw small dots at node positions (for visual interest)
    final nodePaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < nodes.length; i++) {
      final pos = projectedNodes[i];
      if (pos == null) continue;

      final depth = nodeDepths[i] ?? 0;
      final depthFactor = (depth + 2) / 4;
      final opacity = 0.4 + depthFactor.clamp(0.0, 1.0) * 0.6;
      final nodeSize = 2.0 + depthFactor.clamp(0.0, 1.0) * 2.0;

      // Subtle glow
      canvas.drawCircle(
        pos,
        nodeSize + 2,
        Paint()
          ..color = color.withOpacity(opacity * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      // Node dot
      canvas.drawCircle(pos, nodeSize, nodePaint..color = color.withOpacity(opacity));
    }
  }

  @override
  bool shouldRepaint(_AuthenticPhaseShapePainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.nodes != nodes ||
        oldDelegate.edges != edges;
  }
}
