import 'mira_models.dart';

/// Repository for MIRA graph data persistence and retrieval
class MiraRepo {
  // In-memory storage for now (will be replaced with Hive later)
  final Map<String, MiraNode> _nodes = {};
  final Map<String, MiraEdge> _edges = {};
  final Map<String, bool> _processedEntries = {};

  /// Initialize the repository
  Future<void> init() async {
    // In-memory storage - no initialization needed
  }

  /// Close the repository
  Future<void> close() async {
    // In-memory storage - no cleanup needed
  }

  /// Check if an entry has already been processed
  bool isEntryProcessed(String entryId) {
    return _processedEntries[entryId] ?? false;
  }

  /// Mark an entry as processed
  Future<void> markEntryProcessed(String entryId) async {
    _processedEntries[entryId] = true;
  }

  /// Upsert a node (create if not exists, update if exists)
  Future<void> upsertNode(MiraNode node) async {
    final existing = _nodes[node.id];
    if (existing != null) {
      // Update existing node
      final updated = existing.copyWith(
        label: node.label,
        updatedAt: DateTime.now(),
      );
      _nodes[node.id] = updated;
    } else {
      // Create new node
      _nodes[node.id] = node;
    }
  }

  /// Get a node by ID
  MiraNode? getNode(String id) {
    return _nodes[id];
  }

  /// Get all nodes of a specific type
  List<MiraNode> getNodesByType(MiraNodeType type) {
    return _nodes.values.where((node) => node.type == type).toList();
  }

  /// Upsert an edge (create if not exists, update if exists)
  Future<void> upsertEdge(MiraEdge edge) async {
    final key = edge.key;
    final existing = _edges[key];
    
    if (existing != null) {
      // Update existing edge by bumping frequency
      final updated = existing.bump(wConfidence: edge.wConfidence);
      _edges[key] = updated;
    } else {
      // Create new edge
      _edges[key] = edge;
    }
  }

  /// Get an edge by its key
  MiraEdge? getEdge(String key) {
    return _edges[key];
  }

  /// Get all edges of a specific kind
  List<MiraEdge> getEdgesByKind(MiraEdgeKind kind) {
    return _edges.values.where((edge) => edge.kind == kind).toList();
  }

  /// Get edges from a specific source node
  List<MiraEdge> getEdgesFromNode(String srcId) {
    return _edges.values.where((edge) => edge.srcId == srcId).toList();
  }

  /// Get edges to a specific destination node
  List<MiraEdge> getEdgesToNode(String dstId) {
    return _edges.values.where((edge) => edge.dstId == dstId).toList();
  }

  /// Get edges between two specific nodes
  List<MiraEdge> getEdgesBetweenNodes(String srcId, String dstId) {
    return _edges.values.where((edge) => 
      (edge.srcId == srcId && edge.dstId == dstId) ||
      (edge.srcId == dstId && edge.dstId == srcId)
    ).toList();
  }

  /// Get all edges (for debugging and analysis)
  List<MiraEdge> getAllEdges() {
    return _edges.values.toList();
  }

  /// Get all nodes (for debugging and analysis)
  List<MiraNode> getAllNodes() {
    return _nodes.values.toList();
  }

  /// Get edges within a time window
  List<MiraEdge> getEdgesInWindow(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    return _edges.values.where((edge) => edge.updatedAt.isAfter(cutoff)).toList();
  }

  /// Get nodes created within a time window
  List<MiraNode> getNodesInWindow(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    return _nodes.values.where((node) => node.createdAt.isAfter(cutoff)).toList();
  }

  /// Clear all data (for testing)
  Future<void> clearAll() async {
    _nodes.clear();
    _edges.clear();
    _processedEntries.clear();
  }

  /// Get statistics about the graph
  Map<String, dynamic> getStats() {
    final nodeCounts = <MiraNodeType, int>{};
    final edgeCounts = <MiraEdgeKind, int>{};
    
    for (final node in _nodes.values) {
      nodeCounts[node.type] = (nodeCounts[node.type] ?? 0) + 1;
    }
    
    for (final edge in _edges.values) {
      edgeCounts[edge.kind] = (edgeCounts[edge.kind] ?? 0) + 1;
    }
    
    return {
      'totalNodes': _nodes.length,
      'totalEdges': _edges.length,
      'processedEntries': _processedEntries.length,
      'nodeCounts': nodeCounts,
      'edgeCounts': edgeCounts,
    };
  }

  /// Get edges for co-occurrence analysis (undirected pairs)
  Map<String, MiraEdge> getCooccurrenceEdges() {
    final cooccurEdges = <String, MiraEdge>{};
    
    for (final edge in _edges.values) {
      if (edge.kind == MiraEdgeKind.cooccurs) {
        cooccurEdges[edge.key] = edge;
      }
    }
    
    return cooccurEdges;
  }

  /// Get edges for keyword mentions (Entry -> Keyword)
  List<MiraEdge> getMentionEdges() {
    return _edges.values.where((edge) => edge.kind == MiraEdgeKind.mentions).toList();
  }

  /// Get edges for phase tagging (Entry -> Phase)
  List<MiraEdge> getPhaseTagEdges() {
    return _edges.values.where((edge) => edge.kind == MiraEdgeKind.taggedAs).toList();
  }

  /// Get edges for emotion expression (Entry -> Emotion)
  List<MiraEdge> getEmotionEdges() {
    return _edges.values.where((edge) => edge.kind == MiraEdgeKind.expresses).toList();
  }

  /// Get edges for period membership (Entry -> Period)
  List<MiraEdge> getPeriodEdges() {
    return _edges.values.where((edge) => edge.kind == MiraEdgeKind.inPeriod).toList();
  }

  /// Find entries in a specific time window
  List<String> getEntriesInWindow(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    final entryNodes = _nodes.values
        .where((node) => node.type == MiraNodeType.entry && node.createdAt.isAfter(cutoff))
        .map((node) => node.id)
        .toList();
    return entryNodes;
  }

  /// Find entries tagged with a specific phase
  List<String> getEntriesByPhase(String phase) {
    final phaseId = 'phase:$phase';
    final phaseEdges = _edges.values
        .where((edge) => edge.kind == MiraEdgeKind.taggedAs && edge.dstId == phaseId)
        .map((edge) => edge.srcId)
        .toList();
    return phaseEdges;
  }

  /// Find entries tagged with a specific phase in a time window
  List<String> getEntriesByPhaseInWindow(String phase, Duration window) {
    final cutoff = DateTime.now().subtract(window);
    final phaseId = 'phase:$phase';
    
    final phaseEdges = _edges.values
        .where((edge) => edge.kind == MiraEdgeKind.taggedAs && edge.dstId == phaseId)
        .toList();
    
    // Filter by time window using the edge's updatedAt timestamp
    final recentPhaseEdges = phaseEdges
        .where((edge) => edge.updatedAt.isAfter(cutoff))
        .map((edge) => edge.srcId)
        .toList();
    
    return recentPhaseEdges;
  }
}
