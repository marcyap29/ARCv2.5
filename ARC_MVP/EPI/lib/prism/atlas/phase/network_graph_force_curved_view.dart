// lib/features/insights/network_graph_force_curved_view.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'your_patterns_view.dart' show KeywordNode, KeywordEdge;

class NetworkGraphForceCurvedView extends StatefulWidget {
  const NetworkGraphForceCurvedView({
    super.key,
    required this.nodes,
    this.edges,
    this.cooccurrence,
    required this.onTapNode,
  });

  final List<KeywordNode> nodes;
  final List<KeywordEdge>? edges;
  final Map<String, Map<String, num>>? cooccurrence;
  final ValueChanged<KeywordNode> onTapNode;

  @override
  State<NetworkGraphForceCurvedView> createState() => _NetworkGraphForceCurvedViewState();
}

class _NetworkGraphForceCurvedViewState extends State<NetworkGraphForceCurvedView> {
  late List<KeywordEdge> _edges;
  final _stackKey = GlobalKey();
  List<_EdgeScreenSeg> _screenEdges = const [];

  // Selection state
  String? _selectedId;
  final _neighbors = <String, Set<String>>{}; // nodeId -> neighbor ids set
  
  // Force-directed layout state
  final Map<String, Offset> _nodePositions = {};
  final Map<String, Offset> _nodeVelocities = {};
  bool _isAnimating = false;
  
  // Node manipulation state - use ValueNotifier for better performance
  String? _draggedNodeId;
  final Map<String, bool> _isNodeDragged = {};
  final ValueNotifier<Map<String, Offset>> _nodePositionsNotifier = ValueNotifier({});
  
  // Traditional zoom state
  final TransformationController _transformationController = TransformationController();

