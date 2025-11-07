// lib/arcform/render/arcform_renderer_3d.dart
// 3D Constellation ARCForm renderer with orbit controls

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
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
  final double? initialZoom; // Optional initial zoom level (for card previews)

  const Arcform3D({
    super.key,
    required this.nodes,
    required this.edges,
    required this.phase,
    required this.skin,
    this.showNebula = true,
    this.enableLabels = false,
    this.initialZoom,
  });

  @override
  State<Arcform3D> createState() => _Arcform3DState();
}

class _Arcform3DState extends State<Arcform3D> {
  // PHASE-AWARE CAMERA ANGLES: Each phase gets optimized 3/4 view
  // Set dynamically based on phase to show each shape clearly
  late double _rotationX;
  late double _rotationY;
  late double _rotationZ; // Add Z-axis rotation for two-finger rotation
  late double _zoom;

  // Gesture handling for 3D interaction
  Offset? _lastPanPosition;
  double _baseScaleFactor = 1.0;
  int _initialPointerCount = 0;

  // Camera translation for single-finger panning
  double _cameraX = 0.0;
  double _cameraY = 0.0;

  // Track two-finger positions for opposite direction detection
  Offset? _finger1LastPos;
  Offset? _finger2LastPos;

  // Track previous rotation for delta calculation
  double _lastRotation = 0.0;

  List<_Star> _stars = [];
  List<_Edge> _edges = [];
  List<NebulaParticle> _nebulaParticles = [];

  @override
  void initState() {
    super.initState();
    _setCameraForPhase();
    _buildScene();
  }

  /// Set camera angle optimized for the current phase's shape
  void _setCameraForPhase() {
    // Use initialZoom if provided (for card previews), otherwise use phase-specific defaults
    final baseZoom = widget.initialZoom;
    
    switch (widget.phase.toLowerCase()) {
      case 'discovery':
        // HELIX: Side view to show helix structure clearly
        _rotationX = 0.0;   // No X rotation for straight side view
        _rotationY = math.pi / 4;   // 45-degree Y rotation to see helix from side
        _rotationZ = math.pi / 2;   // 90-degree Z rotation for proper helix orientation
        _zoom = baseZoom ?? 1.8;        // Zoom out more for card previews to show full helix
        break;

      case 'exploration':
      case 'expansion':
        // PETAL RINGS: Angled down to see layered concentric rings
        _rotationX = 0.3;
        _rotationY = 0.2;
        _rotationZ = 0.0;
        _zoom = baseZoom ?? 2.5;
        break;

      case 'transition':
        // CYLINDER: Side view to see cylinder structure clearly
        _rotationX = 0.0;   // Straight side view
        _rotationY = math.pi / 4;   // 45-degree rotation to see rings
        _rotationZ = 0.0;
        _zoom = baseZoom ?? 2.2;        // Zoom out more for card previews
        break;

      case 'consolidation':
        // LATTICE: Slight angle to see geodesic dome structure
        _rotationX = 0.4;   // Slight tilt to show depth
        _rotationY = 0.3;   // Some rotation to see 3D structure
        _rotationZ = 0.0;
        _zoom = baseZoom ?? 3.5;        // Zoom out more for card previews
        break;

      case 'recovery':
        // SIMPLE PYRAMID: Angled view to see pyramid structure clearly
        _rotationX = 0.3;   // Angled down to see pyramid
        _rotationY = math.pi / 6;   // 30-degree rotation to see structure
        _rotationZ = 0.0;
        _zoom = baseZoom ?? 2.0;        // Zoom out more for card previews
        break;

      case 'breakthrough':
        // 5-POINTED STAR: Top-down view to see star shape clearly
        _rotationX = 0.5;   // Angled down to see star from above
        _rotationY = 0.0;   // Straight-on to see star shape
        _rotationZ = 0.0;
        _zoom = baseZoom ?? 2.1;        // Zoom out more for card previews
        break;

      default:
        // SPHERICAL: Balanced view of Fibonacci sphere
        _rotationX = 0.2;
        _rotationY = 0.0;
        _rotationZ = 0.0;
        _zoom = baseZoom ?? 3.0;
    }

    print('📷 Camera set for ${widget.phase}: rotX=$_rotationX, rotY=$_rotationY, zoom=$_zoom');
  }

