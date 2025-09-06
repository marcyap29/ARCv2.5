import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import 'mira_graph_cubit.dart';
import 'widgets/mira_node_sheet.dart';
import 'info/info_icon.dart';

/// Interactive MIRA graph visualization
class MiraGraphView extends StatefulWidget {
  const MiraGraphView({Key? key}) : super(key: key);

  @override
  State<MiraGraphView> createState() => _MiraGraphViewState();
}

class _MiraGraphViewState extends State<MiraGraphView> {
  late MiraGraphCubit _cubit;
  final TransformationController _transformationController = TransformationController();
  
  // Hit testing
  MiraGraphNode? _hoveredNode;
  MiraGraphEdge? _hoveredEdge;
  Offset? _lastTapPosition; // DEBUG: Track last tap position

  @override
  void initState() {
    super.initState();
    _cubit = MiraGraphCubit();
    _cubit.loadGraph();
  }

  @override
  void dispose() {
    _cubit.close();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcSurfaceColor,
      appBar: AppBar(
        title: Text(
          'Your Patterns',
          style: heading2Style(context).copyWith(color: kcPrimaryColor),
        ),
        backgroundColor: kcSurfaceColor,
        elevation: 0,
        actions: [
          InfoIcons.patternsScreen(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: kcPrimaryColor),
            onPressed: () {
              _cubit.loadGraph();
            },
          ),
        ],
      ),
      body: StreamBuilder<MiraGraphState>(
        stream: _cubit.stream,
        builder: (context, snapshot) {
          final state = snapshot.data ?? _cubit.state;

          if (state is MiraGraphLoading) {
            return const Center(
              child: CircularProgressIndicator(color: kcPrimaryColor),
            );
          }

          if (state is MiraGraphError) {
            return _buildErrorState(state.message);
          }

          if (state is MiraGraphLoaded) {
            if (state.nodes.isEmpty) {
              return _buildEmptyState();
            }
            return _buildGraphView(state);
          }

          return const Center(
            child: CircularProgressIndicator(color: kcPrimaryColor),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: kcDangerColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Graph',
            style: heading3Style(context).copyWith(color: kcDangerColor),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _cubit.loadGraph();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 64,
            color: kcSecondaryTextColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No Patterns Yet',
            style: heading3Style(context).copyWith(color: kcSecondaryTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Add more journal entries to see your patterns emerge.',
            style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGraphView(MiraGraphLoaded state) {
    // Convert MiraGraphNode to NodeView
    final nodeViews = state.nodes.map((node) => NodeView(
      position: node.position,
      radius: node.size / 2,
      color: node.color,
      strokeWidth: 1.5,
      label: node.label,
      labelStyle: const TextStyle(
        color: kcPrimaryTextColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    )).toList();

    return Column(
      children: [
        // Helper text
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Follow a word to its moments.',
            style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
            textAlign: TextAlign.center,
          ),
        ),
        
        // Graph canvas using ConstellationBox
        Expanded(
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.5,
            maxScale: 3.0,
            child: Center(
              child: SizedBox(
                width: 500,
                height: 500,
                child: ConstellationBox(
                  nodes: nodeViews,
                  useNormalized: false, // MIRA uses pixels-from-center
                  onNodeTap: (node) {
                    // Find the original MiraGraphNode and show sheet
                    final originalNode = state.nodes.firstWhere((n) => n.label == node.label);
                    _showNodeSheet(originalNode, state);
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleTapDown(TapDownDetails details, MiraGraphLoaded state) {
    final localPosition = details.localPosition;
    final center = Offset(250, 250); // Simple center for 500x500 canvas

    // DEBUG: Store tap position for visual debugging
    setState(() {
      _lastTapPosition = localPosition;
    });

    print('DEBUG: Tap at local: $localPosition');

    // Find clicked node - simple approach
    for (final node in state.nodes) {
      final nodePosition = center + node.position;
      final distance = (localPosition - nodePosition).distance;
      final radius = node.size / 2;
      final tolerance = radius + 20; // Generous tolerance
      print('DEBUG: Node ${node.label} at: $nodePosition, distance: $distance, radius: $radius, tolerance: $tolerance');
      if (distance <= tolerance) {
        print('DEBUG: Tapped on node ${node.label}');
        _showNodeSheet(node, state);
        return;
      }
    }

    // Find clicked edge
    for (final edge in state.edges) {
      final fromNode = state.nodes.firstWhere((n) => n.id == edge.fromNodeId);
      final toNode = state.nodes.firstWhere((n) => n.id == edge.toNodeId);
      
      final fromPosition = center + fromNode.position;
      final toPosition = center + toNode.position;
      
      if (_isPointNearLine(localPosition, fromPosition, toPosition)) {
        print('DEBUG: Tapped on edge ${edge.fromNodeId} -> ${edge.toNodeId}');
        _showEdgeSheet(edge, state);
        return;
      }
    }
    
    print('DEBUG: No node or edge found at tap position');
  }

  void _handlePanStart(DragStartDetails details, MiraGraphLoaded state) {
    // Handle pan gestures if needed
  }

  bool _isPointNearLine(Offset point, Offset lineStart, Offset lineEnd) {
    final lineLength = (lineEnd - lineStart).distance;
    if (lineLength == 0) return false;

    // Calculate dot product manually
    final lineVector = lineEnd - lineStart;
    final pointVector = point - lineStart;
    final dotProduct = pointVector.dx * lineVector.dx + pointVector.dy * lineVector.dy;
    
    final t = dotProduct / (lineLength * lineLength);
    final tClamped = t.clamp(0.0, 1.0);
    final closestPoint = lineStart + (lineEnd - lineStart) * tClamped;
    
    return (point - closestPoint).distance <= 10.0; // 10px tolerance
  }

  void _showNodeSheet(MiraGraphNode node, MiraGraphLoaded state) {
    final entries = _cubit.getEntriesForKeyword(node.id);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: kcSurfaceAltColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => MiraNodeSheet(
        keyword: node.label,
        frequency: node.frequency,
        entries: entries,
      ),
    );
  }

  void _showEdgeSheet(MiraGraphEdge edge, MiraGraphLoaded state) {
    final entries = _cubit.getEntriesForEdge(edge.fromNodeId, edge.toNodeId);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: kcSurfaceAltColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => MiraNodeSheet(
        keyword: '${edge.fromNodeId} + ${edge.toNodeId}',
        frequency: edge.cooccurrenceCount,
        entries: entries,
        isEdge: true,
      ),
    );
  }
}

/// Custom painter for the MIRA graph
class MiraGraphPainter extends CustomPainter {
  final List<MiraGraphNode> nodes;
  final List<MiraGraphEdge> edges;
  final MiraGraphNode? hoveredNode;
  final MiraGraphEdge? hoveredEdge;
  final Offset? lastTapPosition; // DEBUG: Last tap position

  MiraGraphPainter({
    required this.nodes,
    required this.edges,
    this.hoveredNode,
    this.hoveredEdge,
    this.lastTapPosition, // DEBUG: Last tap position
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(250, 250); // Simple center for 500x500 canvas

    // Draw edges first (so they appear behind nodes)
    for (final edge in edges) {
      final fromNode = nodes.firstWhere((n) => n.id == edge.fromNodeId);
      final toNode = nodes.firstWhere((n) => n.id == edge.toNodeId);
      
      final startPoint = center + fromNode.position;
      final endPoint = center + toNode.position;
      
      final paint = Paint()
        ..color = edge == hoveredEdge 
            ? edge.color.withOpacity(0.9)
            : edge.color
        ..strokeWidth = edge == hoveredEdge 
            ? edge.thickness + 1.0
            : edge.thickness
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(startPoint, endPoint, paint);
    }

    // Draw nodes
    for (final node in nodes) {
      final position = center + node.position;
      
      // Node background
      final nodePaint = Paint()
        ..color = node == hoveredNode 
            ? node.color.withOpacity(0.9)
            : node.color
        ..style = PaintingStyle.fill;

      // Simple visual radius
      final visualRadius = node.size / 2;
      canvas.drawCircle(position, visualRadius, nodePaint);

      // Node border
      final borderPaint = Paint()
        ..color = kcPrimaryColor.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = node == hoveredNode ? 3.0 : 1.5;

      canvas.drawCircle(position, visualRadius, borderPaint);
      
      // DEBUG: Draw a small red dot at the exact center for debugging
      final debugPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;
      canvas.drawCircle(position, 3.0, debugPaint);

      // Node label - ensure perfect centering
      final textPainter = TextPainter(
        text: TextSpan(
          text: node.label,
          style: const TextStyle(
            color: kcPrimaryTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      
      textPainter.layout();
      final textOffset = Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    }
    
    // DEBUG: Draw tap position
    if (lastTapPosition != null) {
      final tapPaint = Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.fill;
      canvas.drawCircle(lastTapPosition!, 8.0, tapPaint);
      
      // Draw a cross at tap position
      final crossPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(lastTapPosition!.dx - 10, lastTapPosition!.dy),
        Offset(lastTapPosition!.dx + 10, lastTapPosition!.dy),
        crossPaint,
      );
      canvas.drawLine(
        Offset(lastTapPosition!.dx, lastTapPosition!.dy - 10),
        Offset(lastTapPosition!.dx, lastTapPosition!.dy + 10),
        crossPaint,
      );
    }
  }

  @override
  bool shouldRepaint(MiraGraphPainter oldDelegate) {
    return nodes != oldDelegate.nodes ||
           edges != oldDelegate.edges ||
           hoveredNode != oldDelegate.hoveredNode ||
           hoveredEdge != oldDelegate.hoveredEdge ||
           lastTapPosition != oldDelegate.lastTapPosition; // DEBUG: Include tap position
  }
}

/// NodeView class for constellation box
class NodeView {
  NodeView({
    required this.position,   // EITHER normalized [-1..1] or px-from-center (match flag)
    required this.radius,     // px
    required this.color,
    this.strokeWidth = 1.5,
    this.label,
    this.labelStyle,
  });

  final Offset position;
  final double radius;
  final Color color;
  final double strokeWidth;
  final String? label;
  final TextStyle? labelStyle;
}

/// One box to rule them all - ensures painter and hit-test use same math
class ConstellationBox extends StatelessWidget {
  const ConstellationBox({
    super.key,
    required this.nodes,
    this.padding = const EdgeInsets.fromLTRB(16, 120, 16, 24),
    this.useNormalized = false, // <-- set true if node.position is in [-1..1]
    this.onNodeTap,
  });

  final List<NodeView> nodes;
  final EdgeInsets padding;
  final bool useNormalized;
  final void Function(NodeView node)? onNodeTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque, // same box as painter
          onTapDown: (d) => _handleTap(d.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: ConstellationPainter(
              nodes: nodes,
              padding: padding,
              useNormalized: useNormalized,
              debugGuides: false, // Disable debug guides for production
            ),
          ),
        );
      },
    );
  }

  // ----- shared math used by BOTH draw and hit-test -----
  Offset _center(Size size) {
    final vw = size.width - padding.horizontal;
    final vh = size.height - padding.vertical;
    return Offset(padding.left + vw / 2.0, padding.top + vh / 2.0);
  }

  double _radius(Size size) {
    final vw = size.width - padding.horizontal;
    final vh = size.height - padding.vertical;
    return 0.5 * math.min(vw, vh);
  }

  Offset _toCanvas(Offset model, Size size) {
    final c = _center(size);
    if (useNormalized) {
      return Offset(c.dx + model.dx * _radius(size),
                    c.dy + model.dy * _radius(size));
    } else {
      // model already pixels-from-center
      return c + model;
    }
  }

  void _handleTap(Offset local, Size size) {
    final c = _center(size);

    for (final node in nodes) {
      final pos = _toCanvas(node.position, size);
      final r = node.radius; // radius in px (match painter)
      final tol = r + 8;     // reduced tolerance for more precise tapping
      final dist = (local - pos).distance;

      // Debug (disabled for production)
      // print('Tap @ $local | node ${node.label} pos=$pos, r=$r, d=$dist, tol=$tol');

      if (dist <= tol) {
        onNodeTap?.call(node);
        return;
      }
    }
  }
}

/// Painter that uses the same math as ConstellationBox
class ConstellationPainter extends CustomPainter {
  ConstellationPainter({
    required this.nodes,
    this.padding = const EdgeInsets.fromLTRB(16, 120, 16, 24),
    this.useNormalized = false,
    this.debugGuides = false,
  });

  final List<NodeView> nodes;
  final EdgeInsets padding;
  final bool useNormalized;
  final bool debugGuides;

  @override
  void paint(Canvas canvas, Size size) {
    final vw = size.width - padding.horizontal;
    final vh = size.height - padding.vertical;
    final center = Offset(padding.left + vw / 2.0, padding.top + vh / 2.0);
    final radius = 0.5 * math.min(vw, vh);

    if (debugGuides) {
      final g = Paint()..color = Colors.grey.withOpacity(0.35)..strokeWidth = 1;
      canvas.drawLine(Offset(center.dx, padding.top), Offset(center.dx, size.height - padding.bottom), g);
      canvas.drawLine(Offset(padding.left, center.dy), Offset(size.width - padding.right, center.dy), g);
      canvas.drawCircle(center, 2, g..style = PaintingStyle.fill);
    }

    for (final n in nodes) {
      final pos = useNormalized
          ? Offset(center.dx + n.position.dx * radius, center.dy + n.position.dy * radius)
          : center + n.position; // pixels-from-center

      // Fill (centered per node)
      final rect = Rect.fromCircle(center: pos, radius: n.radius);
      final fill = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [n.color.withOpacity(0.95), n.color.withOpacity(0.14)],
          stops: const [0, 1],
        ).createShader(rect);
      canvas.drawCircle(pos, n.radius, fill);

      // Stroke
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = n.strokeWidth
        ..color = n.color.withOpacity(0.9);
      canvas.drawCircle(pos, n.radius, stroke);

      // Debug dot to verify hit space aligns (disabled for production)
      // canvas.drawCircle(pos, 2, Paint()..color = Colors.red);

      // Label (centered)
      final text = (n.label ?? '');
      if (text.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(text: text, style: n.labelStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(minWidth: 0, maxWidth: n.radius * 1.8);
        tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant ConstellationPainter old) =>
      old.nodes != nodes || old.padding != padding || old.useNormalized != useNormalized || old.debugGuides != debugGuides;
}
