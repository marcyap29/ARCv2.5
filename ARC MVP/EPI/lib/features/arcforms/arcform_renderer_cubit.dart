import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/arcforms/arcform_renderer_state.dart';
import 'package:my_app/features/arcforms/geometry/geometry_layouts.dart';
import 'package:my_app/features/arcforms/arcform_mvp_implementation.dart';
import 'package:my_app/models/arcform_snapshot_model.dart';
import 'package:hive/hive.dart';

class ArcformRendererCubit extends Cubit<ArcformRendererState> {
  static const String _snapshotBoxName = 'arcform_snapshots';
  
  ArcformRendererCubit() : super(const ArcformRendererInitial());

  void initialize() {
    emit(const ArcformRendererLoading());

    // Load actual arcform data if available, otherwise use sample data
    _loadArcformData();
  }

  /// Load arcform data from storage or use sample data
  Future<void> _loadArcformData() async {
    try {
      // Try to load the latest arcform snapshot
      final snapshotData = await _getLatestArcformSnapshot();
      
      if (snapshotData != null) {
        // Use actual data from storage
        final sampleKeywords = ['Journal', 'Reflection', 'Growth', 'Insight', 'Pattern', 'Awareness', 'Clarity', 'Wisdom'];
        final phase = snapshotData['phase'] as String?;
        final geometryName = snapshotData['geometry'] as String?;
        
        print('DEBUG: Loading arcform data - phase: $phase, geometry: $geometryName');
        
        // Map phase to geometry if geometry not found
        final geometry = geometryName != null 
            ? _stringToGeometryPattern(geometryName)
            : _phaseToGeometryPattern(phase ?? 'Discovery');

        // Create initial loaded state with actual phase and geometry
        emit(ArcformRendererLoaded(
          nodes: const [],
          edges: const [],
          selectedGeometry: geometry,
          currentPhase: phase ?? 'Discovery',
        ));

        // Update with actual phase and geometry
        _updateStateWithKeywords(sampleKeywords, geometry, phase);
      } else {
        // Fallback to sample data
        _loadSampleData();
      }
    } catch (e) {
      // Error loading, use sample data
      _loadSampleData();
    }
  }

  /// Load sample data (original behavior)
  void _loadSampleData() {
    Future.delayed(const Duration(milliseconds: 500), () {
      // Create sample keywords for demonstration
      final sampleKeywords = ['Journal', 'Reflection', 'Growth', 'Insight', 'Pattern', 'Awareness', 'Clarity', 'Wisdom'];
      const defaultGeometry = GeometryPattern.spiral;

      // Create initial loaded state
      emit(const ArcformRendererLoaded(
        nodes: [],
        edges: [],
        selectedGeometry: GeometryPattern.spiral,
        currentPhase: 'Discovery', // Default starting phase
      ));

      // Then use the proper geometry system for layout
      _updateStateWithKeywords(sampleKeywords, defaultGeometry);
    });
  }