  @override
  void didUpdateWidget(Arcform3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) {
      _setCameraForPhase(); // Update camera when phase changes
      _buildScene();
    } else if (oldWidget.nodes != widget.nodes ||
        oldWidget.edges != widget.edges ||
        oldWidget.skin != widget.skin) {
      _buildScene();
    }
    // NO setState() calls here - prevents spinning during navigation
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Build 3D nodes using molecular design approach with proper rotation math
  List<Widget> _build3DNodes() {
    final nodes = <Widget>[];
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height * 0.35);

    for (final star in _stars) {
      // Apply proper 3D rotation math (like molecular design) with Z rotation
      // First apply Z rotation around the Z-axis
      final zRotatedX = star.position.x * math.cos(_rotationZ) - star.position.y * math.sin(_rotationZ);
      final zRotatedY = star.position.x * math.sin(_rotationZ) + star.position.y * math.cos(_rotationZ);
      final zRotatedZ = star.position.z;
      
      // Then apply Y rotation around the Y-axis
      final rotatedX = zRotatedX * math.cos(_rotationY) - zRotatedZ * math.sin(_rotationY);
      final rotatedZ = zRotatedX * math.sin(_rotationY) + zRotatedZ * math.cos(_rotationY);
      final rotatedY = zRotatedY * math.cos(_rotationX) - rotatedZ * math.sin(_rotationX);
      final finalZ = zRotatedY * math.sin(_rotationX) + rotatedZ * math.cos(_rotationX);

      // Perspective projection with original molecular approach
      const focalLength = 400.0; // Original focal length from simple_3d_arcform
      const baseScale = 30.0; // Much smaller scale for closer nodes (was 100.0)
      final perspective = focalLength / (focalLength + finalZ); // Original perspective formula
      final projectedX = rotatedX * perspective * baseScale * _zoom; // Original direct scaling
      final projectedY = rotatedY * perspective * baseScale * _zoom;

      // Scale for depth effect - original molecular sizing
      final depthScale = (1.0 + finalZ / 300).clamp(0.4, 1.8); // Original molecular scale range
      final nodeSize = (star.size * depthScale * _zoom).clamp(8.0, 30.0); // Original molecular size range

      // Calculate screen position with camera translation
      final screenX = center.dx + projectedX + _cameraX;
      final screenY = center.dy + projectedY + _cameraY;

      // Only render nodes that are visible
      if (screenX > -50 && screenX < size.width + 50 &&
          screenY > -50 && screenY < size.height + 50) {

        nodes.add(
          Positioned(
            left: screenX - nodeSize / 2,
            top: screenY - nodeSize / 2,
            child: _MolecularNodeWidget(
              size: nodeSize,
              color: star.color,
              label: widget.enableLabels ? star.label : '',
              depth: finalZ,
            ),
          ),
        );
      }
    }

    return nodes;
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
        position: vm.Vector3(node.x * 2, node.y * 2, node.z * 2), // Original molecular spacing
        color: Color.fromRGBO(
          (color.x * 255).toInt(),
          (color.y * 255).toInt(),
          (color.z * 255).toInt(),
          1.0,
        ),
        size: 6.0 + node.weight * 8.0, // Larger, more visible stars
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
        particleCount: 25, // Moderately more particles for better coverage
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
      // Handle all gestures with scale detector (superset of pan)
      onScaleStart: (details) {
        _baseScaleFactor = _zoom;
        _lastPanPosition = details.focalPoint;
        _initialPointerCount = details.pointerCount;
        _lastRotation = 0.0; // Initialize rotation tracking
      },
      onScaleUpdate: (details) {
        setState(() {
          final currentPointerCount = details.pointerCount;

          if (currentPointerCount == 1) {
            // One-finger drag: Move/rotate the object (x & y axes)
            if (_lastPanPosition != null) {
              final delta = details.focalPoint - _lastPanPosition!;
              _rotationY += delta.dx * 0.01; // Horizontal drag rotates around Y-axis
              _rotationX -= delta.dy * 0.01; // Vertical drag rotates around X-axis
              _rotationX = _rotationX.clamp(-math.pi/2, math.pi/2);
              _rotationY = _rotationY % (2 * math.pi);
            }
          } else if (currentPointerCount == 2) {
            // Two-finger gestures: pinch zoom, pan/drag translation, twist rotation

            // Two-finger pinch: Zoom in (open) / Zoom out (close)
            if (details.scale != 1.0) {
              _zoom = (_baseScaleFactor * details.scale).clamp(0.5, 8.0);
            }

            // Two-finger pan/drag: Translate object/camera in plane
            if (_lastPanPosition != null) {
              final delta = details.focalPoint - _lastPanPosition!;
              _cameraX += delta.dx * 1.0; // Horizontal translation
              _cameraY += delta.dy * 1.0; // Vertical translation
            }

            // Two-finger rotation (twist): Rotate around axis
            final rotationDelta = details.rotation - _lastRotation;
            if (rotationDelta.abs() > 0.001) { // Only apply if there's meaningful change
              _rotationZ += rotationDelta * 0.5; // Z-axis rotation for twist
              _rotationZ = _rotationZ % (2 * math.pi); // Allow full rotation
            }
            _lastRotation = details.rotation;
          }

          _lastPanPosition = details.focalPoint;
        });
      },
      onScaleEnd: (_) {
        _baseScaleFactor = _zoom;
        _lastPanPosition = null;
        _initialPointerCount = 0;
        _lastRotation = 0.0; // Reset rotation tracking
      },

