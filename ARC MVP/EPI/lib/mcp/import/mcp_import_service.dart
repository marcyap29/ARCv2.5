import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:my_app/mcp/import/manifest_reader.dart';
import 'package:my_app/mcp/import/ndjson_stream_reader.dart';
import 'package:my_app/mcp/validation/mcp_import_validator.dart';
import 'package:my_app/mcp/adapters/mira_writer.dart';
import 'package:my_app/mcp/adapters/cas_resolver.dart';
import 'package:my_app/mcp/models/mcp_schemas.dart';

/// Result of an MCP import operation
class McpImportResult {
  final bool success;
  final String message;
  final Map<String, int> counts;
  final List<String> warnings;
  final List<String> errors;
  final Duration processingTime;
  final String? batchId;

  const McpImportResult({
    required this.success,
    required this.message,
    required this.counts,
    required this.warnings,
    required this.errors,
    required this.processingTime,
    this.batchId,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    'counts': counts,
    'warnings': warnings,
    'errors': errors,
    'processing_time_ms': processingTime.inMilliseconds,
    'batch_id': batchId,
  };
}

/// Options for MCP import operation
class McpImportOptions {
  final bool dryRun;
  final bool verifyCas;
  final bool strictMode;
  final bool rebuildIndexes;
  final int maxErrors;

  const McpImportOptions({
    this.dryRun = false,
    this.verifyCas = false,
    this.strictMode = false,
    this.rebuildIndexes = true,
    this.maxErrors = 100,
  });
}

/// High-level orchestrator for MCP bundle imports
/// 
/// Validates bundle integrity, streams NDJSON into MIRA storage (append-only),
/// rebuilds indexes, and preserves pointer privacy/provenance and embedding lineage.
class McpImportService {
  final ManifestReader _manifestReader;
  final NdjsonStreamReader _ndjsonReader;
  final McpImportValidator _validator;
  final MiraWriter _miraWriter;
  final CasResolver? _casResolver;

  McpImportService({
    ManifestReader? manifestReader,
    NdjsonStreamReader? ndjsonReader,
    McpImportValidator? validator,
    MiraWriter? miraWriter,
    CasResolver? casResolver,
  })  : _manifestReader = manifestReader ?? ManifestReader(),
        _ndjsonReader = ndjsonReader ?? NdjsonStreamReader(),
        _validator = validator ?? McpImportValidator(),
        _miraWriter = miraWriter ?? MiraWriter(),
        _casResolver = casResolver;

