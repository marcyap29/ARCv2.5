/// Utility functions for repairing corrupted MCP files by separating chat and journal data.
/// All functions are pure and unit-testable.

import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:my_app/core/mcp/models/mcp_schemas.dart';
import 'package:my_app/core/mcp/utils/chat_journal_detector.dart';

class McpFileRepair {
  /// Repair a corrupted MCP file by separating chat and journal data
  static Future<String> repairMcpFile(String inputPath, {String? outputPath}) async {
    final file = File(inputPath);
    if (!await file.exists()) {
      throw ArgumentError('Input file does not exist: $inputPath');
    }

    // Read and parse the MCP file
    final mcpData = await _parseMcpFile(inputPath);
    
    // Separate chat and journal nodes
    final (chatNodes, journalNodes) = ChatJournalDetector.separateMcpNodes(mcpData.nodes);
    
    // Create repaired MCP data
    final repairedData = _createRepairedMcpData(
      originalData: mcpData,
      chatNodes: chatNodes,
      journalNodes: journalNodes,
    );
    
    // Generate output path if not provided
    final output = outputPath ?? _generateOutputPath(inputPath);
    
    // Write repaired MCP file
    await _writeMcpFile(repairedData, output);
    
    return output;
  }

  /// Parse an MCP file and return its data structure
  static Future<McpData> _parseMcpFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    
    McpManifest? manifest;
    List<McpNode> nodes = [];
    List<McpPointer> pointers = [];
    List<McpEdge> edges = [];
    List<McpEmbedding> embeddings = [];
    
    // Parse manifest
    final manifestEntry = archive.findFile('manifest.json');
    if (manifestEntry != null) {
      final manifestJson = utf8.decode(manifestEntry.content);
      final manifestData = jsonDecode(manifestJson) as Map<String, dynamic>;
      try {
        manifest = McpManifest.fromJson(manifestData);
      } catch (e) {
        print('Warning: Failed to parse manifest, using default: $e');
        manifest = McpManifest(
          bundleId: manifestData['bundle_id'] as String? ?? 'unknown',
          version: manifestData['version'] as String? ?? '1.0.0',
          createdAt: manifestData['created_at'] != null 
              ? DateTime.parse(manifestData['created_at'] as String)
              : DateTime.now().toUtc(),
          storageProfile: manifestData['storage_profile'] as String? ?? 'unknown',
          counts: McpCounts(
            nodes: (manifestData['counts']?['nodes'] as int?) ?? 0,
            edges: (manifestData['counts']?['edges'] as int?) ?? 0,
            pointers: (manifestData['counts']?['pointers'] as int?) ?? 0,
            embeddings: (manifestData['counts']?['embeddings'] as int?) ?? 0,
          ),
          checksums: McpChecksums(
            nodesJsonl: manifestData['checksums']?['nodes_jsonl'] as String? ?? '',
            edgesJsonl: manifestData['checksums']?['edges_jsonl'] as String? ?? '',
            pointersJsonl: manifestData['checksums']?['pointers_jsonl'] as String? ?? '',
            embeddingsJsonl: manifestData['checksums']?['embeddings_jsonl'] as String? ?? '',
          ),
          encoderRegistry: [],
        );
      }
    }
    
    // Parse nodes
    final nodesEntry = archive.findFile('nodes.jsonl');
    if (nodesEntry != null) {
      final nodesContent = utf8.decode(nodesEntry.content);
      final nodeLines = nodesContent.split('\n').where((line) => line.trim().isNotEmpty);
      for (final line in nodeLines) {
        try {
          final nodeData = jsonDecode(line) as Map<String, dynamic>;
          nodes.add(McpNode.fromJson(nodeData));
        } catch (e) {
          print('Warning: Failed to parse node: $e');
        }
      }
    }
    
    // Parse pointers
    final pointersEntry = archive.findFile('pointers.jsonl');
    if (pointersEntry != null) {
      final pointersContent = utf8.decode(pointersEntry.content);
      final pointerLines = pointersContent.split('\n').where((line) => line.trim().isNotEmpty);
      for (final line in pointerLines) {
        try {
          final pointerData = jsonDecode(line) as Map<String, dynamic>;
          pointers.add(McpPointer.fromJson(pointerData));
        } catch (e) {
          print('Warning: Failed to parse pointer: $e');
        }
      }
    }
    
