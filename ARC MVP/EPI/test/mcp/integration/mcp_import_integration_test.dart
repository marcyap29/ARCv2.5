import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/mcp/import/mcp_import_service.dart';

/// Integration tests for the complete MCP import pipeline
/// 
/// These tests demonstrate the full end-to-end import flow using realistic
/// test data and validate that all components work together correctly.
void main() {
  group('MCP Import Integration Tests', () {
    late Directory tempDir;
    late Directory bundleDir;
    late Directory storageDir;
    late McpImportService importService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mcp_integration_test');
      bundleDir = Directory('${tempDir.path}/test_bundle');
      storageDir = Directory('${tempDir.path}/mira_storage');
      
      await bundleDir.create();
      await storageDir.create();

      importService = McpImportService();
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Golden Test: Complete MCP bundle import flow', () async {
      // Step 1: Create a comprehensive test bundle
      await _createGoldenTestBundle(bundleDir);

      // Step 2: Import with default options
      const options = McpImportOptions(
        dryRun: false,
        strictMode: true,
        rebuildIndexes: true,
      );

      final result = await importService.importBundle(bundleDir, options);

      // Step 3: Verify import success
      expect(result.success, isTrue, reason: 'Import should succeed for valid bundle');
      expect(result.errors, isEmpty, reason: 'No errors should occur with valid bundle');
      expect(result.batchId, isNotNull, reason: 'Batch ID should be generated');
      expect(result.processingTime.inMilliseconds, greaterThan(0), reason: 'Processing should take measurable time');

      // Step 4: Verify imported counts match manifest
      expect(result.counts['nodes'], equals(3), reason: 'All nodes should be imported');
      expect(result.counts['edges'], equals(2), reason: 'All edges should be imported');
      expect(result.counts['pointers'], equals(2), reason: 'All pointers should be imported');
      expect(result.counts['embeddings'], equals(1), reason: 'All embeddings should be imported');

      // Step 5: Verify MIRA storage structure was created
      await _verifyMiraStorageStructure(storageDir, result.batchId!);

      // Step 6: Verify data integrity and lineage tracking
      await _verifyDataIntegrity(storageDir, result.batchId!);

      // Step 7: Verify index creation
      await _verifyIndexCreation(storageDir);
    });

    test('Dry Run: Validation without import', () async {
      // Step 1: Create test bundle
      await _createGoldenTestBundle(bundleDir);

      // Step 2: Perform dry run
      const options = McpImportOptions(dryRun: true);
      final result = await importService.importBundle(bundleDir, options);

      // Step 3: Verify validation success without data import
      expect(result.success, isTrue, reason: 'Dry run validation should succeed');
      expect(result.message, contains('Dry run completed'), reason: 'Should indicate dry run mode');
      expect(result.batchId, isNull, reason: 'No batch ID should be generated in dry run');

      // Step 4: Verify no data was written to storage
      final batchesDir = Directory('${storageDir.path}/batches');
      expect(batchesDir.existsSync(), isFalse, reason: 'No storage should be created in dry run');
    });

    test('Error Handling: Invalid bundle structure', () async {
      // Step 1: Create invalid bundle (missing manifest)
      await _createInvalidBundle(bundleDir);

      // Step 2: Attempt import
      const options = McpImportOptions();
      final result = await importService.importBundle(bundleDir, options);

      // Step 3: Verify appropriate error handling
      expect(result.success, isFalse, reason: 'Import should fail for invalid bundle');
      expect(result.errors, isNotEmpty, reason: 'Errors should be reported');
      expect(result.errors.first, contains('manifest'), reason: 'Should identify manifest issue');
    });

    test('Performance: Large bundle import', () async {
      // Step 1: Create large test bundle
      await _createLargeTestBundle(bundleDir);

      // Step 2: Import with performance tracking
      final stopwatch = Stopwatch()..start();
      const options = McpImportOptions();
      final result = await importService.importBundle(bundleDir, options);
      stopwatch.stop();

      // Step 3: Verify performance characteristics
      expect(result.success, isTrue, reason: 'Large bundle import should succeed');
      expect(stopwatch.elapsedMilliseconds, lessThan(30000), reason: 'Import should complete within 30 seconds');
      expect(result.counts['nodes'], equals(1000), reason: 'All 1000 nodes should be imported');
      
      // Verify memory efficiency (no explicit assertions, but test should not OOM)
      print('Large bundle import completed in ${stopwatch.elapsedMilliseconds}ms');
      print('Import stats: ${result.counts}');
    });

    test('Privacy Levels: PII handling and propagation', () async {
      // Step 1: Create bundle with various privacy levels
      await _createPrivacyTestBundle(bundleDir);

      // Step 2: Import bundle
      const options = McpImportOptions();
      final result = await importService.importBundle(bundleDir, options);

      // Step 3: Verify privacy level handling
      expect(result.success, isTrue, reason: 'Privacy test bundle should import successfully');
      
      // Step 4: Verify privacy propagation in stored data
      await _verifyPrivacyHandling(storageDir, result.batchId!);
    });

    test('Schema Validation: MCP Draft 2020-12 compliance', () async {
      // Step 1: Create bundle with various schema edge cases
      await _createSchemaValidationBundle(bundleDir);

      // Step 2: Import with strict validation
      const options = McpImportOptions(strictMode: true);
      final result = await importService.importBundle(bundleDir, options);

      // Step 3: Verify schema compliance
      expect(result.success, isTrue, reason: 'Schema-compliant bundle should import');
      expect(result.warnings, isEmpty, reason: 'No warnings should occur with compliant data');
    });
  });
}

