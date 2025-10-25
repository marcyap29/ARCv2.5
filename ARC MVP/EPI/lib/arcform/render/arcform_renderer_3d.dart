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

class _Arcform3DState extends State<Arcform3D> {
  // PHASE-AWARE CAMERA ANGLES: Each phase gets optimized 3/4 view
  // Set dynamically based on phase to show each shape clearly
  late double _rotationX;
  late double _rotationY;
  late double _zoom;

  // Gesture handling for 3D interaction
  Offset? _lastPanPosition;
  double _baseScaleFactor = 1.0;

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
    switch (widget.phase.toLowerCase()) {
      case 'discovery':
        // HELIX: Balanced view to show vertical spiral clearly
        _rotationX = 0.2;   // Slight angle to show depth
        _rotationY = 0.0;   // No rotation for clear helix view
        _zoom = 3.5;        // Good distance to see full helix
        break;

      case 'exploration':
      case 'expansion':
        // PETAL RINGS: Angled down to see layered concentric rings
        _rotationX = 0.3;
        _rotationY = 0.2;
        _zoom = 3.0;
        break;

      case 'transition':
        // BRANCHES: Straight-on view to see "reaching fingers" from side
        _rotationX = 0.1;   // Very slight angle
        _rotationY = 0.0;   // No rotation - see fingers reaching horizontally
        _zoom = 2.8;        // Good distance to see full reach
        break;

      case 'consolidation':
        // LATTICE: Slight angle to see geodesic dome structure
        _rotationX = 0.4;   // Slight tilt to show depth
        _rotationY = 0.3;   // Some rotation to see 3D structure
        _zoom = 4.0;        // Further out to see complete sphere structure
        break;

      case 'recovery':
        // CLUSTER: Close view to see cluster detail
        _rotationX = 0.2;   // Very slight angle
        _rotationY = 0.1;   // Minimal rotation
        _zoom = 2.5;        // Closer to see cluster detail
        break;

      case 'breakthrough':
        // BURST: Angled view to see radial explosion pattern
        _rotationX = 0.6;   // Higher angle looking down
        _rotationY = 0.4;   // Some rotation for full radial view
        _zoom = 4.5;        // Far back to see full starburst
        break;

      default:
        // SPHERICAL: Balanced view of Fibonacci sphere
        _rotationX = 0.2;
        _rotationY = 0.0;
        _zoom = 3.5;
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
      // Apply proper 3D rotation math (like molecular design)
      final rotatedX = star.position.x * math.cos(_rotationY) - star.position.z * math.sin(_rotationY);
      final rotatedZ = star.position.x * math.sin(_rotationY) + star.position.z * math.cos(_rotationY);
      final rotatedY = star.position.y * math.cos(_rotationX) - rotatedZ * math.sin(_rotationX);
      final finalZ = star.position.y * math.sin(_rotationX) + rotatedZ * math.cos(_rotationX);

      // Perspective projection with original molecular approach
      const focalLength = 400.0; // Original focal length from simple_3d_arcform
      const baseScale = 30.0; // Much smaller scale for closer nodes (was 100.0)
      final perspective = focalLength / (focalLength + finalZ); // Original perspective formula
      final projectedX = rotatedX * perspective * baseScale * _zoom; // Original direct scaling
      final projectedY = rotatedY * perspective * baseScale * _zoom;

      // Scale for depth effect - original molecular sizing
      final depthScale = (1.0 + finalZ / 300).clamp(0.4, 1.8); // Original molecular scale range
      final nodeSize = (star.size * depthScale * _zoom).clamp(8.0, 30.0); // Original molecular size range

      // Calculate screen position
      final screenX = center.dx + projectedX;
      final screenY = center.dy + projectedY;

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
      // Scale gesture handles rotation (single finger), zoom (pinch), and two-finger rotation
      onScaleStart: (details) {
        _baseScaleFactor = _zoom;
        _lastPanPosition = details.focalPoint;
      },
      onScaleUpdate: (details) {
        setState(() {
          // Handle zoom - Flutter scale is REVERSE from Swift, so use division
          if (details.scale != 1.0) {
            _zoom = (_baseScaleFactor / details.scale).clamp(0.5, 8.0);
          }

          // Handle rotation based on finger count with improved sensitivity
          if (_lastPanPosition != null) {
            if (details.pointerCount == 1) {
              // Single finger: drag to rotate around X and Y axes (increased sensitivity)
              final delta = details.focalPoint - _lastPanPosition!;
              _rotationY += delta.dx * 0.02; // Increased from 0.01 to 0.02
              _rotationX -= delta.dy * 0.02; // Increased from 0.01 to 0.02
              _rotationX = _rotationX.clamp(-math.pi/2, math.pi/2); // Clamp X rotation
              _rotationY = _rotationY % (2 * math.pi); // Wrap Y rotation
              _lastPanPosition = details.focalPoint;
            } else if (details.pointerCount == 2) {
              // Two fingers: only handle rotation if NOT zooming (prevent interference)
              if (details.rotation != 0 && details.scale == 1.0) {
                _rotationY += details.rotation * 0.3; // Reduced from 0.5 to 0.3 for better control
              }
              // Only update focal point if we're not zooming to prevent rotation during pinch
              if (details.scale == 1.0) {
                _lastPanPosition = details.focalPoint;
              }
            }
          }
        });
      },
      onScaleEnd: (_) {
        _baseScaleFactor = _zoom;
        _lastPanPosition = null;
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
              zoom: _zoom,
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
                zoom: _zoom,
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

        // Position label slightly above the star
        final labelOffset = Offset(
          projected.dx - textPainter.width / 2,
          projected.dy - star.size * 2 - textPainter.height,
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

        // Position label slightly above the star (scaled with zoom)
        final labelOffset = Offset(
          projected.dx - textPainter.width / 2,
          projected.dy - (star.size * zoom * 2) - textPainter.height,
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
    _twinkleController = AnimationController(
      duration: Duration(milliseconds: 1500 + (widget.depth * 10).round()),
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
        final twinkle = 0.7 + (_twinkleController.value * 0.3);
        final glowIntensity = (1.0 - (widget.depth / 500).clamp(0.0, 0.8)) * twinkle;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow
            Container(
              width: widget.size * 3,
              height: widget.size * 3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(glowIntensity * 0.3),
                    blurRadius: widget.size * 2,
                    spreadRadius: widget.size * 0.5,
                  ),
                ],
              ),
            ),
            // Inner glow
            Container(
              width: widget.size * 1.5,
              height: widget.size * 1.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(glowIntensity * 0.6),
                    blurRadius: widget.size,
                    spreadRadius: widget.size * 0.2,
                  ),
                ],
              ),
            ),
            // Core node
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(glowIntensity),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(glowIntensity * 0.8),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
            // Label
            if (widget.label.isNotEmpty)
              Positioned(
                top: widget.size + 8,
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

/// Nebula glow painter with twinkling effects
class _NebulaGlowPainter extends CustomPainter {
  final List<NebulaParticle> particles;
  final double rotationX;
  final double rotationY;
  final double zoom;
  final double twinkleValue;

  _NebulaGlowPainter({
    required this.particles,
    required this.rotationX,
    required this.rotationY,
    required this.zoom,
    required this.twinkleValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final particle in particles) {
      // Apply 3D rotation to nebula particles
      final rotatedX = particle.x * math.cos(rotationY) - particle.z * math.sin(rotationY);
      final rotatedZ = particle.x * math.sin(rotationY) + particle.z * math.cos(rotationY);
      final rotatedY = particle.y * math.cos(rotationX) - rotatedZ * math.sin(rotationX);
      final finalZ = particle.y * math.sin(rotationX) + rotatedZ * math.cos(rotationX);

      // Perspective projection matching molecular nodes exactly
      const focalLength = 400.0; // Match node rendering exactly
      const baseScale = 30.0; // Match node rendering (reduced from 100.0)
      final scale = focalLength / (focalLength + finalZ); // Match original perspective formula
      final projectedX = rotatedX * scale * baseScale * zoom; // Match node scaling exactly
      final projectedY = rotatedY * scale * baseScale * zoom;

      final screenPos = Offset(
        center.dx + projectedX,
        center.dy + projectedY,
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
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particle.size * scale * 15);

      canvas.drawCircle(screenPos, particle.size * scale * 30, paint); // Balanced nebula size
    }
  }

  @override
  bool shouldRepaint(_NebulaGlowPainter oldDelegate) {
    return oldDelegate.twinkleValue != twinkleValue ||
        oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.zoom != zoom;
  }
}

/// Constellation lines painter with 3D depth and colorful connections
class _ConstellationLinesPainter extends CustomPainter {
  final List<_Star> stars;
  final List<_Edge> edges;
  final double rotationX;
  final double rotationY;
  final double zoom;

  _ConstellationLinesPainter({
    required this.stars,
    required this.edges,
    required this.rotationX,
    required this.rotationY,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Create a map for quick star lookup by label
    final starByLabel = {for (var star in stars) star.label: star};

    // Draw constellation connecting lines
    for (final edge in edges) {
      final sourceStar = starByLabel[edge.start.toString()];
      final targetStar = starByLabel[edge.end.toString()];

      if (sourceStar == null || targetStar == null) continue;

      // Apply 3D rotation to both endpoints
      final startRotatedX = edge.start.x * math.cos(rotationY) - edge.start.z * math.sin(rotationY);
      final startRotatedZ = edge.start.x * math.sin(rotationY) + edge.start.z * math.cos(rotationY);
      final startRotatedY = edge.start.y * math.cos(rotationX) - startRotatedZ * math.sin(rotationX);
      final startFinalZ = edge.start.y * math.sin(rotationX) + startRotatedZ * math.cos(rotationX);

      final endRotatedX = edge.end.x * math.cos(rotationY) - edge.end.z * math.sin(rotationY);
      final endRotatedZ = edge.end.x * math.sin(rotationY) + edge.end.z * math.cos(rotationY);
      final endRotatedY = edge.end.y * math.cos(rotationX) - endRotatedZ * math.sin(rotationX);
      final endFinalZ = edge.end.y * math.sin(rotationX) + endRotatedZ * math.cos(rotationX);

      // Perspective projection matching molecular nodes exactly
      const focalLength = 400.0; // Match node rendering exactly
      const baseScale = 30.0; // Match node rendering (reduced from 100.0)
      final startScale = focalLength / (focalLength + startFinalZ); // Match original perspective formula
      final endScale = focalLength / (focalLength + endFinalZ);

      final startProj = Offset(
        center.dx + startRotatedX * startScale * baseScale * zoom, // Match node scaling exactly
        center.dy + startRotatedY * startScale * baseScale * zoom,
      );
      final endProj = Offset(
        center.dx + endRotatedX * endScale * baseScale * zoom,
        center.dy + endRotatedY * endScale * baseScale * zoom,
      );

      // Calculate line opacity based on depth and distance
      final avgDepth = (startFinalZ + endFinalZ) / 2;
      final distance = (startProj - endProj).distance;
      final depthOpacity = (1.0 - (avgDepth / 500).clamp(0.0, 0.8));
      final distanceOpacity = (1.0 - (distance / 400).clamp(0.0, 0.8));
      final finalOpacity = (depthOpacity * distanceOpacity * 0.4).clamp(0.05, 0.4);

      // Create gradient line color based on connected stars
      final blendedColor = Color.lerp(sourceStar.color, targetStar.color, 0.5) ?? edge.color;

      // Draw constellation line with glow
      final linePaint = Paint()
        ..color = blendedColor.withOpacity(finalOpacity)
        ..strokeWidth = (2.0 * depthOpacity).clamp(0.5, 3.0)
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

      canvas.drawLine(startProj, endProj, linePaint);

      // Add inner bright line
      final innerLinePaint = Paint()
        ..color = blendedColor.withOpacity(finalOpacity * 1.5)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(startProj, endProj, innerLinePaint);
    }
  }

  @override
  bool shouldRepaint(_ConstellationLinesPainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.zoom != zoom;
  }
}

