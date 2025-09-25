import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
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
      registerFallbackValue(_testPointer());
      registerFallbackValue(_testEmbedding());
      registerFallbackValue(_testNode());
      registerFallbackValue(_testEdge());
    });

    group('importBundle', () {
      test('should successfully import a valid bundle', () async {
        // Arrange
        final manifest = _testManifest(
          counts: const McpCounts(nodes: 2, edges: 1),
          checksums: const McpChecksums(
            nodesJsonl: 'checksum-nodes',
            edgesJsonl: 'checksum-edges',
            pointersJsonl: 'checksum-pointers',
            embeddingsJsonl: 'checksum-embeddings',
          ),
        );

        const options = McpImportOptions(dryRun: false);

        when(() => mockBundleDir.path).thenReturn('/test/bundle');
        when(() => mockManifestReader.readManifest(any())).thenAnswer((_) async => manifest);
        
        // Mock file existence and checksums
        when(() => File('/test/bundle/nodes.jsonl').existsSync()).thenReturn(true);
        when(() => File('/test/bundle/edges.jsonl').existsSync()).thenReturn(true);
        when(() => File('/test/bundle/nodes.jsonl').readAsBytes()).thenAnswer((_) async => Uint8List.fromList([1]));
        when(() => File('/test/bundle/edges.jsonl').readAsBytes()).thenAnswer((_) async => Uint8List.fromList([2]));
        
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
        final manifest = _testManifest();

        const options = McpImportOptions(dryRun: true);

        when(() => mockBundleDir.path).thenReturn('/test/bundle');
        when(() => mockManifestReader.readManifest(any())).thenAnswer((_) async => manifest);
        when(() => File('/test/bundle/nodes.jsonl').existsSync()).thenReturn(false);
        when(() => mockValidator.validateNdjsonFile(any(), any())).thenAnswer((_) async =>
            const McpValidationResult(
              isValid: true,
              errors: [],
              warnings: [],
              totalRecords: 0,
              validRecords: 0,
              processingTime: Duration.zero,
            ));

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
        final manifest = _testManifest(
          checksums: const McpChecksums(
            nodesJsonl: 'expected_checksum',
            edgesJsonl: 'checksum-edges',
            pointersJsonl: 'checksum-pointers',
            embeddingsJsonl: 'checksum-embeddings',
          ),
        );

        const options = McpImportOptions(strictMode: true);

        when(() => mockBundleDir.path).thenReturn('/test/bundle');
        when(() => mockManifestReader.readManifest(any())).thenAnswer((_) async => manifest);
        when(() => File('/test/bundle/nodes.jsonl').existsSync()).thenReturn(true);
        when(() => File('/test/bundle/nodes.jsonl').readAsBytes())
            .thenAnswer((_) async => Uint8List.fromList(utf8.encode('invalid content')));

        // Act
        final result = await service.importBundle(mockBundleDir, options);

        // Assert
        expect(result.success, isFalse);
        expect(result.message, contains('Bundle integrity check failed'));
        expect(result.errors, contains(contains('Checksum mismatch')));
      });

      test('should respect max errors limit', () async {
        // Arrange
        final manifest = _testManifest(
          counts: const McpCounts(nodes: 1),
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
        final manifest = _testManifest(schemaVersion: '1.2.3');

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
        final manifest = _testManifest(schemaVersion: '2.0.0');

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
        final manifest = _testManifest(
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
        final manifest = _testManifest(
          counts: const McpCounts(nodes: 1, edges: 1, pointers: 1, embeddings: 1),
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

McpProvenance _testProvenance() => const McpProvenance(
      source: 'test',
      device: 'device',
      app: 'app',
      importMethod: 'unit_test',
    );

McpManifest _testManifest({
  String schemaVersion = '1.0.0',
  McpCounts counts = const McpCounts(),
  McpChecksums? checksums,
  String version = '1.0.0',
  DateTime? createdAt,
}) => McpManifest(
      schemaVersion: schemaVersion,
      version: version,
      createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      bundleId: 'bundle-id',
      counts: counts,
      checksums: checksums ?? const McpChecksums(
        nodesJsonl: 'checksum-nodes',
        edgesJsonl: 'checksum-edges',
        pointersJsonl: 'checksum-pointers',
        embeddingsJsonl: 'checksum-embeddings',
      ),
      encoderRegistry: const [McpEncoderRegistry(modelId: 'model', embeddingVersion: 'v1', dim: 0)],
      storageProfile: McpStorageProfile.balanced.value,
      casRemotes: const [],
    );

McpPointer _testPointer() => McpPointer(
      id: 'pointer',
      mediaType: 'application/json',
      descriptor: const McpDescriptor(),
      samplingManifest: const McpSamplingManifest(),
      integrity: McpIntegrity(
        contentHash: 'hash',
        bytes: 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
      provenance: _testProvenance(),
      privacy: const McpPrivacy(),
      labels: const [],
      casRefs: const [],
    );

McpEmbedding _testEmbedding() => McpEmbedding(
      id: 'embedding',
      vector: const [],
      modelId: 'model',
      embeddingVersion: 'v1',
      dim: 0,
      pointerRef: 'pointer',
    );

McpNode _testNode() => McpNode(
      id: 'node',
      type: 'test',
      timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      provenance: _testProvenance(),
      schemaVersion: 'node.v1',
    );

McpEdge _testEdge() => McpEdge(
      source: 'node',
      target: 'node2',
      relation: 'rel',
      timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      schemaVersion: 'edge.v1',
    );