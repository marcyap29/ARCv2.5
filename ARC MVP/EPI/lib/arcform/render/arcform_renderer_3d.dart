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
/// Features: Connected star formation, manual 3D rotation controls, pinch-to-zoom
/// The constellation remains stationary until the user interacts with it via drag or pinch gestures
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

class _Arcform3DState extends State<Arcform3D> with TickerProviderStateMixin {
  double _rotationX = 0.2;
  double _rotationY = 0.0;
  double _zoom = 2.0; // Start more zoomed out to see the galaxy spread
  Offset? _lastPanPosition;

  List<_Star> _stars = [];
  List<_Edge> _edges = [];
  List<NebulaParticle> _nebulaParticles = [];
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
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
        position: vm.Vector3(node.x * 3, node.y * 3, node.z * 3), // Increased scale for galaxy spread
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
          
          // Blend colors of both connected stars for constellation lines
          final sourceHsl = rgbToHsl(vm.Vector3(
            sourceStar.color.red / 255.0,
            sourceStar.color.green / 255.0,
            sourceStar.color.blue / 255.0,
          ));
          final targetHsl = rgbToHsl(vm.Vector3(
            targetStar.color.red / 255.0,
            targetStar.color.green / 255.0,
            targetStar.color.blue / 255.0,
          ));
          
          // Blend the hues, saturations, and lightness of both stars
          final blendedHue = (sourceHsl.x + targetHsl.x) / 2.0;
          final blendedSat = (sourceHsl.y + targetHsl.y) / 2.0;
          final blendedLight = (sourceHsl.z + targetHsl.z) / 2.0;
          
          // Add subtle jitter for variation
          final jitter = (rng.nextDouble() - 0.5) * 0.1; // Reduced jitter for more stable colors
          final finalHue = (blendedHue + jitter).clamp(0.0, 1.0);
          final rgb = hslToRgb(finalHue, blendedSat * 0.8, blendedLight * 0.9);
          
          _edges.add(_Edge(
            start: vm.Vector3(sourceStar.position.x, sourceStar.position.y, sourceStar.position.z),
            end: vm.Vector3(targetStar.position.x, targetStar.position.y, targetStar.position.z),
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
            _zoom = (_zoom / details.scale).clamp(0.5, 12.0); // Increased zoom range for galaxy exploration
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

    // Draw constellation connecting lines - subtle and colorful
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

      // Create gradient effect by blending the edge color with transparency
      final lineColor = edge.color.withOpacity(0.3 + edge.weight * 0.4); // More subtle, 0.3-0.7 opacity
      
      // Multiple line layers for constellation effect
      // Outer glow line (very subtle)
      final outerLinePaint = Paint()
        ..color = lineColor.withOpacity(0.1)
        ..strokeWidth = 3.0 + edge.weight * 2.0
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawLine(startProj, endProj, outerLinePaint);

      // Main constellation line
      final mainLinePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 0.8 + edge.weight * 0.8 // Thinner, more delicate lines
        ..style = PaintingStyle.stroke;

      canvas.drawLine(startProj, endProj, mainLinePaint);

      // Inner bright line for definition
      final innerLinePaint = Paint()
        ..color = lineColor.withOpacity(0.6)
        ..strokeWidth = 0.3 + edge.weight * 0.3
        ..style = PaintingStyle.stroke;

      canvas.drawLine(startProj, endProj, innerLinePaint);
    }

    // Draw stars
    for (final star in stars) {
      final rotated = rotation.transform3(star.position);
      
      final projected = Offset(
        center.dx + rotated.x * scale,
        center.dy - rotated.y * scale,
      );

      // Galaxy-like twinkling stars with phase-specific shapes
      final twinkle = 1.0 + 0.4 * math.sin(animationValue * 2 * 3.14159 + star.position.x * 0.3 + star.position.y * 0.2);
      final finalSize = star.size * twinkle;

      // Multiple glow layers for galaxy star effect
      // Outer glow (largest, most transparent)
      final outerGlowPaint = Paint()
        ..color = star.color.withOpacity(0.15)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

      canvas.drawCircle(projected, finalSize * 4.0, outerGlowPaint);

      // Middle glow
      final middleGlowPaint = Paint()
        ..color = star.color.withOpacity(0.25)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(projected, finalSize * 2.5, middleGlowPaint);

      // Inner glow
      final innerGlowPaint = Paint()
        ..color = star.color.withOpacity(0.4)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(projected, finalSize * 1.5, innerGlowPaint);

      // Core star
      final starPaint = Paint()
        ..color = star.color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(projected, finalSize, starPaint);

      // Bright white center for twinkling effect
      final centerPaint = Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(projected, finalSize * 0.3, centerPaint);
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.zoom != zoom ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.stars != stars ||
        oldDelegate.edges != edges ||
        oldDelegate.nebula != nebula;
  }
}

