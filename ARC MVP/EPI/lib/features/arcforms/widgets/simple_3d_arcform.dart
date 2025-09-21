import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:my_app/features/arcforms/arcform_mvp_implementation.dart';
import 'package:my_app/features/arcforms/arcform_renderer_state.dart';
import 'package:my_app/features/arcforms/geometry/geometry_3d_layouts.dart';
import 'package:my_app/features/arcforms/widgets/spherical_node_widget.dart';
import 'package:my_app/features/arcforms/services/emotional_valence_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

/// Simple 3D Arcform using Flutter's Transform widget and custom painting
class Simple3DArcform extends StatefulWidget {
  final List<Node> nodes;
  final List<Edge> edges;
  final Function(String, double, double)? onNodeMoved;
  final Function(String)? onNodeTapped;
  final ArcformGeometry selectedGeometry;
  final Function(ArcformGeometry) onGeometryChanged;
  final VoidCallback? onExport;
  final VoidCallback? onAutoRotate;
  final VoidCallback? onResetView;

  const Simple3DArcform({
    super.key,
    required this.nodes,
    required this.edges,
    this.onNodeMoved,
    this.onNodeTapped,
    required this.selectedGeometry,
    required this.onGeometryChanged,
    this.onExport,
    this.onAutoRotate,
    this.onResetView,
  });

  @override
  State<Simple3DArcform> createState() => _Simple3DArcformState();
}