  /// Get the latest arcform snapshot data from storage
  Future<Map<String, dynamic>?> _getLatestArcformSnapshot() async {
    try {
      final box = await Hive.openBox<ArcformSnapshot>('arcform_snapshots');
      
      print('DEBUG: Hive box has ${box.length} snapshots');
      if (box.isEmpty) {
        print('DEBUG: No snapshots found in storage');
        return null;
      }

      // Find the most recent snapshot
      ArcformSnapshot? latestSnapshot;
      DateTime? latestDate;
      
      for (final key in box.keys) {
        final snapshot = box.get(key);
        if (snapshot != null) {
          if (latestDate == null || snapshot.timestamp.isAfter(latestDate)) {
            latestDate = snapshot.timestamp;
            latestSnapshot = snapshot;
          }
        }
      }
      
      if (latestSnapshot != null) {
        final phase = latestSnapshot.data['phase'] as String?;
        final geometry = latestSnapshot.data['geometry'] as String?;
        print('DEBUG: Retrieved snapshot - phase: $phase, geometry: $geometry');
        return {
          'phase': phase,
          'geometry': geometry,
        };
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Convert string to GeometryPattern
  GeometryPattern _stringToGeometryPattern(String geometryName) {
    switch (geometryName.toLowerCase()) {
      case 'spiral':
        return GeometryPattern.spiral;
      case 'flower':
        return GeometryPattern.flower;
      case 'branch':
        return GeometryPattern.branch;
      case 'weave':
        return GeometryPattern.weave;
      case 'glowcore':
        return GeometryPattern.glowCore;
      case 'fractal':
        return GeometryPattern.fractal;
      default:
        return GeometryPattern.spiral;
    }
  }

  /// Map phase to GeometryPattern
  GeometryPattern _phaseToGeometryPattern(String phase) {
    switch (phase) {
      case 'Discovery':
        return GeometryPattern.spiral;
      case 'Expansion':
        return GeometryPattern.flower;
      case 'Transition':
        return GeometryPattern.branch;
      case 'Consolidation':
        return GeometryPattern.weave;
      case 'Recovery':
        return GeometryPattern.glowCore;
      case 'Breakthrough':
        return GeometryPattern.fractal;
      default:
        return GeometryPattern.spiral; // Default to Discovery
    }
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
  void _updateStateWithKeywords(List<String> keywords, GeometryPattern geometry, [String? phase]) {
    // Map GeometryPattern to ArcformGeometry for layout calculations
    final arcformGeometry = _mapGeometryPattern(geometry);
    
    // Create nodes using proper geometry layouts
    final nodes = _createNodesWithGeometry(keywords, arcformGeometry);
    
    // Create edges based on geometry pattern
    final edges = _createEdgesForGeometry(keywords.length, geometry);
    
    // Use provided phase or determine from keywords
    final currentPhase = phase ?? _determinePhaseHint('', keywords);
    
    emit(ArcformRendererLoaded(
      nodes: nodes,
      edges: edges,
      selectedGeometry: geometry,
      currentPhase: currentPhase,
    ));
  }

  /// Map GeometryPattern to ArcformGeometry
  ArcformGeometry _mapGeometryPattern(GeometryPattern pattern) {
    switch (pattern) {
      case GeometryPattern.spiral:
        return ArcformGeometry.spiral;
      case GeometryPattern.flower:
        return ArcformGeometry.flower;
      case GeometryPattern.branch:
        return ArcformGeometry.branch;
      case GeometryPattern.weave:
        return ArcformGeometry.weave;
      case GeometryPattern.glowCore:
        return ArcformGeometry.glowCore;
      case GeometryPattern.fractal:
        return ArcformGeometry.fractal;
    }
  }

  /// Create nodes using proper geometry layouts
  List<Node> _createNodesWithGeometry(List<String> keywords, ArcformGeometry geometry) {
    final nodes = <Node>[];
    
    // Define canvas size for layout calculations
    const canvasSize = Size(400.0, 400.0);
    
    // Get positions from geometry layout system
    final positions = GeometryLayouts.getPositions(
      geometry: geometry,
      nodeCount: keywords.length,
      canvasSize: canvasSize,
    );
    
    // Create nodes at calculated positions
    for (int i = 0; i < keywords.length; i++) {
      final position = i < positions.length ? positions[i] : const Offset(200.0, 200.0);
      
      nodes.add(Node(
        id: (i + 1).toString(),
        label: keywords[i],
        x: position.dx,
        y: position.dy,
        size: 20.0 + (keywords[i].length * 1.5),
      ));
    }
    
    return nodes;
  }

  /// Create edges based on geometry pattern
  List<Edge> _createEdgesForGeometry(int nodeCount, GeometryPattern geometry) {
    final edges = <Edge>[];
    
    switch (geometry) {
      case GeometryPattern.spiral: // Discovery - connected spiral path
        for (int i = 0; i < nodeCount - 1; i++) {
          edges.add(Edge(
            source: (i + 1).toString(),
            target: (i + 2).toString(),
          ));
        }
        break;
        
      case GeometryPattern.flower: // Expansion - all petals connect to center
        if (nodeCount > 1) {
          for (int i = 1; i < nodeCount; i++) {
            edges.add(Edge(
              source: '1',
              target: (i + 1).toString(),
            ));
          }
        }
        break;
        
      case GeometryPattern.branch: // Transition - tree structure
        if (nodeCount > 1) {
          // Connect to root (first node)
          for (int i = 1; i < nodeCount; i++) {
            final parentIndex = i <= 4 ? 1 : ((i - 2) % 4) + 2;
            edges.add(Edge(
              source: parentIndex.toString(),
              target: (i + 1).toString(),
            ));
          }
        }
        break;
        
      case GeometryPattern.weave: // Consolidation - grid connections
        final gridSize = sqrt(nodeCount).ceil();
        for (int i = 0; i < nodeCount; i++) {
          final row = i ~/ gridSize;
          final col = i % gridSize;
          
          // Connect to right neighbor
          if (col < gridSize - 1 && i + 1 < nodeCount) {
            edges.add(Edge(
              source: (i + 1).toString(),
              target: (i + 2).toString(),
            ));
          }
          
          // Connect to bottom neighbor
          if (row < gridSize - 1 && i + gridSize < nodeCount) {
            edges.add(Edge(
              source: (i + 1).toString(),
              target: (i + gridSize + 1).toString(),
            ));
          }
        }
        break;
        
      case GeometryPattern.glowCore: // Recovery - radial from center
        if (nodeCount > 1) {
          for (int i = 1; i < nodeCount; i++) {
            edges.add(Edge(
              source: '1',
              target: (i + 1).toString(),
            ));
          }
          // Add some inter-ring connections
          if (nodeCount > 6) {
            for (int i = 1; i < min(7, nodeCount); i++) {
              final nextIndex = i < 6 ? i + 1 : 2;
              if (nextIndex < nodeCount) {
                edges.add(Edge(
                  source: (i + 1).toString(),
                  target: (nextIndex + 1).toString(),
                ));
              }
            }
          }
        }
        break;
        
      case GeometryPattern.fractal: // Breakthrough - hierarchical branches
        if (nodeCount > 1) {
          for (int i = 1; i < nodeCount; i++) {
            // Connect each node to its parent in the fractal structure
            final parentIndex = _getFractalParent(i);
            edges.add(Edge(
              source: parentIndex.toString(),
              target: (i + 1).toString(),
            ));
          }
        }
        break;
    }
    
    return edges;
  }

  /// Get parent index for fractal structure
  int _getFractalParent(int childIndex) {
    if (childIndex == 1) return 1; // Root
    if (childIndex <= 3) return 1; // First level branches connect to root
    
    // Higher levels - simplified parent calculation
    return ((childIndex - 2) ~/ 2) + 1;
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
      return 'Recovery'; // Better mapping for difficulty
    } else if (lowerContent.contains('gratitude') || lowerContent.contains('appreciate') || lowerContent.contains('blessed')) {
      return 'Expansion'; // Better mapping for positive emotions
    } else if (lowerContent.contains('change') || lowerContent.contains('moving') || lowerContent.contains('transition')) {
      return 'Transition';
    } else if (lowerContent.contains('routine') || lowerContent.contains('organize') || lowerContent.contains('stable')) {
      return 'Consolidation';
    } else {
      // More balanced default based on content length
      if (content.length > 100) {
        return 'Consolidation';
      } else {
        return 'Expansion';
      }
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