  /// Import an MCP bundle from the specified directory
  Future<McpImportResult> importBundle(
    Directory bundleDir,
    McpImportOptions options,
  ) async {
    final stopwatch = Stopwatch()..start();
    final warnings = <String>[];
    final errors = <String>[];
    final counts = <String, int>{};

    try {
      // Step 1: Read and validate manifest
      print('📋 Reading manifest...');
      final manifest = await _readAndValidateManifest(bundleDir, errors, warnings);
      if (manifest == null) {
        return McpImportResult(
          success: false,
          message: 'Failed to read or validate manifest',
          counts: counts,
          warnings: warnings,
          errors: errors,
          processingTime: stopwatch.elapsed,
        );
      }

      // Step 2: Verify bundle integrity (checksums)
      print('🔐 Verifying bundle integrity...');
      final integrityValid = await _verifyBundleIntegrity(bundleDir, manifest, errors);
      if (!integrityValid && options.strictMode) {
        return McpImportResult(
          success: false,
          message: 'Bundle integrity check failed',
          counts: counts,
          warnings: warnings,
          errors: errors,
          processingTime: stopwatch.elapsed,
        );
      }

      if (options.dryRun) {
        print('🧪 Dry run mode - validating schemas only...');
        await _validateSchemas(bundleDir, manifest, errors, warnings);
        return McpImportResult(
          success: errors.isEmpty,
          message: 'Dry run completed',
          counts: manifest.counts ?? {},
          warnings: warnings,
          errors: errors,
          processingTime: stopwatch.elapsed,
        );
      }

      // Step 3: Generate batch ID for this import
      final batchId = _generateBatchId(manifest);
      print('🏷️  Import batch ID: $batchId');

      // Step 4: Stream ingest NDJSON tables (order: pointers → embeddings → nodes → edges)
      print('📥 Starting NDJSON ingest...');
      
      // Import pointers first (substrate)
      final pointerCount = await _importPointers(bundleDir, manifest, batchId, errors, warnings, options);
      counts['pointers'] = pointerCount;

      // Import embeddings (lineage tracking)
      final embeddingCount = await _importEmbeddings(bundleDir, manifest, batchId, errors, warnings, options);
      counts['embeddings'] = embeddingCount;

      // Import nodes (SAGE mapping)
      final nodeCount = await _importNodes(bundleDir, manifest, batchId, errors, warnings, options);
      counts['nodes'] = nodeCount;

      // Import edges (relations)
      final edgeCount = await _importEdges(bundleDir, manifest, batchId, errors, warnings, options);
      counts['edges'] = edgeCount;

      // Step 5: Verify counts match manifest
      await _verifyImportCounts(manifest, counts, warnings);

      // Step 6: Rebuild indexes if requested
      if (options.rebuildIndexes) {
        print('🔄 Rebuilding indexes...');
        await _rebuildIndexes(batchId);
      }

      stopwatch.stop();

      final success = errors.length <= options.maxErrors;
      return McpImportResult(
        success: success,
        message: success ? 'Import completed successfully' : 'Import completed with errors',
        counts: counts,
        warnings: warnings,
        errors: errors,
        processingTime: stopwatch.elapsed,
        batchId: batchId,
      );

    } catch (e, stackTrace) {
      stopwatch.stop();
      errors.add('Unexpected error: $e');
      print('❌ Import failed: $e');
      print('Stack trace: $stackTrace');

      return McpImportResult(
        success: false,
        message: 'Import failed with exception: $e',
        counts: counts,
        warnings: warnings,
        errors: errors,
        processingTime: stopwatch.elapsed,
      );
    }
  }

  /// Read and validate the manifest.json file
  Future<McpManifest?> _readAndValidateManifest(
    Directory bundleDir,
    List<String> errors,
    List<String> warnings,
  ) async {
    try {
      final manifest = await _manifestReader.readManifest(bundleDir);
      
      // Validate required fields
      if (manifest.schemaVersion.isEmpty) {
        errors.add('Manifest missing required field: schema_version');
      }
      
      if (manifest.version.isEmpty) {
        errors.add('Manifest missing required field: version');
      }

      if (manifest.createdAt == null) {
        errors.add('Manifest missing required field: created_at');
      }

      // Validate schema version compatibility
      if (!_isSchemaVersionCompatible(manifest.schemaVersion)) {
        errors.add('Incompatible schema version: ${manifest.schemaVersion}');
      }

      // Record warnings for optional sections
      if (manifest.encoderRegistry == null || manifest.encoderRegistry!.isEmpty) {
        warnings.add('Manifest missing encoder_registry - lineage tracking limited');
      }

      if (manifest.casRemotes == null || manifest.casRemotes!.isEmpty) {
        warnings.add('Manifest missing cas_remotes - CAS resolution disabled');
      }

      return errors.isEmpty ? manifest : null;
    } catch (e) {
      errors.add('Failed to read manifest: $e');
      return null;
    }
  }