/// Create a comprehensive golden test bundle with realistic data
Future<void> _createGoldenTestBundle(Directory bundleDir) async {
  final now = DateTime.now().toUtc();
  
  // Create manifest.json with all required and optional fields
  final manifest = {
    'schema_version': '1.0.0',
    'version': '1.2.3',
    'created_at': now.toIso8601String(),
    'storage_profile': 'balanced',
    'notes': 'Golden test bundle for integration testing',
    'counts': {
      'nodes': 3,
      'edges': 2,
      'pointers': 2,
      'embeddings': 1,
    },
    'checksums': {
      'nodes.jsonl': await _calculateFileChecksum('nodes content'),
      'edges.jsonl': await _calculateFileChecksum('edges content'),
      'pointers.jsonl': await _calculateFileChecksum('pointers content'),
      'embeddings.jsonl': await _calculateFileChecksum('embeddings content'),
    },
    'encoder_registry': [
      {
        'model_id': 'qwen3-embedding-0.6b',
        'encoder_type': 'transformer',
        'vector_size': 768,
        'context_length': 4096,
      }
    ],
    'cas_remotes': [
      'https://cas.example.com/v1',
    ],
  };

  await File('${bundleDir.path}/manifest.json').writeAsString(jsonEncode(manifest));

  // Create nodes.jsonl with SAGE structure
  final nodes = [
    {
      'id': 'node_001',
      'type': 'memory',
      'label': 'Learning Python Basics',
      'properties': {
        'situation': 'Started learning Python programming language',
        'action': 'Completed basic syntax tutorial and wrote first program',
        'growth': 'Understood variables, loops, and basic data structures',
        'essence': 'Programming fundamentals are building blocks for complex software',
      },
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'privacy_level': 'personal',
      'phase': 'learning',
      'source_hash': 'sha256:abc123',
      'metadata': {
        'source': 'learning_journal',
        'tags': ['programming', 'python', 'education'],
      },
    },
    {
      'id': 'node_002',
      'type': 'insight',
      'label': 'Code Review Benefits',
      'properties': {
        'situation': 'Participated in team code review session',
        'action': 'Reviewed peer code and received feedback on my implementation',
        'growth': 'Learned importance of code readability and error handling',
        'essence': 'Collaborative development improves code quality and team knowledge',
      },
      'created_at': now.add(const Duration(hours: 1)).toIso8601String(),
      'updated_at': now.add(const Duration(hours: 1)).toIso8601String(),
      'privacy_level': 'team',
      'phase': 'reflection',
      'source_hash': 'sha256:def456',
      'metadata': {
        'source': 'team_collaboration',
        'tags': ['code-review', 'teamwork'],
      },
    },
    {
      'id': 'node_003',
      'type': 'goal',
      'label': 'Build Personal Project',
      'properties': {
        'situation': 'Want to apply learned Python skills to real project',
        'action': 'Planning a personal task management application',
        'growth': 'Will integrate database, web interface, and API design',
        'essence': 'Practical application reinforces theoretical knowledge',
      },
      'created_at': now.add(const Duration(hours: 2)).toIso8601String(),
      'updated_at': now.add(const Duration(hours: 2)).toIso8601String(),
      'privacy_level': 'personal',
      'phase': 'planning',
      'source_hash': 'sha256:ghi789',
      'metadata': {
        'source': 'goal_setting',
        'tags': ['project', 'application'],
        'priority': 'high',
      },
    },
  ];

  await File('${bundleDir.path}/nodes.jsonl').writeAsString(
    nodes.map((node) => jsonEncode(node)).join('\n'),
  );

  // Create edges.jsonl with relations
  final edges = [
    {
      'id': 'edge_001',
      'type': 'influences',
      'source_id': 'node_001',
      'target_id': 'node_002',
      'properties': {
        'strength': 'high',
        'context': 'Learning led to better code review participation',
      },
      'weight': 0.8,
      'directed': true,
      'created_at': now.add(const Duration(minutes: 30)).toIso8601String(),
      'privacy_level': 'personal',
      'phase': 'connection',
      'metadata': {
        'relationship_type': 'causal',
      },
    },
    {
      'id': 'edge_002',
      'type': 'enables',
      'source_id': 'node_002',
      'target_id': 'node_003',
      'properties': {
        'strength': 'medium',
        'context': 'Code review experience informs project planning',
      },
      'weight': 0.6,
      'directed': true,
      'created_at': now.add(const Duration(minutes: 45)).toIso8601String(),
      'privacy_level': 'personal',
      'phase': 'connection',
      'metadata': {
        'relationship_type': 'enabling',
      },
    },
  ];

  await File('${bundleDir.path}/edges.jsonl').writeAsString(
    edges.map((edge) => jsonEncode(edge)).join('\n'),
  );

  // Create pointers.jsonl
  final pointers = [
    {
      'id': 'ptr_001',
      'descriptor': 'Python Tutorial Completion Certificate',
      'source_uri': 'https://example.com/certificates/python_basics_2024',
      'storage_type': 'external_reference',
      'content_hash': 'sha256:cert_hash_001',
      'content_encoding': 'pdf',
      'metadata': {
        'document_type': 'certificate',
        'issuer': 'Python Learning Platform',
        'issue_date': now.toIso8601String(),
      },
      'privacy_level': 'personal',
      'created_at': now.toIso8601String(),
      'cas_refs': ['cas:sha256:cert_content_hash'],
    },
    {
      'id': 'ptr_002',
      'descriptor': 'Code Review Feedback Document',
      'source_uri': 'file:///team_shared/reviews/review_2024_001.md',
      'storage_type': 'local_file',
      'content_hash': 'sha256:review_hash_002',
      'content_encoding': 'markdown',
      'metadata': {
        'document_type': 'review',
        'reviewer': 'senior_dev_alice',
        'review_date': now.add(const Duration(hours: 1)).toIso8601String(),
      },
      'privacy_level': 'team',
      'created_at': now.add(const Duration(hours: 1)).toIso8601String(),
      'cas_refs': ['cas:sha256:review_content_hash'],
    },
  ];

  await File('${bundleDir.path}/pointers.jsonl').writeAsString(
    pointers.map((pointer) => jsonEncode(pointer)).join('\n'),
  );

  // Create embeddings.jsonl
  final embeddings = [
    {
      'id': 'emb_001',
      'vector': List.generate(768, (i) => (i % 100) / 100.0), // Mock 768-dimensional vector
      'model': 'qwen3-embedding-0.6b',
      'source_text': 'Learning Python programming language fundamentals including variables loops and data structures',
      'chunk_index': 0,
      'total_chunks': 1,
      'metadata': {
        'source_node_id': 'node_001',
        'encoding_timestamp': now.toIso8601String(),
        'chunk_strategy': 'sentence_boundary',
      },
      'created_at': now.toIso8601String(),
      'source_hash': 'sha256:text_hash_001',
      'privacy_level': 'personal',
    },
  ];

  await File('${bundleDir.path}/embeddings.jsonl').writeAsString(
    embeddings.map((embedding) => jsonEncode(embedding)).join('\n'),
  );
}