  @override
  void dispose() {
    _nodePositionsNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _edges = widget.edges ??
        buildEdgesFromMatrix(widget.cooccurrence ?? {}, widget.nodes);

    // Build neighbor map (undirected)
    for (final e in _edges) {
      _neighbors.putIfAbsent(e.a, () => <String>{}).add(e.b);
      _neighbors.putIfAbsent(e.b, () => <String>{}).add(e.a);
    }

    _initializePositions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sampleEdgeScreenPositions();
      // Set initial zoom to be closer
      _transformationController.value = Matrix4.identity()..scale(1.5);
    });
  }


  void _initializePositions() {
    const center = Offset(400, 400); // Center of 800x800 container
    
    if (widget.nodes.isEmpty) return;
    
    // Find the most connected node to place at center (like "Universal Backlog")
    final mostConnectedNode = widget.nodes.reduce((a, b) => 
      (_neighbors[a.id]?.length ?? 0) > (_neighbors[b.id]?.length ?? 0) ? a : b
    );
    
    // Place most connected node at center
    _nodePositions[mostConnectedNode.id] = center;
    
    if (widget.nodes.length == 1) {
      // Only center node
      return;
    }
    
    // Arrange remaining nodes in concentric circles with more spacing
    final remainingNodes = widget.nodes.where((n) => n.id != mostConnectedNode.id).toList();
    
    if (remainingNodes.length <= 6) {
      // First ring - more spread out
      const radius = 200.0; // Increased from 120.0
      for (int i = 0; i < remainingNodes.length; i++) {
        final node = remainingNodes[i];
        final angle = (2 * math.pi * i) / remainingNodes.length;
        final x = center.dx + radius * math.cos(angle);
        final y = center.dy + radius * math.sin(angle);
        _nodePositions[node.id] = Offset(x, y);
      }
    } else {
      // Multiple rings for larger networks with more spacing
      final firstRingCount = math.min(6, remainingNodes.length);
      final secondRingCount = remainingNodes.length - firstRingCount;
      
      // First ring - more spread out
      const radius1 = 180.0; // Increased from 100.0
      for (int i = 0; i < firstRingCount; i++) {
        final node = remainingNodes[i];
        final angle = (2 * math.pi * i) / firstRingCount;
        final x = center.dx + radius1 * math.cos(angle);
        final y = center.dy + radius1 * math.sin(angle);
        _nodePositions[node.id] = Offset(x, y);
      }
      
      // Second ring - much more spread out
      if (secondRingCount > 0) {
        const radius2 = 300.0; // Increased from 180.0
        for (int i = 0; i < secondRingCount; i++) {
          final node = remainingNodes[firstRingCount + i];
          final angle = (2 * math.pi * i) / secondRingCount;
          final x = center.dx + radius2 * math.cos(angle);
          final y = center.dy + radius2 * math.sin(angle);
          _nodePositions[node.id] = Offset(x, y);
        }
      }
    }
    
    // Initialize velocities for all nodes
    for (final node in widget.nodes) {
      _nodeVelocities[node.id] = Offset.zero;
    }
    
    // Run gentle force simulation for natural settling
    _runForceSimulation();
  }

  Map<String, Color> _getNodeColorMap() {
    final colorMap = <String, Color>{};
    for (final node in widget.nodes) {
      colorMap[node.id] = _emotionColor(node.emotion);
    }
    return colorMap;
  }

  void _runForceSimulation() {
    if (_isAnimating) return;
    _isAnimating = true;
    
    // Work with all nodes
    if (widget.nodes.isEmpty) {
      _isAnimating = false;
      return;
    }
    
    // Ensure all nodes have positions initialized
    for (final node in widget.nodes) {
      if (!_nodePositions.containsKey(node.id)) {
        _nodePositions[node.id] = const Offset(400, 400); // Default center position
        _nodeVelocities[node.id] = Offset.zero;
      }
    }
    
      const iterations = 50; // Reduced for faster settling
      const damping = 0.8;
      const repulsion = 200.0; // Reduced to keep nodes closer
      const attraction = 0.3; // Increased to strengthen connections
      const maxVelocity = 5.0; // Reduced for smoother movement
    
    for (int iter = 0; iter < iterations; iter++) {
      // Reset forces
      final forces = <String, Offset>{};
      for (final node in widget.nodes) {
        forces[node.id] = Offset.zero;
      }
      
      // Repulsion forces between all nodes
      for (int i = 0; i < widget.nodes.length; i++) {
        for (int j = i + 1; j < widget.nodes.length; j++) {
          final nodeA = widget.nodes[i];
          final nodeB = widget.nodes[j];
          final posA = _nodePositions[nodeA.id]!;
          final posB = _nodePositions[nodeB.id]!;
          
          final dx = posA.dx - posB.dx;
          final dy = posA.dy - posB.dy;
          final distance = math.sqrt(dx * dx + dy * dy);
          
          if (distance > 0) {
            final force = repulsion / (distance * distance);
            final fx = (dx / distance) * force;
            final fy = (dy / distance) * force;
            
            forces[nodeA.id] = forces[nodeA.id]! + Offset(fx, fy);
            forces[nodeB.id] = forces[nodeB.id]! - Offset(fx, fy);
          }
        }
      }
      
      // Attraction forces for connected nodes
      for (final edge in _edges) {
        final posA = _nodePositions[edge.a];
        final posB = _nodePositions[edge.b];
        if (posA == null || posB == null) continue;
        
        final dx = posB.dx - posA.dx;
        final dy = posB.dy - posA.dy;
        final distance = math.sqrt(dx * dx + dy * dy);
        
        if (distance > 0) {
          final force = attraction * edge.weight * distance;
          final fx = (dx / distance) * force;
          final fy = (dy / distance) * force;
          
          forces[edge.a] = forces[edge.a]! + Offset(fx, fy);
          forces[edge.b] = forces[edge.b]! - Offset(fx, fy);
        }
      }
      
        // Apply forces and update positions
        for (final node in widget.nodes) {
          // Skip physics for dragged nodes
          if (_isNodeDragged[node.id] == true) {
            continue;
          }
          
          final force = forces[node.id]!;
          final velocity = _nodeVelocities[node.id]!;
          
          // Update velocity
          final newVelocity = velocity + force;
          final speed = math.sqrt(newVelocity.dx * newVelocity.dx + newVelocity.dy * newVelocity.dy);
          
          if (speed > maxVelocity) {
            _nodeVelocities[node.id] = Offset(
              (newVelocity.dx / speed) * maxVelocity,
              (newVelocity.dy / speed) * maxVelocity,
            );
          } else {
            _nodeVelocities[node.id] = newVelocity;
          }
          
          // Update position
          final newPos = _nodePositions[node.id]! + _nodeVelocities[node.id]!;
          _nodePositions[node.id] = newPos;
          
          // Apply damping
          _nodeVelocities[node.id] = _nodeVelocities[node.id]! * damping;
        }
    }
    
    _isAnimating = false;
    _sampleEdgeScreenPositions();
  }

  void _sampleEdgeScreenPositions() {
    final segments = <_EdgeScreenSeg>[];
    
    for (final e in _edges) {
      final a = _nodePositions[e.a];
      final b = _nodePositions[e.b];
      if (a == null || b == null) continue;

      final isHighlighted = _isEdgeHighlighted(e.a, e.b);
      segments.add(_EdgeScreenSeg(
        a: a, 
        b: b, 
        weight: e.weight, 
        highlighted: isHighlighted,
        nodeA: e.a,
        nodeB: e.b,
      ));
    }
    setState(() => _screenEdges = segments);
  }

  bool _isEdgeHighlighted(String a, String b) {
    if (_selectedId == null) return true; // nothing selected, show all vivid
    // edge is highlighted if it touches the selected node
    return a == _selectedId || b == _selectedId;
  }

  bool _isNodeHighlighted(String id) {
    if (_selectedId == null) return true;
    if (id == _selectedId) return true;
    final neigh = _neighbors[_selectedId];
    return neigh != null && neigh.contains(id);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _stackKey,
      fit: StackFit.expand,
      children: [
        InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.3,
          maxScale: 3.0,
          constrained: false,
          scaleFactor: 200.0,
          panEnabled: true,
          scaleEnabled: true,
          onInteractionStart: (details) {
            // Handle interaction start if needed
          },
          onInteractionUpdate: (details) {
            // Handle interaction update if needed
          },
          onInteractionEnd: (details) {
            _sampleEdgeScreenPositions();
          },
          child: SizedBox(
            width: 800,
            height: 800,
            child: Stack(
              children: [
                  // Glowing edges overlay
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _CurvedEdgesPainter(
                          _screenEdges, 
                          selectedId: _selectedId,
                          nodeColors: _getNodeColorMap(),
                        ),
                      ),
                    ),
                  ),
                // Force-directed node layout
                ..._buildForceDirectedNodes(),
              ],
            ),
          ),
        ),
        // Zoom reset button
        Positioned(
          left: 12,
          top: 12,
          child: GestureDetector(
            onTap: () {
              _transformationController.value = Matrix4.identity()..scale(1.5);
              _sampleEdgeScreenPositions();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.zoom_out_map,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        Positioned(right: 12, top: 12, child: _LegendCard()),
      ],
    );
  }


  List<Widget> _buildForceDirectedNodes() {
    final nodes = <Widget>[];
    
    for (final node in widget.nodes) {
      final position = _nodePositions[node.id];
      if (position == null) continue;
      
      final highlighted = _isNodeHighlighted(node.id);
      final dotSize = 24.0 + (node.frequency.clamp(0, 60) / 60.0) * 24.0; // Increased base size
      
      // Show all nodes with full opacity
      const opacity = 1.0;
      
        nodes.add(
          Positioned(
            left: position.dx - 40, // Adjusted for larger nodes
            top: position.dy - 40,  // Adjusted for larger nodes
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: opacity * (highlighted ? 1.0 : 0.6),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedId = (_selectedId == node.id) ? null : node.id;
                  });
                  widget.onTapNode(node);
                },
                onPanStart: (details) {
                  setState(() {
                    _draggedNodeId = node.id;
                    _isNodeDragged[node.id] = true;
                  });
                },
                onPanUpdate: (details) {
                  if (_draggedNodeId == node.id) {
                    // Update position without triggering full rebuild
                    _nodePositions[node.id] = _nodePositions[node.id]! + details.delta;
                    _nodePositionsNotifier.value = Map.from(_nodePositions);
                    _sampleEdgeScreenPositions();
                  }
                },
                onPanEnd: (details) {
                  setState(() {
                    _draggedNodeId = null;
                    _isNodeDragged[node.id] = false;
                  });
                  // Resume physics simulation
                  _runForceSimulation();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CapacitiesNode(
                      label: node.label,
                      phase: node.phase,
                      emotion: node.emotion,
                      size: dotSize,
                      isDragged: _isNodeDragged[node.id] == true,
                      isHub: false, // No semantic zoom, so no special hub treatment
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    }
    
    return nodes;
  }
}


