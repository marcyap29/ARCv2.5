import 'package:flutter/material.dart';
import 'package:my_app/features/arcforms/arcform_renderer_state.dart';
import 'package:my_app/features/arcforms/widgets/node_widget.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';


class ArcformLayout extends StatefulWidget {
  final List<Node> nodes;
  final List<Edge> edges;
  final Function(String, double, double)? onNodeMoved;
  final Function(String)? onNodeTapped;
  final GeometryPattern selectedGeometry;
  final String currentPhase;
  final Function(GeometryPattern) onGeometryChanged;

  const ArcformLayout({
    super.key,
    required this.nodes,
    required this.edges,
    this.onNodeMoved,
    this.onNodeTapped,
    required this.selectedGeometry,
    required this.currentPhase,
    required this.onGeometryChanged,
  });

  @override
  State<ArcformLayout> createState() => _ArcformLayoutState();
}

class _ArcformLayoutState extends State<ArcformLayout>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  // Rotation state
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  double _rotationZ = 0.0;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Offset? _lastFocalPoint;

  void _handleScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // Handle scaling with pinch gestures
      if (details.scale != 1.0) {
        _scale = (_scale * details.scale).clamp(0.5, 3.0);
      }
      
      // Handle rotation with single finger drag (when scale is close to 1.0)
      if (_lastFocalPoint != null && details.pointerCount == 1) {
        final delta = details.focalPoint - _lastFocalPoint!;
        _rotationY += delta.dx * 0.01; // Horizontal drag rotates around Y-axis
        _rotationX -= delta.dy * 0.01; // Vertical drag rotates around X-axis
        
        // Clamp rotations to prevent extreme angles
        _rotationX = _rotationX.clamp(-1.5, 1.5);
        _rotationY = _rotationY.clamp(-3.14, 3.14);
      }
      
      // Handle Z-axis rotation with two-finger twist
      if (details.pointerCount == 2 && details.rotation != 0) {
        _rotationZ += details.rotation * 0.5;
      }
      
      _lastFocalPoint = details.focalPoint;
    });
  }


  @override
  void didUpdateWidget(covariant ArcformLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedGeometry != widget.selectedGeometry) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  List<Node> _calculateGeometryNodes() {
    // Use the pre-calculated positions from the cubit instead of recalculating
    // The nodes already have the correct positions based on their geometry
    return widget.nodes;
  }




  @override
  Widget build(BuildContext context) {
    final geometryNodes = _calculateGeometryNodes();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: kcBackgroundColor,
      body: Stack(
        children: [
          // Rotatable Arcform container
          GestureDetector(
            onScaleStart: _handleScaleStart,
            onScaleUpdate: _handleScaleUpdate,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // Add perspective
                ..rotateX(_rotationX)
                ..rotateY(_rotationY)
                ..rotateZ(_rotationZ)
                ..scale(_scale),
              child: Stack(
                children: [
                  // Edges
                  CustomPaint(
                    size: size,
                    painter: EdgePainter(
                      edges: widget.edges,
                      nodes: geometryNodes,
                      animation: _animation,
                    ),
                  ),
                  // Nodes
                  ...geometryNodes.map((node) {
                    return NodeWidget(
                      key: ValueKey(node.id),
                      node: node,
                      onMoved: widget.onNodeMoved,
                      onTapped: widget.onNodeTapped,
                    );
                  }),
                ],
              ),
            ),
          ),
          // Geometry selector
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kcSurfaceColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sacred Geometry',
                    style: heading2Style(context).copyWith(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: GeometryPattern.values.map((pattern) {
                        final isSelected = pattern == widget.selectedGeometry;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              pattern.displayName,
                              style: isSelected
                                  ? bodyStyle(context).copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    )
                                  : bodyStyle(context).copyWith(
                                      color: kcSecondaryColor,
                                    ),
                            ),
                            selected: isSelected,
                            selectedColor: kcPrimaryColor,
                            backgroundColor: kcSurfaceAltColor,
                            onSelected: (selected) {
                              if (selected) {
                                widget.onGeometryChanged(pattern);
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
        ],
      ),
    );
  }
}

class EdgePainter extends CustomPainter {
  final List<Edge> edges;
  final List<Node> nodes;
  final Animation<double> animation;

  EdgePainter({
    required this.edges,
    required this.nodes,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kcSecondaryColor.withOpacity(0.3 * animation.value)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final sourceNode = nodes.firstWhere(
        (node) => node.id == edge.source,
        orElse: () => nodes.first,
      );
      final targetNode = nodes.firstWhere(
        (node) => node.id == edge.target,
        orElse: () => nodes.last,
      );

      canvas.drawLine(
        Offset(sourceNode.x, sourceNode.y),
        Offset(targetNode.x, targetNode.y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
