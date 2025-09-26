// lib/features/insights/your_patterns_view.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:graphview/GraphView.dart';
import 'package:my_app/atlas/phase_detection/pattern_analysis_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';

enum PatternsView { wordCloud, network, timeline, radial }

class KeywordNode {
  final String id;
  final String label;
  final int frequency;          // total count
  final double recencyScore;    // 0..1 (recently used)
  final String emotion;         // e.g., "positive", "neutral", "reflective"
  final String phase;           // ATLAS phase name
  final List<String> excerpts;  // short snippets
  final List<int> series;       // trend over time for sparkline

  KeywordNode({
    required this.id,
    required this.label,
    required this.frequency,
    required this.recencyScore,
    required this.emotion,
    required this.phase,
    required this.excerpts,
    required this.series,
  });
}

class KeywordEdge {
  final String a;
  final String b;
  double weight; // co-occurrence strength 0..1

  KeywordEdge({required this.a, required this.b, required this.weight});
}

class YourPatternsView extends StatefulWidget {
  const YourPatternsView({super.key});

  @override
  State<YourPatternsView> createState() => _YourPatternsViewState();
}

class _YourPatternsViewState extends State<YourPatternsView> {
  PatternsView current = PatternsView.network;

  // Filters
  String? emotionFilter; // null = all
  String? phaseFilter;   // null = all
  DateTimeRange? range;  // null = all time

  // Real data from journal entries
  late List<KeywordNode> nodes;
  late List<KeywordEdge> edges;
  late PatternAnalysisService _patternService;

  @override
  void initState() {
    super.initState();
    _patternService = PatternAnalysisService(JournalRepository());
    _loadRealData();
  }