/// Create an invalid bundle for error testing
Future<void> _createInvalidBundle(Directory bundleDir) async {
  // Create a bundle with missing manifest.json
  await File('${bundleDir.path}/nodes.jsonl').writeAsString(
    '{"id":"invalid","type":"test"}\n',
  );
}

/// Create a large bundle for performance testing
Future<void> _createLargeTestBundle(Directory bundleDir) async {
  final now = DateTime.now().toUtc();
  
  // Create manifest for large bundle
  final manifest = {
    'schema_version': '1.0.0',
    'version': '1.0.0',
    'created_at': now.toIso8601String(),
    'counts': {'nodes': 1000},
    'checksums': {},
  };

  await File('${bundleDir.path}/manifest.json').writeAsString(jsonEncode(manifest));

  // Create large nodes.jsonl
  final buffer = StringBuffer();
  for (int i = 0; i < 1000; i++) {
    final node = {
      'id': 'large_node_$i',
      'type': 'test',
      'label': 'Large Test Node $i',
      'properties': {
        'index': i,
        'batch': 'performance_test',
        'data': 'x' * 100, // Add some bulk to each node
      },
      'created_at': now.add(Duration(milliseconds: i)).toIso8601String(),
      'privacy_level': 'test',
      'phase': 'generated',
    };
    buffer.writeln(jsonEncode(node));
  }

  await File('${bundleDir.path}/nodes.jsonl').writeAsString(buffer.toString());
}

