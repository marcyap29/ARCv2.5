import 'dart:math' as math;
import 'package:flutter/material.dart' hide Material;
import 'package:flutter_cube/flutter_cube.dart' as cube;
import 'package:my_app/arc/ui/arcforms/arcform_mvp_implementation.dart';
import 'package:my_app/arc/ui/arcforms/arcform_renderer_state.dart';
import 'package:my_app/arc/ui/arcforms/geometry/geometry_3d_layouts.dart';
import 'package:my_app/arc/ui/arcforms/widgets/spherical_node_widget.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class Arcform3DLayout extends StatefulWidget {
  final List<Node> nodes;
  final List<Edge> edges;
  final Function(String, double, double)? onNodeMoved;
  final Function(String)? onNodeTapped;
  final ArcformGeometry selectedGeometry;
  final Function(ArcformGeometry) onGeometryChanged;

  const Arcform3DLayout({
    super.key,
    required this.nodes,
    required this.edges,
    this.onNodeMoved,
    this.onNodeTapped,
    required this.selectedGeometry,
    required this.onGeometryChanged,
  });

  @override
  State<Arcform3DLayout> createState() => _Arcform3DLayoutState();
}

class _Arcform3DLayoutState extends State<Arcform3DLayout>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  // 3D rotation and scaling state
  double _rotationX = 0.2; // Start with slight tilt for better 3D view
  double _rotationY = 0.0;
  double _rotationZ = 0.0;
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
  void didUpdateWidget(covariant Arcform3DLayout oldWidget) {
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
      _autoRotate = false; // Stop auto-rotation when user interacts
    });
    _autoRotateController.stop();
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      final currentPointerCount = details.pointerCount;

      if (currentPointerCount == 1) {
        // Single finger: orbit around the center
        if (_lastFocalPoint != null) {
          final delta = details.focalPoint - _lastFocalPoint!;
          // Orbit controls - horizontal movement orbits around Y-axis, vertical around X-axis
          _rotationY += delta.dx * 0.01; // Horizontal drag orbits around Y-axis
          _rotationX -= delta.dy * 0.01; // Vertical drag orbits around X-axis (inverted for natural feel)
          _rotationX = _rotationX.clamp(-math.pi/2, math.pi/2); // Prevent flipping upside down
          _rotationY = _rotationY % (2 * math.pi); // Allow full rotation around Y
        }
      } else if (currentPointerCount == 2) {
        // Two fingers: pinch to zoom AND rotate in all axes

        // Pinch zoom
        if (details.scale != 1.0) {
          _scale = (_scale * details.scale).clamp(0.3, 3.0);
        }

        // Two-finger rotation in X, Y, and Z axes
        if (_lastFocalPoint != null) {
          final delta = details.focalPoint - _lastFocalPoint!;

          // X and Y rotation from focal point movement
          _rotationY += delta.dx * 0.008; // Slightly less sensitive for two-finger
          _rotationX -= delta.dy * 0.008;
          _rotationX = _rotationX.clamp(-math.pi/2, math.pi/2);
          _rotationY = _rotationY % (2 * math.pi);

          // Z-axis rotation from twist gesture
          if (details.rotation != 0) {
            _rotationZ += details.rotation * 0.5; // Z-axis rotation for twist
            _rotationZ = _rotationZ % (2 * math.pi);
          }
        }
      }

      _lastFocalPoint = details.focalPoint;
    });
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    // Optionally restart auto-rotation after a delay
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
    return Geometry3DLayouts.getPositions3D(
      geometry: widget.selectedGeometry,
      nodeCount: widget.nodes.length,
      canvasSize: size,
    );
  }

  Widget _build3DScene() {
    final nodes3D = _calculate3DNodes();
    
    return AnimatedBuilder(
      animation: _autoRotateController,
      builder: (context, child) {
        final autoRotY = _autoRotate ? _autoRotateController.value * 2 * math.pi : 0.0;
        
        return cube.Cube(
          onSceneCreated: (cube.Scene scene) {
            // Clear existing objects
            scene.world.children.clear();
            
            // Create materials for different geometry types (simplified)
            final cube.Material nodeMaterial = cube.Material();
            final cube.Material edgeMaterial = cube.Material();
            
            // Add 3D nodes as spheres
            for (final node in nodes3D) {
              final sphere = cube.Object(
                mesh: _createSphereMesh(radius: node.size / 40), // Scale for 3D scene
                position: cube.Vector3(
                  node.x / 100, // Scale positions for 3D scene
                  node.y / 100,
                  node.z / 100,
                ),
              );
              scene.world.add(sphere);
            }
            
            // Apply rotations to the camera/view instead
            scene.camera.position.x = 5.0 * math.cos(_rotationY + autoRotY);
            scene.camera.position.z = 5.0 * math.sin(_rotationY + autoRotY);
            scene.camera.position.y = 3.0 * math.sin(_rotationX);
            // scene.camera.target = cube.Vector3.zero(); // target is final, cannot be assigned
          },
        );
      },
    );
  }

  Color _getGeometryColor() {
    switch (widget.selectedGeometry) {
      case ArcformGeometry.spiral:
        return const Color(0xFF4F46E5); // Blue for Discovery
      case ArcformGeometry.flower:
        return const Color(0xFF7C3AED); // Purple for Expansion
      case ArcformGeometry.branch:
        return const Color(0xFF6BE3A0); // Green for Transition
      case ArcformGeometry.weave:
        return const Color(0xFFF7D774); // Yellow for Consolidation
      case ArcformGeometry.glowCore:
        return const Color(0xFFFF6B6B); // Red for Recovery
      case ArcformGeometry.fractal:
        return const Color(0xFF4ECDC4); // Teal for Breakthrough
    }
  }

  cube.Mesh _createSphereMesh({double radius = 1.0}) {
    final vertices = <cube.Vector3>[];
    final normals = <cube.Vector3>[];
    final indices = <int>[];
    
    const latSegments = 12;
    const lonSegments = 12;
    
    // Generate vertices and normals
    for (int lat = 0; lat <= latSegments; lat++) {
      final theta = lat * math.pi / latSegments;
      final sinTheta = math.sin(theta);
      final cosTheta = math.cos(theta);
      
      for (int lon = 0; lon <= lonSegments; lon++) {
        final phi = lon * 2 * math.pi / lonSegments;
        final sinPhi = math.sin(phi);
        final cosPhi = math.cos(phi);
        
        final x = cosPhi * sinTheta;
        final y = cosTheta;
        final z = sinPhi * sinTheta;
        
        vertices.add(cube.Vector3(x * radius, y * radius, z * radius));
        normals.add(cube.Vector3(x, y, z));
      }
    }
    
    // Generate indices for triangles
    for (int lat = 0; lat < latSegments; lat++) {
      for (int lon = 0; lon < lonSegments; lon++) {
        final first = (lat * (lonSegments + 1)) + lon;
        final second = first + lonSegments + 1;
        
        indices.addAll([first, second, first + 1]);
        indices.addAll([second, second + 1, first + 1]);
      }
    }
    
    return cube.Mesh(
      vertices: vertices,
      // normals: normals, // normals parameter not defined in cube.Mesh
      // indices: indices, // indices type mismatch
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      body: Stack(
        children: [
          // 3D Scene
          GestureDetector(
            onScaleStart: _handleScaleStart,
            onScaleUpdate: _handleScaleUpdate,
            onScaleEnd: _handleScaleEnd,
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _animation.value,
                    child: _build3DScene(),
                  );
                },
              ),
            ),
          ),
          
          // Geometry selector overlay
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kcSurfaceColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
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
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '3D Arcform Geometry',
                        style: heading3Style(context).copyWith(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ArcformGeometry.values.map((geometry) {
                        final isSelected = geometry == widget.selectedGeometry;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              geometry.name,
                              style: captionStyle(context).copyWith(
                                color: isSelected ? Colors.white : kcSecondaryColor,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
                ],
              ),
            ),
          ),
          
          // Controls overlay
          Positioned(
            bottom: 30,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Auto-rotate toggle
                FloatingActionButton.small(
                  onPressed: () {
                    setState(() {
                      _autoRotate = !_autoRotate;
                    });
                    if (_autoRotate) {
                      _autoRotateController.repeat();
                    } else {
                      _autoRotateController.stop();
                    }
                  },
                  backgroundColor: _autoRotate ? kcPrimaryColor : kcSurfaceAltColor,
                  child: Icon(
                    Icons.rotate_right,
                    color: _autoRotate ? Colors.white : kcSecondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                // Reset view
                FloatingActionButton.small(
                  onPressed: () {
                    setState(() {
                      _rotationX = 0.2;
                      _rotationY = 0.0;
                      _rotationZ = 0.0;
                      _scale = 1.0;
                    });
                  },
                  backgroundColor: kcSurfaceAltColor,
                  child: const Icon(
                    Icons.center_focus_strong,
                    color: kcSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}