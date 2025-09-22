import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/mcp/import/mcp_import_service.dart';
import 'package:my_app/mcp/import/manifest_reader.dart';
import 'package:my_app/mcp/import/ndjson_stream_reader.dart';
import 'package:my_app/mcp/validation/mcp_import_validator.dart';
import 'package:my_app/mcp/adapters/mira_writer.dart';
import 'package:my_app/mcp/adapters/cas_resolver.dart';
import 'package:my_app/mcp/models/mcp_schemas.dart';

// Mock classes
class MockManifestReader extends Mock implements ManifestReader {}
class MockNdjsonStreamReader extends Mock implements NdjsonStreamReader {}
class MockMcpImportValidator extends Mock implements McpImportValidator {}
class MockMiraWriter extends Mock implements MiraWriter {}
class MockCasResolver extends Mock implements CasResolver {}
class MockDirectory extends Mock implements Directory {}

void main() {
  group('McpImportService', () {
    late McpImportService service;
    late MockManifestReader mockManifestReader;
    late MockNdjsonStreamReader mockNdjsonReader;
    late MockMcpImportValidator mockValidator;
    late MockMiraWriter mockMiraWriter;
    late MockCasResolver mockCasResolver;
    late MockDirectory mockBundleDir;

    setUp(() {
      mockManifestReader = MockManifestReader();
      mockNdjsonReader = MockNdjsonStreamReader();
      mockValidator = MockMcpImportValidator();
      mockMiraWriter = MockMiraWriter();
      mockCasResolver = MockCasResolver();
      mockBundleDir = MockDirectory();

      service = McpImportService(
        manifestReader: mockManifestReader,
        ndjsonReader: mockNdjsonReader,
        validator: mockValidator,
        miraWriter: mockMiraWriter,
        casResolver: mockCasResolver,
      );

      // Register fallback values
      registerFallbackValue(mockBundleDir);
      registerFallbackValue(const McpImportOptions());
      registerFallbackValue(const McpPointer(id: 'test', descriptor: 'test'));
      registerFallbackValue(const McpEmbedding(id: 'test', vector: [], model: 'test'));
      registerFallbackValue(const McpNode(id: 'test', type: 'test'));
      registerFallbackValue(const McpEdge(id: 'test', sourceId: 'test', targetId: 'test', type: 'test'));
    });

    group('importBundle', () {
      test('should successfully import a valid bundle', () async {
        // Arrange
        final manifest = McpManifest(
          schemaVersion: '1.0.0',
          version: '1.0.0',
          createdAt: DateTime.now().toUtc(),
          counts: {'nodes': 2, 'edges': 1},
          checksums: {
            'nodes.jsonl': 'test_checksum_nodes',
            'edges.jsonl': 'test_checksum_edges',
          },
        );

        const options = McpImportOptions(dryRun: false);

        when(() => mockBundleDir.path).thenReturn('/test/bundle');
        when(() => mockManifestReader.readManifest(any())).thenAnswer((_) async => manifest);
        
        // Mock file existence and checksums
        when(() => File('/test/bundle/nodes.jsonl').existsSync()).thenReturn(true);
        when(() => File('/test/bundle/edges.jsonl').existsSync()).thenReturn(true);
        when(() => File('/test/bundle/nodes.jsonl').readAsBytes()).thenAnswer((_) async => []);
        when(() => File('/test/bundle/edges.jsonl').readAsBytes()).thenAnswer((_) async => []);
        
        // Mock NDJSON streams
        when(() => mockNdjsonReader.readStream(any())).thenAnswer((_) async* {
          yield '{"id":"node1","type":"test","label":"Test Node"}';
          yield '{"id":"node2","type":"test","label":"Another Node"}';
        });

        when(() => mockMiraWriter.putNode(any(), any())).thenAnswer((_) async {});
        when(() => mockMiraWriter.putEdge(any(), any())).thenAnswer((_) async {});
        when(() => mockMiraWriter.putPointer(any(), any())).thenAnswer((_) async {});
        when(() => mockMiraWriter.putEmbedding(any(), any())).thenAnswer((_) async {});
        when(() => mockMiraWriter.rebuildTimeIndexes(any())).thenAnswer((_) async {});
        when(() => mockMiraWriter.rebuildKeywordIndexes(any())).thenAnswer((_) async {});
        when(() => mockMiraWriter.rebuildPhaseIndexes(any())).thenAnswer((_) async {});
        when(() => mockMiraWriter.rebuildRelationIndexes(any())).thenAnswer((_) async {});

        // Act
        final result = await service.importBundle(mockBundleDir, options);

        // Assert
        expect(result.success, isTrue);
        expect(result.errors, isEmpty);
        expect(result.batchId, isNotNull);
        verify(() => mockManifestReader.readManifest(mockBundleDir)).called(1);
        verify(() => mockMiraWriter.rebuildTimeIndexes(any())).called(1);
      });

      test('should handle manifest reading failure', () async {
        // Arrange
        const options = McpImportOptions();
        when(() => mockManifestReader.readManifest(any()))
            .thenThrow(Exception('Manifest not found'));

        // Act
        final result = await service.importBundle(mockBundleDir, options);

        // Assert
        expect(result.success, isFalse);
        expect(result.errors, isNotEmpty);
        expect(result.errors.first, contains('Failed to read manifest'));
      });

      test('should perform dry run validation only', () async {
        // Arrange
        final manifest = McpManifest(
          schemaVersion: '1.0.0',
          version: '1.0.0',
          createdAt: DateTime.now().toUtc(),
        );

        const options = McpImportOptions(dryRun: true);

        when(() => mockBundleDir.path).thenReturn('/test/bundle');
        when(() => mockManifestReader.readManifest(any())).thenAnswer((_) async => manifest);
        when(() => File('/test/bundle/nodes.jsonl').existsSync()).thenReturn(false);
        when(() => mockValidator.validateNdjsonFile(any(), any()))
            .thenAnswer((_) async => const McpValidationResult(isValid: true, errors: []));

        // Act
        final result = await service.importBundle(mockBundleDir, options);

        // Assert
        expect(result.success, isTrue);
        expect(result.message, contains('Dry run completed'));
        verifyNever(() => mockMiraWriter.putNode(any(), any()));
        verifyNever(() => mockMiraWriter.rebuildTimeIndexes(any()));
      });

      test('should handle checksum validation failure in strict mode', () async {
        // Arrange
        final manifest = McpManifest(
          schemaVersion: '1.0.0',
          version: '1.0.0',
          createdAt: DateTime.now().toUtc(),
          checksums: {'nodes.jsonl': 'expected_checksum'},
        );

        const options = McpImportOptions(strictMode: true);

        when(() => mockBundleDir.path).thenReturn('/test/bundle');
        when(() => mockManifestReader.readManifest(any())).thenAnswer((_) async => manifest);
        when(() => File('/test/bundle/nodes.jsonl').existsSync()).thenReturn(true);
        when(() => File('/test/bundle/nodes.jsonl').readAsBytes())
            .thenAnswer((_) async => utf8.encode('invalid content'));

        // Act
        final result = await service.importBundle(mockBundleDir, options);

        // Assert
        expect(result.success, isFalse);
        expect(result.message, contains('Bundle integrity check failed'));
        expect(result.errors, contains(contains('Checksum mismatch')));
      });

      test('should respect max errors limit', () async {
        // Arrange
        final manifest = McpManifest(
          schemaVersion: '1.0.0',
          version: '1.0.0',
          createdAt: DateTime.now().toUtc(),
          counts: {'nodes': 1},
          checksums: {},
        );

        const options = McpImportOptions(maxErrors: 2);

        when(() => mockBundleDir.path).thenReturn('/test/bundle');
        when(() => mockManifestReader.readManifest(any())).thenAnswer((_) async => manifest);
        when(() => File('/test/bundle/nodes.jsonl').existsSync()).thenReturn(true);
        when(() => mockNdjsonReader.readStream(any())).thenAnswer((_) async* {
          yield 'invalid json 1';
          yield 'invalid json 2';
          yield 'invalid json 3';
          yield 'invalid json 4';
        });

        // Act
        final result = await service.importBundle(mockBundleDir, options);

        // Assert
        expect(result.success, isFalse);
        expect(result.errors.length, equals(3)); // 2 max errors + 1 from empty counts verification
      });
    });

    group('schema version compatibility', () {
      test('should accept compatible schema versions', () async {
        // Arrange
        final manifest = McpManifest(
          schemaVersion: '1.2.3',
          version: '1.0.0',
          createdAt: DateTime.now().toUtc(),
        );

        const options = McpImportOptions(dryRun: true);

        when(() => mockBundleDir.path).thenReturn('/test/bundle');
        when(() => mockManifestReader.readManifest(any())).thenAnswer((_) async => manifest);

        // Act
        final result = await service.importBundle(mockBundleDir, options);

        // Assert
        expect(result.success, isTrue);
        expect(result.errors, isEmpty);
      });

      test('should reject incompatible schema versions', () async {
        // Arrange
        final manifest = McpManifest(
          schemaVersion: '2.0.0',
          version: '1.0.0',
          createdAt: DateTime.now().toUtc(),
        );

        const options = McpImportOptions();

        when(() => mockBundleDir.path).thenReturn('/test/bundle');
        when(() => mockManifestReader.readManifest(any())).thenAnswer((_) async => manifest);

        // Act
        final result = await service.importBundle(mockBundleDir, options);

        // Assert
        expect(result.success, isFalse);
        expect(result.errors, contains(contains('Incompatible schema version')));
      });
    });

    group('batch ID generation', () {
      test('should generate consistent batch IDs for same manifest', () async {
        // Arrange
        final dateTime = DateTime.utc(2024, 1, 1, 12, 0, 0);
        final manifest = McpManifest(
          schemaVersion: '1.0.0',
          version: '1.2.3',
          createdAt: dateTime,
        );

        const options = McpImportOptions(dryRun: true);

        when(() => mockBundleDir.path).thenReturn('/test/bundle');
        when(() => mockManifestReader.readManifest(any())).thenAnswer((_) async => manifest);

        // Act
        final result1 = await service.importBundle(mockBundleDir, options);
        final result2 = await service.importBundle(mockBundleDir, options);

        // Assert
        expect(result1.batchId, isNotNull);
        expect(result2.batchId, isNotNull);
        // Batch IDs should be different due to timestamp component
        expect(result1.batchId, isNot(equals(result2.batchId)));
      });
    });

    group('import order validation', () {
      test('should import in correct order: pointers → embeddings → nodes → edges', () async {
        // Arrange
        final manifest = McpManifest(
          schemaVersion: '1.0.0',
          version: '1.0.0',
          createdAt: DateTime.now().toUtc(),
          counts: {
            'pointers': 1,
            'embeddings': 1,
            'nodes': 1,
            'edges': 1,
          },
          checksums: {},
        );

        const options = McpImportOptions();
        final importOrder = <String>[];

        when(() => mockBundleDir.path).thenReturn('/test/bundle');
        when(() => mockManifestReader.readManifest(any())).thenAnswer((_) async => manifest);
        
        // Mock all files exist
        when(() => File('/test/bundle/pointers.jsonl').existsSync()).thenReturn(true);
        when(() => File('/test/bundle/embeddings.jsonl').existsSync()).thenReturn(true);
        when(() => File('/test/bundle/nodes.jsonl').existsSync()).thenReturn(true);
        when(() => File('/test/bundle/edges.jsonl').existsSync()).thenReturn(true);

        when(() => mockNdjsonReader.readStream(any())).thenAnswer((invocation) async* {
          final file = invocation.positionalArguments[0] as File;
          final filename = file.path.split('/').last;
          yield '{"id":"test1","type":"test"}';
        });

        when(() => mockMiraWriter.putPointer(any(), any())).thenAnswer((_) async {
          importOrder.add('pointer');
        });
        when(() => mockMiraWriter.putEmbedding(any(), any())).thenAnswer((_) async {
          importOrder.add('embedding');
        });
        when(() => mockMiraWriter.putNode(any(), any())).thenAnswer((_) async {
          importOrder.add('node');
        });
        when(() => mockMiraWriter.putEdge(any(), any())).thenAnswer((_) async {
          importOrder.add('edge');
        });
        when(() => mockMiraWriter.rebuildTimeIndexes(any())).thenAnswer((_) async {});
        when(() => mockMiraWriter.rebuildKeywordIndexes(any())).thenAnswer((_) async {});
        when(() => mockMiraWriter.rebuildPhaseIndexes(any())).thenAnswer((_) async {});
        when(() => mockMiraWriter.rebuildRelationIndexes(any())).thenAnswer((_) async {});

        // Act
        await service.importBundle(mockBundleDir, options);

        // Assert
        expect(importOrder, equals(['pointer', 'embedding', 'node', 'edge']));
      });
    });
  });
}