// lib/lumara/services/reflective_node_storage.dart
// Hive-based storage for ReflectiveNode objects

import 'package:hive/hive.dart';
import '../models/reflective_node.dart';

class ReflectiveNodeStorage {
  static const String _boxName = 'reflective_nodes';
  late Box<ReflectiveNode> _nodesBox;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Register adapters
      if (!Hive.isAdapterRegistered(100)) {
        Hive.registerAdapter(MediaRefAdapter());
      }
      if (!Hive.isAdapterRegistered(101)) {
        Hive.registerAdapter(ReflectiveNodeAdapter());
      }

      _nodesBox = await Hive.openBox<ReflectiveNode>(_boxName);
      _initialized = true;
      print('LUMARA: ReflectiveNodeStorage initialized');
    } catch (e) {
      print('LUMARA: Storage initialization error: $e');
      // For now, continue without Hive adapters
      _initialized = true;
    }
  }

  Future<void> saveNode(ReflectiveNode node) async {
    if (!_initialized) await initialize();
    
    try {
      await _nodesBox.put(node.id, node);
      print('LUMARA: Saved node ${node.id} (${node.type.name})');
    } catch (e) {
      print('LUMARA: Error saving node ${node.id}: $e');
      rethrow;
    }
  }

  Future<void> saveNodes(List<ReflectiveNode> nodes) async {
    if (!_initialized) await initialize();
    
    try {
      final Map<String, ReflectiveNode> nodeMap = {
        for (final node in nodes) node.id: node
      };
      await _nodesBox.putAll(nodeMap);
      print('LUMARA: Saved ${nodes.length} nodes');
    } catch (e) {
      print('LUMARA: Error saving nodes: $e');
      rethrow;
    }
  }

  List<ReflectiveNode> getAllNodes({
    required String userId,
    int? maxYears,
    NodeType? type,
  }) {
    if (!_initialized) {
      print('LUMARA: Storage not initialized');
      return [];
    }

    try {
      final now = DateTime.now();
      final cutoffDate = maxYears != null
          ? now.subtract(Duration(days: maxYears * 365))
          : null;

      return _nodesBox.values.where((node) {
        // Filter by user
        if (node.userId != userId) return false;
        
        // Filter by type
        if (type != null && node.type != type) return false;
        
        // Filter by date range
        if (cutoffDate != null) {
          final nodeDate = node.createdAt;
          if (nodeDate.isBefore(cutoffDate)) return false;
        }
        
        // Exclude deleted nodes
        if (node.deleted) return false;
        
        return true;
      }).toList();
    } catch (e) {
      print('LUMARA: Error querying nodes: $e');
      return [];
    }
  }

  List<ReflectiveNode> getNodesByType({
    required String userId,
    required NodeType type,
    int? maxYears,
  }) {
    return getAllNodes(
      userId: userId,
      maxYears: maxYears,
      type: type,
    );
  }

  List<ReflectiveNode> getNodesByPhase({
    required String userId,
    required PhaseHint phase,
    int? maxYears,
  }) {
    if (!_initialized) return [];

    try {
      final now = DateTime.now();
      final cutoffDate = maxYears != null
          ? now.subtract(Duration(days: maxYears * 365))
          : null;

      return _nodesBox.values.where((node) {
        if (node.userId != userId) return false;
        if (node.phaseHint != phase) return false;
        if (node.deleted) return false;
        
        if (cutoffDate != null) {
          final nodeDate = node.createdAt;
          if (nodeDate.isBefore(cutoffDate)) return false;
        }
        
        return true;
      }).toList();
    } catch (e) {
      print('LUMARA: Error querying nodes by phase: $e');
      return [];
    }
  }

  ReflectiveNode? getNode(String id) {
    if (!_initialized) return null;
    
    try {
      return _nodesBox.get(id);
    } catch (e) {
      print('LUMARA: Error getting node $id: $e');
      return null;
    }
  }

  Future<void> deleteNode(String id) async {
    if (!_initialized) await initialize();
    
    try {
      final node = _nodesBox.get(id);
      if (node != null) {
        final updatedNode = node.copyWith(deleted: true);
        await _nodesBox.put(id, updatedNode);
        print('LUMARA: Marked node $id as deleted');
      }
    } catch (e) {
      print('LUMARA: Error deleting node $id: $e');
      rethrow;
    }
  }

  Future<void> clearAll() async {
    if (!_initialized) await initialize();
    
    try {
      await _nodesBox.clear();
      print('LUMARA: Cleared all nodes');
    } catch (e) {
      print('LUMARA: Error clearing nodes: $e');
      rethrow;
    }
  }

  int get nodeCount {
    if (!_initialized) return 0;
    return _nodesBox.length;
  }

  List<ReflectiveNode> searchNodes({
    required String userId,
    required String query,
    int? maxResults,
  }) {
    if (!_initialized) return [];

    try {
      final queryLower = query.toLowerCase();
      final results = <ReflectiveNode>[];

      for (final node in _nodesBox.values) {
        if (node.userId != userId || node.deleted) continue;

        // Search in content text
        if (node.contentText?.toLowerCase().contains(queryLower) == true) {
          results.add(node);
          continue;
        }

        // Search in transcription
        if (node.transcription?.toLowerCase().contains(queryLower) == true) {
          results.add(node);
          continue;
        }

        // Search in caption
        if (node.captionText?.toLowerCase().contains(queryLower) == true) {
          results.add(node);
          continue;
        }

        // Search in keywords
        if (node.keywords?.any((k) => k.toLowerCase().contains(queryLower)) == true) {
          results.add(node);
          continue;
        }
      }

      // Sort by creation date (newest first)
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return maxResults != null ? results.take(maxResults).toList() : results;
    } catch (e) {
      print('LUMARA: Error searching nodes: $e');
      return [];
    }
  }

  Map<String, int> getNodeTypeCounts(String userId) {
    if (!_initialized) return {};

    try {
      final counts = <String, int>{};
      
      for (final node in _nodesBox.values) {
        if (node.userId != userId || node.deleted) continue;
        
        final typeName = node.type.name;
        counts[typeName] = (counts[typeName] ?? 0) + 1;
      }
      
      return counts;
    } catch (e) {
      print('LUMARA: Error getting node type counts: $e');
      return {};
    }
  }

  Map<String, int> getPhaseCounts(String userId) {
    if (!_initialized) return {};

    try {
      final counts = <String, int>{};
      
      for (final node in _nodesBox.values) {
        if (node.userId != userId || node.deleted) continue;
        
        final phaseName = node.phaseHint?.name ?? 'unknown';
        counts[phaseName] = (counts[phaseName] ?? 0) + 1;
      }
      
      return counts;
    } catch (e) {
      print('LUMARA: Error getting phase counts: $e');
      return {};
    }
  }

  Future<void> close() async {
    if (_initialized) {
      await _nodesBox.close();
      _initialized = false;
      print('LUMARA: ReflectiveNodeStorage closed');
    }
  }
}