import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/arcforms/arcform_renderer_state.dart';
import 'package:hive/hive.dart';

class ArcformRendererCubit extends Cubit<ArcformRendererState> {
  static const String _snapshotBoxName = 'arcform_snapshots';
  
  ArcformRendererCubit() : super(const ArcformRendererInitial());

  void initialize() {
    emit(const ArcformRendererLoading());

    // Simulate loading data
    Future.delayed(const Duration(milliseconds: 500), () {
      // Create sample nodes with force-directed layout simulation
      final nodes = <Node>[
        Node(id: '1', label: 'Journal', x: 100, y: 100),
        Node(id: '2', label: 'Reflection', x: 200, y: 150),
        Node(id: '3', label: 'Growth', x: 300, y: 100),
        Node(id: '4', label: 'Insight', x: 150, y: 250),
        Node(id: '5', label: 'Pattern', x: 250, y: 250),
        Node(id: '6', label: 'Awareness', x: 350, y: 200),
        Node(id: '7', label: 'Clarity', x: 200, y: 300),
        Node(id: '8', label: 'Wisdom', x: 300, y: 350),
      ];

      // Create sample edges
      final edges = <Edge>[
        Edge(source: '1', target: '2'),
        Edge(source: '2', target: '3'),
        Edge(source: '1', target: '4'),
        Edge(source: '4', target: '5'),
        Edge(source: '3', target: '5'),
        Edge(source: '5', target: '6'),
        Edge(source: '4', target: '7'),
        Edge(source: '7', target: '8'),
        Edge(source: '6', target: '8'),
      ];

      emit(ArcformRendererLoaded(
        nodes: nodes,
        edges: edges,
        selectedGeometry: GeometryPattern.spiral,
        currentPhase: 'Discovery',
      ));
    });
  }

