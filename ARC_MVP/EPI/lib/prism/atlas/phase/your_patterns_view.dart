// lib/features/insights/your_patterns_view.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/services/patterns_data_service.dart';

enum PatternsView { wordCloud, mindMap, timeline }

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
  PatternsView current = PatternsView.wordCloud;

  // Filters
  String? emotionFilter; // null = all
  String? phaseFilter;   // null = all
  DateTimeRange? range;  // null = all time

  // Data (replace with MIRA-powered repository later)
  late List<KeywordNode> nodes;
  late List<KeywordEdge> edges;

  // Loading state
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRealData();
  }

  Future<void> _loadRealData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        nodes = [];
        edges = [];
      });
    }

    try {
      final journalRepo = context.read<JournalRepository>();
      final service = PatternsDataService(journalRepository: journalRepo);

      print('DEBUG: Loading patterns data from real journal entries...');
      final data = await service.getPatternsData();

      if (mounted) {
        setState(() {
          nodes = data.$1;
          edges = data.$2;
          _isLoading = false;
        });
        print('DEBUG: Successfully loaded ${nodes.length} nodes and ${edges.length} edges');
      }
    } catch (e) {
      print('ERROR: Failed to load patterns data: $e');
      print('ERROR: Stack trace: ${StackTrace.current}');

      // Fallback to demo data on error
      if (mounted) {
        final demo = _demoData();
        setState(() {
          nodes = demo.$1;
          edges = demo.$2;
          _isLoading = false;
        });
        print('DEBUG: Using demo data as fallback');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Patterns'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Patterns',
            onPressed: _isLoading ? null : _loadRealData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
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
    // Show empty state if no data
    if (nodes.isEmpty) {
      return _buildEmptyState();
    }

    final filteredNodes = nodes.where(_nodePassesFilters).toList();
    final filteredEdges = edges.where((e) {
      final aOk = filteredNodes.any((n) => n.id == e.a);
      final bOk = filteredNodes.any((n) => n.id == e.b);
      return aOk && bOk;
    }).toList();

    // Show filtered empty state if filters removed all data
    if (filteredNodes.isEmpty) {
      return _buildFilteredEmptyState();
    }

    switch (current) {
      case PatternsView.wordCloud:
        return WordCloudView(
          key: const ValueKey('wordCloud'),
          nodes: filteredNodes,
          onTap: _showDetails,
        );
      case PatternsView.mindMap:
        return MindMapView(
          key: const ValueKey('mindMap'),
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
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_graph,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No Patterns Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start journaling to see your patterns emerge.\nPatterns are generated from your journal entries.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.edit),
              label: const Text('Start Journaling'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Matches',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters to see more patterns.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _nodePassesFilters(KeywordNode n) {
    final emotionOk = emotionFilter == null || n.emotion == emotionFilter;
    final phaseOk = phaseFilter == null || n.phase == phaseFilter;
    // Time filtering would require per-entry timestamps; here we rely on series/recencyScore.
    const timeOk = true; // Replace with real check when wired to entries
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

  (List<KeywordNode>, List<KeywordEdge>) _demoData() {
    // Use the MIRA co-occurrence matrix adapter for demo data
    final mockSemanticData = CoOccurrenceMatrixAdapter.generateMockSemanticData();
    return CoOccurrenceMatrixAdapter.fromMiraSemanticData(
      semanticData: mockSemanticData,
      minWeight: 0.3, // Show only stronger connections for demo
      maxNodes: 8,    // Limit to keep visualization clean
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
        ButtonSegment(value: PatternsView.mindMap,   label: Text('Mind map'),   icon: Icon(Icons.account_tree)),
        ButtonSegment(value: PatternsView.timeline,  label: Text('Timeline'),   icon: Icon(Icons.timeline)),
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

/// MIND MAP: pick a word from list, show center + associated words (from edges), tap branch to re-center.
class MindMapView extends StatefulWidget {
  const MindMapView({
    super.key,
    required this.nodes,
    required this.edges,
    required this.onTapNode,
  });
  final List<KeywordNode> nodes;
  final List<KeywordEdge> edges;
  final ValueChanged<KeywordNode> onTapNode;

  @override
  State<MindMapView> createState() => _MindMapViewState();
}

class _MindMapViewState extends State<MindMapView> {
  static const int _maxBranches = 20;
  String? _centerId;

  KeywordNode? get _centerNode {
    if (_centerId == null) return null;
    try {
      return widget.nodes.firstWhere((n) => n.id == _centerId);
    } catch (_) {
      return null;
    }
  }

  /// Neighbors of center from edges, sorted by weight descending, capped at _maxBranches.
  List<KeywordNode> get _branchNodes {
    final center = _centerNode;
    if (center == null) return [];
    final branchIds = <String, double>{};
    for (final e in widget.edges) {
      if (e.a == center.id) branchIds[e.b] = e.weight;
      if (e.b == center.id) branchIds[e.a] = e.weight;
    }
    final sorted = branchIds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final ids = sorted.take(_maxBranches).map((e) => e.key).toSet();
    return widget.nodes.where((n) => ids.contains(n.id)).toList();
  }

  @override
  void didUpdateWidget(MindMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodes != widget.nodes || oldWidget.edges != widget.edges) {
      if (_centerId != null && !widget.nodes.any((n) => n.id == _centerId)) {
        setState(() => _centerId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nodes.isEmpty) return const Center(child: Text('No data'));

    final center = _centerNode ?? widget.nodes.first;
    final centerId = _centerId ?? center.id;
    if (_centerId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _centerId = centerId);
      });
    }

    final branches = _branchNodes;
    final wordList = [...widget.nodes]..sort((a, b) => b.frequency.compareTo(a.frequency));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text('Pick a word:', style: Theme.of(context).textTheme.labelLarge),
        ),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: wordList.length,
            itemBuilder: (_, i) {
              final n = wordList[i];
              final selected = n.id == _centerId;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(n.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _centerId = n.id),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (_, constraints) {
              final centerPos = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _MindMapLinesPainter(
                      center: centerPos,
                      centerNode: center,
                      branchNodes: branches,
                      edges: widget.edges,
                      centerId: center.id,
                    ),
                  ),
                  Positioned(
                    left: centerPos.dx - 28,
                    top: centerPos.dy - 28,
                    child: GestureDetector(
                      onTap: () => widget.onTapNode(center),
                      child: _GlowDot(label: center.label, size: 56, color: _emotionColor(center.emotion)),
                    ),
                  ),
                  ...branches.asMap().entries.map((e) {
                    final idx = e.key;
                    final n = e.value;
                    final pos = _ringPosition(idx, branches.length, constraints.biggest, radiusFactor: 0.42);
                    return Positioned(
                      left: pos.dx - 18,
                      top: pos.dy - 18,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _centerId = n.id);
                          widget.onTapNode(n);
                        },
                        child: _GlowDot(label: n.label, size: 36, color: _emotionColor(n.emotion)),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
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

class _MindMapLinesPainter extends CustomPainter {
  _MindMapLinesPainter({
    required this.center,
    required this.centerNode,
    required this.branchNodes,
    required this.edges,
    required this.centerId,
  });
  final Offset center;
  final KeywordNode centerNode;
  final List<KeywordNode> branchNodes;
  final List<KeywordEdge> edges;
  final String centerId;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.shortestSide * 0.42;
    for (var i = 0; i < branchNodes.length; i++) {
      final n = branchNodes[i];
      final angle = (i / branchNodes.length) * 3.14159 * 2;
      final end = Offset(cx + r * MathHelper.cos(angle), cy + r * MathHelper.sin(angle));
      final weight = edges
          .where((e) => (e.a == centerId && e.b == n.id) || (e.b == centerId && e.a == n.id))
          .map((e) => e.weight)
          .fold(0.0, (a, b) => a > b ? a : b);
      final paint = Paint()
        ..strokeWidth = 1.0 + 2.0 * weight
        ..color = _emotionColor(n.emotion).withOpacity(0.4 + 0.4 * weight)
        ..style = PaintingStyle.stroke;
      canvas.drawLine(center, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MindMapLinesPainter old) =>
      old.center != center || old.centerId != centerId || old.branchNodes != branchNodes;
}

/// Co-occurrence matrix adapter for MIRA semantic memory integration
class CoOccurrenceMatrixAdapter {
  /// Converts MIRA semantic data into keyword nodes and weighted edges
  static (List<KeywordNode>, List<KeywordEdge>) fromMiraSemanticData({
    required Map<String, dynamic> semanticData,
    double minWeight = 0.1,
    int maxNodes = 50,
  }) {
    final nodes = <KeywordNode>[];
    final edges = <KeywordEdge>[];

    // Extract co-occurrence matrix
    final coOccurrenceMatrix = semanticData['co_occurrence_matrix'] as Map<String, dynamic>? ?? {};
    final keywordStats = semanticData['keyword_stats'] as Map<String, dynamic>? ?? {};
    final phaseAssociations = semanticData['phase_associations'] as Map<String, dynamic>? ?? {};
    final emotionMappings = semanticData['emotion_mappings'] as Map<String, dynamic>? ?? {};
    final timeSeries = semanticData['time_series'] as Map<String, dynamic>? ?? {};

    // Build nodes from keyword statistics
    final nodeMap = <String, KeywordNode>{};
    for (final entry in keywordStats.entries) {
      final keyword = entry.key;
      final stats = entry.value as Map<String, dynamic>;

      final frequency = (stats['frequency'] as int?) ?? 0;
      final recencyScore = (stats['recency_score'] as double?) ?? 0.0;
      final phase = phaseAssociations[keyword] as String? ?? 'Discovery';
      final emotion = emotionMappings[keyword] as String? ?? 'neutral';
      final excerpts = (stats['excerpts'] as List<dynamic>?)?.cast<String>() ?? [];
      final series = (timeSeries[keyword] as List<dynamic>?)?.cast<int>() ?? [0];

      final node = KeywordNode(
        id: keyword,
        label: keyword,
        frequency: frequency,
        recencyScore: recencyScore,
        emotion: emotion,
        phase: phase,
        excerpts: excerpts.take(5).toList(), // Limit to 5 excerpts
        series: series,
      );

      nodeMap[keyword] = node;
      nodes.add(node);
    }

    // Sort by frequency and limit nodes
    nodes.sort((a, b) => b.frequency.compareTo(a.frequency));
    final limitedNodes = nodes.take(maxNodes).toList();
    final limitedNodeIds = limitedNodes.map((n) => n.id).toSet();

    // Build edges from co-occurrence matrix
    for (final entry in coOccurrenceMatrix.entries) {
      final keywordA = entry.key;
      if (!limitedNodeIds.contains(keywordA)) continue;

      final connections = entry.value as Map<String, dynamic>;
      for (final connectionEntry in connections.entries) {
        final keywordB = connectionEntry.key;
        if (!limitedNodeIds.contains(keywordB) || keywordA == keywordB) continue;

        final weight = (connectionEntry.value as double?) ?? 0.0;
        if (weight >= minWeight) {
          // Avoid duplicate edges (A-B is same as B-A)
          final existingEdge = edges.any((e) =>
            (e.a == keywordA && e.b == keywordB) ||
            (e.a == keywordB && e.b == keywordA)
          );

          if (!existingEdge) {
            edges.add(KeywordEdge(a: keywordA, b: keywordB, weight: weight));
          }
        }
      }
    }

    // Normalize edge weights
    if (edges.isNotEmpty) {
      final maxWeight = edges.map((e) => e.weight).reduce((a, b) => a > b ? a : b);
      for (final edge in edges) {
        edge.weight = edge.weight / maxWeight;
      }
    }

    return (limitedNodes, edges);
  }

  /// Generates mock MIRA-compatible semantic data for testing
  static Map<String, dynamic> generateMockSemanticData() {
    return {
      'co_occurrence_matrix': {
        'breakthrough': {
          'resilience': 0.9,
          'uncertainty': 0.6,
          'focus': 0.3,
          'creativity': 0.8,
          'momentum': 0.7,
        },
        'resilience': {
          'breakthrough': 0.9,
          'recovery': 0.8,
          'persistence': 0.7,
          'strength': 0.6,
        },
        'uncertainty': {
          'breakthrough': 0.6,
          'transition': 0.8,
          'exploration': 0.7,
          'adaptation': 0.5,
        },
        'focus': {
          'breakthrough': 0.3,
          'clarity': 0.9,
          'concentration': 0.8,
          'discipline': 0.7,
        },
        'creativity': {
          'breakthrough': 0.8,
          'innovation': 0.9,
          'inspiration': 0.7,
          'imagination': 0.6,
        },
        'momentum': {
          'breakthrough': 0.7,
          'progress': 0.8,
          'acceleration': 0.6,
        },
        'recovery': {
          'resilience': 0.8,
          'healing': 0.9,
          'restoration': 0.7,
        },
        'transition': {
          'uncertainty': 0.8,
          'change': 0.9,
          'evolution': 0.6,
        },
      },
      'keyword_stats': {
        'breakthrough': {
          'frequency': 42,
          'recency_score': 0.8,
          'excerpts': [
            'Felt an inflection today on the project.',
            'Noticed a pattern in how I approach tough problems.',
            'The insight came suddenly and changed everything.',
          ],
        },
        'resilience': {
          'frequency': 35,
          'recency_score': 0.9,
          'excerpts': [
            'Kept going even with low energy.',
            'Found strength I didn\'t know I had.',
          ],
        },
        'uncertainty': {
          'frequency': 28,
          'recency_score': 0.6,
          'excerpts': [
            'Leaning into unknowns with more patience.',
          ],
        },
        'focus': {
          'frequency': 18,
          'recency_score': 0.5,
          'excerpts': [
            'Tightened scope and reduced noise today.',
          ],
        },
        'creativity': {
          'frequency': 25,
          'recency_score': 0.7,
          'excerpts': [
            'New ideas flowing more freely.',
            'Connected disparate concepts in a novel way.',
          ],
        },
        'momentum': {
          'frequency': 20,
          'recency_score': 0.8,
          'excerpts': [
            'Building speed on this initiative.',
          ],
        },
        'recovery': {
          'frequency': 15,
          'recency_score': 0.4,
          'excerpts': [
            'Taking time to rest and recharge.',
          ],
        },
        'transition': {
          'frequency': 22,
          'recency_score': 0.6,
          'excerpts': [
            'Moving between phases feels natural now.',
          ],
        },
      },
      'phase_associations': {
        'breakthrough': 'Breakthrough',
        'resilience': 'Recovery',
        'uncertainty': 'Transition',
        'focus': 'Consolidation',
        'creativity': 'Expansion',
        'momentum': 'Expansion',
        'recovery': 'Recovery',
        'transition': 'Transition',
      },
      'emotion_mappings': {
        'breakthrough': 'positive',
        'resilience': 'positive',
        'uncertainty': 'reflective',
        'focus': 'neutral',
        'creativity': 'positive',
        'momentum': 'positive',
        'recovery': 'neutral',
        'transition': 'reflective',
      },
      'time_series': {
        'breakthrough': [1, 2, 3, 5, 8, 13, 21],
        'resilience': [2, 3, 3, 4, 6, 7, 10],
        'uncertainty': [3, 3, 4, 4, 5, 6, 6],
        'focus': [5, 5, 4, 4, 3, 3, 2],
        'creativity': [1, 3, 5, 8, 6, 9, 12],
        'momentum': [2, 4, 6, 8, 10, 12, 14],
        'recovery': [8, 6, 4, 3, 2, 4, 6],
        'transition': [3, 4, 5, 4, 5, 6, 5],
      },
    };
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

/// TIMELINE (simple list with mini trend; swap with charts later)
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
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