/// Create bundle with various privacy levels for testing privacy handling
Future<void> _createPrivacyTestBundle(Directory bundleDir) async {
  final now = DateTime.now().toUtc();
  
  final manifest = {
    'schema_version': '1.0.0',
    'version': '1.0.0',
    'created_at': now.toIso8601String(),
    'counts': {'nodes': 3},
    'checksums': {},
  };

  await File('${bundleDir.path}/manifest.json').writeAsString(jsonEncode(manifest));

  final nodes = [
    {
      'id': 'public_node',
      'type': 'insight',
      'label': 'Public Knowledge',
      'privacy_level': 'public',
      'created_at': now.toIso8601String(),
    },
    {
      'id': 'personal_node',
      'type': 'memory',
      'label': 'Personal Experience',
      'privacy_level': 'personal',
      'created_at': now.toIso8601String(),
      'metadata': {
        'contains_pii': true,
        'redaction_applied': false,
      },
    },
    {
      'id': 'confidential_node',
      'type': 'work',
      'label': 'Confidential Information',
      'privacy_level': 'confidential',
      'created_at': now.toIso8601String(),
      'metadata': {
        'classification': 'restricted',
        'access_level': 'team_only',
      },
    },
  ];

  await File('${bundleDir.path}/nodes.jsonl').writeAsString(
    nodes.map((node) => jsonEncode(node)).join('\n'),
  );
}

/// Create bundle for comprehensive schema validation testing
Future<void> _createSchemaValidationBundle(Directory bundleDir) async {
  final now = DateTime.now().toUtc();
  
  final manifest = {
    'schema_version': '1.0.0',
    'version': '1.0.0',
    'created_at': now.toIso8601String(),
    'counts': {'nodes': 2},
    'checksums': {},
  };

  await File('${bundleDir.path}/manifest.json').writeAsString(jsonEncode(manifest));

  // Test various valid schema patterns
  final nodes = [
    {
      'id': 'minimal_node',
      'type': 'test',
      'created_at': now.toIso8601String(),
    },
    {
      'id': 'maximal_node',
      'type': 'comprehensive',
      'label': 'Node with All Optional Fields',
      'properties': {
        'situation': 'Complex scenario with all SAGE fields',
        'action': 'Comprehensive action description',
        'growth': 'Detailed growth analysis',
        'essence': 'Deep essence understanding',
        'custom_field': 'Additional properties allowed',
      },
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'privacy_level': 'personal',
      'phase': 'complete',
      'source_hash': 'sha256:comprehensive_hash',
      'metadata': {
        'validation_test': true,
        'nested': {
          'deep_field': 'nested_value',
        },
        'array_field': [1, 2, 3],
      },
    },
  ];

  await File('${bundleDir.path}/nodes.jsonl').writeAsString(
    nodes.map((node) => jsonEncode(node)).join('\n'),
  );
}