  /// ARC MVP: Create an Arcform from journal entry data
  Future<void> createArcformFromEntry({
    required String entryId,
    required String title,
    required String content,
    required String mood,
    required List<String> keywords,
  }) async {
    try {
      // Determine geometry pattern based on content and keywords
      final geometry = _determineGeometry(content, keywords);
      
      // Generate color map for keywords
      final colorMap = _generateColorMap(keywords);
      
      // Generate edges between keywords
      final edges = _generateEdges(keywords);
      
      // Create snapshot data
      final snapshotData = {
        'id': _generateId(),
        'entryId': entryId,
        'title': title,
        'content': content,
        'mood': mood,
        'keywords': keywords,
        'geometry': geometry.name,
        'colorMap': colorMap,
        'edges': edges,
        'phaseHint': _determinePhaseHint(content, keywords),
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      // Save to Hive
      await _saveSnapshot(snapshotData);
      
      // Update the current state with new data
      _updateStateWithKeywords(keywords, geometry);
      
    } catch (e) {
      emit(ArcformRendererError('Failed to create Arcform: $e'));
    }
  }

  /// Update the current state with new keywords and geometry
  void _updateStateWithKeywords(List<String> keywords, GeometryPattern geometry) {
    if (state is ArcformRendererLoaded) {
      final currentState = state as ArcformRendererLoaded;
      
      // Create nodes from keywords
      final nodes = <Node>[];
      const centerX = 200.0;
      const centerY = 200.0;
      const radius = 150.0;
      
      for (int i = 0; i < keywords.length; i++) {
        final angle = (2 * 3.14159 * i) / keywords.length;
        final x = centerX + radius * _cos(angle);
        final y = centerY + radius * _sin(angle);
        
        nodes.add(Node(
          id: (i + 1).toString(),
          label: keywords[i],
          x: x,
          y: y,
          size: 20.0 + (keywords[i].length * 2.0),
        ));
      }
      
      // Create edges between adjacent keywords
      final edges = <Edge>[];
      for (int i = 0; i < keywords.length - 1; i++) {
        edges.add(Edge(
          source: (i + 1).toString(),
          target: (i + 2).toString(),
        ));
      }
      
      // Connect first and last for circular pattern
      if (keywords.length > 2) {
        edges.add(Edge(
          source: '1',
          target: keywords.length.toString(),
        ));
      }
      
      emit(ArcformRendererLoaded(
        nodes: nodes,
        edges: edges,
        selectedGeometry: geometry,
        currentPhase: _determinePhaseHint('', keywords),
      ));
    }
  }

  /// Determine geometry pattern based on content and keywords
  GeometryPattern _determineGeometry(String content, List<String> keywords) {
    final contentLength = content.length;
    final keywordCount = keywords.length;
    
    if (contentLength > 500 && keywordCount > 7) {
      return GeometryPattern.fractal;
    } else if (contentLength > 300 && keywordCount > 5) {
      return GeometryPattern.branch;
    } else if (keywordCount > 3) {
      return GeometryPattern.flower;
    } else {
      return GeometryPattern.spiral;
    }
  }

  /// Generate color map for keywords
  Map<String, String> _generateColorMap(List<String> keywords) {
    final colors = [
      '#4F46E5', // Primary blue
      '#7C3AED', // Purple
      '#D1B3FF', // Light purple
      '#6BE3A0', // Green
      '#F7D774', // Yellow
      '#FF6B6B', // Red
    ];
    
    final colorMap = <String, String>{};
    for (int i = 0; i < keywords.length; i++) {
      colorMap[keywords[i]] = colors[i % colors.length];
    }
    
    return colorMap;
  }

  /// Generate edges between keywords
  List<List<dynamic>> _generateEdges(List<String> keywords) {
    final edges = <List<dynamic>>[];
    
    // Create connections between adjacent keywords
    for (int i = 0; i < keywords.length - 1; i++) {
      edges.add([i, i + 1, 0.8]); // [source, target, weight]
    }
    
    // Create some cross-connections for visual interest
    if (keywords.length > 3) {
      edges.add([0, keywords.length - 1, 0.6]); // Connect first and last
      if (keywords.length > 5) {
        edges.add([1, keywords.length - 2, 0.5]); // Connect second and second-to-last
      }
    }
    
    return edges;
  }

  /// Determine ATLAS phase hint
  String _determinePhaseHint(String content, List<String> keywords) {
    final lowerContent = content.toLowerCase();
    
    if (lowerContent.contains('growth') || lowerContent.contains('learn') || lowerContent.contains('improve')) {
      return 'Discovery';
    } else if (lowerContent.contains('challenge') || lowerContent.contains('struggle') || lowerContent.contains('difficult')) {
      return 'Integration';
    } else if (lowerContent.contains('gratitude') || lowerContent.contains('appreciate') || lowerContent.contains('blessed')) {
      return 'Transcendence';
    } else {
      return 'Discovery';
    }
  }

  /// Save snapshot to Hive
  Future<void> _saveSnapshot(Map<String, dynamic> snapshotData) async {
    final box = await Hive.openBox(_snapshotBoxName);
    await box.put(snapshotData['id'], snapshotData);
  }

  /// Generate a simple ID
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Simple math functions
  double _cos(double angle) => cos(angle);
  double _sin(double angle) => sin(angle);

  void updateNodePosition(String nodeId, double x, double y) {
    if (state is ArcformRendererLoaded) {
      final currentState = state as ArcformRendererLoaded;
      final updatedNodes = currentState.nodes.map((node) {
        if (node.id == nodeId) {
          return Node(
            id: node.id,
            label: node.label,
            x: x,
            y: y,
            size: node.size,
          );
        }
        return node;
      }).toList();

      emit(currentState.copyWith(nodes: updatedNodes));
    }
  }

  void changeGeometry(GeometryPattern geometry) {
    if (state is ArcformRendererLoaded) {
      final currentState = state as ArcformRendererLoaded;
      emit(currentState.copyWith(selectedGeometry: geometry));
    }
  }
}
