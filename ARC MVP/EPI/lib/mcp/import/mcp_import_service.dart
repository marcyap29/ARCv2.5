import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:my_app/mcp/import/manifest_reader.dart';
import 'package:my_app/mcp/import/ndjson_stream_reader.dart';
import 'package:my_app/mcp/validation/mcp_import_validator.dart';
import 'package:my_app/mcp/adapters/mira_writer.dart';
import 'package:my_app/mcp/adapters/cas_resolver.dart';
import 'package:my_app/mcp/models/mcp_schemas.dart';
import 'package:my_app/lumara/chat/chat_repo.dart';
import 'package:my_app/lumara/chat/chat_models.dart';

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
  final ChatRepo? _chatRepo;

  McpImportService({
    ManifestReader? manifestReader,
    NdjsonStreamReader? ndjsonReader,
    McpImportValidator? validator,
    MiraWriter? miraWriter,
    CasResolver? casResolver,
    ChatRepo? chatRepo,
  })  : _manifestReader = manifestReader ?? ManifestReader(),
        _ndjsonReader = ndjsonReader ?? NdjsonStreamReader(),
        _validator = validator ?? McpImportValidator(),
        _miraWriter = miraWriter ?? MiraWriter(),
        _casResolver = casResolver,
        _chatRepo = chatRepo;

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
              counts: {
                'nodes': manifest.counts.nodes,
                'edges': manifest.counts.edges,
                'pointers': manifest.counts.pointers,
                'embeddings': manifest.counts.embeddings,
              },
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

      // Step 4.5: Import chat data if chat repository is available
      if (_chatRepo != null) {
        final chatCounts = await _importChatData(bundleDir, manifest, batchId, errors, warnings, options);
        counts['chat_sessions'] = chatCounts['sessions'] ?? 0;
        counts['chat_messages'] = chatCounts['messages'] ?? 0;
        print('📱 Imported ${chatCounts['sessions']} chat sessions, ${chatCounts['messages']} messages');
      }

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

      // Validate schema version compatibility
      if (!_isSchemaVersionCompatible(manifest.schemaVersion)) {
        errors.add('Incompatible schema version: ${manifest.schemaVersion}');
      }

      // Record warnings for optional sections
      if (manifest.encoderRegistry.isEmpty) {
        warnings.add('Manifest missing encoder_registry - lineage tracking limited');
      }

      if (manifest.casRemotes.isEmpty) {
        warnings.add('Manifest missing cas_remotes - CAS resolution disabled');
      }

      return errors.isEmpty ? manifest : null;
    } catch (e) {
      errors.add('Failed to read manifest: $e');
      return null;
    }
  }

  /// Get checksum for a specific file from manifest
  String? _getChecksumForFile(McpChecksums checksums, String filename) {
    switch (filename) {
      case 'nodes.jsonl':
        return checksums.nodesJsonl;
      case 'edges.jsonl':
        return checksums.edgesJsonl;
      case 'pointers.jsonl':
        return checksums.pointersJsonl;
      case 'embeddings.jsonl':
        return checksums.embeddingsJsonl;
      case 'vectors.parquet':
        return checksums.vectorsParquet;
      default:
        return null;
    }
  }

  /// Verify bundle integrity using checksums
  Future<bool> _verifyBundleIntegrity(
    Directory bundleDir,
    McpManifest manifest,
    List<String> errors,
  ) async {
    final files = ['nodes.jsonl', 'edges.jsonl', 'pointers.jsonl', 'embeddings.jsonl'];
    bool allValid = true;

    for (final filename in files) {
      final file = File('${bundleDir.path}/$filename');
      if (!file.existsSync()) {
        continue; // Optional files
      }

          final expectedChecksum = _getChecksumForFile(manifest.checksums, filename);
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

  /// Import chat data (sessions and messages)
  Future<Map<String, int>> _importChatData(
    Directory bundleDir,
    McpManifest manifest,
    String batchId,
    List<String> errors,
    List<String> warnings,
    McpImportOptions options,
  ) async {
    if (_chatRepo == null) {
      warnings.add('No chat repository available - skipping chat data import');
      return {'sessions': 0, 'messages': 0};
    }

    final file = File('${bundleDir.path}/nodes.jsonl');
    if (!file.existsSync()) {
      warnings.add('No nodes.jsonl found - skipping chat import');
      return {'sessions': 0, 'messages': 0};
    }

    print('📱 Importing chat data...');
    int sessionCount = 0;
    int messageCount = 0;

    final sessionNodes = <McpNode>[];
    final messageNodes = <McpNode>[];

    // First pass: collect chat nodes
    await for (final line in _ndjsonReader.readStream(file)) {
      try {
        final node = McpNode.fromJson(jsonDecode(line));

        if (node.type == 'ChatSession') {
          sessionNodes.add(node);
        } else if (node.type == 'ChatMessage') {
          messageNodes.add(node);
        }
      } catch (e) {
        errors.add('Failed to parse node for chat import: $e');
        if (errors.length > options.maxErrors) break;
      }
    }

    // Import chat sessions
    final sessionMap = <String, String>{}; // MCP ID -> Chat ID mapping
    for (final node in sessionNodes) {
      try {
        final chatSession = await _convertMcpNodeToChatSession(node);
        final sessionId = await _chatRepo!.createSession(
          subject: chatSession.subject,
          tags: chatSession.tags,
        );

        // Store mapping for message imports
        sessionMap[node.id] = sessionId;
        sessionCount++;

        if (sessionCount % 100 == 0) {
          print('  Imported $sessionCount chat sessions...');
        }
      } catch (e) {
        errors.add('Failed to import chat session ${node.id}: $e');
        if (errors.length > options.maxErrors) break;
      }
    }

    // Import chat messages (requires sessions to exist first)
    for (final node in messageNodes) {
      try {
        final chatMessage = await _convertMcpNodeToChatMessage(node);

        // Find the session this message belongs to by looking at edges
        final sessionId = await _findSessionForMessage(bundleDir, node.id, sessionMap);
        if (sessionId == null) {
          warnings.add('No session found for message ${node.id} - skipping');
          continue;
        }

        await _chatRepo!.addMessage(
          sessionId: sessionId,
          role: chatMessage.role,
          content: chatMessage.content,
        );

        messageCount++;

        if (messageCount % 500 == 0) {
          print('  Imported $messageCount chat messages...');
        }
      } catch (e) {
        errors.add('Failed to import chat message ${node.id}: $e');
        if (errors.length > options.maxErrors) break;
      }
    }

    print('✅ Imported $sessionCount chat sessions, $messageCount chat messages');
    return {'sessions': sessionCount, 'messages': messageCount};
  }

  /// Convert MCP Node to ChatSession
  Future<ChatSession> _convertMcpNodeToChatSession(McpNode node) async {
    return ChatSession(
      id: '', // Will be generated by repository
      subject: node.contentSummary ?? node.narrative ?? 'Imported Session',
      createdAt: node.timestamp,
      updatedAt: node.timestamp,
      isPinned: false,
      isArchived: false,
      archivedAt: null,
      tags: node.keywords,
      messageCount: 0, // Will be updated as messages are added
    );
  }

  /// Convert MCP Node to ChatMessage
  Future<ChatMessage> _convertMcpNodeToChatMessage(McpNode node) async {
    // Determine role from node metadata or content analysis
    MessageRole role = MessageRole.user; // Default

    // Check if we can infer the role from the narrative or metadata
    final content = node.narrative ?? node.contentSummary ?? '';
    if (content.toLowerCase().contains('assistant:') ||
        content.toLowerCase().startsWith('ai:') ||
        content.toLowerCase().contains('lumara:')) {
      role = MessageRole.assistant;
    }

    return ChatMessage(
      id: '', // Will be generated by repository
      sessionId: '', // Will be set during import
      role: role,
      content: content,
      createdAt: node.timestamp,
      metadata: {
        'imported_from_mcp': true,
        'original_mcp_id': node.id,
        'import_timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Find the session ID for a message by looking at contains edges
  Future<String?> _findSessionForMessage(
    Directory bundleDir,
    String messageNodeId,
    Map<String, String> sessionMap,
  ) async {
    final edgesFile = File('${bundleDir.path}/edges.jsonl');
    if (!edgesFile.existsSync()) {
      return null;
    }

    await for (final line in _ndjsonReader.readStream(edgesFile)) {
      try {
        final edge = McpEdge.fromJson(jsonDecode(line));

        // Look for contains relationship where target is our message
        if (edge.relation == 'contains' && edge.target == messageNodeId) {
          // The source should be a session node
          final sessionId = sessionMap[edge.source];
          if (sessionId != null) {
            return sessionId;
          }
        }
      } catch (e) {
        // Skip malformed edges
        continue;
      }
    }

    return null;
  }

  /// Verify import counts match manifest expectations
  Future<void> _verifyImportCounts(
    McpManifest manifest,
    Map<String, int> actualCounts,
    List<String> warnings,
  ) async {
    final expectedCounts = {
      'nodes': manifest.counts.nodes,
      'edges': manifest.counts.edges,
      'pointers': manifest.counts.pointers,
      'embeddings': manifest.counts.embeddings,
    };
    
    for (final entry in expectedCounts.entries) {
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
           (pointer.descriptor.isNotEmpty ?? false);
  }
}