/// MCP Exporter Golden Tests
/// 
/// Comprehensive test suite for MCP export functionality including
/// golden tests, schema validation, and determinism checks.
library;

import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/mcp/export/mcp_export_service.dart';
import 'package:my_app/mcp/models/mcp_schemas.dart';
import 'package:my_app/mcp/validation/mcp_validator.dart';
import 'package:my_app/mcp/export/ndjson_writer.dart';
import 'package:my_app/mcp/export/manifest_builder.dart';
import 'package:my_app/mcp/export/checksum_utils.dart';

void main() {
  group('MCP Exporter Golden Tests', () {
    late Directory tempDir;
    late McpExportService exportService;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('mcp_test_');
    });

    tearDownAll(() async {
      await tempDir.delete(recursive: true);
    });

    setUp(() {
      exportService = McpExportService(
        bundleId: 'test_bundle_001',
        storageProfile: McpStorageProfile.balanced,
        notes: 'Golden test export',
      );
    });

    test('Golden Minimal Bundle', () async {
      // Create minimal test data
      final journalEntries = [
        JournalEntry(
          id: 'entry_2025_09_10_01',
          content: 'This is a test journal entry for MCP export.',
          createdAt: DateTime(2025, 9, 10, 20, 0, 0),
          tags: {'test', 'mcp'},
          userId: 'test_user',
          metadata: {'phase': 'Discovery'},
        ),
      ];

      final mediaFiles = <MediaFile>[];

      // Export to MCP
      final result = await exportService.exportToMcp(
        outputDir: tempDir,
        scope: McpExportScope.all,
        journalEntries: journalEntries,
        mediaFiles: mediaFiles,
      );

      expect(result.success, isTrue);
      expect(result.bundleId, equals('test_bundle_001'));
      expect(result.counts, isNotNull);
      expect(result.counts!.nodes, equals(1));
      expect(result.counts!.edges, equals(0));
      expect(result.counts!.pointers, equals(0));
      expect(result.counts!.embeddings, equals(1));

      // Verify files exist
      expect(await File('${tempDir.path}/manifest.json').exists(), isTrue);
      expect(await File('${tempDir.path}/nodes.jsonl').exists(), isTrue);
      expect(await File('${tempDir.path}/edges.jsonl').exists(), isTrue);
      expect(await File('${tempDir.path}/pointers.jsonl').exists(), isTrue);
      expect(await File('${tempDir.path}/embeddings.jsonl').exists(), isTrue);

      // Verify manifest structure
      final manifestFile = File('${tempDir.path}/manifest.json');
      final manifestContent = await manifestFile.readAsString();
      final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;

      expect(manifest['bundle_id'], equals('test_bundle_001'));
      expect(manifest['version'], equals('1.0.0'));
      expect(manifest['storage_profile'], equals('balanced'));
      expect(manifest['schema_version'], equals('manifest.v1'));

      // Verify counts in manifest
      final counts = manifest['counts'] as Map<String, dynamic>;
      expect(counts['nodes'], equals(1));
      expect(counts['edges'], equals(0));
      expect(counts['pointers'], equals(0));
      expect(counts['embeddings'], equals(1));

      // Verify checksums exist
      final checksums = manifest['checksums'] as Map<String, dynamic>;
      expect(checksums['nodes_jsonl'], isA<String>());
      expect(checksums['edges_jsonl'], isA<String>());
      expect(checksums['pointers_jsonl'], isA<String>());
      expect(checksums['embeddings_jsonl'], isA<String>());

      // Verify encoder registry
      final encoderRegistry = manifest['encoder_registry'] as List<dynamic>;
      expect(encoderRegistry.length, equals(1));
      final encoder = encoderRegistry.first as Map<String, dynamic>;
      expect(encoder['model_id'], equals('qwen-2.5-1.5b'));
      expect(encoder['embedding_version'], equals('1.0.0'));
      expect(encoder['dim'], equals(384));
    });

    test('Schema Conformance', () async {
      // Create test data
      final journalEntries = [
        JournalEntry(
          id: 'entry_001',
          content: 'Test content for schema validation.',
          createdAt: DateTime.now(),
          tags: {'test'},
          userId: 'user_001',
        ),
      ];

      // Export to MCP
      final result = await exportService.exportToMcp(
        outputDir: tempDir,
        scope: McpExportScope.all,
        journalEntries: journalEntries,
        mediaFiles: [],
      );

      expect(result.success, isTrue);

      // Validate each NDJSON file
      final ndjsonFiles = {
        'nodes': File('${tempDir.path}/nodes.jsonl'),
        'edges': File('${tempDir.path}/edges.jsonl'),
        'pointers': File('${tempDir.path}/pointers.jsonl'),
        'embeddings': File('${tempDir.path}/embeddings.jsonl'),
      };

      for (final entry in ndjsonFiles.entries) {
        final isValid = await McpNdjsonWriter.validateNdjsonFile(entry.value);
        expect(isValid, isTrue, reason: '${entry.key}.jsonl should be valid NDJSON');
      }

      // Validate manifest
      final manifestFile = File('${tempDir.path}/manifest.json');
      final manifestValid = await McpManifestBuilder.validateManifest(manifestFile);
      expect(manifestValid, isTrue, reason: 'manifest.json should be valid');
    });

    test('Determinism', () async {
      // Create test data
      final journalEntries = [
        JournalEntry(
          id: 'entry_001',
          content: 'Deterministic test content.',
          createdAt: DateTime(2025, 9, 10, 12, 0, 0),
          tags: {'test', 'deterministic'},
          userId: 'user_001',
        ),
        JournalEntry(
          id: 'entry_002',
          content: 'Another deterministic test entry.',
          createdAt: DateTime(2025, 9, 10, 13, 0, 0),
          tags: {'test', 'deterministic'},
          userId: 'user_001',
        ),
      ];

      // Export twice with same data
      final dir1 = Directory('${tempDir.path}/export1');
      final dir2 = Directory('${tempDir.path}/export2');

      final result1 = await exportService.exportToMcp(
        outputDir: dir1,
        scope: McpExportScope.all,
        journalEntries: journalEntries,
        mediaFiles: [],
      );

      final result2 = await exportService.exportToMcp(
        outputDir: dir2,
        scope: McpExportScope.all,
        journalEntries: journalEntries,
        mediaFiles: [],
      );

      expect(result1.success, isTrue);
      expect(result2.success, isTrue);

      // Compare file checksums
      final files = ['manifest.json', 'nodes.jsonl', 'edges.jsonl', 'pointers.jsonl', 'embeddings.jsonl'];
      
      for (final filename in files) {
        final file1 = File('${dir1.path}/$filename');
        final file2 = File('${dir2.path}/$filename');
        
        final checksum1 = McpChecksumUtils.computeFileChecksum(file1);
        final checksum2 = McpChecksumUtils.computeFileChecksum(file2);
        
        expect(checksum1, equals(checksum2), reason: '$filename should be identical between exports');
      }

      // Clean up
      await dir1.delete(recursive: true);
      await dir2.delete(recursive: true);
    });

    test('Raw Link Failure', () async {
      // Create test data with media files that have invalid URIs
      final journalEntries = [
        JournalEntry(
          id: 'entry_001',
          content: 'Test with media reference.',
          createdAt: DateTime.now(),
          tags: {'test'},
          userId: 'user_001',
        ),
      ];

      final mediaFiles = [
        MediaFile(
          id: 'media_001',
          type: 'image',
          uri: 'file:///nonexistent/path/image.jpg', // Invalid URI
          filename: 'image.jpg',
          mimeType: 'image/jpeg',
          createdAt: DateTime.now(),
          userId: 'user_001',
          tags: {'test'},
          file: File('/nonexistent/path/image.jpg'),
        ),
      ];

      // Export should succeed even with invalid source URIs
      final result = await exportService.exportToMcp(
        outputDir: tempDir,
        scope: McpExportScope.all,
        journalEntries: journalEntries,
        mediaFiles: mediaFiles,
      );

      expect(result.success, isTrue);
      expect(result.counts!.pointers, equals(1));

      // Verify pointer has CAS URI as alternative
      final pointersFile = File('${tempDir.path}/pointers.jsonl');
      final pointersContent = await pointersFile.readAsString();
      final pointerLines = pointersContent.split('\n').where((line) => line.isNotEmpty);
      
      expect(pointerLines.length, equals(1));
      
      final pointerJson = jsonDecode(pointerLines.first) as Map<String, dynamic>;
      expect(pointerJson['alt_uris'], isA<List>());
      expect(pointerJson['alt_uris'].length, greaterThan(0));
      
      // Verify CAS URI format
      final casUri = pointerJson['alt_uris'].first as String;
      expect(casUri.startsWith('cas://sha256/'), isTrue);
      expect(casUri.length, equals('cas://sha256/'.length + 64));
    });

    test('Privacy Propagation', () async {
      // Create test data with privacy-sensitive content
      final journalEntries = [
        JournalEntry(
          id: 'entry_001',
          content: 'This entry contains personal information about John Doe.',
          createdAt: DateTime.now(),
          tags: {'personal', 'pii'},
          userId: 'user_001',
        ),
      ];

      final mediaFiles = [
        MediaFile(
          id: 'media_001',
          type: 'image',
          uri: 'file:///path/to/photo.jpg',
          filename: 'photo.jpg',
          mimeType: 'image/jpeg',
          createdAt: DateTime.now(),
          userId: 'user_001',
          tags: {'photo', 'faces'},
          file: File('/path/to/photo.jpg'),
        ),
      ];

      // Export to MCP
      final result = await exportService.exportToMcp(
        outputDir: tempDir,
        scope: McpExportScope.all,
        journalEntries: journalEntries,
        mediaFiles: mediaFiles,
      );

      expect(result.success, isTrue);

      // Verify privacy fields are set on pointers
      final pointersFile = File('${tempDir.path}/pointers.jsonl');
      final pointersContent = await pointersFile.readAsString();
      final pointerLines = pointersContent.split('\n').where((line) => line.isNotEmpty);
      
      expect(pointerLines.length, equals(1));
      
      final pointerJson = jsonDecode(pointerLines.first) as Map<String, dynamic>;
      final privacy = pointerJson['privacy'] as Map<String, dynamic>;
      
      // Verify privacy fields are present
      expect(privacy['contains_pii'], isA<bool>());
      expect(privacy['faces_detected'], isA<bool>());
      expect(privacy['sharing_policy'], isA<String>());
    });

    test('Encoder Registry', () async {
      // Create test data
      final journalEntries = [
        JournalEntry(
          id: 'entry_001',
          content: 'Test content for encoder registry.',
          createdAt: DateTime.now(),
          tags: {'test'},
          userId: 'user_001',
        ),
      ];

      // Export to MCP
      final result = await exportService.exportToMcp(
        outputDir: tempDir,
        scope: McpExportScope.all,
        journalEntries: journalEntries,
        mediaFiles: [],
      );

      expect(result.success, isTrue);
      expect(result.encoderRegistry, isNotNull);
      expect(result.encoderRegistry!.length, equals(1));

      final encoder = result.encoderRegistry!.first;
      expect(encoder.modelId, equals('qwen-2.5-1.5b'));
      expect(encoder.embeddingVersion, equals('1.0.0'));
      expect(encoder.dim, equals(384));

      // Verify encoder registry in manifest
      final manifestFile = File('${tempDir.path}/manifest.json');
      final manifestContent = await manifestFile.readAsString();
      final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;
      
      final encoderRegistry = manifest['encoder_registry'] as List<dynamic>;
      expect(encoderRegistry.length, equals(1));
      
      final manifestEncoder = encoderRegistry.first as Map<String, dynamic>;
      expect(manifestEncoder['model_id'], equals('qwen-2.5-1.5b'));
      expect(manifestEncoder['embedding_version'], equals('1.0.0'));
      expect(manifestEncoder['dim'], equals(384));
    });

    test('SAGE to Node Mapping', () async {
      // Create test data with SAGE-like content
      final journalEntries = [
        JournalEntry(
          id: 'entry_001',
          content: 'Situation: I was working on a difficult problem. Action: I decided to take a break and think about it differently. Growth: I realized that stepping back often helps me see the bigger picture. Essence: Patience and perspective are key to problem-solving.',
          createdAt: DateTime.now(),
          tags: {'sage', 'reflection'},
          userId: 'user_001',
        ),
      ];

      // Export to MCP
      final result = await exportService.exportToMcp(
        outputDir: tempDir,
        scope: McpExportScope.all,
        journalEntries: journalEntries,
        mediaFiles: [],
      );

      expect(result.success, isTrue);

      // Verify SAGE mapping in nodes
      final nodesFile = File('${tempDir.path}/nodes.jsonl');
      final nodesContent = await nodesFile.readAsString();
      final nodeLines = nodesContent.split('\n').where((line) => line.isNotEmpty);
      
      expect(nodeLines.length, equals(1));
      
      final nodeJson = jsonDecode(nodeLines.first) as Map<String, dynamic>;
      expect(nodeJson['narrative'], isA<Map<String, dynamic>>());
      
      final narrative = nodeJson['narrative'] as Map<String, dynamic>;
      expect(narrative['situation'], isA<String>());
      expect(narrative['action'], isA<String>());
      expect(narrative['growth'], isA<String>());
      expect(narrative['essence'], isA<String>());
    });

    test('Storage Profile Impact', () async {
      // Test different storage profiles
      final profiles = [
        McpStorageProfile.minimal,
        McpStorageProfile.spaceSaver,
        McpStorageProfile.balanced,
        McpStorageProfile.hiFidelity,
      ];

      for (final profile in profiles) {
        final testDir = Directory('${tempDir.path}/profile_${profile.value}');
        
        final testService = McpExportService(
          bundleId: 'test_${profile.value}',
          storageProfile: profile,
        );

        final journalEntries = [
          JournalEntry(
            id: 'entry_001',
            content: 'Test content for storage profile: ${profile.value}',
            createdAt: DateTime.now(),
            tags: {'test', 'profile'},
            userId: 'user_001',
          ),
        ];

        final result = await testService.exportToMcp(
          outputDir: testDir,
          scope: McpExportScope.all,
          journalEntries: journalEntries,
          mediaFiles: [],
        );

        expect(result.success, isTrue);

        // Verify storage profile in manifest
        final manifestFile = File('${testDir.path}/manifest.json');
        final manifestContent = await manifestFile.readAsString();
        final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;
        
        expect(manifest['storage_profile'], equals(profile.value));

        // Clean up
        await testDir.delete(recursive: true);
      }
    });

    test('Bundle Validation', () async {
      // Create test data
      final journalEntries = [
        JournalEntry(
          id: 'entry_001',
          content: 'Test content for bundle validation.',
          createdAt: DateTime.now(),
          tags: {'test'},
          userId: 'user_001',
        ),
      ];

      // Export to MCP
      final result = await exportService.exportToMcp(
        outputDir: tempDir,
        scope: McpExportScope.all,
        journalEntries: journalEntries,
        mediaFiles: [],
      );

      expect(result.success, isTrue);

      // Validate the entire bundle
      final validationResult = await McpValidator.validateBundle(tempDir);
      expect(validationResult.isValid, isTrue, reason: validationResult.toString());
    });
  });

  group('MCP Schema Validation', () {
    test('Node validation', () {
      final validNode = McpNode(
        id: 'test_node',
        type: 'journal_entry',
        timestamp: DateTime.now().toUtc(),
        contentSummary: 'Test content',
        provenance: const McpProvenance(source: 'ARC'),
      );

      final result = McpValidator.validateNode(validNode);
      expect(result.isValid, isTrue);

      final invalidNode = McpNode(
        id: '', // Invalid: empty ID
        type: 'journal_entry',
        timestamp: DateTime.now(), // Invalid: not UTC
        contentSummary: 'Test content',
        provenance: const McpProvenance(source: 'ARC'),
      );

      final invalidResult = McpValidator.validateNode(invalidNode);
      expect(invalidResult.isValid, isFalse);
      expect(invalidResult.errors.length, greaterThan(0));
    });

    test('Edge validation', () {
      final validEdge = McpEdge(
        source: 'node1',
        target: 'node2',
        relation: 'time_adjacent',
        timestamp: DateTime.now().toUtc(),
      );

      final result = McpValidator.validateEdge(validEdge);
      expect(result.isValid, isTrue);
    });

    test('Pointer validation', () {
      final validPointer = McpPointer(
        id: 'test_pointer',
        mediaType: 'text',
        descriptor: const McpDescriptor(),
        samplingManifest: const McpSamplingManifest(),
        integrity: McpIntegrity(
          contentHash: 'a' * 64, // Valid SHA-256 length
          bytes: 100,
          createdAt: DateTime.now().toUtc(),
        ),
        provenance: const McpProvenance(source: 'ARC'),
        privacy: const McpPrivacy(),
      );

      final result = McpValidator.validatePointer(validPointer);
      expect(result.isValid, isTrue);
    });

    test('Embedding validation', () {
      final validEmbedding = McpEmbedding(
        id: 'test_embedding',
        pointerRef: 'test_pointer',
        vector: List.generate(384, (i) => i * 0.01),
        modelId: 'qwen-2.5-1.5b',
        embeddingVersion: '1.0.0',
        dim: 384,
      );

      final result = McpValidator.validateEmbedding(validEmbedding);
      expect(result.isValid, isTrue);
    });
  });

  group('MCP Guardrails', () {
    test('Append-only semantics', () {
      final existingNodes = [
        McpNode(
          id: 'node1',
          type: 'journal_entry',
          timestamp: DateTime.now().toUtc(),
          provenance: const McpProvenance(source: 'ARC'),
        ),
      ];

      final newNodes = [
        McpNode(
          id: 'node2', // Different ID
          type: 'journal_entry',
          timestamp: DateTime.now().toUtc(),
          provenance: const McpProvenance(source: 'ARC'),
        ),
      ];

      final isAppendOnly = McpGuardrails.isAppendOnly(existingNodes, newNodes);
      expect(isAppendOnly, isTrue);

      // Test with overlapping IDs (should fail)
      final overlappingNodes = [
        McpNode(
          id: 'node1', // Same ID as existing
          type: 'journal_entry',
          timestamp: DateTime.now().toUtc(),
          provenance: const McpProvenance(source: 'ARC'),
        ),
      ];

      final isNotAppendOnly = McpGuardrails.isAppendOnly(existingNodes, overlappingNodes);
      expect(isNotAppendOnly, isFalse);
    });

    test('Deterministic pointer structure', () {
      final validPointer = McpPointer(
        id: 'test_pointer',
        mediaType: 'text',
        descriptor: const McpDescriptor(metadata: {'key': 'value'}),
        samplingManifest: const McpSamplingManifest(metadata: {'sampling': 'automatic'}),
        integrity: McpIntegrity(
          contentHash: 'a' * 64,
          bytes: 100,
          createdAt: DateTime.now().toUtc(),
        ),
        provenance: const McpProvenance(source: 'ARC'),
        privacy: const McpPrivacy(sharingPolicy: 'private'),
      );

      final isDeterministic = McpGuardrails.isDeterministicPointer(validPointer);
      expect(isDeterministic, isTrue);
    });

    test('Privacy propagation', () {
      final pointerWithPrivacy = McpPointer(
        id: 'test_pointer',
        mediaType: 'image',
        descriptor: const McpDescriptor(),
        samplingManifest: const McpSamplingManifest(),
        integrity: McpIntegrity(
          contentHash: 'a' * 64,
          bytes: 100,
          createdAt: DateTime.now().toUtc(),
        ),
        provenance: const McpProvenance(source: 'ARC'),
        privacy: const McpPrivacy(
          containsPii: true,
          facesDetected: true,
          sharingPolicy: 'private',
        ),
      );

      final hasPrivacyPropagation = McpGuardrails.hasPrivacyPropagation(pointerWithPrivacy);
      expect(hasPrivacyPropagation, isTrue);
    });

    test('Encoder provenance', () {
      final embeddingWithProvenance = McpEmbedding(
        id: 'test_embedding',
        pointerRef: 'test_pointer',
        vector: List.generate(384, (i) => i * 0.01),
        modelId: 'qwen-2.5-1.5b',
        embeddingVersion: '1.0.0',
        dim: 384,
      );

      final hasProvenance = McpGuardrails.hasEncoderProvenance(embeddingWithProvenance);
      expect(hasProvenance, isTrue);
    });
  });
}
