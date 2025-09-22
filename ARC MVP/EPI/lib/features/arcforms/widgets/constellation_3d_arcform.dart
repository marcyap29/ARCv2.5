import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/features/arcforms/arcform_mvp_implementation.dart';
import 'package:my_app/features/arcforms/arcform_renderer_state.dart';
import 'package:my_app/features/arcforms/services/emotional_valence_service.dart';
import 'package:my_app/features/arcforms/geometry/geometry_layouts.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

/// Constellation-style 3D Arcform renderer - shows starfield visualization
class Constellation3DArcform extends StatefulWidget {
  final List<Node> nodes;
  final List<Edge> edges;
  final Function(String, double, double)? onNodeMoved;
  final Function(String)? onNodeTapped;
  final ArcformGeometry selectedGeometry;
  final Function(ArcformGeometry) onGeometryChanged;
  final VoidCallback? on3DToggle;
  final VoidCallback? onExport;
  final VoidCallback? onAutoRotate;
  final VoidCallback? onResetView;
  final VoidCallback? onStyleToggle;

  const Constellation3DArcform({
    super.key,
    required this.nodes,
    required this.edges,
    this.onNodeMoved,
    this.onNodeTapped,
    required this.selectedGeometry,
    required this.onGeometryChanged,
    this.on3DToggle,
    this.onExport,
    this.onAutoRotate,
    this.onResetView,
    this.onStyleToggle,
  });

  @override
  State<Constellation3DArcform> createState() => _Constellation3DArcformState();
}

