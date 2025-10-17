import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

/// Analysis results for orphan nodes and duplicates in an MCP bundle
class OrphanAnalysis {
  final List<String> orphanNodes;          // Nodes with no pointer
  final List<String> orphanKeywords;       // Keywords not used by entries
  final List<DuplicateGroup> duplicateEntries;  // Entries with same content
  final List<String> duplicatePointers;    // Pointers with duplicate IDs
  final List<EdgeDuplicate> duplicateEdges;  // Edges with same signature
  final Map<String, int> stats;

  const OrphanAnalysis({
    required this.orphanNodes,
    required this.orphanKeywords,
    required this.duplicateEntries,
    required this.duplicatePointers,
    required this.duplicateEdges,
    required this.stats,
  });

  int get orphanNodeCount => orphanNodes.length;
  int get orphanKeywordCount => orphanKeywords.length;
  int get duplicateEntryCount => duplicateEntries.length;
  int get duplicatePointerCount => duplicatePointers.length;
  int get duplicateEdgeCount => duplicateEdges.length;
}

/// A group of duplicate entries with the same content
class DuplicateGroup {
  final String contentPreview;
  final List<DuplicateEntry> entries;

  const DuplicateGroup({
    required this.contentPreview,
    required this.entries,
  });
}

/// A duplicate entry within a group
class DuplicateEntry {
  final String id;
  final String timestamp;
  final String contentPreview;

  const DuplicateEntry({
    required this.id,
    required this.timestamp,
    required this.contentPreview,
  });
}

/// A duplicate edge with the same signature
class EdgeDuplicate {
  final String source;
  final String target;
  final String relation;
  final int count;

  const EdgeDuplicate({
    required this.source,
    required this.target,
    required this.relation,
    required this.count,
  });
}

/// Cleanup options for removing orphans and duplicates
class CleanupOptions {
  final bool removeOrphanNodes;
  final bool removeOrphanKeywords;
  final bool removeDuplicateEntries;
  final bool removeDuplicatePointers;
  final bool removeDuplicateEdges;

  const CleanupOptions({
    this.removeOrphanNodes = true,
    this.removeOrphanKeywords = true,
    this.removeDuplicateEntries = true,
    this.removeDuplicatePointers = true,
    this.removeDuplicateEdges = true,
  });
}

/// Result of cleanup operation
class CleanupResult {
  final int nodesRemoved;
  final int pointersRemoved;
  final int edgesRemoved;
  final int orphanNodesRemoved;
  final int orphanKeywordsRemoved;
  final int duplicateEntriesRemoved;
  final int duplicatePointersRemoved;
  final int duplicateEdgesRemoved;
  final int sizeReductionBytes;

  const CleanupResult({
    required this.nodesRemoved,
    required this.pointersRemoved,
    required this.edgesRemoved,
    required this.orphanNodesRemoved,
    required this.orphanKeywordsRemoved,
    required this.duplicateEntriesRemoved,
    required this.duplicatePointersRemoved,
    required this.duplicateEdgesRemoved,
    required this.sizeReductionBytes,
  });
}