/// Phase label with icon
class _PhaseLabel extends StatelessWidget {
  const _PhaseLabel({required this.label, required this.phase});
  final String label;
  final String phase;

  @override
  Widget build(BuildContext context) {
    final icon = _phaseIcon(phase);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  IconData _phaseIcon(String p) {
    switch (p) {
      case 'Discovery': return Icons.explore;          // spiral motif (metaphor)
      case 'Expansion': return Icons.local_florist;    // flower
      case 'Transition': return Icons.change_history;  // triangle
      case 'Consolidation': return Icons.layers;       // weave/stack
      case 'Recovery': return Icons.brightness_low;    // glow core
      case 'Breakthrough': return Icons.auto_awesome;  // fractal spark
      default: return Icons.blur_on;
    }
  }
}

/// Legend (unchanged except text)
class _LegendCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70);
    return Card(
      color: Colors.black.withOpacity(0.55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Legend', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white)),
          const SizedBox(height: 8),
          _chipRow(color: const Color(0xFF57F287), label: 'Positive emotion', style: labelStyle),
          _chipRow(color: const Color(0xFF66CCFF), label: 'Reflective emotion', style: labelStyle),
          _chipRow(color: const Color(0xFFD0D3D4), label: 'Neutral emotion', style: labelStyle),
          const SizedBox(height: 8),
          _lineSample(1.0, 'Weak link', labelStyle),
          _lineSample(3.0, 'Medium link', labelStyle),
          _lineSample(5.0, 'Strong link', labelStyle),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.explore, size: 14, color: Colors.white70), const SizedBox(width: 4), Text('Discovery', style: labelStyle),
            const SizedBox(width: 10),
            const Icon(Icons.local_florist, size: 14, color: Colors.white70), const SizedBox(width: 4), Text('Expansion', style: labelStyle),
          ]),
          Row(children: [
            const Icon(Icons.change_history, size: 14, color: Colors.white70), const SizedBox(width: 4), Text('Transition', style: labelStyle),
            const SizedBox(width: 10),
            const Icon(Icons.layers, size: 14, color: Colors.white70), const SizedBox(width: 4), Text('Consolidation', style: labelStyle),
          ]),
          Row(children: [
            const Icon(Icons.brightness_low, size: 14, color: Colors.white70), const SizedBox(width: 4), Text('Recovery', style: labelStyle),
            const SizedBox(width: 10),
            const Icon(Icons.auto_awesome, size: 14, color: Colors.white70), const SizedBox(width: 4), Text('Breakthrough', style: labelStyle),
          ]),
        ]),
      ),
    );
  }

  Widget _chipRow({required Color color, required String label, TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: style),
      ]),
    );
  }

  Widget _lineSample(double width, String label, TextStyle? style) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        CustomPaint(size: const Size(28, 10), painter: _LinePainter(width)),
        const SizedBox(width: 6),
        Text(label, style: style),
      ]),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.strokeWidth);
  final double strokeWidth;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white70
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, size.height/2), Offset(size.width, size.height/2), p);
  }
  @override
  bool shouldRepaint(covariant _LinePainter old) => old.strokeWidth != strokeWidth;
}

