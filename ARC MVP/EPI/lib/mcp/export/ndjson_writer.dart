/// MCP NDJSON Writer
/// 
/// Handles writing MCP records to NDJSON format with proper formatting
/// and deterministic ordering for reproducible exports.

import 'dart:convert';
import 'dart:io';
import '../models/mcp_schemas.dart';

class McpNdjsonWriter {
  final Directory outputDir;
  final bool prettyPrint;

  McpNdjsonWriter({
    required this.outputDir,
    this.prettyPrint = false,
  });

  /// Write nodes to NDJSON file
  Future<File> writeNodes(List<McpNode> nodes) async {
    final file = File('${outputDir.path}/nodes.jsonl');
    final sink = file.openWrite();
    
    try {
      // Sort nodes deterministically by ID
      final sortedNodes = List<McpNode>.from(nodes)
        ..sort((a, b) => a.id.compareTo(b.id));
      
      for (final node in sortedNodes) {
        final json = node.toJson();
        final line = _formatJsonLine(json);
        sink.writeln(line);
      }
    } finally {
      await sink.close();
    }
    
    return file;
  }

  /// Write edges to NDJSON file
  Future<File> writeEdges(List<McpEdge> edges) async {
    final file = File('${outputDir.path}/edges.jsonl');
    final sink = file.openWrite();
    
    try {
      // Sort edges deterministically by source, then target
      final sortedEdges = List<McpEdge>.from(edges)
        ..sort((a, b) {
          final sourceCompare = a.source.compareTo(b.source);
          if (sourceCompare != 0) return sourceCompare;
          return a.target.compareTo(b.target);
        });
      
      for (final edge in sortedEdges) {
        final json = edge.toJson();
        final line = _formatJsonLine(json);
        sink.writeln(line);
      }
    } finally {
      await sink.close();
    }
    
    return file;
  }

  /// Write pointers to NDJSON file
  Future<File> writePointers(List<McpPointer> pointers) async {
    final file = File('${outputDir.path}/pointers.jsonl');
    final sink = file.openWrite();
    
    try {
      // Sort pointers deterministically by ID
      final sortedPointers = List<McpPointer>.from(pointers)
        ..sort((a, b) => a.id.compareTo(b.id));
      
      for (final pointer in sortedPointers) {
        final json = pointer.toJson();
        final line = _formatJsonLine(json);
        sink.writeln(line);
      }
    } finally {
      await sink.close();
    }
    
    return file;
  }

  /// Write embeddings to NDJSON file
  Future<File> writeEmbeddings(List<McpEmbedding> embeddings) async {
    final file = File('${outputDir.path}/embeddings.jsonl');
    final sink = file.openWrite();
    
    try {
      // Sort embeddings deterministically by ID
      final sortedEmbeddings = List<McpEmbedding>.from(embeddings)
        ..sort((a, b) => a.id.compareTo(b.id));
      
      for (final embedding in sortedEmbeddings) {
        final json = embedding.toJson();
        final line = _formatJsonLine(json);
        sink.writeln(line);
      }
    } finally {
      await sink.close();
    }
    
    return file;
  }

  /// Write all MCP records to NDJSON files
  Future<Map<String, File>> writeAll({
    required List<McpNode> nodes,
    required List<McpEdge> edges,
    required List<McpPointer> pointers,
    required List<McpEmbedding> embeddings,
  }) async {
    final results = <String, File>{};
    
    results['nodes'] = await writeNodes(nodes);
    results['edges'] = await writeEdges(edges);
    results['pointers'] = await writePointers(pointers);
    results['embeddings'] = await writeEmbeddings(embeddings);
    
    return results;
  }

  /// Format a JSON object as a single line for NDJSON
  String _formatJsonLine(Map<String, dynamic> json) {
    if (prettyPrint) {
      // For debugging, use pretty print
      return const JsonEncoder.withIndent('  ').convert(json);
    } else {
      // For production, use compact format
      return const JsonEncoder().convert(json);
    }
  }

  /// Read and parse NDJSON file
  static Future<List<Map<String, dynamic>>> readNdjsonFile(File file) async {
    final lines = await file.readAsLines();
    final records = <Map<String, dynamic>>[];
    
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      
      try {
        final record = jsonDecode(line) as Map<String, dynamic>;
        records.add(record);
      } catch (e) {
        throw FormatException('Invalid JSON line in NDJSON file: $line', e);
      }
    }
    
    return records;
  }

  /// Validate NDJSON file format
  static Future<bool> validateNdjsonFile(File file) async {
    try {
      await readNdjsonFile(file);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Count records in NDJSON file
  static Future<int> countRecords(File file) async {
    final records = await readNdjsonFile(file);
    return records.length;
  }
}