  void _loadRealData() {
    final realData = _patternService.analyzePatterns(
      minWeight: 0.1, // More permissive to work with limited data
      maxNodes: 8,
    );
    print('DEBUG: Pattern analysis results - Nodes: ${realData.$1.length}, Edges: ${realData.$2.length}');
    if (realData.$1.isNotEmpty) {
      print('DEBUG: First node: ${realData.$1.first.label} (${realData.$1.first.frequency} freq)');
      print('DEBUG: Sample node excerpts: ${realData.$1.first.excerpts}');
    }
    if (realData.$2.isNotEmpty) {
      print('DEBUG: First edge: ${realData.$2.first.a} -> ${realData.$2.first.b} (${realData.$2.first.weight})');
    }
    setState(() {
      nodes = realData.$1;
      edges = realData.$2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Patterns')),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _ViewSwitcher(
            current: current,
            onChanged: (v) => setState(() => current = v),
          ),
          _FilterBar(
            emotion: emotionFilter,
            phase: phaseFilter,
            range: range,
            onEmotion: (e) => setState(() => emotionFilter = e),
            onPhase: (p) => setState(() => phaseFilter = p),
            onRange: (r) => setState(() => range = r),
            onClear: () => setState(() {
              emotionFilter = null;
              phaseFilter = null;
              range = null;
            }),
          ),
          const Divider(height: 1),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildCurrentView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    final filteredNodes = nodes.where(_nodePassesFilters).toList();
    final filteredEdges = edges.where((e) {
      final aOk = filteredNodes.any((n) => n.id == e.a);
      final bOk = filteredNodes.any((n) => n.id == e.b);
      return aOk && bOk;
    }).toList();

    switch (current) {
      case PatternsView.wordCloud:
        return WordCloudView(
          key: const ValueKey('wordCloud'),
          nodes: filteredNodes,
          onTap: _showDetails,
        );
      case PatternsView.network:
        return NetworkGraphForceView(
          key: const ValueKey('network'),
          nodes: filteredNodes,
          edges: filteredEdges,
          onTapNode: _showDetails,
        );
      case PatternsView.timeline:
        return PatternsTimelineView(
          key: const ValueKey('timeline'),
          nodes: filteredNodes,
          onTap: _showDetails,
        );
      case PatternsView.radial:
        return RadialView(
          key: const ValueKey('radial'),
          nodes: filteredNodes,
          onTap: _showDetails,
        );
    }
  }

  bool _nodePassesFilters(KeywordNode n) {
    final emotionOk = emotionFilter == null || n.emotion == emotionFilter;
    final phaseOk = phaseFilter == null || n.phase == phaseFilter;
    // Time filtering would require per-entry timestamps; here we rely on series/recencyScore.
    final timeOk = true; // Replace with real check when wired to entries
    return emotionOk && phaseOk && timeOk;
  }

  void _showDetails(KeywordNode node) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => KeywordDetailsSheet(node: node),
    );
  }

}

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({
    required this.current,
    required this.onChanged,
  });

  final PatternsView current;
  final ValueChanged<PatternsView> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PatternsView>(
      segments: const [
        ButtonSegment(value: PatternsView.wordCloud, label: Text('Word Cloud'), icon: Icon(Icons.cloud)),
        ButtonSegment(value: PatternsView.network,   label: Text('Network'),    icon: Icon(Icons.hub)),
        ButtonSegment(value: PatternsView.timeline,  label: Text('Timeline'),   icon: Icon(Icons.timeline)),
        ButtonSegment(value: PatternsView.radial,    label: Text('Radial'),     icon: Icon(Icons.radar)),
      ],
      selected: {current},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.emotion,
    required this.phase,
    required this.range,
    required this.onEmotion,
    required this.onPhase,
    required this.onRange,
    required this.onClear,
  });

  final String? emotion;
  final String? phase;
  final DateTimeRange? range;
  final ValueChanged<String?> onEmotion;
  final ValueChanged<String?> onPhase;
  final ValueChanged<DateTimeRange?> onRange;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _FilterChip(
        label: 'Emotion',
        value: emotion ?? 'All',
        onTap: () async {
          final value = await _pickFrom(context, ['All','positive','neutral','reflective']);
          onEmotion(value == 'All' ? null : value);
        },
      ),
      _FilterChip(
        label: 'Phase',
        value: phase ?? 'All',
        onTap: () async {
          final value = await _pickFrom(context, ['All','Discovery','Expansion','Transition','Consolidation','Recovery','Breakthrough']);
          onPhase(value == 'All' ? null : value);
        },
      ),
      _FilterChip(
        label: 'Time',
        value: range == null ? 'All time' : '${range!.start.toString().split(" ").first} → ${range!.end.toString().split(" ").first}',
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(now.year - 3),
            lastDate: now,
            initialDateRange: range,
          );
          onRange(picked);
        },
      ),
      TextButton.icon(onPressed: onClear, icon: const Icon(Icons.clear), label: const Text('Clear')),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: chips.map((c) => Padding(padding: const EdgeInsets.only(right: 8), child: c)).toList()),
    );
  }

  Future<String?> _pickFrom(BuildContext ctx, List<String> options) async {
    return await showModalBottomSheet<String>(
      context: ctx,
      builder: (_) => ListView(
        children: options.map((o) => ListTile(
          title: Text(o),
          onTap: () => Navigator.pop(ctx, o),
        )).toList(),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: Theme.of(context).textTheme.labelMedium),
          Text(value),
        ],
      ),
      onPressed: onTap,
    );
  }
}

/// WORD CLOUD (placeholder painter: size by frequency)
class WordCloudView extends StatelessWidget {
  const WordCloudView({super.key, required this.nodes, required this.onTap});
  final List<KeywordNode> nodes;
  final ValueChanged<KeywordNode> onTap;

  @override
  Widget build(BuildContext context) {
    // Simple wrap layout; replace with a proper cloud algorithm if desired.
    final sorted = [...nodes]..sort((a,b) => b.frequency.compareTo(a.frequency));
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: sorted.map((n) {
          final fontSize = 12.0 + (n.frequency.clamp(0, 60) / 60.0) * 24.0;
          final color = _emotionColor(n.emotion).withOpacity(0.9);
          return GestureDetector(
            onTap: () => onTap(n),
            child: Text(n.label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: color)),
          );
        }).toList(),
      ),
    );
  }
}

/// SIMPLE NETWORK GRAPH - Clean implementation
class NetworkGraphForceView extends StatefulWidget {
  const NetworkGraphForceView({super.key, required this.nodes, required this.edges, required this.onTapNode});
  final List<KeywordNode> nodes;
  final List<KeywordEdge> edges;
  final ValueChanged<KeywordNode> onTapNode;