class _Simple3DArcformState extends State<Simple3DArcform>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  // 3D rotation and scaling state
  double _rotationX = 0.2; // Start with slight tilt for better 3D view
  double _rotationY = 0.0;
  double _scale = 1.0;
  bool _autoRotate = true;
  
  late AnimationController _autoRotateController;

  @override
  void initState() {
    super.initState();
    
    // Geometry transition animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    
    // Auto-rotation animation
    _autoRotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    
    if (_autoRotate) {
      _autoRotateController.repeat();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _autoRotateController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant Simple3DArcform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedGeometry != widget.selectedGeometry) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  Offset? _lastFocalPoint;

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
        _rotationY += delta.dx * 0.01;
        _rotationX -= delta.dy * 0.01;
        
        _rotationX = _rotationX.clamp(-math.pi/2, math.pi/2);
        _rotationY = _rotationY % (2 * math.pi);
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

  List<Node3D> _calculate3DNodes() {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height * 0.35);
    
    // Get 3D positions for the geometry
    final positions3D = Geometry3DLayouts.getPositions3D(
      geometry: widget.selectedGeometry,
      nodeCount: widget.nodes.length,
      canvasSize: size,
    );
    
    // Map the 2D nodes to 3D positions, preserving the actual node data
    final mappedNodes = <Node3D>[];
    for (int i = 0; i < widget.nodes.length && i < positions3D.length; i++) {
      final originalNode = widget.nodes[i];
      final position3D = positions3D[i];
      
      mappedNodes.add(Node3D(
        id: originalNode.id,
        label: originalNode.label,
        x: position3D.x - center.dx, // Remove center offset since we'll add it back in projection
        y: position3D.y - center.dy,
        z: position3D.z,
        size: originalNode.size,
        color: null, // Color will be determined by emotional valence service
      ));
    }
    
    return mappedNodes;
  }


  Widget _build3DNode(Node3D node3D, double autoRotY) {
    // Calculate the projected 2D position from 3D coordinates
    final rotatedX = node3D.x * math.cos(_rotationY + autoRotY) - node3D.z * math.sin(_rotationY + autoRotY);
    final rotatedZ = node3D.x * math.sin(_rotationY + autoRotY) + node3D.z * math.cos(_rotationY + autoRotY);
    final rotatedY = node3D.y * math.cos(_rotationX) - rotatedZ * math.sin(_rotationX);
    final finalZ = node3D.y * math.sin(_rotationX) + rotatedZ * math.cos(_rotationX);
    
    // Simple perspective projection with better bounds
    const focalLength = 400.0;
    final scale = focalLength / (focalLength + finalZ);
    final projectedX = rotatedX * scale;
    final projectedY = rotatedY * scale;
    
    // Scale for depth effect
    final depthScale = (1.0 + finalZ / 300).clamp(0.4, 1.8);
    final nodeSize = node3D.size * depthScale * _scale;
    
    // Get emotional color for this node
    final emotionalService = EmotionalValenceService();
    final nodeColor = emotionalService.getEmotionalColor(node3D.label);
    
    // Center the projection in the screen
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height * 0.25; // Move arcform higher up
    
    final finalX = centerX + projectedX - nodeSize / 2;
    final finalY = centerY + projectedY - nodeSize / 2;
    
    // Only render if within reasonable bounds
    if (finalX < -nodeSize || finalX > screenSize.width + nodeSize ||
        finalY < -nodeSize || finalY > screenSize.height + nodeSize) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      left: finalX,
      top: finalY,
      child: GestureDetector(
        onTap: () => widget.onNodeTapped?.call(node3D.label),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 3D Sphere
            CustomPaint(
              size: Size(nodeSize, nodeSize),
              painter: SpherePainter(
                color: nodeColor,
                depth: finalZ,
              ),
            ),
            // Label
            if (nodeSize > 20) // Only show label if sphere is large enough
              Container(
                constraints: BoxConstraints(
                  maxWidth: nodeSize * 0.8,
                  maxHeight: nodeSize * 0.8,
                ),
                child: Text(
                  node3D.label.length > 8 
                    ? node3D.label.substring(0, 1).toUpperCase()
                    : node3D.label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: nodeSize * 0.25,
                    shadows: [
                      Shadow(
                        offset: const Offset(1, 1),
                        blurRadius: 2.0,
                        color: Colors.black.withOpacity(0.7),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _build3DEdges(List<Node3D> nodes3D, double autoRotY) {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: Edge3DPainter(
        nodes: nodes3D,
        edges: widget.edges,
        rotationX: _rotationX,
        rotationY: _rotationY + autoRotY,
        scale: _scale,
        screenCenter: Offset(
          MediaQuery.of(context).size.width / 2,
          MediaQuery.of(context).size.height * 0.25, // Move arcform higher up
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nodes3D = _calculate3DNodes();
    
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      body: Stack(
        children: [
          // 3D Scene with nodes
          GestureDetector(
            onScaleStart: _handleScaleStart,
            onScaleUpdate: _handleScaleUpdate,
            onScaleEnd: _handleScaleEnd,
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: AnimatedBuilder(
                animation: Listenable.merge([_animation, _autoRotateController]),
                builder: (context, child) {
                  final autoRotY = _autoRotate ? _autoRotateController.value * 2 * math.pi : 0.0;
                  
                  return Opacity(
                    opacity: _animation.value,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 3D Edges (drawn first, behind nodes)
                        _build3DEdges(nodes3D, autoRotY),
                        // Position center reference point
                        Positioned.fill(
                          child: Center(
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: kcPrimaryColor.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                        // 3D Nodes
                        ...nodes3D.map((node3D) => _build3DNode(node3D, autoRotY)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Geometry selector overlay
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
                        Icons.view_in_ar,
                        color: kcPrimaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '3D Arcform Geometry',
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
                      const SizedBox(width: 8),
                      // Auto-rotate button
                      Container(
                        decoration: BoxDecoration(
                          color: _autoRotate ? kcPrimaryColor : kcSurfaceAltColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _autoRotate ? kcPrimaryColor : kcSecondaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _autoRotate = !_autoRotate;
                            });
                            if (_autoRotate) {
                              _autoRotateController.repeat();
                            } else {
                              _autoRotateController.stop();
                            }
                            widget.onAutoRotate?.call();
                          },
                          icon: Icon(
                            Icons.refresh,
                            color: _autoRotate ? Colors.white : kcSecondaryColor,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Reset view button
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
                          onPressed: () {
                            setState(() {
                              _rotationX = 0.2;
                              _rotationY = 0.0;
                              _scale = 1.0;
                            });
                            widget.onResetView?.call();
                          },
                          icon: const Icon(
                            Icons.center_focus_strong,
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

/// Custom painter for 3D sphere effect using gradients
class SpherePainter extends CustomPainter {
  final Color color;
  final double depth;

  SpherePainter({required this.color, required this.depth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Create gradient for 3D sphere effect
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.3), // Light source from top-left
      radius: 1.0,
      colors: [
        color.withOpacity(0.9), // Highlight
        color.withOpacity(0.7), // Main color
        color.withOpacity(0.3), // Shadow
        color.withOpacity(0.1), // Deep shadow
      ],
      stops: const [0.0, 0.4, 0.8, 1.0],
    );
    
    final paint = Paint()..shader = gradient.createShader(
      Rect.fromCircle(center: center, radius: radius),
    );
    
    // Draw sphere with depth-based opacity
    final depthOpacity = (1.0 - (depth / 300).clamp(0.0, 0.7));
    paint.color = paint.color.withOpacity(depthOpacity);
    
    canvas.drawCircle(center, radius, paint);
    
    // Add highlight for extra 3D effect
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3 * depthOpacity)
      ..style = PaintingStyle.fill;
      
    canvas.drawCircle(
      center + Offset(-radius * 0.3, -radius * 0.3),
      radius * 0.3,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Custom painter for 3D edges between nodes
class Edge3DPainter extends CustomPainter {
  final List<Node3D> nodes;
  final List<Edge> edges;
  final double rotationX;
  final double rotationY;
  final double scale;
  final Offset screenCenter;

  Edge3DPainter({
    required this.nodes,
    required this.edges,
    required this.rotationX,
    required this.rotationY,
    required this.scale,
    required this.screenCenter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Project 3D coordinates to 2D for each node
    final projectedNodes = <String, Offset>{};
    
    for (final node in nodes) {
      // Apply 3D rotations
      final rotatedX = node.x * math.cos(rotationY) - node.z * math.sin(rotationY);
      final rotatedZ = node.x * math.sin(rotationY) + node.z * math.cos(rotationY);
      final rotatedY = node.y * math.cos(rotationX) - rotatedZ * math.sin(rotationX);
      final finalZ = node.y * math.sin(rotationX) + rotatedZ * math.cos(rotationX);
      
      // Perspective projection
      const focalLength = 400.0;
      final projScale = focalLength / (focalLength + finalZ);
      final projectedX = rotatedX * projScale;
      final projectedY = rotatedY * projScale;
      
      // Convert to screen coordinates
      final screenX = screenCenter.dx + projectedX;
      final screenY = screenCenter.dy + projectedY;
      
      // Use node.id for matching with edges (not node.label)
      projectedNodes[node.id] = Offset(screenX, screenY);
    }

    // Draw edges
    for (final edge in edges) {
      final fromNode = projectedNodes[edge.source];
      final toNode = projectedNodes[edge.target];
      
      if (fromNode != null && toNode != null) {
        // Calculate distance for opacity
        final distance = (fromNode - toNode).distance;
        final opacity = (1.0 - (distance / 200.0)).clamp(0.3, 0.8);
        
        paint.color = Colors.white.withOpacity(opacity);
        canvas.drawLine(fromNode, toNode, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}