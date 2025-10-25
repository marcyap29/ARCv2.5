import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:my_app/features/arcforms/arcform_mvp_implementation.dart';
import 'package:my_app/features/arcforms/arcform_renderer_state.dart';
import 'package:my_app/features/arcforms/services/emotional_valence_service.dart';

/// New 3D Constellation Arcform using proper 3D mathematics
class Constellation3DArcformNew extends StatefulWidget {
  final List<Node> nodes;
  final List<Edge> edges;
  final ArcformGeometry selectedGeometry;
  final Function(String)? onNodeTapped;
  final Function()? onStyleToggle;

  const Constellation3DArcformNew({
    super.key,
    required this.nodes,
    required this.edges,
    required this.selectedGeometry,
    this.onNodeTapped,
    this.onStyleToggle,
  });

  @override
  State<Constellation3DArcformNew> createState() => _Constellation3DArcformNewState();
}

class _Constellation3DArcformNewState extends State<Constellation3DArcformNew>
    with SingleTickerProviderStateMixin {
  late AnimationController _twinkleController;
  late AnimationController _selectionPulseController;
  
  // 3D rotation and scaling state
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  double _rotationZ = 0.0;
  double _scale = 1.0;
  final bool _autoRotate = true;
  
  // Interactive selection state
  String? _selectedNodeId;

  // Gesture handling state
  Offset? _lastFocalPoint;

  @override
  void initState() {
    super.initState();
    
    _twinkleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _selectionPulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    _selectionPulseController.dispose();
    super.dispose();
  }

  void _handleNodeTapped(String nodeId) {
    setState(() {
      _selectedNodeId = nodeId;
    });
    _selectionPulseController.forward().then((_) {
      _selectionPulseController.reverse();
    });
    widget.onNodeTapped?.call(nodeId);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      final currentPointerCount = details.pointerCount;

      if (currentPointerCount == 1) {
        // One-finger drag: Move/rotate the object (x & y axes)
        if (_lastFocalPoint != null) {
          final delta = details.focalPoint - _lastFocalPoint!;
          _rotationY += delta.dx * 0.01; // Horizontal drag rotates around Y-axis
          _rotationX -= delta.dy * 0.01; // Vertical drag rotates around X-axis
          _rotationX = _rotationX.clamp(-math.pi/2, math.pi/2);
          _rotationY = _rotationY % (2 * math.pi);
        }
      } else if (currentPointerCount == 2) {
        // Two-finger gestures: pinch zoom, pan/drag translation, twist rotation

        // Two-finger pinch: Zoom in (open) / Zoom out (close)
        if (details.scale != 1.0) {
          _scale = (_scale * details.scale).clamp(0.5, 3.0);
        }

        // Two-finger pan/drag: Translate object in plane
        // Note: This implementation doesn't have camera translation, so we'll use it for additional rotation
        if (_lastFocalPoint != null) {
          final delta = details.focalPoint - _lastFocalPoint!;
          // For this helix renderer, use pan as fine rotation adjustment
          _rotationY += delta.dx * 0.005; // Fine horizontal rotation
          _rotationX -= delta.dy * 0.005; // Fine vertical rotation
          _rotationX = _rotationX.clamp(-math.pi/2, math.pi/2);
          _rotationY = _rotationY % (2 * math.pi);
        }

        // Two-finger rotation (twist): Rotate around Z axis
        if (details.rotation != 0) {
          _rotationZ += details.rotation * 0.5; // Z-axis rotation for twist
          _rotationZ = _rotationZ % (2 * math.pi);
        }
      }

      _lastFocalPoint = details.focalPoint;
    });
  }

  void _handleDoubleTap() {
    setState(() {
      _rotationX = 0.0;
      _rotationY = 0.0;
      _rotationZ = 0.0;
      _scale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
      onDoubleTap: _handleDoubleTap,
      child: CustomPaint(
        painter: _ConstellationPainter(
          nodes: widget.nodes,
          edges: widget.edges,
          rotationX: _rotationX,
          rotationY: _rotationY,
          rotationZ: _rotationZ,
          scale: _scale,
          twinkleValue: _twinkleController.value,
          selectedNodeId: _selectedNodeId,
          selectionPulse: _selectionPulseController.value,
          selectedGeometry: widget.selectedGeometry,
          onNodeTapped: _handleNodeTapped,
        ),
        isComplex: true,
        willChange: true,
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Custom painter for constellation stars using proper 3D mathematics
class _ConstellationPainter extends CustomPainter {
  final List<Node> nodes;
  final List<Edge> edges;
  final double rotationX;
  final double rotationY;
  final double rotationZ;
  final double scale;
  final double twinkleValue;
  final String? selectedNodeId;
  final double selectionPulse;
  final ArcformGeometry selectedGeometry;
  final Function(String)? onNodeTapped;

  _ConstellationPainter({
    required this.nodes,
    required this.edges,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
    required this.scale,
    required this.twinkleValue,
    this.selectedNodeId,
    required this.selectionPulse,
    required this.selectedGeometry,
    this.onNodeTapped,
  });

  final _rand = math.Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    print('DEBUG: Constellation3DArcformNew paint() called with ${nodes.length} nodes');
    
    // 1) Generate a vertical helix in MODEL space (y up)
    final points = <vm.Vector3>[];
    final edges = <(int, int)>[];
    const turns = 2.5; // helix length (in revolutions)
    const totalAngle = turns * 2 * math.pi;
    const radius = 90.0;
    const pitch = 15.0; // vertical spacing per radian
    
    // Generate helix points based on the number of nodes we have
    final nodeCount = nodes.length;
    print('DEBUG: Generating helix with $nodeCount nodes');
    for (int i = 0; i < nodeCount; i++) {
      final t = (i / (nodeCount - 1)) * totalAngle; // 0..totalAngle
      final x = radius * math.cos(t);
      final y = pitch * t;                // vertical rise
      final z = radius * math.sin(t);
      points.add(vm.Vector3(x, y, z));
      if (i > 0) edges.add((i - 1, i));   // simple chain
    }

    // Center the helix at origin
    const midY = (pitch * totalAngle) * 0.5;
    for (final p in points) {
      p.y -= midY;
    }

    // 2) Build MODEL rotation (Rx * Ry * Rz)
    final model = vm.Matrix4.identity()
      ..rotateX(rotationX)
      ..rotateY(rotationY)
      ..rotateZ(rotationZ);

    // 3) VIEW matrix (camera looking at origin)
    // Eye back on +Z so we look toward -Z (right-handed)
    final eye = vm.Vector3(0, 0, 420);
    final target = vm.Vector3.zero();
    final up = vm.Vector3(0, 1, 0);
    final view = vm.makeViewMatrix(eye, target, up);

    // 4) PROJECTION matrix
    final aspect = size.width / size.height;
    final fovY = vm.radians(55.0);
    final proj = vm.makePerspectiveMatrix(fovY, aspect, 0.1, 3000.0);

    final mvp = proj * view * model;

    // 5) Transform + perspective divide + viewport map
    final transformed = <_Projected>[];
    for (int i = 0; i < points.length; i++) {
      final v4 = mvp.transform(vm.Vector4(points[i].x, points[i].y, points[i].z, 1));
      // perspective divide
      if (v4.w.abs() < 1e-6) continue;
      final ndc = vm.Vector3(v4.x / v4.w, v4.y / v4.w, v4.z / v4.w); // -1..1
      // map to screen; invert y for Flutter's downwards Y
      final sx = (ndc.x * 0.5 + 0.5) * size.width;
      final sy = (1.0 - (ndc.y * 0.5 + 0.5)) * size.height;
      transformed.add(_Projected(
        index: i,
        screen: Offset(sx, sy),
        // depth for sorting: smaller camera-space z is farther after proj; we can use ndc.z
        depth: ndc.z,
      ));
    }

    // 6) Depth sort (back-to-front: far first)
    transformed.sort((a, b) => a.depth.compareTo(b.depth));

    // 7) Optional background stars (cheap parallax feel)
    _paintBackground(canvas, size);

    // 8) Draw enhanced colored edges
    final emotionalService = EmotionalValenceService();

    // Use a map index->screen for fast lookup
    final posMap = {for (final p in transformed) p.index: p.screen};
    for (final (a, b) in edges) {
      final pa = posMap[a], pb = posMap[b];
      if (pa != null && pb != null && a < nodeCount && b < nodeCount) {
        // Get colors from connected nodes
        final nodeA = nodes[a];
        final nodeB = nodes[b];
        final colorA = emotionalService.getEmotionalColor(nodeA.label);
        final colorB = emotionalService.getEmotionalColor(nodeB.label);
        final blendedColor = Color.lerp(colorA, colorB, 0.5) ?? colorA;

        // Calculate depth-based opacity
        final depthA = transformed.firstWhere((p) => p.index == a).depth;
        final depthB = transformed.firstWhere((p) => p.index == b).depth;
        final avgDepth = (depthA + depthB) / 2;
        final depthOpacity = (1.0 - (avgDepth / 200).clamp(0.0, 0.8));
        final baseOpacity = (depthOpacity * 0.8).clamp(0.2, 0.8);

        // Draw layered colored edge
        final glowPaint = Paint()
          ..color = blendedColor.withOpacity(baseOpacity * 0.4)
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
          ..isAntiAlias = true;

        final corePaint = Paint()
          ..color = blendedColor.withOpacity(baseOpacity)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true;

        canvas.drawLine(pa, pb, glowPaint);
        canvas.drawLine(pa, pb, corePaint);
      }
    }

    // 9) Draw stars (core + halo), near last for additive look
    for (final p in transformed) {
      if (p.index < nodeCount) {
        final node = nodes[p.index];
        final isSelected = selectedNodeId == node.id;
        
        // Get emotional color
        final valence = emotionalService.getEmotionalValence(node.label);
        final color = _getEmotionalColor(valence);
        
        // Calculate star size based on selection and depth
        const baseSize = 8.0;
        final depthScale = math.max(0.3, 1.0 - (p.depth / 200.0));
        final selectionScale = isSelected ? 1.0 + selectionPulse * 0.5 : 1.0;
        final finalSize = baseSize * depthScale * selectionScale * scale;
        
        // Create glow effect
        final halo = Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
          ..color = color.withOpacity(0.18);
        final core = Paint()
          ..color = color
          ..isAntiAlias = true;

        // tiny twinkle by depth (or time via repaint)
        const rCore = 2.2;
        canvas.drawCircle(p.screen, rCore + 2.5, halo);
        canvas.drawCircle(p.screen, rCore, core);
        
        // Draw label
        if (finalSize > 4) {
          _paintNodeLabel(canvas, p.screen, node.label, color);
        }
      }
    }
  }

  void _paintBackground(Canvas c, Size s) {
    final paint = Paint()..color = Colors.white.withOpacity(0.08);
    for (int i = 0; i < 180; i++) {
      final x = _rand.nextDouble() * s.width;
      final y = _rand.nextDouble() * s.height;
      c.drawCircle(Offset(x, y), _rand.nextDouble() * 1.4 + 0.4, paint);
    }
  }
  
  void _paintNodeLabel(Canvas canvas, Offset position, String label, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    final textOffset = Offset(
      position.dx - textPainter.width / 2,  // Center horizontally
      position.dy + 50, // Position even lower below star
    );
    
    textPainter.paint(canvas, textOffset);
  }
  
  Color _getEmotionalColor(double valence) {
    if (valence > 0.6) {
      return const Color(0xFF4CAF50); // Green for positive
    } else if (valence > 0.3) {
      return const Color(0xFF2196F3); // Blue for neutral-positive
    } else if (valence > -0.3) {
      return const Color(0xFFFF9800); // Orange for neutral
    } else if (valence > -0.6) {
      return const Color(0xFFFF5722); // Red-orange for negative
    } else {
      return const Color(0xFFE91E63); // Pink for very negative
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter old) =>
      rotationX != old.rotationX || rotationY != old.rotationY || rotationZ != old.rotationZ ||
      scale != old.scale || twinkleValue != old.twinkleValue || selectionPulse != old.selectionPulse;
}

class _Projected {
  final int index;
  final Offset screen;
  final double depth; // use for painter's back-to-front ordering
  _Projected({required this.index, required this.screen, required this.depth});
}