  @override
  State<NetworkGraphForceView> createState() => _NetworkGraphForceViewState();
}

class _NetworkGraphForceViewState extends State<NetworkGraphForceView> {
  String? selectedNodeId;

  @override
  Widget build(BuildContext context) {
    print('DEBUG: NetworkGraphForceView build - Nodes: ${widget.nodes.length}, Edges: ${widget.edges.length}');
    if (widget.nodes.isEmpty) {
      return const Center(child: Text('No network data available'));
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            Colors.black.withOpacity(0.2),
            Colors.black.withOpacity(0.05),
            Colors.transparent,
          ],
        ),
      ),
      child: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(200),
        minScale: 0.3,
        maxScale: 3.0,
        child: SizedBox(
          width: 1200,
          height: 1200,
          child: Stack(
            children: [
              // Simple circular layout for now
              ...widget.nodes.asMap().entries.map((entry) {
                final index = entry.key;
                final node = entry.value;
                final angle = (index / widget.nodes.length) * 2 * math.pi;
                final radius = 200.0;
                final centerX = 600.0;
                final centerY = 600.0;
                final x = centerX + radius * math.cos(angle);
                final y = centerY + radius * math.sin(angle);
                
                final size = 32.0 + (node.frequency.clamp(0, 50) / 50.0) * 24.0;
                final color = _emotionColor(node.emotion);
                final isSelected = selectedNodeId == node.id;

                return Positioned(
                  left: x - size / 2,
                  top: y - size / 2,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedNodeId = selectedNodeId == node.id ? null : node.id;
                      });
                      widget.onTapNode(node);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(isSelected ? 1.0 : 0.6),
                            blurRadius: isSelected ? 12 : 8,
                            spreadRadius: isSelected ? 4 : 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          node.label.length > 3 ? node.label.substring(0, 3) : node.label,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: size * 0.3,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  IconData _phaseIcon(String phase) {
    switch (phase) {
      case 'Discovery': return Icons.explore;
      case 'Expansion': return Icons.trending_up;
      case 'Transition': return Icons.swap_horiz;
      case 'Consolidation': return Icons.compress;
      case 'Recovery': return Icons.healing;
      case 'Breakthrough': return Icons.lightbulb;
      default: return Icons.circle;
    }
  }

/// Custom painter for curved edges with Bezier curves and arrowheads
class CurvedEdgesPainter extends CustomPainter {
  final List<KeywordNode> nodes;
  final List<KeywordEdge> edges;
  final Map<String, Offset> nodePositions;
  final String? selectedNodeId;

  CurvedEdgesPainter({
    required this.nodes,
    required this.edges,
    required this.nodePositions,
    this.selectedNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (nodePositions.isEmpty) return;

    for (final edge in edges) {
      final posA = nodePositions[edge.a];
      final posB = nodePositions[edge.b];

      if (posA == null || posB == null) continue;

      // Check if edge should be highlighted
      final isHighlighted = selectedNodeId != null &&
        (edge.a == selectedNodeId || edge.b == selectedNodeId);

      final opacity = selectedNodeId == null || isHighlighted ?
        (0.2 + 0.6 * edge.weight) : 0.1;

      final strokeWidth = isHighlighted ?
        (2.0 + 4.0 * edge.weight) : (1.0 + 2.0 * edge.weight);

      // Create curved path with control points
      final controlOffset = _calculateControlPoint(posA, posB, edge.weight);
      final path = Path();
      path.moveTo(posA.dx, posA.dy);
      path.quadraticBezierTo(
        controlOffset.dx, controlOffset.dy,
        posB.dx, posB.dy,
      );

      // Draw curved edge
      final edgePaint = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, edgePaint);

      // Draw arrowhead at the end
      if (isHighlighted || edge.weight > 0.5) {
        _drawArrowhead(canvas, posA, posB, controlOffset, edgePaint);
      }

      // Draw weight indicator for strong connections
      if (edge.weight > 0.7 && isHighlighted) {
        _drawWeightIndicator(canvas, controlOffset, edge.weight);
      }
    }
  }

  Offset _calculateControlPoint(Offset start, Offset end, double weight) {
    final midpoint = Offset(
      (start.dx + end.dx) / 2,
      (start.dy + end.dy) / 2,
    );

    // Calculate perpendicular offset for curve
    final direction = end - start;
    final perpendicular = Offset(-direction.dy, direction.dx).normalize();
    final curveIntensity = 60 + (weight * 80); // Stronger weights = more curve

    return midpoint + perpendicular * curveIntensity;
  }

  void _drawArrowhead(Canvas canvas, Offset start, Offset end, Offset control, Paint paint) {
    // Calculate direction at the end of the curve
    final t = 0.9; // Position along curve for arrowhead
    final curvePoint = _bezierPoint(start, control, end, t);
    final nextPoint = _bezierPoint(start, control, end, t + 0.05);
    final direction = (nextPoint - curvePoint).normalize();

    const arrowSize = 8.0;
    final arrowPoint1 = curvePoint + Offset(
      -direction.dx * arrowSize + direction.dy * arrowSize * 0.5,
      -direction.dy * arrowSize - direction.dx * arrowSize * 0.5,
    );
    final arrowPoint2 = curvePoint + Offset(
      -direction.dx * arrowSize - direction.dy * arrowSize * 0.5,
      -direction.dy * arrowSize + direction.dx * arrowSize * 0.5,
    );

    final arrowPath = Path()
      ..moveTo(curvePoint.dx, curvePoint.dy)
      ..lineTo(arrowPoint1.dx, arrowPoint1.dy)
      ..lineTo(arrowPoint2.dx, arrowPoint2.dy)
      ..close();

    canvas.drawPath(arrowPath, paint..style = PaintingStyle.fill);
    paint.style = PaintingStyle.stroke; // Reset style
  }

  void _drawWeightIndicator(Canvas canvas, Offset position, double weight) {
    final radius = 4 + (weight * 6);
    final indicatorPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(position, radius, indicatorPaint);

    // Draw weight text
    final textPainter = TextPainter(
      text: TextSpan(
        text: (weight * 100).toInt().toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
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

  Offset _bezierPoint(Offset start, Offset control, Offset end, double t) {
    final oneMinusT = 1.0 - t;
    return start * (oneMinusT * oneMinusT) +
           control * (2 * oneMinusT * t) +
           end * (t * t);
  }

  @override
  bool shouldRepaint(covariant CurvedEdgesPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
           oldDelegate.edges != edges ||
           oldDelegate.nodePositions != nodePositions ||
           oldDelegate.selectedNodeId != selectedNodeId;
  }
}

extension on Offset {
  Offset normalize() {
    final magnitude = distance;
    if (magnitude == 0) return Offset.zero;
    return this / magnitude;
  }
}


class _GlowDot extends StatelessWidget {
  const _GlowDot({required this.label, required this.size, required this.color});
  final String label;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: size * 0.8, spreadRadius: size * 0.2)],
            color: color.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white)),
        ),
      ],
    );
  }
}

