// lib/arcform/render/arcform_renderer_3d.dart
// 3D Constellation ARCForm renderer with orbit controls

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:math' as math;
import '../models/arcform_models.dart';
import '../util/seeded.dart';
import 'color_map.dart';
import 'nebula.dart';

/// Main 3D ARCForm widget with static constellation that users can manually rotate
/// Features: Connected star formation, subtle twinkling, manual 3D rotation controls
class Arcform3D extends StatefulWidget {
  final List<ArcNode3D> nodes;
  final List<ArcEdge3D> edges;
  final String phase;
  final ArcformSkin skin;
  final bool showNebula;
  final bool enableLabels;

  const Arcform3D({
    super.key,
    required this.nodes,
    required this.edges,
    required this.phase,
    required this.skin,
    this.showNebula = true,
    this.enableLabels = false,
  });

  @override
  State<Arcform3D> createState() => _Arcform3DState();
}

class _Arcform3DState extends State<Arcform3D> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  double _rotationX = 0.2;
  double _rotationY = 0.0;
  double _zoom = 3.5;
  Offset? _lastPanPosition;
  
  List<_Star> _stars = [];
  List<_Edge> _edges = [];
  List<NebulaParticle> _nebulaParticles = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(); // Gentle twinkling effect
    _buildScene();
  }

  @override
  void didUpdateWidget(Arcform3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodes != widget.nodes ||
        oldWidget.edges != widget.edges ||
        oldWidget.phase != widget.phase ||
        oldWidget.skin != widget.skin) {
      _buildScene();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _buildScene() {
    // Build stars from nodes
    _stars = widget.nodes.map((node) {
      final rng = Seeded('${widget.skin.seed}:${node.id}');
      final color = arcRgb(
        valence: node.valence,
        rng: rng,
        skin: widget.skin,
      );
      
      return _Star(
        position: vm.Vector3(node.x * 2, node.y * 2, node.z * 2),
        color: Color.fromRGBO(
          (color.x * 255).toInt(),
          (color.y * 255).toInt(),
          (color.z * 255).toInt(),
          1.0,
        ),
        size: 4.0 + node.weight * 6.0,
        label: node.label,
      );
    }).toList();

    // Build edges
    final nodeById = {for (var node in widget.nodes) node.id: node};
    final starByLabel = {for (var star in _stars) star.label: star};
    
    _edges = [];
    for (final edge in widget.edges) {
      final sourceNode = nodeById[edge.sourceId];
      final targetNode = nodeById[edge.targetId];
      if (sourceNode != null && targetNode != null) {
        final sourceStar = starByLabel[sourceNode.label];
        final targetStar = starByLabel[targetNode.label];
        if (sourceStar != null && targetStar != null) {
          final rng = Seeded('${widget.skin.seed}:edge:${edge.sourceId}:${edge.targetId}');
          
          // Jitter the colors slightly
          final sourceHsl = rgbToHsl(vm.Vector3(
            sourceStar.color.red / 255.0,
            sourceStar.color.green / 255.0,
            sourceStar.color.blue / 255.0,
          ));
          final jitter = (rng.nextDouble() - 0.5) * 2.0 * widget.skin.lineHueJitter;
          final newHue = (sourceHsl.x + jitter).clamp(0.0, 1.0);
          final rgb = hslToRgb(newHue, sourceHsl.y * 0.9, sourceHsl.z * 0.95);
          
          _edges.add(_Edge(
            start: sourceStar.position,
            end: targetStar.position,
            color: Color.fromRGBO(
              (rgb.x * 255).toInt(),
              (rgb.y * 255).toInt(),
              (rgb.z * 255).toInt(),
              widget.skin.lineAlphaBase,
            ),
            weight: edge.weight,
          ));
        }
      }
    }

    // Generate nebula particles
    if (widget.showNebula) {
      _nebulaParticles = NebulaGenerator.generate(
        phase: widget.phase,
        skin: widget.skin,
        particleCount: 18,
      );
    } else {
      _nebulaParticles = [];
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        _lastPanPosition = details.localPosition;
      },
      onPanUpdate: (details) {
        final delta = details.localPosition - (_lastPanPosition ?? details.localPosition);
        setState(() {
          _rotationY += delta.dx * 0.01;
          _rotationX = (_rotationX - delta.dy * 0.01).clamp(-1.5, 1.5);
        });
        _lastPanPosition = details.localPosition;
      },
      onPanEnd: (_) {
        _lastPanPosition = null;
      },
      onScaleStart: (_) {},
      onScaleUpdate: (details) {
        if (details.scale != 1.0) {
          setState(() {
            _zoom = (_zoom / details.scale).clamp(2.0, 8.0);
          });
        }
      },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ConstellationPainter(
              stars: _stars,
              edges: _edges,
              nebula: _nebulaParticles,
              rotationX: _rotationX,
              rotationY: _rotationY,
              zoom: _zoom,
              animationValue: _animationController.value,
            ),
          );
        },
      ),
    );
  }
}

