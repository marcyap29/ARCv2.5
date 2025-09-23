import 'dart:math' as math;
import 'package:flutter/material.dart' hide Material;
import 'package:flutter_cube/flutter_cube.dart' as cube;
import 'package:my_app/features/arcforms/arcform_renderer_state.dart';

/// A 3D spherical node widget using flutter_cube
class SphericalNodeWidget extends StatefulWidget {
  final Node node;
  final Function(String, double, double)? onMoved;
  final Function(String)? onTapped;
  final double rotationX;
  final double rotationY;
  final double rotationZ;
  final double scale;

  const SphericalNodeWidget({
    super.key,
    required this.node,
    this.onMoved,
    this.onTapped,
    this.rotationX = 0.0,
    this.rotationY = 0.0,
    this.rotationZ = 0.0,
    this.scale = 1.0,
  });

  @override
  State<SphericalNodeWidget> createState() => _SphericalNodeWidgetState();
}

class _SphericalNodeWidgetState extends State<SphericalNodeWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for node highlight
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Auto-rotation for the sphere
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    _rotationController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  Color _getNodeColor() {
    // Convert node label to a consistent color
    final hash = widget.node.label.hashCode;
    final hue = (hash.abs() % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.7, 0.6).toColor();
  }

  cube.Mesh _createSphereMesh() {
    final vertices = <cube.Vector3>[];
    final indices = <cube.Polygon>[];
    
    const latSegments = 16;
    const lonSegments = 16;
    const radius = 1.0;
    
    // Generate vertices
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
      }
    }
    
    // Generate indices for triangles as Polygon objects
    for (int lat = 0; lat < latSegments; lat++) {
      for (int lon = 0; lon < lonSegments; lon++) {
        final first = (lat * (lonSegments + 1)) + lon;
        final second = first + lonSegments + 1;
        
        // Create triangles as Polygon objects
        indices.add(cube.Polygon(first, second, first + 1));
        indices.add(cube.Polygon(second, second + 1, first + 1));
      }
    }
    
    return cube.Mesh(
      vertices: vertices,
      indices: indices,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nodeColor = _getNodeColor();
    final size = widget.node.size;
    
    return Positioned(
      left: widget.node.x - size / 2,
      top: widget.node.y - size / 2,
      child: GestureDetector(
        onTap: () => widget.onTapped?.call(widget.node.id),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.scale * _pulseAnimation.value,
              child: SizedBox(
                width: size,
                height: size,
                child: cube.Cube(
                  onSceneCreated: (cube.Scene scene) {
                    scene.world.add(
                      cube.Object(
                        mesh: _createSphereMesh(),
                        rotation: cube.Vector3(
                          widget.rotationX,
                          widget.rotationY,
                          widget.rotationZ,
                        ),
                      ),
                    );
                    
                    // Basic scene setup (no lighting configuration needed)
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 3D Node data structure with Z coordinate
class Node3D {
  final String id;
  final String label;
  final double x;
  final double y;
  final double z;
  final double size;
  final Color? color;

  Node3D({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.z,
    required this.size,
    this.color,
  });
}

/// Helper to convert 2D nodes to 3D
Node3D convertTo3D(Node node, {double z = 0.0}) {
  return Node3D(
    id: node.id,
    label: node.label,
    x: node.x,
    y: node.y,
    z: z,
    size: node.size,
  );
}