/// PATTERNS TIMELINE (simple list with mini trend; swap with charts later)
class PatternsTimelineView extends StatelessWidget {
  const PatternsTimelineView({super.key, required this.nodes, required this.onTap});
  final List<KeywordNode> nodes;
  final ValueChanged<KeywordNode> onTap;

  @override
  Widget build(BuildContext context) {
    final sorted = [...nodes]..sort((a,b) => b.recencyScore.compareTo(a.recencyScore));
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final n = sorted[i];
        return ListTile(
          title: Text(n.label),
          subtitle: Text('Freq ${n.frequency} • ${n.emotion} • ${n.phase}'),
          trailing: _MiniSparkline(series: n.series),
          onTap: () => onTap(n),
        );
      },
    );
  }
}

/// RADIAL (central theme + spokes; pick max-frequency as center)
class RadialView extends StatelessWidget {
  const RadialView({super.key, required this.nodes, required this.onTap});
  final List<KeywordNode> nodes;
  final ValueChanged<KeywordNode> onTap;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) return const Center(child: Text('No data'));
    final sorted = [...nodes]..sort((a,b) => b.frequency.compareTo(a.frequency));
    final center = sorted.first;
    final spokes = sorted.skip(1).toList();

    return LayoutBuilder(
      builder: (_, c) {
        final centerPos = Offset(c.maxWidth/2, c.maxHeight/2);
        return Stack(
          fit: StackFit.expand,
          children: [
            // spokes
            CustomPaint(
              painter: _RadialSpokesPainter(center: centerPos, nodes: spokes),
            ),
            // center node
            Positioned(
              left: centerPos.dx - 28,
              top: centerPos.dy - 28,
              child: GestureDetector(
                onTap: () => onTap(center),
                child: _GlowDot(label: center.label, size: 56, color: _emotionColor(center.emotion)),
              ),
            ),
            // spoke nodes
            ...spokes.asMap().entries.map((e) {
              final idx = e.key;
              final n = e.value;
              final pos = _ringPosition(idx, spokes.length, c.biggest, radiusFactor: 0.42);
              return Positioned(
                left: pos.dx - 18, top: pos.dy - 18,
                child: GestureDetector(
                  onTap: () => onTap(n),
                  child: _GlowDot(label: n.label, size: 36, color: _emotionColor(n.emotion)),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Offset _ringPosition(int i, int total, Size size, {double radiusFactor = 0.42}) {
    final r = size.shortestSide * radiusFactor;
    final angle = (i / total) * 3.14159 * 2;
    final cx = size.width / 2;
    final cy = size.height / 2;
    return Offset(cx + r * MathHelper.cos(angle), cy + r * MathHelper.sin(angle));
  }
}

class _RadialSpokesPainter extends CustomPainter {
  _RadialSpokesPainter({required this.center, required this.nodes});
  final Offset center;
  final List<KeywordNode> nodes;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final p = _ring(i, nodes.length, size);
      final paint = Paint()
        ..strokeWidth = 1.5
        ..color = _emotionColor(n.emotion).withOpacity(0.5);
      canvas.drawLine(center, p, paint);
    }
  }

  Offset _ring(int i, int total, Size size) {
    final r = size.shortestSide * 0.42;
    final angle = (i / total) * 3.14159 * 2;
    final cx = size.width / 2;
    final cy = size.height / 2;
    return Offset(cx + r * MathHelper.cos(angle), cy + r * MathHelper.sin(angle));
  }

  @override
  bool shouldRepaint(covariant _RadialSpokesPainter oldDelegate) => false;
}

class KeywordDetailsSheet extends StatelessWidget {
  const KeywordDetailsSheet({super.key, required this.node});
  final KeywordNode node;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, ctrl) {
        return Material(
          color: Theme.of(context).colorScheme.surface,
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(backgroundColor: _emotionColor(node.emotion), radius: 8),
                  const SizedBox(width: 8),
                  Text(node.label, style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _Pill('Frequency', '${node.frequency}'),
                  _Pill('Phase', node.phase),
                  _Pill('Emotion', node.emotion),
                  _Pill('Recency', node.recencyScore.toStringAsFixed(2)),
                ],
              ),
              const SizedBox(height: 16),
              Text('Trend', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _MiniSparkline(series: node.series, height: 48),
              const SizedBox(height: 16),
              Text('Related Excerpts', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...node.excerpts.map((e) => Card(
                child: Padding(padding: const EdgeInsets.all(12), child: Text('"$e"')),
              )),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  // TODO: navigate to filtered journal list
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.menu_book),
                label: const Text('View related entries'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ', style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({required this.series, this.height = 36});
  final List<int> series;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      width: 120,
      child: CustomPaint(painter: _SparkPainter(series)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.series);
  final List<int> series;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2) return;

    final maxVal = (series.reduce((a,b) => a > b ? a : b)).toDouble().clamp(1, double.infinity);
    final dx = size.width / (series.length - 1);
    final path = Path();
    for (var i = 0; i < series.length; i++) {
      final x = i * dx;
      final y = size.height - (series[i] / maxVal) * size.height;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.9);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) => oldDelegate.series != series;
}

Color _emotionColor(String emotion) {
  switch (emotion) {
    case 'positive': return const Color(0xFF57F287);
    case 'reflective': return const Color(0xFF66CCFF);
    case 'neutral': return const Color(0xFFD0D3D4);
    default: return const Color(0xFFB39DDB);
  }
}

/// math helpers to avoid importing dart:math everywhere in painters
class MathHelper {
  static double sin(double v) => math.sin(v);
  static double cos(double v) => math.cos(v);
}