      child: Stack(
        children: [
          // Constellation connection lines (behind nodes)
          CustomPaint(
            size: Size.infinite,
            painter: _ConstellationLinesPainter(
              stars: _stars,
              edges: _edges,
              rotationX: _rotationX,
              rotationY: _rotationY,
              rotationZ: _rotationZ,
              zoom: _zoom,
              cameraX: _cameraX,
              cameraY: _cameraY,
            ),
          ),

          // Node-to-node connectors (behind nodes)
          CustomPaint(
            size: Size.infinite,
            painter: _NodeConnectorsPainter(
              stars: _stars,
              rotationX: _rotationX,
              rotationY: _rotationY,
              rotationZ: _rotationZ,
              zoom: _zoom,
              cameraX: _cameraX,
              cameraY: _cameraY,
            ),
          ),

          // Twinkling nebula background
          if (widget.showNebula)
            CustomPaint(
              size: Size.infinite,
              painter: _NebulaGlowPainter(
                particles: _nebulaParticles,
                rotationX: _rotationX,
                rotationY: _rotationY,
                rotationZ: _rotationZ,
                zoom: _zoom,
                cameraX: _cameraX,
                cameraY: _cameraY,
                twinkleValue: (DateTime.now().millisecondsSinceEpoch / 1000.0) % 1.0,
              ),
            ),

          // 3D molecular constellation nodes with proper depth
          ..._build3DNodes(),
        ],
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
  final bool enableLabels;

  _ConstellationPainter({
    required this.stars,
    required this.edges,
    required this.nebula,
    required this.rotationX,
    required this.rotationY,
    required this.zoom,
    required this.enableLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 6.0;

    // Draw nebula first (background)
    for (final particle in nebula) {
      final pos3d = vm.Vector3(particle.x, particle.y, particle.z);

      // Apply proper 3D perspective projection with Z-depth
      final perspective = 1.0 / (1.0 + pos3d.z * 0.1);
      final projected = Offset(
        center.dx + pos3d.x * scale * perspective,
        center.dy - pos3d.y * scale * perspective,
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

      canvas.drawCircle(projected, particle.size * scale * 12 * perspective, paint);
    }

    // Draw constellation connecting lines - subtle and colorful
    for (final edge in edges) {
      // Apply proper 3D perspective projection with Z-depth
      final startPerspective = 1.0 / (1.0 + edge.start.z * 0.1);
      final endPerspective = 1.0 / (1.0 + edge.end.z * 0.1);
      final startProj = Offset(
        center.dx + edge.start.x * scale * startPerspective,
        center.dy - edge.start.y * scale * startPerspective,
      );
      final endProj = Offset(
        center.dx + edge.end.x * scale * endPerspective,
        center.dy - edge.end.y * scale * endPerspective,
      );

      // Create enhanced gradient effect with more vibrant colors
      final baseOpacity = (0.5 + edge.weight * 0.5).clamp(0.3, 0.9); // Increased base opacity
      final lineColor = edge.color.withOpacity(baseOpacity);

      // Enhanced multiple line layers for constellation effect
      // Outer glow line (more visible)
      final outerLinePaint = Paint()
        ..color = lineColor.withOpacity(0.3)
        ..strokeWidth = (4.0 + edge.weight * 3.0).clamp(2.0, 8.0)
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawLine(startProj, endProj, outerLinePaint);

      // Inner glow line
      final innerGlowPaint = Paint()
        ..color = lineColor.withOpacity(0.6)
        ..strokeWidth = (2.0 + edge.weight * 1.5).clamp(1.0, 4.0)
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      canvas.drawLine(startProj, endProj, innerGlowPaint);

      // Main constellation line (core)
      final mainLinePaint = Paint()
        ..color = lineColor
        ..strokeWidth = (1.0 + edge.weight * 1.0).clamp(0.5, 2.5) // Slightly thicker core
        ..style = PaintingStyle.stroke;

      canvas.drawLine(startProj, endProj, mainLinePaint);

      // Inner bright line for definition
      final innerLinePaint = Paint()
        ..color = lineColor.withOpacity(0.6)
        ..strokeWidth = 0.3 + edge.weight * 0.3
        ..style = PaintingStyle.stroke;

      canvas.drawLine(startProj, endProj, innerLinePaint);
    }

    // Draw stars with depth sorting for proper 3D layering
    final starsWithDepth = stars.map((star) {
      return MapEntry(star.position.z, star);
    }).toList();
    
    // Sort by Z-depth (farthest first)
    starsWithDepth.sort((a, b) => a.key.compareTo(b.key));
    
    for (final entry in starsWithDepth) {
      final star = entry.value;
      // Apply proper 3D perspective projection with Z-depth
      final perspective = 1.0 / (1.0 + star.position.z * 0.1); // Perspective divisor based on Z-depth
      final projected = Offset(
        center.dx + star.position.x * scale * perspective,
        center.dy - star.position.y * scale * perspective,
      );

      // Static stars - no twinkling for clean, stable constellation
      // Scale star size based on perspective (closer = bigger, farther = smaller)
      final finalSize = star.size * perspective;

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

    // Draw labels if enabled
    if (enableLabels) {
      // Create rotation matrix from rotationX and rotationY
      final rotation = vm.Matrix4.identity()
        ..rotateX(rotationX)
        ..rotateY(rotationY);
      _drawLabels(canvas, size, center, scale, rotation);
    }
  }

  void _drawLabels(Canvas canvas, Size size, Offset center, double scale, vm.Matrix4 rotation) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );

    for (final star in stars) {
      final rotated = rotation.transform3(star.position);
      final projected = Offset(
        center.dx + rotated.x * scale,
        center.dy - rotated.y * scale,
      );

      // Only show labels if they're not too far from center (avoid edge labels)
      final distanceFromCenter = (projected - center).distance;
      if (distanceFromCenter < size.width * 0.4) {
        final textPainter = TextPainter(
          text: TextSpan(text: star.label, style: textStyle),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        // Position label much lower below the star with extra spacing
        final labelOffset = Offset(
          projected.dx - textPainter.width / 2,
          projected.dy + star.size * 4 + 35, // Position even lower below star
        );

        // Draw label background for readability
        final backgroundRect = Rect.fromLTWH(
          labelOffset.dx - 2,
          labelOffset.dy - 1,
          textPainter.width + 4,
          textPainter.height + 2,
        );
        final backgroundPaint = Paint()
          ..color = Colors.black.withOpacity(0.7)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(backgroundRect, const Radius.circular(4)),
          backgroundPaint,
        );

        textPainter.paint(canvas, labelOffset);
      }
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter oldDelegate) {
    // Only repaint when user interaction changes rotation/zoom, or when scene data changes
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.zoom != zoom ||
        oldDelegate.stars != stars ||
        oldDelegate.edges != edges ||
        oldDelegate.nebula != nebula ||
        oldDelegate.enableLabels != enableLabels;
  }
}

/// Separate painter for labels that aren't affected by 3D transformation
/// but are positioned correctly relative to the 3D stars
class _LabelsPainter extends CustomPainter {
  final List<_Star> stars;
  final double rotationX;
  final double rotationY;
  final double zoom;

  _LabelsPainter({
    required this.stars,
    required this.rotationX,
    required this.rotationY,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 6.0;

    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );

    // Create the same rotation matrix as the 3D transform
    final rotation = vm.Matrix4.identity()
      ..rotateX(rotationX)
      ..rotateY(rotationY);

    for (final star in stars) {
      // Apply 3D transformation to get the same position as the star
      final transformed = rotation.transform3(star.position);
      final projected = Offset(
        center.dx + transformed.x * scale * zoom,
        center.dy - transformed.y * scale * zoom,
      );

      // Only show labels if they're not too far from center and have content
      final distanceFromCenter = (projected - center).distance;
      if (distanceFromCenter < size.width * 0.4 && star.label.isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(text: star.label, style: textStyle),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        // Position label much lower below the star with extra spacing (scaled with zoom)
        final labelOffset = Offset(
          projected.dx - textPainter.width / 2,
          projected.dy + (star.size * zoom * 4) + 35, // Position even lower below star
        );

        // Draw label background for readability
        final backgroundRect = Rect.fromLTWH(
          labelOffset.dx - 2,
          labelOffset.dy - 1,
          textPainter.width + 4,
          textPainter.height + 2,
        );
        final backgroundPaint = Paint()
          ..color = Colors.black.withOpacity(0.7)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(backgroundRect, const Radius.circular(4)),
          backgroundPaint,
        );

        textPainter.paint(canvas, labelOffset);
      }
    }
  }

  @override
  bool shouldRepaint(_LabelsPainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.zoom != zoom ||
        oldDelegate.stars != stars;
  }
}

/// Molecular-style 3D node widget with glow and twinkling effects
class _MolecularNodeWidget extends StatefulWidget {
  final double size;
  final Color color;
  final String label;
  final double depth;

  const _MolecularNodeWidget({
    required this.size,
    required this.color,
    required this.label,
    required this.depth,
  });

  @override
  State<_MolecularNodeWidget> createState() => _MolecularNodeWidgetState();
}

class _MolecularNodeWidgetState extends State<_MolecularNodeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _twinkleController;

  @override
  void initState() {
    super.initState();
    // More varied twinkling durations for natural effect
    final baseDuration = 1200 + (widget.depth * 15).round();
    final randomOffset = ((widget.depth * 7) % 800).round(); // Add some randomness
    _twinkleController = AnimationController(
      duration: Duration(milliseconds: baseDuration + randomOffset),
      vsync: this,
    );
    _twinkleController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _twinkleController,
      builder: (context, child) {
        // Enhanced twinkling with more dramatic variation
        final twinkle = 0.4 + (_twinkleController.value * 0.6); // Range from 0.4 to 1.0
        final glowIntensity = (1.0 - (widget.depth / 500).clamp(0.0, 0.8)) * twinkle;
        
        // Add a secondary twinkle for sparkle effect
        final sparkle = math.sin(_twinkleController.value * math.pi * 2) * 0.3 + 0.7;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Custom painted glow layers for perfect circular fade
            CustomPaint(
              size: Size(widget.size * 6, widget.size * 6),
              painter: _NodeGlowPainter(
                color: widget.color,
                glowIntensity: glowIntensity,
                nodeSize: widget.size,
                twinkleValue: twinkle,
                sparkleValue: sparkle,
              ),
            ),
            // Core node - semi-transparent to allow connectors to show through
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(glowIntensity * 0.7), // More transparent
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(glowIntensity * 0.6),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
            // Label
            if (widget.label.isNotEmpty)
              Positioned(
                top: widget.size + 45, // Position even lower below the node
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(glowIntensity),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Custom painter for connecting all nodes with subtle lines
class _NodeConnectorsPainter extends CustomPainter {
  final List<_Star> stars;
  final double rotationX;
  final double rotationY;
  final double rotationZ;
  final double zoom;
  final double cameraX;
  final double cameraY;

  _NodeConnectorsPainter({
    required this.stars,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
    required this.zoom,
    required this.cameraX,
    required this.cameraY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (stars.length < 2) return;

    final center = Offset(size.width / 2, size.height / 2);

    // Project all stars to 2D coordinates
    final projectedStars = <_Star, Offset>{};
    for (final star in stars) {
      // Apply 3D rotation with Z rotation
      final zRotatedX = star.position.x * math.cos(rotationZ) - star.position.y * math.sin(rotationZ);
      final zRotatedY = star.position.x * math.sin(rotationZ) + star.position.y * math.cos(rotationZ);
      final zRotatedZ = star.position.z;
      
      final rotatedX = zRotatedX * math.cos(rotationY) - zRotatedZ * math.sin(rotationY);
      final rotatedZ = zRotatedX * math.sin(rotationY) + zRotatedZ * math.cos(rotationY);
      final rotatedY = zRotatedY * math.cos(rotationX) - rotatedZ * math.sin(rotationX);
      final finalZ = zRotatedY * math.sin(rotationX) + rotatedZ * math.cos(rotationX);

      // Perspective projection
      const focalLength = 400.0;
      const baseScale = 30.0;
      final perspective = focalLength / (focalLength + finalZ);
      final projectedX = rotatedX * perspective * baseScale * zoom;
      final projectedY = rotatedY * perspective * baseScale * zoom;

      final projected = Offset(
        center.dx + projectedX + cameraX,
        center.dy + projectedY + cameraY,
      );
      projectedStars[star] = projected;
    }

    // Draw helix connections - end nodes have 1 connection, middle nodes have 2
    final starList = stars.toList();
    
    // Sort stars by their Z position to maintain helix order
    starList.sort((a, b) => a.position.z.compareTo(b.position.z));
    
    for (int i = 0; i < starList.length; i++) {
      final currentStar = starList[i];
      final currentPos = projectedStars[currentStar]!;
      
      // Determine how many connections this node should have
      int maxConnections;
      if (starList.length <= 2) {
        // For 1-2 nodes, connect all to each other
        maxConnections = starList.length - 1;
      } else if (i == 0 || i == starList.length - 1) {
        // End nodes: only 1 connection
        maxConnections = 1;
      } else {
        // Middle nodes: 2 connections
        maxConnections = 2;
      }
      
      // Find the closest neighbors in 3D space
      final distances = <_Star, double>{};
      for (final otherStar in starList) {
        if (otherStar == currentStar) continue;
        
        // Calculate 3D distance
        final dx = currentStar.position.x - otherStar.position.x;
        final dy = currentStar.position.y - otherStar.position.y;
        final dz = currentStar.position.z - otherStar.position.z;
        final distance3D = math.sqrt(dx * dx + dy * dy + dz * dz);
        distances[otherStar] = distance3D;
      }
      
      // Sort by distance and take the closest neighbors
      final sortedDistances = distances.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      final closestNeighbors = sortedDistances.take(maxConnections).map((e) => e.key).toList();
      
      // Draw connections to the closest neighbors
      for (final neighbor in closestNeighbors) {
        final neighborPos = projectedStars[neighbor]!;
        
        // Calculate connection points on the edges of the nodes
        final directionVector = neighborPos - currentPos;
        final distance = directionVector.distance;
        final direction = distance > 0 ? Offset(directionVector.dx / distance, directionVector.dy / distance) : Offset.zero;
        
        final currentNodeRadius = currentStar.size / 2;
        final neighborNodeRadius = neighbor.size / 2;
        
        // Start point: edge of current node
        final startPoint = currentPos + Offset(direction.dx * currentNodeRadius, direction.dy * currentNodeRadius);
        // End point: edge of neighbor node  
        final endPoint = neighborPos - Offset(direction.dx * neighborNodeRadius, direction.dy * neighborNodeRadius);
        
        // Create a more vibrant blend of the two connected stars' colors
        final blendedColor = Color.lerp(currentStar.color, neighbor.color, 0.5)!;
        // Enhance the color saturation for better visibility
        final enhancedColor = Color.fromARGB(
          blendedColor.alpha,
          (blendedColor.red * 1.2).clamp(0, 255).round(),
          (blendedColor.green * 1.2).clamp(0, 255).round(),
          (blendedColor.blue * 1.2).clamp(0, 255).round(),
        );
        
        final connectorPaint = Paint()
          ..color = enhancedColor.withOpacity(0.8) // Higher opacity for better visibility
          ..strokeWidth = 2.0 // Thicker lines for better visibility
          ..style = PaintingStyle.stroke;

        canvas.drawLine(startPoint, endPoint, connectorPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _NodeConnectorsPainter &&
        (oldDelegate.stars != stars ||
            oldDelegate.rotationX != rotationX ||
            oldDelegate.rotationY != rotationY ||
            oldDelegate.rotationZ != rotationZ ||
            oldDelegate.zoom != zoom ||
            oldDelegate.cameraX != cameraX ||
            oldDelegate.cameraY != cameraY);
  }
}

/// Custom painter for node glow effects with perfect circular fade
class _NodeGlowPainter extends CustomPainter {
  final Color color;
  final double glowIntensity;
  final double nodeSize;
  final double twinkleValue;
  final double sparkleValue;

  _NodeGlowPainter({
    required this.color,
    required this.glowIntensity,
    required this.nodeSize,
    required this.twinkleValue,
    required this.sparkleValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Enhanced twinkling effect with multiple layers
    final twinkledIntensity = glowIntensity * twinkleValue;
    final sparkledIntensity = twinkledIntensity * sparkleValue;

    // Outer glow (largest, most transparent) - twinkles
    final outerGlowPaint = Paint()
      ..color = color.withOpacity(twinkledIntensity * 0.2)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    canvas.drawCircle(center, nodeSize * 4.0, outerGlowPaint);

    // Middle glow - sparkles
    final middleGlowPaint = Paint()
      ..color = color.withOpacity(sparkledIntensity * 0.35)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(center, nodeSize * 2.5, middleGlowPaint);

    // Inner glow - most dramatic twinkling
    final innerGlowPaint = Paint()
      ..color = color.withOpacity(sparkledIntensity * 0.6)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(center, nodeSize * 1.5, innerGlowPaint);

    // Add a bright sparkle core that pulses
    final sparkleCorePaint = Paint()
      ..color = color.withOpacity(sparkledIntensity * 0.9)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawCircle(center, nodeSize * 0.8, sparkleCorePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _NodeGlowPainter &&
        (oldDelegate.color != color ||
            oldDelegate.glowIntensity != glowIntensity ||
            oldDelegate.nodeSize != nodeSize ||
            oldDelegate.twinkleValue != twinkleValue ||
            oldDelegate.sparkleValue != sparkleValue);
  }
}

/// Nebula glow painter with twinkling effects
class _NebulaGlowPainter extends CustomPainter {
  final List<NebulaParticle> particles;
  final double rotationX;
  final double rotationY;
  final double rotationZ; // Add Z rotation parameter
  final double zoom;
  final double cameraX;
  final double cameraY;
  final double twinkleValue;

  _NebulaGlowPainter({
    required this.particles,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ, // Add Z rotation parameter
    required this.zoom,
    required this.cameraX,
    required this.cameraY,
    required this.twinkleValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final particle in particles) {
      // Apply 3D rotation to nebula particles with Z rotation
      // First apply Z rotation around the Z-axis
      final zRotatedX = particle.x * math.cos(rotationZ) - particle.y * math.sin(rotationZ);
      final zRotatedY = particle.x * math.sin(rotationZ) + particle.y * math.cos(rotationZ);
      final zRotatedZ = particle.z;
      
      // Then apply Y rotation around the Y-axis
      final rotatedX = zRotatedX * math.cos(rotationY) - zRotatedZ * math.sin(rotationY);
      final rotatedZ = zRotatedX * math.sin(rotationY) + zRotatedZ * math.cos(rotationY);
      final rotatedY = zRotatedY * math.cos(rotationX) - rotatedZ * math.sin(rotationX);
      final finalZ = zRotatedY * math.sin(rotationX) + rotatedZ * math.cos(rotationX);

      // Perspective projection matching molecular nodes exactly
      const focalLength = 400.0; // Match node rendering exactly
      const baseScale = 30.0; // Match node rendering (reduced from 100.0)
      final scale = focalLength / (focalLength + finalZ); // Match original perspective formula
      final projectedX = rotatedX * scale * baseScale * zoom; // Match node scaling exactly
      final projectedY = rotatedY * scale * baseScale * zoom;

      final screenPos = Offset(
        center.dx + projectedX + cameraX,
        center.dy + projectedY + cameraY,
      );

      // Individual twinkling with depth-based variation
      final depthTwinkle = (1.0 - (finalZ / 600).clamp(0.0, 0.7));
      final twinklePhase = (twinkleValue + particle.x * 0.1) % 1.0;
      final twinkleIntensity = (math.sin(twinklePhase * math.pi * 2) + 1) * 0.5;
      final finalAlpha = particle.alpha * depthTwinkle * (0.4 + twinkleIntensity * 0.6);

      final paint = Paint()
        ..color = Color.fromRGBO(
          (particle.r * 255).toInt(),
          (particle.g * 255).toInt(),
          (particle.b * 255).toInt(),
          finalAlpha,
        )
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particle.size * scale * 25); // Moderately larger blur

      canvas.drawCircle(screenPos, particle.size * scale * 50, paint); // Moderately larger nebula
    }
  }

  @override
  bool shouldRepaint(_NebulaGlowPainter oldDelegate) {
    return oldDelegate.twinkleValue != twinkleValue ||
        oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.rotationZ != rotationZ ||
        oldDelegate.zoom != zoom ||
        oldDelegate.cameraX != cameraX ||
        oldDelegate.cameraY != cameraY;
  }
}

/// Constellation lines painter with 3D depth and colorful connections
class _ConstellationLinesPainter extends CustomPainter {
  final List<_Star> stars;
  final List<_Edge> edges;
  final double rotationX;
  final double rotationY;
  final double rotationZ; // Add Z rotation parameter
  final double zoom;
  final double cameraX;
  final double cameraY;

  _ConstellationLinesPainter({
    required this.stars,
    required this.edges,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ, // Add Z rotation parameter
    required this.zoom,
    required this.cameraX,
    required this.cameraY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw constellation connecting lines
    // Edges already contain the correct 3D positions as Vector3
    for (final edge in edges) {
      // edge.start and edge.end are already Vector3 positions, not labels
      // No lookup needed - use positions directly

      // Apply 3D rotation to both endpoints with Z rotation
      // First apply Z rotation around the Z-axis for start point
      final startZRotatedX = edge.start.x * math.cos(rotationZ) - edge.start.y * math.sin(rotationZ);
      final startZRotatedY = edge.start.x * math.sin(rotationZ) + edge.start.y * math.cos(rotationZ);
      final startZRotatedZ = edge.start.z;
      
      // Then apply Y rotation around the Y-axis for start point
      final startRotatedX = startZRotatedX * math.cos(rotationY) - startZRotatedZ * math.sin(rotationY);
      final startRotatedZ = startZRotatedX * math.sin(rotationY) + startZRotatedZ * math.cos(rotationY);
      final startRotatedY = startZRotatedY * math.cos(rotationX) - startRotatedZ * math.sin(rotationX);
      final startFinalZ = startZRotatedY * math.sin(rotationX) + startRotatedZ * math.cos(rotationX);

      // First apply Z rotation around the Z-axis for end point
      final endZRotatedX = edge.end.x * math.cos(rotationZ) - edge.end.y * math.sin(rotationZ);
      final endZRotatedY = edge.end.x * math.sin(rotationZ) + edge.end.y * math.cos(rotationZ);
      final endZRotatedZ = edge.end.z;
      
      // Then apply Y rotation around the Y-axis for end point
      final endRotatedX = endZRotatedX * math.cos(rotationY) - endZRotatedZ * math.sin(rotationY);
      final endRotatedZ = endZRotatedX * math.sin(rotationY) + endZRotatedZ * math.cos(rotationY);
      final endRotatedY = endZRotatedY * math.cos(rotationX) - endRotatedZ * math.sin(rotationX);
      final endFinalZ = endZRotatedY * math.sin(rotationX) + endRotatedZ * math.cos(rotationX);

      // Perspective projection matching molecular nodes exactly
      const focalLength = 400.0; // Match node rendering exactly
      const baseScale = 30.0; // Match node rendering (reduced from 100.0)
      final startScale = focalLength / (focalLength + startFinalZ); // Match original perspective formula
      final endScale = focalLength / (focalLength + endFinalZ);

      final startProj = Offset(
        center.dx + startRotatedX * startScale * baseScale * zoom + cameraX, // Add camera translation
        center.dy + startRotatedY * startScale * baseScale * zoom + cameraY,
      );
      final endProj = Offset(
        center.dx + endRotatedX * endScale * baseScale * zoom + cameraX, // Add camera translation
        center.dy + endRotatedY * endScale * baseScale * zoom + cameraY,
      );

      // Calculate line opacity based on depth and distance
      final avgDepth = (startFinalZ + endFinalZ) / 2;
      final distance = (startProj - endProj).distance;
      final depthOpacity = (1.0 - (avgDepth / 500).clamp(0.0, 0.8));
      final distanceOpacity = (1.0 - (distance / 400).clamp(0.0, 0.8));
      final baseOpacity = (depthOpacity * distanceOpacity * 0.8).clamp(0.15, 0.8); // Increased opacity

      // Use edge color directly (already blended in _buildScene)
      final blendedColor = edge.color;

      // Draw enhanced constellation line with layered glow effect
      final outerGlowPaint = Paint()
        ..color = blendedColor.withOpacity(baseOpacity * 0.3)
        ..strokeWidth = (5.0 * depthOpacity).clamp(2.0, 8.0)
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      final innerGlowPaint = Paint()
        ..color = blendedColor.withOpacity(baseOpacity * 0.6)
        ..strokeWidth = (3.0 * depthOpacity).clamp(1.0, 4.0)
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      final corePaint = Paint()
        ..color = blendedColor.withOpacity(baseOpacity)
        ..strokeWidth = (1.5 * depthOpacity).clamp(0.5, 2.0)
        ..style = PaintingStyle.stroke;

      // Draw layered effect: outer glow -> inner glow -> core line
      canvas.drawLine(startProj, endProj, outerGlowPaint);
      canvas.drawLine(startProj, endProj, innerGlowPaint);
      canvas.drawLine(startProj, endProj, corePaint);
    }
  }

  @override
  bool shouldRepaint(_ConstellationLinesPainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.rotationZ != rotationZ ||
        oldDelegate.zoom != zoom ||
        oldDelegate.cameraX != cameraX ||
        oldDelegate.cameraY != cameraY;
  }
}