class _EdgeScreenSeg {
  _EdgeScreenSeg({
    required this.a, 
    required this.b, 
    required this.weight, 
    required this.highlighted,
    required this.nodeA,
    required this.nodeB,
  });
  final Offset a;
  final Offset b;
  final double weight;
  final bool highlighted;
  final String nodeA; // Node ID for color lookup
  final String nodeB; // Node ID for color lookup
}

class _CurvedEdgesPainter extends CustomPainter {
  _CurvedEdgesPainter(this.edges, {this.selectedId, this.nodeColors});
  final List<_EdgeScreenSeg> edges;
  final String? selectedId;
  final Map<String, Color>? nodeColors; // Node ID -> Color mapping

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      final opacity = e.highlighted ? 1.0 : 0.3;
      final baseOpacity = (0.4 + 0.4 * e.weight.clamp(0, 1)) * opacity;
      final strokeWidth = (1.0 + 2.0 * e.weight.clamp(0, 1)) * (e.highlighted ? 1.0 : 0.8);
      
      // Get colors for both nodes to create gradient effect
      final colorA = nodeColors?[e.nodeA] ?? Colors.white;
      final colorB = nodeColors?[e.nodeB] ?? Colors.white;
      
      // Create glowing effect with multiple layers
      _drawGlowingEdge(canvas, e.a, e.b, colorA, colorB, strokeWidth, baseOpacity);
    }
  }
  
  void _drawGlowingEdge(Canvas canvas, Offset start, Offset end, Color colorA, Color colorB, double strokeWidth, double opacity) {
    // Outer glow layer (larger, more transparent)
    final glowPaint = Paint()
      ..color = _blendColors(colorA, colorB).withOpacity(opacity * 0.3)
      ..strokeWidth = strokeWidth * 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawLine(start, end, glowPaint);
    
    // Middle glow layer
    final middlePaint = Paint()
      ..color = _blendColors(colorA, colorB).withOpacity(opacity * 0.6)
      ..strokeWidth = strokeWidth * 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    
    canvas.drawLine(start, end, middlePaint);
    
    // Main edge line
    final mainPaint = Paint()
      ..color = _blendColors(colorA, colorB).withOpacity(opacity)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(start, end, mainPaint);
  }
  
  Color _blendColors(Color colorA, Color colorB) {
    // Blend two colors to create a gradient effect
    final r = ((colorA.red + colorB.red) / 2).round();
    final g = ((colorA.green + colorB.green) / 2).round();
    final b = ((colorA.blue + colorB.blue) / 2).round();
    return Color.fromRGBO(r, g, b, 1.0);
  }


  @override
  bool shouldRepaint(covariant _CurvedEdgesPainter old) => old.edges != edges || old.selectedId != selectedId;
}

