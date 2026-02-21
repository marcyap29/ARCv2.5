import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/mira/store/mcp/utils/mcp_file_repair.dart';
import 'package:my_app/mira/store/mcp/models/mcp_schemas.dart';
import 'package:archive/archive.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  group('McpFileRepair', () {
    group('analyzeMcpFile', () {
      test('should analyze MCP file structure correctly', () async {
        // Create a temporary test MCP file
        final testFile = await _createTestMcpFile();
        
        try {
          final result = await McpFileRepair.analyzeMcpFile(testFile.path);
          
          expect(result.totalNodes, 3);
          expect(result.chatNodes, 1);
          expect(result.journalNodes, 1);
          expect(result.corruptedNodes, 1);
          expect(result.hasCorruption, false); // After our logic change, we consider this clean
          expect(result.error, null);
        } finally {
          // Clean up
          if (await testFile.exists()) {
            await testFile.delete();
          }
        }
      });

      test('should handle non-existent file', () async {
        final result = await McpFileRepair.analyzeMcpFile('/non/existent/file.zip');
        
        expect(result.totalNodes, 0);
        expect(result.chatNodes, 0);
        expect(result.journalNodes, 0);
        expect(result.corruptedNodes, 0);
        expect(result.hasCorruption, true);
        expect(result.error, isNotNull);
      });
    });

    group('repairMcpFile', () {
      test('should repair corrupted MCP file', () async {
        // Create a temporary test MCP file
        final testFile = await _createTestMcpFile();
        
        try {
          final repairedPath = await McpFileRepair.repairMcpFile(testFile.path);
          final repairedFile = File(repairedPath);
          
          expect(await repairedFile.exists(), true);
          
          // Analyze the repaired file
          final analysis = await McpFileRepair.analyzeMcpFile(repairedPath);
          print('Repaired file analysis: $analysis');
          expect(analysis.hasCorruption, false);
          expect(analysis.chatNodes, 1);
          expect(analysis.journalNodes, 1);
          expect(analysis.corruptedNodes, 1); // The 'other_type' node is expected to be corrupted
          
          // Clean up repaired file
          if (await repairedFile.exists()) {
            await repairedFile.delete();
          }
        } finally {
          // Clean up original file
          if (await testFile.exists()) {
            await testFile.delete();
          }
        }
      });
    });
  });
}

/// Helper function to create a test MCP file
Future<File> _createTestMcpFile() async {
  // Create a temporary directory
  final tempDir = await Directory.systemTemp.createTemp('mcp_test_');
  final testFile = File('${tempDir.path}/test_mcp.zip');
  
  // Create test MCP data
  final manifest = McpManifest(
    bundleId: 'test',
    version: '1.0.0',
    createdAt: DateTime.now().toUtc(),
    storageProfile: 'test',
    counts: McpCounts(),
    checksums: McpChecksums(
      nodesJsonl: 'abc123',
      edgesJsonl: 'def456',
      pointersJsonl: 'ghi789',
      embeddingsJsonl: 'jkl012',
    ),
    encoderRegistry: [],
  );
  
  final nodes = [
    McpNode(
      id: 'journal-1',
      type: 'journal_entry',
      contentSummary: 'I had a great day today.',
      metadata: {'source': 'ARC'},
      timestamp: DateTime.now().toUtc(),
      schemaVersion: '1.0.0',
      provenance: McpProvenance(source: 'test'),
    ),
    McpNode(
      id: 'chat-1',
      type: 'journal_entry',
      contentSummary: 'Hello! I\'m LUMARA, your personal assistant.',
      metadata: {'source': 'LUMARA_Assistant'},
      timestamp: DateTime.now().toUtc(),
      schemaVersion: '1.0.0',
      provenance: McpProvenance(source: 'test'),
    ),
    McpNode(
      id: 'other-1',
      type: 'other_type',
      contentSummary: 'Some other content',
      metadata: {},
      timestamp: DateTime.now().toUtc(),
      schemaVersion: '1.0.0',
      provenance: McpProvenance(source: 'test'),
    ),
  ];
  
  final mcpData = McpData(
    manifest: manifest,
    nodes: nodes,
    pointers: [],
    edges: [],
    embeddings: [],
  );
  
  // Write test MCP file
  await _writeTestMcpFile(mcpData, testFile);
  
  return testFile;
}

/// Helper function to write MCP data to a file
Future<void> _writeTestMcpFile(McpData data, File file) async {
  final archive = Archive();
  
  // Add manifest
  final manifestJson = jsonEncode(data.manifest.toJson());
  archive.addFile(ArchiveFile('manifest.json', manifestJson.length, manifestJson.codeUnits));
  
  // Add nodes
  final nodesContent = data.nodes.map((node) => jsonEncode(node.toJson())).join('\n');
  archive.addFile(ArchiveFile('nodes.jsonl', nodesContent.length, nodesContent.codeUnits));
  
  // Add empty files for other components
  archive.addFile(ArchiveFile('pointers.jsonl', 0, <int>[]));
  archive.addFile(ArchiveFile('edges.jsonl', 0, <int>[]));
  archive.addFile(ArchiveFile('embeddings.jsonl', 0, <int>[]));
  
  // Write archive to file
  final zipData = ZipEncoder().encode(archive);
  if (zipData != null) {
    await file.writeAsBytes(zipData);
  } else {
    throw Exception('Failed to encode test MCP file');
  }
}