/// Verify MIRA storage structure was created correctly
Future<void> _verifyMiraStorageStructure(Directory storageDir, String batchId) async {
  // Check required directories exist
  final requiredDirs = [
    'pointers', 'embeddings', 'nodes', 'edges',
    'indexes/time', 'indexes/keyword', 'indexes/phase', 'indexes/relation',
    'batches', 'lineage',
  ];

  for (final dir in requiredDirs) {
    final directory = Directory('${storageDir.path}/$dir');
    expect(directory.existsSync(), isTrue, reason: 'Directory $dir should exist');
  }

  // Check batch summary exists
  final batchFile = File('${storageDir.path}/batches/$batchId.json');
  expect(batchFile.existsSync(), isTrue, reason: 'Batch summary should be created');

  final batchData = jsonDecode(await batchFile.readAsString());
  expect(batchData['batch_id'], equals(batchId));
  expect(batchData['counts'], isA<Map>());
}

/// Verify data integrity and lineage tracking
Future<void> _verifyDataIntegrity(Directory storageDir, String batchId) async {
  // Check nodes were stored correctly
  final nodesDir = Directory('${storageDir.path}/nodes');
  final nodeFiles = await nodesDir.list().where((f) => f.path.endsWith('.json')).toList();
  expect(nodeFiles, hasLength(3), reason: 'Should have 3 node files');

  // Verify lineage tracking
  final lineageFile = File('${storageDir.path}/lineage/node.jsonl');
  expect(lineageFile.existsSync(), isTrue, reason: 'Node lineage should be tracked');

  final lineageContent = await lineageFile.readAsString();
  final lineageLines = lineageContent.trim().split('\n');
  expect(lineageLines, hasLength(3), reason: 'Should have lineage for each node');

  // Verify each lineage record has required fields
  for (final line in lineageLines) {
    final record = jsonDecode(line);
    expect(record['batch_id'], equals(batchId));
    expect(record['lineage_hash'], isNotNull);
    expect(record['imported_at'], isNotNull);
  }
}

/// Verify index creation
Future<void> _verifyIndexCreation(Directory storageDir) async {
  final indexFiles = [
    'indexes/time/monthly_index.json',
    'indexes/keyword/keyword_index.json',
    'indexes/phase/phase_index.json',
    'indexes/relation/relation_index.json',
  ];

  for (final indexPath in indexFiles) {
    final indexFile = File('${storageDir.path}/$indexPath');
    expect(indexFile.existsSync(), isTrue, reason: 'Index $indexPath should be created');

    final indexData = jsonDecode(await indexFile.readAsString());
    expect(indexData['last_updated'], isNotNull);
    expect(indexData['index'], isA<Map>());
  }
}

/// Verify privacy level handling in stored data
Future<void> _verifyPrivacyHandling(Directory storageDir, String batchId) async {
  final nodesDir = Directory('${storageDir.path}/nodes');
  
  await for (final entity in nodesDir.list()) {
    if (entity is File && entity.path.endsWith('.json')) {
      final nodeData = jsonDecode(await entity.readAsString());
      
      // Verify privacy level is preserved
      expect(nodeData['privacy_level'], isNotNull, reason: 'Privacy level should be stored');
      expect(nodeData['batch_id'], equals(batchId), reason: 'Batch ID should be preserved');
      
      // If node has PII metadata, verify it's handled appropriately
      if (nodeData['metadata']?['contains_pii'] == true) {
        expect(nodeData['privacy_level'], isNot(equals('public')), 
               reason: 'PII nodes should not have public privacy level');
      }
    }
  }
}

/// Calculate mock checksum for test data
Future<String> _calculateFileChecksum(String content) async {
  // Mock checksum calculation for testing
  return 'sha256:test_checksum_${content.hashCode.abs().toRadixString(16)}';
}