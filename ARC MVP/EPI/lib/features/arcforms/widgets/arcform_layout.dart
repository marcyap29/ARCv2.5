import 'dart:math';
import 'package:flutter/material.dart';
import 'package:my_app/features/arcforms/arcform_renderer_state.dart';
import 'package:my_app/features/arcforms/widgets/node_widget.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class ArcformLayout extends StatefulWidget {
  final List<Node> nodes;
  final List<Edge> edges;
  final Function(String, double, double)? onNodeMoved;
  final GeometryPattern selectedGeometry;
  final Function(GeometryPattern) onGeometryChanged;

  const ArcformLayout({
    super.key,
    required this.nodes,
    required this.edges,
    this.onNodeMoved,
    required this.selectedGeometry,
    required this.onGeometryChanged,
  });

  @override
  State<ArcformLayout> createState() => _ArcformLayoutState();
}

class _ArcformLayoutState extends State<ArcformLayout>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

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

  @override
  void didUpdateWidget(covariant ArcformLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedGeometry != widget.selectedGeometry) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  List<Node> _calculateGeometryNodes() {
    final size = MediaQuery.of(context).size;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = min(size.width, size.height) * 0.3;

    switch (widget.selectedGeometry) {
      case GeometryPattern.spiral:
        return _calculateSpiralNodes(centerX, centerY, radius);
      case GeometryPattern.flower:
        return _calculateFlowerNodes(centerX, centerY, radius);
      case GeometryPattern.branch:
        return _calculateBranchNodes(centerX, centerY, radius);
      case GeometryPattern.weave:
        return _calculateWeaveNodes(centerX, centerY, radius);
      case GeometryPattern.glowCore:
        return _calculateGlowCoreNodes(centerX, centerY, radius);
      case GeometryPattern.fractal:
        return _calculateFractalNodes(centerX, centerY, radius);
      default:
        return _calculateSpiralNodes(centerX, centerY, radius);
    }
  }

  List<Node> _calculateSpiralNodes(
      double centerX, double centerY, double radius) {
    final nodes = <Node>[];
    final count = widget.nodes.length;

    for (int i = 0; i < count; i++) {
      final progress = i / (count - 1);
      final angle = progress * 4 * pi;
      final distance = progress * radius;

      final x = centerX + distance * cos(angle);
      final y = centerY + distance * sin(angle);

      nodes.add(Node(
        id: widget.nodes[i].id,
        label: widget.nodes[i].label,
        x: x,
        y: y,
        size: widget.nodes[i].size,
      ));
    }

    return nodes;
  }

  List<Node> _calculateFlowerNodes(
      double centerX, double centerY, double radius) {
    final nodes = <Node>[];
    final count = widget.nodes.length;
    final petals = min(count, 8);
    final nodesPerPetal = count ~/ petals;

    for (int i = 0; i < count; i++) {
      final petalIndex = i ~/ nodesPerPetal;
      final nodeInPetal = i % nodesPerPetal;

      final angle = (2 * pi * petalIndex / petals) +
          (nodeInPetal * pi / (4 * nodesPerPetal));
      final distance = radius * (0.3 + 0.7 * (nodeInPetal / nodesPerPetal));

      final x = centerX + distance * cos(angle);
      final y = centerY + distance * sin(angle);

      nodes.add(Node(
        id: widget.nodes[i].id,
        label: widget.nodes[i].label,
        x: x,
        y: y,
        size: widget.nodes[i].size,
      ));
    }

    return nodes;
  }

  List<Node> _calculateBranchNodes(
      double centerX, double centerY, double radius) {
    final nodes = <Node>[];
    final count = widget.nodes.length;

    // Root node at center
    nodes.add(Node(
      id: widget.nodes[0].id,
      label: widget.nodes[0].label,
      x: centerX,
      y: centerY,
      size: widget.nodes[0].size,
    ));

    // Branch nodes
    for (int i = 1; i < count; i++) {
      final branchLevel = (i - 1) ~/ 3;
      final nodeInBranch = (i - 1) % 3;

      final angle = (2 * pi * branchLevel) / (count ~/ 3);
      final distance = radius * (0.2 + 0.8 * (branchLevel / (count ~/ 3)));

      final offsetX = nodeInBranch == 0 ? 0 : (nodeInBranch == 1 ? -30 : 30);
      final offsetY = nodeInBranch == 0 ? -40 : 0;

      final x = centerX + distance * cos(angle) + offsetX;
      final y = centerY + distance * sin(angle) + offsetY;

      nodes.add(Node(
        id: widget.nodes[i].id,
        label: widget.nodes[i].label,
        x: x,
        y: y,
        size: widget.nodes[i].size,
      ));
    }

    return nodes;
  }

  List<Node> _calculateWeaveNodes(
      double centerX, double centerY, double radius) {
    final nodes = <Node>[];
    final count = widget.nodes.length;
    final gridSize = sqrt(count).ceil();

    for (int i = 0; i < count; i++) {
      final row = i ~/ gridSize;
      final col = i % gridSize;

      final x = centerX + (col - gridSize / 2) * (radius / gridSize) * 2;
      final y = centerY + (row - gridSize / 2) * (radius / gridSize) * 2;

      nodes.add(Node(
        id: widget.nodes[i].id,
        label: widget.nodes[i].label,
        x: x,
        y: y,
        size: widget.nodes[i].size,
      ));
    }

    return nodes;
  }

  List<Node> _calculateGlowCoreNodes(
      double centerX, double centerY, double radius) {
    final nodes = <Node>[];
    final count = widget.nodes.length;

    // Core node
    nodes.add(Node(
      id: widget.nodes[0].id,
      label: widget.nodes[0].label,
      x: centerX,
      y: centerY,
      size: widget.nodes[0].size * 1.5,
    ));

    // Orbiting nodes
    for (int i = 1; i < count; i++) {
      final angle = (2 * pi * (i - 1)) / (count - 1);
      final distance = radius * 0.7;

      final x = centerX + distance * cos(angle);
      final y = centerY + distance * sin(angle);

      nodes.add(Node(
        id: widget.nodes[i].id,
        label: widget.nodes[i].label,
        x: x,
        y: y,
        size: widget.nodes[i].size,
      ));
    }

    return nodes;
  }

  List<Node> _calculateFractalNodes(
      double centerX, double centerY, double radius) {
    final nodes = <Node>[];
    final count = widget.nodes.length;

    // Central node
    nodes.add(Node(
      id: widget.nodes[0].id,
      label: widget.nodes[0].label,
      x: centerX,
      y: centerY,
      size: widget.nodes[0].size,
    ));

    // Fractal branches
    for (int i = 1; i < count; i++) {
      final level = (log(i) / log(3)).floor();
      final positionInLevel = i - pow(3, level).toInt();

      final branches = pow(3, level).toInt();
      final angle = (2 * pi * positionInLevel) / branches;
      final distance = radius * (0.2 + 0.6 * (level / 4));

      final x = centerX + distance * cos(angle);
      final y = centerY + distance * sin(angle);

      nodes.add(Node(
        id: widget.nodes[i].id,
        label: widget.nodes[i].label,
        x: x,
        y: y,
        size: widget.nodes[i].size * (1.0 - level * 0.15),
      ));
    }

    return nodes;
  }

  @override
  Widget build(BuildContext context) {
    final geometryNodes = _calculateGeometryNodes();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: kcBackgroundColor,
      body: Stack(
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
            );
          }).toList(),
          // Geometry selector
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kcSurfaceColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Geometry Patterns',
                    style: heading2Style(context).copyWith(
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
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