class _Star {
  final vm.Vector3 position;
  final Color color;
  final double size;
  final String label;

  _Star({
    required this.position,
    required this.color,
    required this.size,
    required this.label,
  });
}

class _Edge {
  final vm.Vector3 start;
  final vm.Vector3 end;
  final Color color;
  final double weight;

  _Edge({
    required this.start,
    required this.end,
    required this.color,
    required this.weight,
  });
}

class _ConstellationPainter extends CustomPainter {
  final List<_Star> stars;
  final List<_Edge> edges;
  final List<NebulaParticle> nebula;
  final double rotationX;
  final double rotationY;
  final double zoom;
  final double animationValue;

  _ConstellationPainter({
    required this.stars,
    required this.edges,
    required this.nebula,
    required this.rotationX,
    required this.rotationY,
    required this.zoom,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 6.0 * (1.0 / zoom);

    // Create rotation matrices
    final rotX = vm.Matrix4.rotationX(rotationX);
    final rotY = vm.Matrix4.rotationY(rotationY);
    final rotation = rotY * rotX;

    // Draw nebula first (background)
    for (final particle in nebula) {
      final pos3d = vm.Vector3(particle.x, particle.y, particle.z);
      final rotated = rotation.transform3(pos3d);
      
      // Simple perspective (no proper projection for performance)
      final projected = Offset(
        center.dx + rotated.x * scale,
        center.dy - rotated.y * scale,
      );

      final paint = Paint()
        ..color = Color.fromRGBO(
          (particle.r * 255).toInt(),
          (particle.g * 255).toInt(),
          (particle.b * 255).toInt(),
          particle.alpha * 0.4,
        )
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particle.size * 8);

      canvas.drawCircle(projected, particle.size * scale * 12, paint);
    }

    // Draw edges
    for (final edge in edges) {
      final start3d = rotation.transform3(edge.start);
      final end3d = rotation.transform3(edge.end);

      final startProj = Offset(
        center.dx + start3d.x * scale,
        center.dy - start3d.y * scale,
      );
      final endProj = Offset(
        center.dx + end3d.x * scale,
        center.dy - end3d.y * scale,
      );

      final paint = Paint()
        ..color = edge.color.withOpacity(edge.color.opacity * edge.weight)
        ..strokeWidth = 1.0 + edge.weight * 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(startProj, endProj, paint);
    }

    // Draw stars
    for (final star in stars) {
      final rotated = rotation.transform3(star.position);
      
      final projected = Offset(
        center.dx + rotated.x * scale,
        center.dy - rotated.y * scale,
      );

      // Subtle twinkling effect like real stars
      final twinkle = 1.0 + 0.1 * math.sin(animationValue * 2 * 3.14159 + star.position.x * 0.5);
      final finalSize = star.size * twinkle;

      // Glow effect
      final glowPaint = Paint()
        ..color = star.color.withOpacity(0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(projected, finalSize * 2.5, glowPaint);

      // Core star
      final starPaint = Paint()
        ..color = star.color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(projected, finalSize, starPaint);

      // Bright center
      final centerPaint = Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(projected, finalSize * 0.4, centerPaint);
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.zoom != zoom ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.stars != stars ||
        oldDelegate.edges != edges;
  }
}

