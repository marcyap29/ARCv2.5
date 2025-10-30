import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'constellation_arcform_renderer.dart';

/// Graph utilities for k-NN and Delaunay-lite edge generation
class GraphUtils {
  /// Find k nearest neighbors for each node
  static List<Connection> findKNearestNeighbors(
    List<ConstellationNode> nodes,
    int k,
  ) {
    if (nodes.length < 2) return [];
    
    final connections = <Connection>[];
    final kValue = math.min(k, nodes.length - 1);
    
    for (int i = 0; i < nodes.length; i++) {
      final nodeA = nodes[i];
      final distances = <_DistancePair>[];
      
      // Calculate distances to all other nodes
      for (int j = 0; j < nodes.length; j++) {
        if (i == j) continue;
        
        final nodeB = nodes[j];
        final distance = (nodeA.pos - nodeB.pos).distance;
        distances.add(_DistancePair(j, distance));
      }
      
      // Sort by distance and take k nearest
      distances.sort((a, b) => a.distance.compareTo(b.distance));
      
      for (int n = 0; n < math.min(kValue, distances.length); n++) {
        final neighborIndex = distances[n].index;
        connections.add(Connection(i, neighborIndex));
      }
    }
    
    // Remove duplicate connections
    return _removeDuplicateConnections(connections);
  }

  /// Generate Delaunay-lite triangulation
  static List<Connection> generateDelaunayLite(
    List<ConstellationNode> nodes,
  ) {
    if (nodes.length < 3) return findKNearestNeighbors(nodes, 2);
    
    final connections = <Connection>[];
    
    // Simple Delaunay-lite: for each node, find the two closest neighbors
    // that don't create overlapping edges
    for (int i = 0; i < nodes.length; i++) {
      final nodeA = nodes[i];
      final candidates = <_DistancePair>[];
      
      // Find all potential neighbors
      for (int j = 0; j < nodes.length; j++) {
        if (i == j) continue;
        
        final nodeB = nodes[j];
        final distance = (nodeA.pos - nodeB.pos).distance;
        candidates.add(_DistancePair(j, distance));
      }
      
      // Sort by distance
      candidates.sort((a, b) => a.distance.compareTo(b.distance));
      
      // Add connections that don't overlap
      final addedConnections = <int>{};
      for (final candidate in candidates) {
        if (addedConnections.length >= 3) break; // Limit connections per node
        
        final neighborIndex = candidate.index;
        if (_isValidConnection(i, neighborIndex, connections, nodes)) {
          connections.add(Connection(i, neighborIndex));
          addedConnections.add(neighborIndex);
        }
      }
    }
    
    return _removeDuplicateConnections(connections);
  }