/// Matrix → edges adapter (unchanged)
List<KeywordEdge> buildEdgesFromMatrix(
  Map<String, Map<String, num>> matrix,
  List<KeywordNode> nodes, {
  double minWeightThreshold = 0.05,
}) {
  if (matrix.isEmpty) return <KeywordEdge>[];
  final idByLabel = { for (final n in nodes) n.label: n.id };

  double maxW = 0;
  final temp = <({String a, String b, double w})>[];
  matrix.forEach((ka, row) {
    row.forEach((kb, v) {
      if (ka == kb) return;
      final aId = idByLabel[ka];
      final bId = idByLabel[kb];
      if (aId == null || bId == null) return;
      final w = v.toDouble();
      if (w <= 0) return;
      maxW = w > maxW ? w : maxW;
      temp.add((a: aId, b: bId, w: w));
    });
  });

  if (maxW <= 0) return <KeywordEdge>[];
  final seen = <String, bool>{};
  final edges = <KeywordEdge>[];
  for (final t in temp) {
    final key = t.a.compareTo(t.b) < 0 ? '${t.a}-${t.b}' : '${t.b}-${t.a}';
    if (seen[key] == true) continue;
    seen[key] = true;

    final norm = (t.w / maxW).clamp(0.0, 1.0);
    if (norm < minWeightThreshold) continue;
    edges.add(KeywordEdge(a: t.a, b: t.b, weight: norm));
  }
  return edges;
}

/// Capacities-style node widget with different types and visual hierarchy
class _CapacitiesNode extends StatelessWidget {
  const _CapacitiesNode({
    required this.label,
    required this.phase,
    required this.emotion,
    required this.size,
    this.isDragged = false,
    this.isHub = false,
  });
  