class _Constellation3DArcformState extends State<Constellation3DArcform>
    with TickerProviderStateMixin {
  late AnimationController _twinkleController;
  late AnimationController _autoRotateController;
  late AnimationController _scaleTransitionController;
  late AnimationController _rotationTransitionController;
  
  // 3D rotation and scaling state - using same approach as molecular design
  double _rotationX = 0.0; // Start with no tilt for proper vertical orientation
  double _rotationY = 0.0;
  double _rotationZ = math.pi / 2; // 90 degrees counterclockwise for proper vertical orientation
  double _scale = 1.0;
  bool _autoRotate = true;
  
  // Interactive selection state
  String? _selectedNodeId;
  late AnimationController _selectionPulseController;
  
  // Smooth transition animations
  late Animation<double> _scaleTransition;
  late Animation<double> _rotationXTransition;
  late Animation<double> _rotationYTransition;

  @override
  void initState() {
    super.initState();
    
    // Initialize twinkle animation
    _twinkleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _twinkleController.repeat(reverse: true);
    
    // Auto-rotation animation
    _autoRotateController = AnimationController(
      duration: const Duration(seconds: 25), // Slower than molecule renderer for peaceful feel
      vsync: this,
    );
    
    // Selection pulse animation
    _selectionPulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _selectionPulseController.repeat(reverse: true);
    
    // Smooth transition controllers
    _scaleTransitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationTransitionController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // Initialize transition animations
    _scaleTransition = Tween<double>(
      begin: _scale,
      end: _scale,
    ).animate(CurvedAnimation(
      parent: _scaleTransitionController,
      curve: Curves.easeOutCubic,
    ));
    
    _rotationXTransition = Tween<double>(
      begin: _rotationX,
      end: _rotationX,
    ).animate(CurvedAnimation(
      parent: _rotationTransitionController,
      curve: Curves.easeOutCubic,
    ));
    
    _rotationYTransition = Tween<double>(
      begin: _rotationY,
      end: _rotationY,
    ).animate(CurvedAnimation(
      parent: _rotationTransitionController,
      curve: Curves.easeOutCubic,
    ));
    
    if (_autoRotate) {
      _autoRotateController.repeat();
    }
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    _autoRotateController.dispose();
    _selectionPulseController.dispose();
    _scaleTransitionController.dispose();
    _rotationTransitionController.dispose();
    super.dispose();
  }

  Offset? _lastFocalPoint;

  // Smooth transition methods
  void _animateScaleTo(double targetScale) {
    final currentScale = _scaleTransition.isCompleted ? _scaleTransition.value : _scale;
    _scaleTransition = Tween<double>(
      begin: currentScale,
      end: targetScale.clamp(0.3, 3.0),
    ).animate(CurvedAnimation(
      parent: _scaleTransitionController,
      curve: Curves.easeOutCubic,
    ));
    
    _scaleTransitionController.forward(from: 0).then((_) {
      setState(() {
        _scale = _scaleTransition.value;
      });
    });
  }

  void _animateRotationTo(double targetRotationX, double targetRotationY, [double targetRotationZ = 0.0]) {
    final currentRotX = _rotationXTransition.isCompleted ? _rotationXTransition.value : _rotationX;
    final currentRotY = _rotationYTransition.isCompleted ? _rotationYTransition.value : _rotationY;
    
    _rotationXTransition = Tween<double>(
      begin: currentRotX,
      end: targetRotationX.clamp(-math.pi/2, math.pi/2),
    ).animate(CurvedAnimation(
      parent: _rotationTransitionController,
      curve: Curves.easeOutCubic,
    ));
    
    _rotationYTransition = Tween<double>(
      begin: currentRotY,
      end: targetRotationY % (2 * math.pi),
    ).animate(CurvedAnimation(
      parent: _rotationTransitionController,
      curve: Curves.easeOutCubic,
    ));
    
    _rotationTransitionController.forward(from: 0).then((_) {
      setState(() {
        _rotationX = _rotationXTransition.value;
        _rotationY = _rotationYTransition.value;
        _rotationZ = targetRotationZ; // Set Z rotation
      });
    });
  }

  void _handleNodeTapped(String nodeId) {
    setState(() {
      _selectedNodeId = _selectedNodeId == nodeId ? null : nodeId;
    });
    
    if (widget.onNodeTapped != null) {
      widget.onNodeTapped!(nodeId);
    }
    
    // Add haptic feedback
    HapticFeedback.lightImpact();
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;
    setState(() {
      _autoRotate = false;
    });
    _autoRotateController.stop();
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if (details.scale != 1.0) {
        _scale = (_scale * details.scale).clamp(0.3, 3.0);
      }
      
      if (_lastFocalPoint != null && details.pointerCount == 1) {
        final delta = details.focalPoint - _lastFocalPoint!;
        _rotationY += delta.dx * 0.01; // Horizontal drag rotates around Y-axis
        _rotationX -= delta.dy * 0.01; // Vertical drag rotates around X-axis
        
        // Clamp rotations to prevent extreme angles
        _rotationX = _rotationX.clamp(-math.pi/2, math.pi/2);
        _rotationY = _rotationY % (2 * math.pi);
      }
      
      // Handle Z-axis rotation with two-finger twist (same as molecular design)
      if (details.pointerCount == 2 && details.rotation != 0) {
        _rotationZ += details.rotation * 0.5;
      }
      
      _lastFocalPoint = details.focalPoint;
    });
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_autoRotate) {
        setState(() {
          _autoRotate = true;
        });
        _autoRotateController.repeat();
      }
    });
  }

  void _handleDoubleTap() {
    // Smooth reset to default view
    _animateScaleTo(1.0);
    _animateRotationTo(0.0, 0.0, 0.0); // Reset to proper vertical orientation
    
    // Reset selection
    setState(() {
      _selectedNodeId = null;
    });
    
    // Haptic feedback for reset
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F), // Deep space background
      body: Stack(
        children: [
          // Starfield background - full screen
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, 0.6), // Center gradient much lower on screen
                radius: 0.6, // Even smaller radius for more compact starry sky
                colors: [
                  Color(0xFF1A1A2E), // Center - slightly lighter
                  Color(0xFF0A0A0F), // Edge - deep space
                ],
              ),
            ),
          ),

          // Constellation stars
          GestureDetector(
            onScaleStart: _handleScaleStart,
            onScaleUpdate: _handleScaleUpdate,
            onScaleEnd: _handleScaleEnd,
            onDoubleTap: _handleDoubleTap,
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _twinkleController, 
                  _autoRotateController,
                  _selectionPulseController,
                  _scaleTransitionController,
                  _rotationTransitionController,
                ]),
                builder: (context, child) {
                  final autoRotY = _autoRotate ? _autoRotateController.value * 2 * math.pi : 0.0;
                  
                  // Use transition values if animations are active, otherwise use direct values
                  final currentScale = _scaleTransitionController.isAnimating 
                      ? _scaleTransition.value 
                      : _scale;
                  final currentRotX = _rotationTransitionController.isAnimating 
                      ? _rotationXTransition.value 
                      : _rotationX;
                  final currentRotY = _rotationTransitionController.isAnimating 
                      ? _rotationYTransition.value 
                      : _rotationY;
                  
                  return CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: ConstellationPainter(
                      nodes: widget.nodes,
                      edges: widget.edges,
                      rotationX: currentRotX,
                      rotationY: currentRotY + autoRotY,
                      rotationZ: _rotationZ, // Add Z rotation parameter
                      scale: currentScale,
                      twinkleValue: _twinkleController.value,
                      selectedNodeId: _selectedNodeId,
                      selectionPulse: _selectionPulseController.value,
                      screenCenter: Offset(
                        MediaQuery.of(context).size.width / 2,
                        MediaQuery.of(context).size.height * 0.4, // Lower the constellation vertically
                      ),
                      selectedGeometry: widget.selectedGeometry,
                      onNodeTapped: _handleNodeTapped,
                    ),
                  );
                },
              ),
            ),
          ),

          // Controls overlay (same as molecule renderer)
          Positioned(
            top: 05,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kcSurfaceColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: kcPrimaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.stars,
                        color: kcPrimaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Constellation Arcform',
                        style: heading3Style(context).copyWith(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ArcformGeometry.values.map((geometry) {
                        final isSelected = geometry == widget.selectedGeometry;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              geometry.name,
                              style: captionStyle(context).copyWith(
                                color: isSelected ? Colors.white : kcSecondaryColor,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                fontSize: 12,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: kcPrimaryColor,
                            backgroundColor: kcSurfaceAltColor,
                            onSelected: (selected) {
                              if (selected) {
                                widget.onGeometryChanged(geometry);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Control buttons row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Style Toggle button (Back to Molecule)
                      Container(
                        decoration: BoxDecoration(
                          color: kcPrimaryColor, // Highlight since this is constellation mode
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: widget.onStyleToggle,
                          icon: const Icon(
                            Icons.stars,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 3D Toggle button
                      Container(
                        decoration: BoxDecoration(
                          color: kcSurfaceAltColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: kcSecondaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          onPressed: widget.on3DToggle,
                          icon: const Icon(
                            Icons.view_in_ar,
                            color: kcSecondaryColor,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Export/Share button
                      Container(
                        decoration: BoxDecoration(
                          color: kcSurfaceAltColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: kcSecondaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          onPressed: widget.onExport,
                          icon: const Icon(
                            Icons.share,
                            color: kcSecondaryColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for constellation stars
class ConstellationPainter extends CustomPainter {
  final List<Node> nodes;
  final List<Edge> edges;
  final double rotationX;
  final double rotationY;
  final double rotationZ; // Add Z rotation parameter
  final double scale;
  final double twinkleValue;
  final String? selectedNodeId;
  final double selectionPulse;
  final Offset screenCenter;
  final ArcformGeometry selectedGeometry;
  final Function(String)? onNodeTapped;

  ConstellationPainter({
    required this.nodes,
    required this.edges,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ, // Add Z rotation parameter
    required this.scale,
    required this.twinkleValue,
    this.selectedNodeId,
    required this.selectionPulse,
    required this.screenCenter,
    required this.selectedGeometry,
    this.onNodeTapped,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final emotionalService = EmotionalValenceService();
    
    // Draw background starfield first (furthest back)
    _drawBackgroundStarfield(canvas, size);
    
    // First, generate 2D positions based on the selected geometry
    final geometryPositions = GeometryLayouts.getPositions(
      geometry: selectedGeometry,
      nodeCount: nodes.length,
      canvasSize: size,
    );
    
    // Then calculate all star positions in 3D space
    final starPositions = <String, StarPosition>{};
    
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final geometryPos = geometryPositions[i];
      
      // Use 2D geometry position and add 3D depth
      final x = geometryPos.dx - size.width / 2;
      final y = geometryPos.dy - size.height * 0.4; // Lower the constellation vertically
      final z = (i * 40.0) - (nodes.length * 20.0); // Create more pronounced depth variation
      
      // Apply 3D rotations in proper order: Z, Y, X
      // First apply Z rotation (around Z axis)
      final zRotX = x * math.cos(rotationZ) - y * math.sin(rotationZ);
      final zRotY = x * math.sin(rotationZ) + y * math.cos(rotationZ);
      final zRotZ = z;
      
      // Then apply Y rotation (around Y axis)
      final yRotX = zRotX * math.cos(rotationY) - zRotZ * math.sin(rotationY);
      final yRotY = zRotY;
      final yRotZ = zRotX * math.sin(rotationY) + zRotZ * math.cos(rotationY);
      
      // Finally apply X rotation (around X axis)
      final finalX = yRotX;
      final finalY = yRotY * math.cos(rotationX) - yRotZ * math.sin(rotationX);
      final finalZ = yRotY * math.sin(rotationX) + yRotZ * math.cos(rotationX);
      
      // Perspective projection
      const focalLength = 500.0;
      final projScale = focalLength / (focalLength + finalZ);
      final projectedX = finalX * projScale * scale;
      final projectedY = finalY * projScale * scale;
      
      // Convert to screen coordinates
      final screenX = screenCenter.dx + projectedX;
      final screenY = screenCenter.dy + projectedY;
      
      starPositions[node.id] = StarPosition(
        screenPos: Offset(screenX, screenY),
        depth: finalZ,
        node: node,
        inBounds: screenX >= -50 && screenX <= size.width + 50 &&
                 screenY >= -50 && screenY <= size.height + 50,
      );
    }
    
    // Draw constellation lines first (behind stars)
    _drawConstellationLines(canvas, starPositions);
    
    // Then draw stars on top
    for (final starPos in starPositions.values) {
      if (!starPos.inBounds) continue;
      
      // Get emotional color for this star
      final starColor = emotionalService.getEmotionalColor(starPos.node.label);
      
      // Calculate star properties with individual twinkle timing
      final depth = starPos.depth;
      final nodeIndex = nodes.indexOf(starPos.node);
      final individualTwinkleOffset = (nodeIndex * 0.37) % (2 * math.pi); // Unique phase offset
      final individualTwinkle = (math.sin(twinkleValue * 2 * math.pi + individualTwinkleOffset) + 1) * 0.5;
      final brightness = (1.0 - (depth / 300).clamp(0.0, 0.7)) * 
                        (0.6 + individualTwinkle * 0.4); // Enhanced individual twinkle
      
      // Calculate projected scale for star size
      const focalLength = 500.0;
      final projScale = focalLength / (focalLength + depth);
      final starSize = (starPos.node.size * 0.3 * projScale * scale).clamp(2.0, 8.0);
      
      // Check if this star is selected for enhanced rendering
      final isSelected = selectedNodeId == starPos.node.id;
      
      _drawStar(canvas, starPos.screenPos, starSize, starColor, brightness, isSelected);
      
      // Draw keyword label for larger stars or selected stars
      if (starSize > 4.0 || isSelected) {
        _drawStarLabel(canvas, starPos.screenPos, starPos.node.label, starColor, brightness, isSelected);
      }
    }
  }
  
  void _drawBackgroundStarfield(Canvas canvas, Size size) {
    final random = math.Random(42); // Fixed seed for consistent starfield
    final backgroundPaint = Paint()..style = PaintingStyle.fill;
    
    // Generate background stars across multiple layers for parallax
    final numStars = 150 + (size.width * size.height / 10000).round(); // Scale with screen size
    
    for (int i = 0; i < numStars; i++) {
      final x = random.nextDouble() * size.width * 1.5 - size.width * 0.25;
      final y = random.nextDouble() * size.height * 1.2 - size.height * 0.1; // Distribute stars more evenly
      
      // Create layered parallax effect
      final layer = random.nextInt(3); // 0, 1, 2 = far, medium, near
      final parallaxOffset = _calculateParallaxOffset(layer, x, y, size);
      
      final finalX = x + parallaxOffset.dx;
      final finalY = y + parallaxOffset.dy;
      
      // Skip stars outside visible area
      if (finalX < -10 || finalX > size.width + 10 ||
          finalY < -10 || finalY > size.height + 10) {
        continue;
      }
      
      // Vary star size and brightness by layer
      final baseSize = layer == 0 ? 0.5 : (layer == 1 ? 1.0 : 1.5);
      final starSize = baseSize + random.nextDouble() * 1.0;
      final baseBrightness = layer == 0 ? 0.2 : (layer == 1 ? 0.4 : 0.6);
      final brightness = baseBrightness + random.nextDouble() * 0.3;
      
      // Add subtle twinkling with individual timing to background stars
      final shouldTwinkle = (i % 3 == 0); // More stars twinkle
      final individualPhase = (i * 0.23) % (2 * math.pi); // Unique phase per star
      final individualTwinkle = shouldTwinkle 
          ? (math.sin(twinkleValue * 2 * math.pi + individualPhase) + 1) * 0.5 * 0.15
          : 0.0;
      final finalBrightness = (brightness + individualTwinkle).clamp(0.1, 0.8);
      
      // Draw background star
      backgroundPaint.color = Colors.white.withOpacity(finalBrightness);
      canvas.drawCircle(Offset(finalX, finalY), starSize, backgroundPaint);
      
      // Add tiny sparkle to brightest stars
      if (finalBrightness > 0.6 && starSize > 1.2) {
        final sparklePaint = Paint()
          ..color = Colors.white.withOpacity(finalBrightness * 0.5)
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke;
        
        // Tiny cross sparkle
        canvas.drawLine(
          Offset(finalX - starSize * 0.8, finalY),
          Offset(finalX + starSize * 0.8, finalY),
          sparklePaint,
        );
        canvas.drawLine(
          Offset(finalX, finalY - starSize * 0.8),
          Offset(finalX, finalY + starSize * 0.8),
          sparklePaint,
        );
      }
    }
  }
  
  Offset _calculateParallaxOffset(int layer, double baseX, double baseY, Size size) {
    // Create subtle parallax movement based on rotation
    final parallaxStrength = layer == 0 ? 0.1 : (layer == 1 ? 0.3 : 0.5);
    
    // Convert rotation to parallax offset
    final offsetX = rotationY * parallaxStrength * 20;
    final offsetY = rotationX * parallaxStrength * 15;
    
    // Add some circular drift for the furthest layer
    if (layer == 0) {
      final driftX = math.sin(rotationY * 2) * 5;
      final driftY = math.cos(rotationX * 2) * 5;
      return Offset(offsetX + driftX, offsetY + driftY);
    }
    
    return Offset(offsetX, offsetY);
  }
  
  void _drawConstellationLines(Canvas canvas, Map<String, StarPosition> starPositions) {
    if (starPositions.length < 2) return;
    
    // Use provided edges instead of generating dynamic connections
    final connections = _createConnectionsFromEdges(starPositions);
    
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    for (final connection in connections) {
      final star1 = starPositions[connection.nodeId1];
      final star2 = starPositions[connection.nodeId2];
      
      if (star1 == null || star2 == null || !star1.inBounds || !star2.inBounds) {
        continue;
      }
      
      // Calculate line opacity based on distance and depth
      final distance = (star1.screenPos - star2.screenPos).distance;
      final avgDepth = (star1.depth + star2.depth) / 2;
      final depthOpacity = (1.0 - (avgDepth / 400).clamp(0.0, 0.8));
      final distanceOpacity = (1.0 - (distance / 300).clamp(0.0, 0.8));
      final finalOpacity = (depthOpacity * distanceOpacity * 0.3).clamp(0.05, 0.3);
      
      // Draw faint constellation line with gentle glow
      linePaint.color = Colors.white.withOpacity(finalOpacity);
      canvas.drawLine(star1.screenPos, star2.screenPos, linePaint);
    }
  }
  
  List<ConstellationConnection> _createConnectionsFromEdges(Map<String, StarPosition> starPositions) {
    final connections = <ConstellationConnection>[];
    
    // Create connections based on the provided edges
    for (final edge in edges) {
      final star1 = starPositions[edge.source];
      final star2 = starPositions[edge.target];
      
      // Only create connection if both stars exist and are visible
      if (star1 != null && star2 != null && star1.inBounds && star2.inBounds) {
        connections.add(ConstellationConnection(edge.source, edge.target));
      }
    }
    
    return connections;
  }
  
  void _drawStar(Canvas canvas, Offset center, double size, Color color, double brightness, bool isSelected) {
    final paint = Paint()
      ..style = PaintingStyle.fill;
    
    // Selection ring animation
    if (isSelected) {
      final ringSize = size * (2.0 + selectionPulse * 0.8); // Pulsing selection ring
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.white.withOpacity((1.0 - selectionPulse) * 0.6);
      
      canvas.drawCircle(center, ringSize, ringPaint);
      
      // Inner selection glow
      final glowPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [
            color.withOpacity(0.3 + selectionPulse * 0.2),
            color.withOpacity(0.1),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: size * 2.5));
      
      canvas.drawCircle(center, size * 2.5, glowPaint);
    }
    
    // Enhanced brightness for selected stars
    final effectiveBrightness = isSelected ? (brightness * 1.3).clamp(0.0, 1.0) : brightness;
    final effectiveSize = isSelected ? size * 1.2 : size;
    
    // Core star
    paint.color = color.withOpacity(effectiveBrightness);
    canvas.drawCircle(center, effectiveSize * 0.3, paint);
    
    // Halo effect
    final haloPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(effectiveBrightness * 0.6),
          color.withOpacity(effectiveBrightness * 0.2),
          color.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: effectiveSize));
    
    canvas.drawCircle(center, effectiveSize, haloPaint);
    
    // Star sparkle lines
    if (effectiveBrightness > 0.8 || isSelected) {
      final sparkleLinesPaint = Paint()
        ..color = Colors.white.withOpacity(effectiveBrightness * 0.7)
        ..strokeWidth = isSelected ? 1.5 : 1.0
        ..style = PaintingStyle.stroke;
      
      final sparkleSize = effectiveSize * (isSelected ? 2.0 : 1.5);
      
      // Vertical sparkle line
      canvas.drawLine(
        center + Offset(0, -sparkleSize),
        center + Offset(0, sparkleSize),
        sparkleLinesPaint,
      );
      
      // Horizontal sparkle line
      canvas.drawLine(
        center + Offset(-sparkleSize, 0),
        center + Offset(sparkleSize, 0),
        sparkleLinesPaint,
      );
      
      // Diagonal sparkles for selected stars
      if (isSelected) {
        canvas.drawLine(
          center + Offset(-sparkleSize * 0.7, -sparkleSize * 0.7),
          center + Offset(sparkleSize * 0.7, sparkleSize * 0.7),
          sparkleLinesPaint,
        );
        canvas.drawLine(
          center + Offset(sparkleSize * 0.7, -sparkleSize * 0.7),
          center + Offset(-sparkleSize * 0.7, sparkleSize * 0.7),
          sparkleLinesPaint,
        );
      }
    }
  }
  
  void _drawStarLabel(Canvas canvas, Offset starPos, String label, Color color, double brightness, bool isSelected) {
    if (!isSelected && brightness < 0.5) return; // Always show labels for selected stars
    
    final effectiveBrightness = isSelected ? 1.0 : brightness;
    final fontSize = isSelected ? 12.0 : 10.0;
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: label.length > 8 ? label.substring(0, 8) : label,
        style: TextStyle(
          color: isSelected 
              ? Colors.white 
              : Colors.white.withOpacity(effectiveBrightness * 0.8),
          fontSize: fontSize,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          shadows: [
            Shadow(
              offset: const Offset(1, 1),
              blurRadius: isSelected ? 3.0 : 2.0,
              color: Colors.black.withOpacity(0.8),
            ),
            if (isSelected)
              Shadow(
                offset: Offset.zero,
                blurRadius: 6,
                color: color.withOpacity(0.5),
              ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Position label further for selected stars
    final labelOffset = isSelected ? const Offset(16, -12) : const Offset(12, -8);
    final labelPos = starPos + labelOffset;
    textPainter.paint(canvas, labelPos);
  }

  @override
  bool hitTest(Offset position) {
    if (onNodeTapped == null) return false;
    
    // Generate the same geometry positions used in paint()
    final geometryPositions = GeometryLayouts.getPositions(
      geometry: selectedGeometry,
      nodeCount: nodes.length,
      canvasSize: Size(screenCenter.dx * 2, screenCenter.dy / 0.45 * 2), // Match paint() size calculation
    );
    
    // Test each star for tap hits
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final geometryPos = geometryPositions[i];
      
      final x = geometryPos.dx - screenCenter.dx;
      final y = geometryPos.dy - screenCenter.dy;
      final z = math.sin(i * 0.5) * 100.0;
      
      // Apply 3D rotations
      final rotatedX = x * math.cos(rotationY) - z * math.sin(rotationY);
      final rotatedZ = x * math.sin(rotationY) + z * math.cos(rotationY);
      final rotatedY = y * math.cos(rotationX) - rotatedZ * math.sin(rotationX);
      final finalZ = y * math.sin(rotationX) + rotatedZ * math.cos(rotationX);
      
      // Perspective projection
      const focalLength = 500.0;
      final projScale = focalLength / (focalLength + finalZ);
      final projectedX = rotatedX * projScale * scale;
      final projectedY = rotatedY * projScale * scale;
      
      final screenX = screenCenter.dx + projectedX;
      final screenY = screenCenter.dy + projectedY;
      
      final starPos = Offset(screenX, screenY);
      final starSize = (node.size * 0.3 * projScale * scale).clamp(2.0, 8.0);
      
      // Expand hit area for better touch interaction
      final hitRadius = math.max(starSize * 2, 20.0);
      
      if ((position - starPos).distance <= hitRadius) {
        onNodeTapped!(node.id);
        return true;
      }
    }
    
    return false;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Helper class to store 3D star position and metadata
class StarPosition {
  final Offset screenPos;
  final double depth;
  final Node node;
  final bool inBounds;

  StarPosition({
    required this.screenPos,
    required this.depth,
    required this.node,
    required this.inBounds,
  });
}

/// Represents a connection between two stars
class ConstellationConnection {
  final String nodeId1;
  final String nodeId2;

  ConstellationConnection(this.nodeId1, this.nodeId2);
}