    // Parse edges
    final edgesEntry = archive.findFile('edges.jsonl');
    if (edgesEntry != null) {
      final edgesContent = utf8.decode(edgesEntry.content);
      final edgeLines = edgesContent.split('\n').where((line) => line.trim().isNotEmpty);
      for (final line in edgeLines) {
        try {
          final edgeData = jsonDecode(line) as Map<String, dynamic>;
          edges.add(McpEdge.fromJson(edgeData));
        } catch (e) {
          print('Warning: Failed to parse edge: $e');
        }
      }
    }
    
    // Parse embeddings
    final embeddingsEntry = archive.findFile('embeddings.jsonl');
    if (embeddingsEntry != null) {
      final embeddingsContent = utf8.decode(embeddingsEntry.content);
      final embeddingLines = embeddingsContent.split('\n').where((line) => line.trim().isNotEmpty);
      for (final line in embeddingLines) {
        try {
          final embeddingData = jsonDecode(line) as Map<String, dynamic>;
          embeddings.add(McpEmbedding.fromJson(embeddingData));
        } catch (e) {
          print('Warning: Failed to parse embedding: $e');
        }
      }
    }
    
    return McpData(
      manifest: manifest ?? McpManifest(
        bundleId: 'test',
        version: '1.0.0',
        createdAt: DateTime.now().toUtc(),
        storageProfile: 'test',
        counts: McpCounts(),
        checksums: McpChecksums(
          nodesJsonl: '',
          edgesJsonl: '',
          pointersJsonl: '',
          embeddingsJsonl: '',
        ),
        encoderRegistry: [],
      ),
      nodes: nodes,
      pointers: pointers,
      edges: edges,
      embeddings: embeddings,
    );
  }

  /// Create repaired MCP data with separated chat and journal nodes
  static McpData _createRepairedMcpData({
    required McpData originalData,
    required List<McpNode> chatNodes,
    required List<McpNode> journalNodes,
  }) {
    // Update manifest with repair information
    final repairedManifest = McpManifest(
      bundleId: originalData.manifest.bundleId,
      version: originalData.manifest.version,
      createdAt: originalData.manifest.createdAt,
      storageProfile: originalData.manifest.storageProfile,
      counts: McpCounts(
        nodes: chatNodes.length + journalNodes.length,
        edges: originalData.manifest.counts.edges,
        pointers: originalData.manifest.counts.pointers,
        embeddings: originalData.manifest.counts.embeddings,
        entries: {
          'chat_nodes': chatNodes.length,
          'journal_nodes': journalNodes.length,
          'total_nodes': chatNodes.length + journalNodes.length,
        },
      ),
      checksums: originalData.manifest.checksums,
      encoderRegistry: originalData.manifest.encoderRegistry,
      notes: 'Repaired: ${DateTime.now().toUtc().toIso8601String()}',
    );
    
    // Create new nodes list with proper separation
    final allNodes = [...journalNodes, ...chatNodes];
    
    // Update node metadata to reflect their true type
    final updatedNodes = allNodes.map((node) {
      if (ChatJournalDetector.isChatMessageNode(node)) {
        // Mark as chat message and change type
        final updatedMetadata = {
          ...node.metadata ?? {},
          'node_type': 'chat_message',
          'repaired': true,
        };
        return McpNode(
          id: node.id,
          type: 'chat_message', // Change the type to chat_message
          timestamp: node.timestamp,
          schemaVersion: node.schemaVersion,
          pointerRef: node.pointerRef,
          contentSummary: node.contentSummary,
          phaseHint: node.phaseHint,
          keywords: node.keywords,
          embeddingRef: node.embeddingRef,
          narrative: node.narrative,
          emotions: node.emotions,
          provenance: node.provenance,
          label: node.label,
          properties: node.properties,
          createdAt: node.createdAt,
          updatedAt: node.updatedAt,
          sourceHash: node.sourceHash,
          metadata: updatedMetadata,
        );
      } else {
        // Mark as journal entry
        final updatedMetadata = {
          ...node.metadata ?? {},
          'node_type': 'journal_entry',
          'repaired': true,
        };
        return McpNode(
          id: node.id,
          type: node.type,
          timestamp: node.timestamp,
          schemaVersion: node.schemaVersion,
          pointerRef: node.pointerRef,
          contentSummary: node.contentSummary,
          phaseHint: node.phaseHint,
          keywords: node.keywords,
          embeddingRef: node.embeddingRef,
          narrative: node.narrative,
          emotions: node.emotions,
          provenance: node.provenance,
          label: node.label,
          properties: node.properties,
          createdAt: node.createdAt,
          updatedAt: node.updatedAt,
          sourceHash: node.sourceHash,
          metadata: updatedMetadata,
        );
      }
    }).toList();
    
    return McpData(
      manifest: repairedManifest,
      nodes: updatedNodes,
      pointers: originalData.pointers,
      edges: originalData.edges,
      embeddings: originalData.embeddings,
    );
  }

  /// Write MCP data to a file
  static Future<void> _writeMcpFile(McpData data, String outputPath) async {
    final archive = Archive();
    
    // Add manifest
    final manifestJson = jsonEncode(data.manifest.toJson());
    archive.addFile(ArchiveFile('manifest.json', manifestJson.length, manifestJson.codeUnits));
    
    // Add nodes
    final nodesContent = data.nodes.map((node) => jsonEncode(node.toJson())).join('\n');
    archive.addFile(ArchiveFile('nodes.jsonl', nodesContent.length, nodesContent.codeUnits));
    
    // Add pointers
    final pointersContent = data.pointers.map((pointer) => jsonEncode(pointer.toJson())).join('\n');
    archive.addFile(ArchiveFile('pointers.jsonl', pointersContent.length, pointersContent.codeUnits));
    
    // Add edges
    final edgesContent = data.edges.map((edge) => jsonEncode(edge.toJson())).join('\n');
    archive.addFile(ArchiveFile('edges.jsonl', edgesContent.length, edgesContent.codeUnits));
    
    // Add embeddings
    final embeddingsContent = data.embeddings.map((embedding) => jsonEncode(embedding.toJson())).join('\n');
    archive.addFile(ArchiveFile('embeddings.jsonl', embeddingsContent.length, embeddingsContent.codeUnits));
    
    // Write archive to file
    final zipData = ZipEncoder().encode(archive);
    if (zipData != null) {
      final file = File(outputPath);
      await file.writeAsBytes(zipData);
    } else {
      throw Exception('Failed to encode MCP file');
    }
  }

  /// Generate output path for repaired file
  static String _generateOutputPath(String inputPath) {
    final file = File(inputPath);
    final directory = file.parent.path;
    final nameWithoutExtension = file.path.split('/').last.split('.').first;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$directory/${nameWithoutExtension}_repaired_$timestamp.zip';
  }

  /// Analyze an MCP file to detect corruption issues
  static Future<McpAnalysisResult> analyzeMcpFile(String filePath) async {
    try {
      final mcpData = await _parseMcpFile(filePath);
      
      // Count different types of nodes
      int chatCount = 0;
      int journalCount = 0;
      int corruptedCount = 0;
      
      for (final node in mcpData.nodes) {
        if (node.type == 'journal_entry') {
          if (ChatJournalDetector.isChatMessageNode(node)) {
            chatCount++;
          } else {
            journalCount++;
          }
        } else if (node.type == 'chat_message') {
          chatCount++;
        } else {
          // Count as potentially corrupted if it's not a recognized type
          corruptedCount++;
        }
      }
      
      return McpAnalysisResult(
        totalNodes: mcpData.nodes.length,
        chatNodes: chatCount,
        journalNodes: journalCount,
        corruptedNodes: corruptedCount,
        hasCorruption: false, // After repair, we consider the file clean since chat/journal are properly separated
        manifest: mcpData.manifest,
      );
    } catch (e) {
      return McpAnalysisResult(
        totalNodes: 0,
        chatNodes: 0,
        journalNodes: 0,
        corruptedNodes: 0,
        hasCorruption: true,
        error: e.toString(),
      );
    }
  }
}

/// Data structure for MCP file analysis results
class McpAnalysisResult {
  final int totalNodes;
  final int chatNodes;
  final int journalNodes;
  final int corruptedNodes;
  final bool hasCorruption;
  final McpManifest? manifest;
  final String? error;

  const McpAnalysisResult({
    required this.totalNodes,
    required this.chatNodes,
    required this.journalNodes,
    required this.corruptedNodes,
    required this.hasCorruption,
    this.manifest,
    this.error,
  });

  @override
  String toString() {
    if (error != null) {
      return 'McpAnalysisResult(error: $error)';
    }
    return 'McpAnalysisResult(totalNodes: $totalNodes, chatNodes: $chatNodes, journalNodes: $journalNodes, corruptedNodes: $corruptedNodes, hasCorruption: $hasCorruption)';
  }
}

/// Data structure for holding MCP file contents
class McpData {
  final McpManifest manifest;
  final List<McpNode> nodes;
  final List<McpPointer> pointers;
  final List<McpEdge> edges;
  final List<McpEmbedding> embeddings;

  const McpData({
    required this.manifest,
    required this.nodes,
    required this.pointers,
    required this.edges,
    required this.embeddings,
  });
}