  /// Generate minimum spanning tree
  static List<Connection> generateMinimumSpanningTree(
    List<ConstellationNode> nodes,
  ) {
    if (nodes.length < 2) return [];
    
    final connections = <Connection>[];
    final visited = <int>{};
    final edges = <_Edge>[];
    
    // Create all possible edges with weights
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final distance = (nodes[i].pos - nodes[j].pos).distance;
        edges.add(_Edge(i, j, distance));
      }
    }
    
    // Sort edges by weight
    edges.sort((a, b) => a.weight.compareTo(b.weight));
    
    // Kruskal's algorithm
    final parent = List.generate(nodes.length, (index) => index);
    
    for (final edge in edges) {
      if (visited.length == nodes.length) break;
      
      if (_find(parent, edge.from) != _find(parent, edge.to)) {
        connections.add(Connection(edge.from, edge.to));
        _union(parent, edge.from, edge.to);
        visited.add(edge.from);
        visited.add(edge.to);
      }
    }
    
    return connections;
  }

  /// Generate phase-specific connections
  static List<Connection> generatePhaseConnections(
    List<ConstellationNode> nodes,
    AtlasPhase phase,
  ) {
    switch (phase) {
      case AtlasPhase.discovery:
        return _generateDiscoveryConnections(nodes);
      case AtlasPhase.expansion:
        return _generateExpansionConnections(nodes);
      case AtlasPhase.transition:
        return _generateTransitionConnections(nodes);
      case AtlasPhase.consolidation:
        return _generateConsolidationConnections(nodes);
      case AtlasPhase.recovery:
        return _generateRecoveryConnections(nodes);
      case AtlasPhase.breakthrough:
        return _generateBreakthroughConnections(nodes);
    }
  }

  /// Check if connection is valid (no overlapping edges)
  static bool _isValidConnection(
    int from,
    int to,
    List<Connection> existingConnections,
    List<ConstellationNode> nodes,
  ) {
    if (from == to) return false;
    
    // Check if connection already exists
    for (final conn in existingConnections) {
      if ((conn.a == from && conn.b == to) || (conn.a == to && conn.b == from)) {
        return false;
      }
    }
    
    // Check for edge intersections
    final nodeA = nodes[from];
    final nodeB = nodes[to];
    
    for (final conn in existingConnections) {
      final nodeC = nodes[conn.a];
      final nodeD = nodes[conn.b];
      
      if (_linesIntersect(nodeA.pos, nodeB.pos, nodeC.pos, nodeD.pos)) {
        return false;
      }
    }
    
    return true;
  }

  /// Check if two line segments intersect
  static bool _linesIntersect(
    Offset p1,
    Offset p2,
    Offset p3,
    Offset p4,
  ) {
    final denom = (p1.dx - p2.dx) * (p3.dy - p4.dy) - (p1.dy - p2.dy) * (p3.dx - p4.dx);
    if (denom.abs() < 1e-10) return false; // Lines are parallel
    
    final t = ((p1.dx - p3.dx) * (p3.dy - p4.dy) - (p1.dy - p3.dy) * (p3.dx - p4.dx)) / denom;
    final u = -((p1.dx - p2.dx) * (p1.dy - p3.dy) - (p1.dy - p2.dy) * (p1.dx - p3.dx)) / denom;
    
    return t >= 0 && t <= 1 && u >= 0 && u <= 1;
  }

  /// Remove duplicate connections
  static List<Connection> _removeDuplicateConnections(List<Connection> connections) {
    final uniqueConnections = <Connection>[];
    final seen = <String>{};
    
    for (final conn in connections) {
      final key = conn.a < conn.b ? '${conn.a}-${conn.b}' : '${conn.b}-${conn.a}';
      if (!seen.contains(key)) {
        seen.add(key);
        uniqueConnections.add(conn);
      }
    }
    
    return uniqueConnections;
  }

  /// Union-Find operations for MST
  static int _find(List<int> parent, int x) {
    if (parent[x] != x) {
      parent[x] = _find(parent, parent[x]);
    }
    return parent[x];
  }

  static void _union(List<int> parent, int x, int y) {
    final px = _find(parent, x);
    final py = _find(parent, y);
    if (px != py) {
      parent[px] = py;
    }
  }

  // Phase-specific connection generators

  static List<Connection> _generateDiscoveryConnections(List<ConstellationNode> nodes) {
    // Discovery: Simple chain connections
    final connections = <Connection>[];
    for (int i = 0; i < nodes.length - 1; i++) {
      connections.add(Connection(i, i + 1));
    }
    return connections;
  }

  static List<Connection> _generateExpansionConnections(List<ConstellationNode> nodes) {
    // Expansion: Dense connections using k-NN
    return findKNearestNeighbors(nodes, 3);
  }

  static List<Connection> _generateTransitionConnections(List<ConstellationNode> nodes) {
    // Transition: Sparse connections, mostly linear
    final connections = <Connection>[];
    for (int i = 0; i < nodes.length - 1; i++) {
      if (i % 2 == 0) { // Every other connection
        connections.add(Connection(i, i + 1));
      }
    }
    return connections;
  }

  static List<Connection> _generateConsolidationConnections(List<ConstellationNode> nodes) {
    // Consolidation: Dense mesh using Delaunay-lite
    return generateDelaunayLite(nodes);
  }

  static List<Connection> _generateRecoveryConnections(List<ConstellationNode> nodes) {
    // Recovery: Very sparse connections, mostly isolated
    final connections = <Connection>[];
    for (int i = 0; i < nodes.length - 1; i += 3) { // Every third connection
      connections.add(Connection(i, i + 1));
    }
    return connections;
  }

  static List<Connection> _generateBreakthroughConnections(List<ConstellationNode> nodes) {
    // Breakthrough: Clustered connections
    final connections = <Connection>[];
    const clusterSize = 3;
    
    for (int i = 0; i < nodes.length; i += clusterSize) {
      final clusterEnd = math.min(i + clusterSize, nodes.length);
      for (int j = i; j < clusterEnd - 1; j++) {
        connections.add(Connection(j, j + 1));
      }
    }
    
    return connections;
  }
}

/// Connection between two nodes
class Connection {
  final int a;
  final int b;

  const Connection(this.a, this.b);

  @override
  String toString() => 'Connection($a -> $b)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Connection &&
          runtimeType == other.runtimeType &&
          a == other.a &&
          b == other.b;

  @override
  int get hashCode => a.hashCode ^ b.hashCode;
}

/// Helper class for distance calculations
class _DistancePair {
  final int index;
  final double distance;

  const _DistancePair(this.index, this.distance);
}

/// Helper class for edge representation
class _Edge {
  final int from;
  final int to;
  final double weight;

  const _Edge(this.from, this.to, this.weight);
}