  /// Verify bundle integrity using checksums
  Future<bool> _verifyBundleIntegrity(
    Directory bundleDir,
    McpManifest manifest,
    List<String> errors,
  ) async {
    if (manifest.checksums == null) {
      errors.add('Manifest missing checksums - cannot verify integrity');
      return false;
    }

    final files = ['nodes.jsonl', 'edges.jsonl', 'pointers.jsonl', 'embeddings.jsonl'];
    bool allValid = true;

    for (final filename in files) {
      final file = File('${bundleDir.path}/$filename');
      if (!file.existsSync()) {
        continue; // Optional files
      }

      final expectedChecksum = manifest.checksums![filename];
      if (expectedChecksum == null) {
        errors.add('Missing checksum for $filename');
        allValid = false;
        continue;
      }

      final bytes = await file.readAsBytes();
      final actualChecksum = sha256.convert(bytes).toString();

      if (actualChecksum != expectedChecksum) {
        errors.add('Checksum mismatch for $filename: expected $expectedChecksum, got $actualChecksum');
        allValid = false;
      }
    }

    return allValid;
  }

  /// Validate schemas for all NDJSON files
  Future<void> _validateSchemas(
    Directory bundleDir,
    McpManifest manifest,
    List<String> errors,
    List<String> warnings,
  ) async {
    final files = {
      'nodes.jsonl': 'node',
      'edges.jsonl': 'edge',
      'pointers.jsonl': 'pointer',
      'embeddings.jsonl': 'embedding',
    };

    for (final entry in files.entries) {
      final file = File('${bundleDir.path}/${entry.key}');
      if (!file.existsSync()) {
        continue;
      }

      try {
        await _validator.validateNdjsonFile(file, entry.value);
      } catch (e) {
        errors.add('Schema validation failed for ${entry.key}: $e');
      }
    }
  }

  /// Import pointers (substrate) - first in order
  Future<int> _importPointers(
    Directory bundleDir,
    McpManifest manifest,
    String batchId,
    List<String> errors,
    List<String> warnings,
    McpImportOptions options,
  ) async {
    final file = File('${bundleDir.path}/pointers.jsonl');
    if (!file.existsSync()) {
      warnings.add('No pointers.jsonl found - skipping pointer import');
      return 0;
    }

    print('📌 Importing pointers...');
    int count = 0;

    await for (final line in _ndjsonReader.readStream(file)) {
      try {
        final pointer = McpPointer.fromJson(jsonDecode(line));
        
        // Validate pointer without requiring source_uri
        if (!_isValidPointer(pointer)) {
          errors.add('Invalid pointer at line ${count + 1}');
          continue;
        }

        // Store pointer as durable substrate
        await _miraWriter.putPointer(pointer, batchId);
        count++;

        if (count % 1000 == 0) {
          print('  Imported $count pointers...');
        }
      } catch (e) {
        errors.add('Failed to import pointer at line ${count + 1}: $e');
        if (errors.length > options.maxErrors) break;
      }
    }

    print('✅ Imported $count pointers');
    return count;
  }

  /// Import embeddings with lineage tracking
  Future<int> _importEmbeddings(
    Directory bundleDir,
    McpManifest manifest,
    String batchId,
    List<String> errors,
    List<String> warnings,
    McpImportOptions options,
  ) async {
    final file = File('${bundleDir.path}/embeddings.jsonl');
    if (!file.existsSync()) {
      warnings.add('No embeddings.jsonl found - skipping embedding import');
      return 0;
    }

    print('🧠 Importing embeddings...');
    int count = 0;

    await for (final line in _ndjsonReader.readStream(file)) {
      try {
        final embedding = McpEmbedding.fromJson(jsonDecode(line));
        
        // Record lineage information
        await _miraWriter.putEmbedding(embedding, batchId);
        count++;

        if (count % 1000 == 0) {
          print('  Imported $count embeddings...');
        }
      } catch (e) {
        errors.add('Failed to import embedding at line ${count + 1}: $e');
        if (errors.length > options.maxErrors) break;
      }
    }

    print('✅ Imported $count embeddings');
    return count;
  }

