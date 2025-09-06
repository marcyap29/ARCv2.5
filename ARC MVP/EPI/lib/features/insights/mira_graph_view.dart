import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import 'mira_graph_cubit.dart';
import 'widgets/mira_node_sheet.dart';

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
        
        // Graph canvas
        Expanded(
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.5,
            maxScale: 3.0,
            child: Center(
              child: SizedBox(
                width: 500,
                height: 500,
                child: CustomPaint(
                  painter: MiraGraphPainter(
                    nodes: state.nodes,
                    edges: state.edges,
                    hoveredNode: _hoveredNode,
                    hoveredEdge: _hoveredEdge,
                  ),
                  child: GestureDetector(
                    onTapDown: (details) => _handleTapDown(details, state),
                    onPanStart: (details) => _handlePanStart(details, state),
                    child: Container(),
                  ),
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
    final center = Offset(250, 250); // Center of the 500x500 canvas
    final relativePosition = Offset(
      localPosition.dx - center.dx,
      localPosition.dy - center.dy,
    );

    // Find clicked node
    for (final node in state.nodes) {
      final distance = (relativePosition - node.position).distance;
      if (distance <= node.size / 2) {
        _showNodeSheet(node, state);
        return;
      }
    }

    // Find clicked edge
    for (final edge in state.edges) {
      final fromNode = state.nodes.firstWhere((n) => n.id == edge.fromNodeId);
      final toNode = state.nodes.firstWhere((n) => n.id == edge.toNodeId);
      
      if (_isPointNearLine(relativePosition, fromNode.position, toNode.position)) {
        _showEdgeSheet(edge, state);
        return;
      }
    }
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

  MiraGraphPainter({
    required this.nodes,
    required this.edges,
    this.hoveredNode,
    this.hoveredEdge,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

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

      canvas.drawCircle(position, node.size / 2, nodePaint);

      // Node border
      final borderPaint = Paint()
        ..color = kcPrimaryColor.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = node == hoveredNode ? 3.0 : 1.5;

      canvas.drawCircle(position, node.size / 2, borderPaint);

      // Node label
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
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        position - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(MiraGraphPainter oldDelegate) {
    return nodes != oldDelegate.nodes ||
           edges != oldDelegate.edges ||
           hoveredNode != oldDelegate.hoveredNode ||
           hoveredEdge != oldDelegate.hoveredEdge;
  }
}