/// Service for detecting and cleaning orphan nodes and duplicates in MCP bundles
class OrphanDetector {
  /// Analyze an MCP bundle for orphan nodes and duplicates
  static Future<OrphanAnalysis> analyzeBundle(Directory bundleDir) async {
    print('🔍 OrphanDetector: Analyzing bundle at ${bundleDir.path}');

    // Load all files
    final nodesFile = File(path.join(bundleDir.path, 'nodes.jsonl'));
    final pointersFile = File(path.join(bundleDir.path, 'pointers.jsonl'));
    final edgesFile = File(path.join(bundleDir.path, 'edges.jsonl'));

    if (!await nodesFile.exists() || !await pointersFile.exists() || !await edgesFile.exists()) {
      throw Exception('MCP bundle files not found');
    }

    // Load nodes
    final nodes = <Map<String, dynamic>>[];
    await for (final line in nodesFile.openRead().transform(utf8.decoder).transform(LineSplitter())) {
      if (line.trim().isNotEmpty) {
        nodes.add(jsonDecode(line) as Map<String, dynamic>);
      }
    }

    // Load pointers
    final pointers = <Map<String, dynamic>>[];
    await for (final line in pointersFile.openRead().transform(utf8.decoder).transform(LineSplitter())) {
      if (line.trim().isNotEmpty) {
        pointers.add(jsonDecode(line) as Map<String, dynamic>);
      }
    }

    // Load edges
    final edges = <Map<String, dynamic>>[];
    await for (final line in edgesFile.openRead().transform(utf8.decoder).transform(LineSplitter())) {
      if (line.trim().isNotEmpty) {
        edges.add(jsonDecode(line) as Map<String, dynamic>);
      }
    }

    print('🔍 OrphanDetector: Loaded ${nodes.length} nodes, ${pointers.length} pointers, ${edges.length} edges');

    // Find orphan nodes (nodes without corresponding pointers)
    final pointerNodeIds = <String>{};
    for (final pointer in pointers) {
      final miraNodeId = pointer['metadata']?['mira_node_id'] as String?;
      if (miraNodeId != null) {
        pointerNodeIds.add(miraNodeId);
      }
    }

    final orphanNodes = <String>[];
    for (final node in nodes) {
      final nodeId = node['id'] as String?;
      if (nodeId != null && !pointerNodeIds.contains(nodeId)) {
        orphanNodes.add(nodeId);
      }
    }

    // Find orphan keywords (keywords not referenced by any journal entry)
    final journalEntryIds = <String>{};
    for (final node in nodes) {
      if (node['type'] == 'journal_entry') {
        final nodeId = node['id'] as String?;
        if (nodeId != null) {
          journalEntryIds.add(nodeId);
        }
      }
    }

    final keywordUsage = <String, Set<String>>{};
    for (final edge in edges) {
      final src = edge['source'] as String?;
      final dst = edge['target'] as String?;
      if (src != null && dst != null && journalEntryIds.contains(src) && dst.startsWith('kw_')) {
        keywordUsage[dst] = (keywordUsage[dst] ?? <String>{})..add(src);
      }
    }

    final allKeywords = <String>{};
    for (final node in nodes) {
      if (node['type'] == 'keyword') {
        final nodeId = node['id'] as String?;
        if (nodeId != null) {
          allKeywords.add(nodeId);
        }
      }
    }

    final orphanKeywords = allKeywords.where((kw) => !keywordUsage.containsKey(kw)).toList();

    // Find duplicate entries (exact same content)
    final contentGroups = <String, List<Map<String, dynamic>>>{};
    for (final node in nodes) {
      if (node['type'] == 'journal_entry') {
        final content = _extractContent(node);
        if (content.isNotEmpty) {
          // Use full content hash for exact matching, not just first 100 chars
          final contentHash = _computeContentHash(content);
          contentGroups[contentHash] = (contentGroups[contentHash] ?? [])..add(node);
        }
      }
    }

    final duplicateGroups = <DuplicateGroup>[];
    for (final entry in contentGroups.entries) {
      if (entry.value.length > 1) {
        final entries = entry.value.map((node) => DuplicateEntry(
          id: node['id'] as String,
          timestamp: node['timestamp'] as String? ?? '',
          contentPreview: _extractContent(node).substring(0, 60),
        )).toList();

        // Sort by timestamp (oldest first)
        entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        duplicateGroups.add(DuplicateGroup(
          contentPreview: entry.key,
          entries: entries,
        ));
      }
    }

    // Find duplicate pointers
    final pointerIds = <String, int>{};
    for (final pointer in pointers) {
      final id = pointer['id'] as String?;
      if (id != null) {
        pointerIds[id] = (pointerIds[id] ?? 0) + 1;
      }
    }

    final duplicatePointers = pointerIds.entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .toList();

    // Find duplicate edges
    final edgeSignatures = <String, int>{};
    for (final edge in edges) {
      final src = edge['source'] as String?;
      final dst = edge['target'] as String?;
      final rel = edge['relation'] as String?;
      if (src != null && dst != null && rel != null) {
        final signature = '$src|$dst|$rel';
        edgeSignatures[signature] = (edgeSignatures[signature] ?? 0) + 1;
      }
    }

    final duplicateEdges = edgeSignatures.entries
        .where((entry) => entry.value > 1)
        .map((entry) {
          final parts = entry.key.split('|');
          return EdgeDuplicate(
            source: parts[0],
            target: parts[1],
            relation: parts[2],
            count: entry.value,
          );
        })
        .toList();

    final stats = <String, int>{
      'total_nodes': nodes.length,
      'total_pointers': pointers.length,
      'total_edges': edges.length,
      'journal_entries': journalEntryIds.length,
      'keywords': allKeywords.length,
    };

    print('🔍 OrphanDetector: Analysis complete - ${orphanNodes.length} orphan nodes, ${orphanKeywords.length} orphan keywords, ${duplicateGroups.length} duplicate groups');

    return OrphanAnalysis(
      orphanNodes: orphanNodes,
      orphanKeywords: orphanKeywords,
      duplicateEntries: duplicateGroups,
      duplicatePointers: duplicatePointers,
      duplicateEdges: duplicateEdges,
      stats: stats,
    );
  }