  final String label;
  final String phase;
  final String emotion;
  final double size;
  final bool isDragged;
  final bool isHub;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Node icon and container
        Container(
          width: isHub ? size * 1.5 : size,
          height: isHub ? size * 1.5 : size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _emotionColor(emotion).withOpacity(isDragged ? 0.8 : 0.6),
                blurRadius: isDragged ? size * 1.2 : size * 0.8,
                spreadRadius: isDragged ? size * 0.4 : size * 0.2,
              ),
            ],
            color: _emotionColor(emotion).withOpacity(isDragged ? 1.0 : 0.9),
            border: isDragged ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: isDragged 
            ? Icon(Icons.drag_indicator, color: Colors.white, size: size * 0.4)
            : _getNodeIcon(),
        ),
        const SizedBox(height: 6),
        // Node label
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isHub ? 14 : 12,
              color: Colors.white,
              fontWeight: isHub ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
        // Phase indicator for non-hub nodes
        if (!isHub && phase.isNotEmpty) ...[
          const SizedBox(height: 2),
          _PhaseLabel(label: phase, phase: phase),
        ],
      ],
    );
  }

  Widget _getNodeIcon() {
    if (isHub) {
      // Central hub - 3D box icon like "Universal Backlog"
      return Icon(
        Icons.inventory_2,
        color: Colors.white,
        size: size * 0.6,
      );
    } else {
      // Regular nodes - different icons based on phase/type
      switch (phase.toLowerCase()) {
        case 'discovery':
          return Icon(Icons.explore, color: Colors.white, size: size * 0.5);
        case 'expansion':
          return Icon(Icons.local_florist, color: Colors.white, size: size * 0.5);
        case 'transition':
          return Icon(Icons.change_history, color: Colors.white, size: size * 0.5);
        case 'consolidation':
          return Icon(Icons.layers, color: Colors.white, size: size * 0.5);
        case 'recovery':
          return Icon(Icons.brightness_low, color: Colors.white, size: size * 0.5);
        case 'breakthrough':
          return Icon(Icons.auto_awesome, color: Colors.white, size: size * 0.5);
        default:
          return Icon(Icons.circle, color: Colors.white, size: size * 0.5);
      }
    }
  }
}


/// Enhanced emotion color mapping with warm/cool temperature
Color _emotionColor(String emotion) {
  switch (emotion.toLowerCase()) {
    // Warm colors (positive, energetic, creative)
    case 'positive':
    case 'happy':
    case 'joy':
    case 'excited':
    case 'energetic':
    case 'creative':
      return const Color(0xFF57F287); // Bright warm green
    case 'love':
    case 'passion':
    case 'enthusiasm':
      return const Color(0xFFFF6B9D); // Warm pink
    case 'confidence':
    case 'strength':
    case 'power':
      return const Color(0xFFFFA726); // Warm orange
    case 'breakthrough':
    case 'success':
    case 'achievement':
      return const Color(0xFFFFD54F); // Warm yellow
    
    // Cool colors (calm, reflective, analytical)
    case 'neutral':
    case 'calm':
    case 'content':
    case 'peaceful':
      return const Color(0xFF81C784); // Cool green
    case 'reflective':
    case 'contemplative':
    case 'thoughtful':
    case 'analytical':
      return const Color(0xFF66CCFF); // Cool blue
    case 'discovery':
    case 'exploration':
    case 'curiosity':
      return const Color(0xFF42A5F5); // Cool blue
    case 'transition':
    case 'change':
    case 'flow':
      return const Color(0xFF64B5F6); // Light cool blue
    
    // Neutral/balanced colors
    case 'consolidation':
    case 'integration':
    case 'balance':
      return const Color(0xFF9C27B0); // Purple (balanced)
    case 'recovery':
    case 'healing':
    case 'restoration':
      return const Color(0xFFAB47BC); // Light purple
    
    // Cool colors (negative, challenging)
    case 'negative':
    case 'sad':
    case 'angry':
    case 'frustrated':
      return const Color(0xFFFF6B6B); // Cool red
    case 'anxiety':
    case 'worry':
    case 'stress':
      return const Color(0xFF7986CB); // Cool indigo
    case 'confusion':
    case 'uncertainty':
      return const Color(0xFF9575CD); // Cool purple
    
    default:
      return const Color(0xFF9B59B6); // Default purple
  }
}