  /// Import nodes with SAGE mapping
  Future<int> _importNodes(
    Directory bundleDir,
    McpManifest manifest,
    String batchId,
    List<String> errors,
    List<String> warnings,
    McpImportOptions options,
  ) async {
    final file = File('${bundleDir.path}/nodes.jsonl');
    if (!file.existsSync()) {
      errors.add('Required nodes.jsonl file not found');
      return 0;
    }

    print('📝 Importing nodes...');
    int count = 0;

    await for (final line in _ndjsonReader.readStream(file)) {
      try {
        final node = McpNode.fromJson(jsonDecode(line));
        
        // Map SAGE fields to MIRA structure
        await _miraWriter.putNode(node, batchId);
        count++;

        if (count % 1000 == 0) {
          print('  Imported $count nodes...');
        }
      } catch (e) {
        errors.add('Failed to import node at line ${count + 1}: $e');
        if (errors.length > options.maxErrors) break;
      }
    }

    print('✅ Imported $count nodes');
    return count;
  }

  /// Import edges (relations)
  Future<int> _importEdges(
    Directory bundleDir,
    McpManifest manifest,
    String batchId,
    List<String> errors,
    List<String> warnings,
    McpImportOptions options,
  ) async {
    final file = File('${bundleDir.path}/edges.jsonl');
    if (!file.existsSync()) {
      warnings.add('No edges.jsonl found - skipping edge import');
      return 0;
    }

    print('🔗 Importing edges...');
    int count = 0;

    await for (final line in _ndjsonReader.readStream(file)) {
      try {
        final edge = McpEdge.fromJson(jsonDecode(line));
        
        // Store normalized relations
        await _miraWriter.putEdge(edge, batchId);
        count++;

        if (count % 1000 == 0) {
          print('  Imported $count edges...');
        }
      } catch (e) {
        errors.add('Failed to import edge at line ${count + 1}: $e');
        if (errors.length > options.maxErrors) break;
      }
    }

    print('✅ Imported $count edges');
    return count;
  }

  /// Verify import counts match manifest expectations
  Future<void> _verifyImportCounts(
    McpManifest manifest,
    Map<String, int> actualCounts,
    List<String> warnings,
  ) async {
    if (manifest.counts == null) {
      warnings.add('Manifest missing counts - cannot verify import completeness');
      return;
    }

    for (final entry in manifest.counts!.entries) {
      final expected = entry.value;
      final actual = actualCounts[entry.key] ?? 0;
      
      if (actual != expected) {
        warnings.add('Count mismatch for ${entry.key}: expected $expected, imported $actual');
      }
    }
  }

  /// Rebuild indexes after import
  Future<void> _rebuildIndexes(String batchId) async {
    // Time-based indexes
    await _miraWriter.rebuildTimeIndexes(batchId);
    
    // Keyword indexes
    await _miraWriter.rebuildKeywordIndexes(batchId);
    
    // Phase indexes
    await _miraWriter.rebuildPhaseIndexes(batchId);
    
    // Relation indexes
    await _miraWriter.rebuildRelationIndexes(batchId);
  }

  /// Generate a batch ID for this import
  String _generateBatchId(McpManifest manifest) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final manifestHash = sha256.convert(utf8.encode('${manifest.version}-${manifest.createdAt}')).toString().substring(0, 8);
    return 'mcp_import_${timestamp}_$manifestHash';
  }

  /// Check if schema version is compatible
  bool _isSchemaVersionCompatible(String version) {
    // Accept same major version (1.x.x)
    final parts = version.split('.');
    if (parts.isEmpty) return false;
    
    try {
      final major = int.parse(parts[0]);
      return major == 1; // Compatible with MCP v1.x
    } catch (e) {
      return false;
    }
  }

  /// Validate pointer structure
  bool _isValidPointer(McpPointer pointer) {
    // Require ID and descriptor, but not source_uri
    return pointer.id.isNotEmpty && 
           pointer.descriptor != null &&
           pointer.descriptor!.isNotEmpty;
  }
}