  /// Clean orphans and duplicates from an MCP bundle
  static Future<CleanupResult> cleanOrphansAndDuplicates(
    Directory bundleDir,
    OrphanAnalysis analysis,
    CleanupOptions options,
  ) async {
    print('🧹 OrphanDetector: Starting cleanup with options: $options');

    final originalSize = await _getDirectorySize(bundleDir);

    // Load all files
    final nodesFile = File(path.join(bundleDir.path, 'nodes.jsonl'));
    final pointersFile = File(path.join(bundleDir.path, 'pointers.jsonl'));
    final edgesFile = File(path.join(bundleDir.path, 'edges.jsonl'));

    // Load data
    final nodes = <Map<String, dynamic>>[];
    await for (final line in nodesFile.openRead().transform(utf8.decoder).transform(LineSplitter())) {
      if (line.trim().isNotEmpty) {
        nodes.add(jsonDecode(line) as Map<String, dynamic>);
      }
    }

    final pointers = <Map<String, dynamic>>[];
    await for (final line in pointersFile.openRead().transform(utf8.decoder).transform(LineSplitter())) {
      if (line.trim().isNotEmpty) {
        pointers.add(jsonDecode(line) as Map<String, dynamic>);
      }
    }

    final edges = <Map<String, dynamic>>[];
    await for (final line in edgesFile.openRead().transform(utf8.decoder).transform(LineSplitter())) {
      if (line.trim().isNotEmpty) {
        edges.add(jsonDecode(line) as Map<String, dynamic>);
      }
    }

    int nodesRemoved = 0;
    int pointersRemoved = 0;
    int edgesRemoved = 0;
    int orphanNodesRemoved = 0;
    int orphanKeywordsRemoved = 0;
    int duplicateEntriesRemoved = 0;
    int duplicatePointersRemoved = 0;
    int duplicateEdgesRemoved = 0;

    // Remove orphan nodes
    if (options.removeOrphanNodes) {
      final nodesToKeep = <Map<String, dynamic>>[];
      for (final node in nodes) {
        final nodeId = node['id'] as String?;
        if (nodeId == null || !analysis.orphanNodes.contains(nodeId)) {
          nodesToKeep.add(node);
        } else {
          nodesRemoved++;
          orphanNodesRemoved++;
          print('🧹 Removed orphan node: $nodeId');
        }
      }
      nodes.clear();
      nodes.addAll(nodesToKeep);
    }

    // Remove orphan keywords
    if (options.removeOrphanKeywords) {
      final nodesToKeep = <Map<String, dynamic>>[];
      for (final node in nodes) {
        final nodeId = node['id'] as String?;
        if (nodeId == null || !analysis.orphanKeywords.contains(nodeId)) {
          nodesToKeep.add(node);
        } else {
          nodesRemoved++;
          orphanKeywordsRemoved++;
          print('🧹 Removed orphan keyword: $nodeId');
        }
      }
      nodes.clear();
      nodes.addAll(nodesToKeep);
    }

    // Remove duplicate entries (keep oldest)
    if (options.removeDuplicateEntries) {
      final nodesToKeep = <Map<String, dynamic>>[];
      final duplicateEntryIdsToRemove = <String>{};

      // Collect IDs of duplicate entries to remove (all except the first in each group)
      for (final group in analysis.duplicateEntries) {
        // Keep the first entry (oldest by timestamp), remove the rest
        for (int i = 1; i < group.entries.length; i++) {
          duplicateEntryIdsToRemove.add(group.entries[i].id);
          duplicateEntriesRemoved++;
          print('🧹 Marked duplicate entry for removal: ${group.entries[i].id}');
        }
      }

      // Keep all nodes except the marked duplicates
      for (final node in nodes) {
        final nodeId = node['id'] as String?;
        if (nodeId == null || !duplicateEntryIdsToRemove.contains(nodeId)) {
          // Keep all nodes that are not marked for removal
          nodesToKeep.add(node);
        } else {
          // Remove only the marked duplicate entries
          nodesRemoved++;
          print('🧹 Removed duplicate entry: $nodeId');
        }
      }
      nodes.clear();
      nodes.addAll(nodesToKeep);
    }

    // Remove duplicate pointers
    if (options.removeDuplicatePointers) {
      final pointersToKeep = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      for (final pointer in pointers) {
        final id = pointer['id'] as String?;
        if (id == null || seenIds.add(id)) {
          pointersToKeep.add(pointer);
        } else {
          pointersRemoved++;
          duplicatePointersRemoved++;
          print('🧹 Removed duplicate pointer: $id');
        }
      }
      pointers.clear();
      pointers.addAll(pointersToKeep);
    }

    // Remove duplicate edges
    if (options.removeDuplicateEdges) {
      final edgesToKeep = <Map<String, dynamic>>[];
      final seenSignatures = <String>{};

      for (final edge in edges) {
        final src = edge['source'] as String?;
        final dst = edge['target'] as String?;
        final rel = edge['relation'] as String?;
        if (src != null && dst != null && rel != null) {
          final signature = '$src|$dst|$rel';
          if (seenSignatures.add(signature)) {
            edgesToKeep.add(edge);
          } else {
            edgesRemoved++;
            duplicateEdgesRemoved++;
            print('🧹 Removed duplicate edge: $src -> $dst');
          }
        } else {
          edgesToKeep.add(edge);
        }
      }
      edges.clear();
      edges.addAll(edgesToKeep);
    }

    // Write cleaned files
    await _writeJsonlFile(nodesFile, nodes);
    await _writeJsonlFile(pointersFile, pointers);
    await _writeJsonlFile(edgesFile, edges);

    final newSize = await _getDirectorySize(bundleDir);
    final sizeReductionBytes = originalSize - newSize;

    print('🧹 OrphanDetector: Cleanup complete - removed $nodesRemoved nodes, $pointersRemoved pointers, $edgesRemoved edges');
    print('🧹 Size reduction: ${(sizeReductionBytes / originalSize * 100).toStringAsFixed(1)}%');

    return CleanupResult(
      nodesRemoved: nodesRemoved,
      pointersRemoved: pointersRemoved,
      edgesRemoved: edgesRemoved,
      orphanNodesRemoved: orphanNodesRemoved,
      orphanKeywordsRemoved: orphanKeywordsRemoved,
      duplicateEntriesRemoved: duplicateEntriesRemoved,
      duplicatePointersRemoved: duplicatePointersRemoved,
      duplicateEdgesRemoved: duplicateEdgesRemoved,
      sizeReductionBytes: sizeReductionBytes,
    );
  }

  /// Extract content from a journal entry node
  static String _extractContent(Map<String, dynamic> node) {
    // Try different content fields
    final metadata = node['metadata'] as Map<String, dynamic>?;
    if (metadata != null) {
      final text = metadata['text'] as String?;
      if (text != null && text.isNotEmpty) return text;
    }

    final content = node['content'] as Map<String, dynamic>?;
    if (content != null) {
      final narrative = content['narrative'] as String?;
      if (narrative != null && narrative.isNotEmpty) return narrative;
    }

    return '';
  }

  /// Get total size of directory in bytes
  static Future<int> _getDirectorySize(Directory dir) async {
    int totalSize = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  /// Write list of maps to JSONL file
  static Future<void> _writeJsonlFile(File file, List<Map<String, dynamic>> data) async {
    final sink = file.openWrite();
    for (final item in data) {
      sink.writeln(jsonEncode(item));
    }
    await sink.close();
  }

  /// Compute a hash of the content for exact duplicate detection
  static String _computeContentHash(String content) {
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
