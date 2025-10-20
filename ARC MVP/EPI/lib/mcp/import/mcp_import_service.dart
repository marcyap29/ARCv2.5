import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:archive/archive_io.dart';
import 'package:my_app/prism/mcp/import/manifest_reader.dart';
import 'package:my_app/prism/mcp/import/ndjson_stream_reader.dart';
import 'package:my_app/prism/mcp/import/media_link_resolver.dart';
import 'package:my_app/prism/mcp/validation/mcp_import_validator.dart';
import 'package:my_app/prism/mcp/adapters/mira_writer.dart';
import 'package:my_app/prism/mcp/adapters/cas_resolver.dart';
import 'package:my_app/prism/mcp/core/mcp_schemas.dart';
import 'package:my_app/lumara/chat/chat_repo.dart';
import 'package:my_app/lumara/chat/chat_models.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/rivet/validation/rivet_provider.dart';
import 'package:my_app/rivet/models/rivet_models.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/features/arcforms/phase_recommender.dart';
import 'package:my_app/core/services/photo_library_service.dart';
import 'package:my_app/data/models/photo_metadata.dart';

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
  final JournalRepository? _journalRepo;
  
  // Media deduplication cache - maps URI to MediaItem to prevent duplicates
  final Map<String, MediaItem> _mediaCache = {};
  
  // Store photo pointers for linking to journal entries
  final Map<String, McpPointer> _photoPointers = {};
  
  // Media link resolver for thumbnails and SHA-256 linking
  MediaLinkResolver? _mediaLinkResolver;

  McpImportService({
    ManifestReader? manifestReader,
    NdjsonStreamReader? ndjsonReader,
    McpImportValidator? validator,
    MiraWriter? miraWriter,
    CasResolver? casResolver,
    ChatRepo? chatRepo,
    JournalRepository? journalRepo,
  })  : _manifestReader = manifestReader ?? ManifestReader(),
        _ndjsonReader = ndjsonReader ?? NdjsonStreamReader(),
        _validator = validator ?? McpImportValidator(),
        _miraWriter = miraWriter ?? MiraWriter(),
        _casResolver = casResolver,
        _chatRepo = chatRepo,
        _journalRepo = journalRepo;

  /// Clear the media cache (call before starting a new import)
  void clearMediaCache() {
    _mediaCache.clear();
    print('🧹 Cleared media cache for new import');
  }

  /// Import an MCP bundle from the specified directory
  Future<McpImportResult> importBundle(
    Directory bundleDir,
    McpImportOptions options,
  ) async {
    final stopwatch = Stopwatch()..start();
    final warnings = <String>[];
    final errors = <String>[];
    final counts = <String, int>{};
    
    // Clear media cache for this import to prevent duplicates
    clearMediaCache();

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

      // Step 2: Initialize MediaLinkResolver for thumbnail and media pack handling
      print('🔗 Initializing media link resolver...');
      _mediaLinkResolver = MediaLinkResolver(bundleDir: bundleDir.path);
      await _mediaLinkResolver!.initialize();
      print('✅ Media link resolver initialized');

      // Step 3: Verify bundle integrity (checksums)
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

      // Log media deduplication summary
      print('📊 Media Deduplication Summary:');
      print('   Total unique media items cached: ${_mediaCache.length}');
      for (final entry in _mediaCache.entries) {
        print('   - ${entry.value.type.name}: ${entry.key}');
      }

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
        
         // If this is a photo pointer, store it for later linking
         if (pointer.id.startsWith('ptr_photo_')) {
          final metadata = pointer.descriptor.metadata;
          final journalEntryId = metadata['journal_entry_id'] as String?;
          final photoId = metadata['photo_id'] as String?;
          
          if (journalEntryId != null && photoId != null) {
            print('📷 Storing photo pointer for linking: $photoId -> $journalEntryId');
            _photoPointers[photoId] = pointer;
          }
        }
        
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
    // Check for journal_v1.mcp.zip first (new format with media)
    final journalZip = File('${bundleDir.path}/journal_v1.mcp.zip');
    if (await journalZip.exists()) {
      print('📦 Found journal_v1.mcp.zip, using structured import...');
      return await _importFromJournalZip(journalZip, batchId, errors, warnings, options);
    }

    // Fallback to nodes.jsonl (legacy format)
    final file = File('${bundleDir.path}/nodes.jsonl');
    print('🔍 DEBUG: Checking for nodes.jsonl at: ${file.path}');

    if (!file.existsSync()) {
      print('❌ DEBUG: nodes.jsonl file not found at ${file.path}');
      errors.add('Required nodes.jsonl file not found');
      return 0;
    }

    final fileSize = await file.length();
    print('✅ DEBUG: Found nodes.jsonl, size: $fileSize bytes');

    print('📝 Importing nodes from legacy format...');
    int count = 0;
    int journalEntriesImported = 0;
    int totalLines = 0;

    await for (final line in _ndjsonReader.readStream(file)) {
      totalLines++;
      try {
        // Debug: Show the raw line content
        print('🔍 DEBUG: Line $totalLines content (first 200 chars): ${line.length > 200 ? '${line.substring(0, 200)}...' : line}');

        // First decode the JSON
        final jsonData = jsonDecode(line);
        print('🔍 DEBUG: JSON decoded successfully, type: ${jsonData.runtimeType}');

        // Check if the JSON is valid
        if (jsonData == null) {
          print('❌ DEBUG: Line $totalLines contains null JSON');
          errors.add('Line $totalLines contains null JSON');
          continue;
        }

        if (jsonData is! Map<String, dynamic>) {
          print('❌ DEBUG: Line $totalLines JSON is not a Map, type: ${jsonData.runtimeType}');
          errors.add('Line $totalLines JSON is not a Map: ${jsonData.runtimeType}');
          continue;
        }

        print('🔍 DEBUG: JSON keys: ${jsonData.keys.toList()}');

        // Now try to create the McpNode
        final node = McpNode.fromJson(jsonData);
        print('🔍 DEBUG: Processing node ${node.id} of type "${node.type}"');

        // Check if this is a journal entry that needs special handling
        if (node.type == 'journal_entry') {
          print('📄 DEBUG: Found journal_entry node: ${node.id}');
          print('📄 DEBUG: Node has contentSummary: ${node.contentSummary != null && node.contentSummary!.isNotEmpty}');
          print('📄 DEBUG: Node has metadata: ${node.metadata != null}');
          if (node.metadata != null) {
            print('📄 DEBUG: Metadata keys: ${node.metadata!.keys}');
            if (node.metadata!.containsKey('journal_entry')) {
              final journalMeta = node.metadata!['journal_entry'] as Map<String, dynamic>?;
              print('📄 DEBUG: Journal metadata has content: ${journalMeta?['content'] != null}');
            }
          }

          final journalEntry = await _convertMcpNodeToJournalEntry(node);
          if (journalEntry != null) {
            await _importJournalEntry(journalEntry);
            journalEntriesImported++;
            print('✅ DEBUG: Successfully imported journal entry: ${journalEntry.title}');
          } else {
            print('❌ DEBUG: Failed to convert node ${node.id} to journal entry');
          }
        }

        // Map SAGE fields to MIRA structure
        await _miraWriter.putNode(node, batchId);
        count++;

        if (count % 100 == 0) {  // More frequent logging
          print('  Imported $count nodes...');
        }
      } catch (e, stackTrace) {
        print('❌ DEBUG: Error processing line $totalLines: $e');
        print('❌ DEBUG: Stack trace: $stackTrace');
        errors.add('Failed to import node at line $totalLines: $e');
        if (errors.length > options.maxErrors) break;
      }
    }

    print('✅ DEBUG: Total lines read from nodes.jsonl: $totalLines');
    print('✅ Imported $count nodes ($journalEntriesImported journal entries)');
    return count;
  }

  /// Import nodes from journal_v1.mcp.zip (new format with media)
  Future<int> _importFromJournalZip(
    File journalZip,
    String batchId,
    List<String> errors,
    List<String> warnings,
    McpImportOptions options,
  ) async {
    try {
      // Extract journal ZIP to a temporary directory
      final tempDir = Directory('${journalZip.parent.path}/journal_extracted');
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      await tempDir.create(recursive: true);

      print('📂 Extracting journal ZIP to: ${tempDir.path}');
      await extractFileToDisk(journalZip.path, tempDir.path);

      // Read entries directory
      final entriesDir = Directory('${tempDir.path}/entries');
      if (!await entriesDir.exists()) {
        print('❌ No entries directory found in journal ZIP');
        errors.add('No entries directory found in journal ZIP');
        return 0;
      }

      print('📝 Importing entries from journal ZIP...');
      int count = 0;
      int journalEntriesImported = 0;

      await for (final entryFile in entriesDir.list()) {
        if (entryFile is File && entryFile.path.endsWith('.json')) {
          try {
            final contents = await entryFile.readAsString();
            final entryJson = jsonDecode(contents) as Map<String, dynamic>;
            
            // Create McpNode from entry JSON
            final timestampValue = entryJson['timestamp'] as String?;
            final parsedTimestamp = timestampValue != null 
                ? DateTime.parse(timestampValue)
                : DateTime.now();
            
            print('🕐 DEBUG: Entry ${entryJson['id']} timestamp: $timestampValue -> $parsedTimestamp');
            
            final node = McpNode(
              id: entryJson['id'] as String,
              type: 'journal_entry',
              contentSummary: entryJson['content'] as String? ?? '',
              timestamp: parsedTimestamp,
              metadata: {
                'journal_entry': {
                  'content': entryJson['content'],
                  'media': entryJson['media'] ?? [],
                },
                ...?entryJson['metadata'] as Map<String, dynamic>?,
              },
              emotions: {},
              keywords: [],
              narrative: null,
              phaseHint: null,
              provenance: McpProvenance(
                source: 'mcp_import',
                app: 'EPI',
                importMethod: 'journal_zip',
              ),
            );

            // Convert to journal entry and import
            final journalEntry = await _convertMcpNodeToJournalEntry(node);
            if (journalEntry != null) {
              await _importJournalEntry(journalEntry);
              journalEntriesImported++;
              print('✅ Imported journal entry: ${journalEntry.title}');
            }

            // Map SAGE fields to MIRA structure
            await _miraWriter.putNode(node, batchId);
            count++;

            if (count % 10 == 0) {
              print('  Imported $count entries...');
            }
          } catch (e, stackTrace) {
            print('❌ Error processing entry file ${entryFile.path}: $e');
            print('Stack trace: $stackTrace');
            errors.add('Failed to import entry ${entryFile.path}: $e');
            if (errors.length > options.maxErrors) break;
          }
        }
      }

      // Clean up temp directory
      await tempDir.delete(recursive: true);

      print('✅ Imported $count entries from journal ZIP ($journalEntriesImported journal entries)');
      return count;
    } catch (e, stackTrace) {
      print('❌ Error importing from journal ZIP: $e');
      print('Stack trace: $stackTrace');
      errors.add('Failed to import from journal ZIP: $e');
      return 0;
    }
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
      subject: node.contentSummary ?? _extractNarrativeText(node.narrative) ?? 'Imported Session',
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
    String role = MessageRole.user; // Default

    // Check if we can infer the role from the narrative or metadata
    final content = _extractNarrativeText(node.narrative) ?? node.contentSummary ?? '';
    if (content.toLowerCase().contains('assistant:') ||
        content.toLowerCase().startsWith('ai:') ||
        content.toLowerCase().contains('lumara:')) {
      role = MessageRole.assistant;
    }

    return ChatMessage.createLegacy(
      id: '', // Will be generated by repository
      sessionId: '', // Will be set during import
      role: role,
      content: content,
      createdAt: node.timestamp,
    );
  }

  /// Extract text content from McpNarrative
  String? _extractNarrativeText(McpNarrative? narrative) {
    if (narrative == null) return null;
    
    // Combine all narrative fields into a single text
    final parts = <String>[];
    if (narrative.situation != null) parts.add('Situation: ${narrative.situation}');
    if (narrative.action != null) parts.add('Action: ${narrative.action}');
    if (narrative.growth != null) parts.add('Growth: ${narrative.growth}');
    if (narrative.essence != null) parts.add('Essence: ${narrative.essence}');
    
    return parts.isNotEmpty ? parts.join('\n') : null;
  }

  /// Convert MCP Node to JournalEntry
  Future<JournalEntry?> _convertMcpNodeToJournalEntry(McpNode node) async {
    try {
      print('🔄 DEBUG: Converting node ${node.id} to journal entry');

      // Extract content from the node - check multiple possible locations
      String content = '';
      String title = 'Imported Entry';

      // Try to get content from the node's content field or metadata
      if (node.contentSummary != null && node.contentSummary!.isNotEmpty) {
        content = node.contentSummary!;
        print('🔄 DEBUG: Got content from contentSummary: ${content.length} chars');
      } else if (node.narrative != null) {
        content = _extractNarrativeText(node.narrative) ?? '';
        print('🔄 DEBUG: Got content from narrative: ${content.length} chars');
      }
      
      // Check for content in the original JSON data (for nodes imported from JSON)
      if (content.isEmpty && node.metadata != null) {
        final originalContent = node.metadata!['content'] as String?;
        if (originalContent != null && originalContent.isNotEmpty) {
          content = originalContent;
          print('🔄 DEBUG: Got content from metadata.content: ${content.length} chars');
        }
      }

      // Early fallback to metadata.content if content is still missing
      if (content.isEmpty && node.metadata != null) {
        final metaContent = node.metadata!['content'] as String?;
        if (metaContent != null && metaContent.isNotEmpty) {
          content = metaContent;
          print('🔄 DEBUG: Got content from metadata.content: ${content.length} chars');
        }
      }

      // Check if there's content or title in metadata
      if (node.metadata != null) {
        print('🔄 DEBUG: Node metadata keys: ${node.metadata!.keys}');

        // Check for journal metadata (used by export)
        if (node.metadata!.containsKey('journal_entry')) {
          final journalEntryMeta = node.metadata!['journal_entry'] as Map<String, dynamic>?;
          if (journalEntryMeta != null) {
            final metaContent = journalEntryMeta['content'] as String?;
            if (metaContent != null && metaContent.isNotEmpty) {
              content = metaContent;
              print('🔄 DEBUG: Got content from journal_entry metadata: ${content.length} chars');
            }

            final metaTitle = journalEntryMeta['title'] as String?;
            if (metaTitle != null && metaTitle.isNotEmpty) {
              title = metaTitle;
              print('🔄 DEBUG: Got title from journal_entry metadata: $title');
            }
          }
        }

        // Also check legacy journal format
        final journalData = node.metadata!['journal'] as Map<String, dynamic>?;
        if (journalData != null) {
          final legacyContent = journalData['text'] as String?;
          if (legacyContent != null && legacyContent.isNotEmpty && content.isEmpty) {
            content = legacyContent;
            print('🔄 DEBUG: Got content from legacy journal metadata: ${content.length} chars');
          }
        }


        // Try to get title from top-level metadata
        final titleFromMeta = node.metadata!['title'] as String?;
        if (titleFromMeta != null && titleFromMeta.isNotEmpty) {
          title = titleFromMeta;
          print('🔄 DEBUG: Got title from top-level metadata: $title');
        }
      }

      // If we still don't have content, skip this entry
      if (content.isEmpty) {
        print('❌ DEBUG: Skipping journal entry ${node.id} - no content found');
        print('❌ DEBUG: ContentSummary: ${node.contentSummary}');
        print('❌ DEBUG: Narrative: ${node.narrative}');
        print('❌ DEBUG: Metadata: ${node.metadata}');
        return null;
      }

      print('✅ DEBUG: Successfully extracted content: ${content.length} chars, title: $title');
      print('🔄 DEBUG: Node keywords: ${node.keywords}');
      
      // Process photo placeholders in content and reconstruct media items
      final processedContent = await _processPhotoPlaceholders(content, node);
      final mediaItems = await _extractMediaFromPlaceholders(content, node);
      
      print('🔄 DEBUG: Processed content length: ${processedContent.length} chars');
      print('🔄 DEBUG: Extracted ${mediaItems.length} media items from placeholders');
      
      // Extract emotions from node
      String mood = 'Neutral';
      String? emotion;
      String? emotionReason;
      
      if (node.emotions.isNotEmpty) {
        // Use the first emotion as the mood
        final firstEmotion = node.emotions.keys.first;
        mood = firstEmotion;
        emotion = firstEmotion;
        emotionReason = 'Imported from MCP';
      }
      
      // Check metadata for emotion info
      if (node.metadata != null) {
        final emotionsData = node.metadata!['emotions'] as Map<String, dynamic>?;
        if (emotionsData != null) {
          mood = emotionsData['mood'] as String? ?? mood;
          emotion = emotionsData['primary'] as String? ?? emotion;
          emotionReason = emotionsData['reason'] as String? ?? emotionReason;
        }
      }
      
      // Create the journal entry
      return JournalEntry(
        id: _extractOriginalId(node.id),
        title: title,
        content: processedContent,
        createdAt: node.timestamp,
        updatedAt: node.timestamp,
        media: mediaItems,
        tags: node.keywords,
        keywords: node.keywords, // Use node keywords for insights
        mood: mood,
        emotion: emotion,
        emotionReason: emotionReason,
        metadata: {
          'imported_from_mcp': true,
          'original_mcp_id': node.id,
          'import_timestamp': DateTime.now().toIso8601String(),
          'phase_hint': node.phaseHint,
        },
      );
    } catch (e) {
      print('  Failed to convert MCP node ${node.id} to journal entry: $e');
      return null;
    }
  }

  /// Extract original ID from MCP node ID (remove prefixes like 'entry_', 'je_', etc.)
  String _extractOriginalId(String mcpId) {
    // Remove common prefixes
    if (mcpId.startsWith('entry_')) {
      return mcpId.substring(6);
    } else if (mcpId.startsWith('je_')) {
      return mcpId.substring(3);
    }
    return mcpId;
  }

  /// Import a journal entry into the journal repository
  Future<void> _importJournalEntry(JournalEntry entry) async {
    print('  DEBUG: _importJournalEntry called for entry: ${entry.title}');
    try {
      if (_journalRepo == null) {
        print('  Warning: No journal repository available - cannot import journal entry: ${entry.title}');
        return;
      }
      
      // Store the journal entry in the repository
      await _journalRepo!.createJournalEntry(entry);
      print('  Stored journal entry: ${entry.title}');
      
      // Create RIVET event for the imported entry
      print('  DEBUG: Creating RIVET event for imported entry...');
      await _createRivetEventForEntry(entry);
      
    } catch (e) {
      print('  Failed to import journal entry ${entry.id}: $e');
    }
  }
  
  /// Create RIVET event for imported journal entry
  Future<void> _createRivetEventForEntry(JournalEntry entry) async {
    print('  DEBUG: _createRivetEventForEntry called for entry: ${entry.title}');
    try {
      const userId = 'default_user'; // TODO: Use actual user ID
      
      // Get current phase from user profile
      print('  DEBUG: Getting current user phase...');
      final currentPhase = await _getCurrentUserPhase();
      print('  DEBUG: Current phase: $currentPhase');
      if (currentPhase == null) {
        print('  Warning: No current phase found, skipping RIVET event creation');
        return;
      }
      
      // Get recommended phase from PhaseRecommender
      final recommendedPhase = PhaseRecommender.recommend(
        emotion: '', // No emotion data from MCP import
        reason: '', // No reason data from MCP import
        text: entry.content,
        selectedKeywords: entry.keywords,
      );
      
      // Create RIVET event
      final rivetEvent = RivetEvent(
        date: entry.createdAt,
        source: EvidenceSource.text,
        keywords: entry.keywords.toSet(),
        predPhase: recommendedPhase,
        refPhase: currentPhase,
        tolerance: const {}, // Stub for categorical phases
      );
      
      // Submit to RIVET
      final rivetProvider = RivetProvider();
      print('  DEBUG: RIVET provider isAvailable: ${rivetProvider.isAvailable}');

      if (!rivetProvider.isAvailable) {
        print('  DEBUG: RIVET provider not available, attempting to initialize...');
        await rivetProvider.initialize(userId);
        print('  DEBUG: RIVET provider isAvailable after init: ${rivetProvider.isAvailable}');
      }

      if (rivetProvider.isAvailable) {
        print('  DEBUG: Submitting RIVET event to provider...');
        final decision = await rivetProvider.safeIngest(rivetEvent, userId);
        print('  RIVET event created for imported entry: ${entry.title}');
        print('  RIVET decision: ${decision != null && decision.open ? "OPEN" : "CLOSED"}');
        print('  RIVET decision details: $decision');
      } else {
        print('  ERROR: RIVET provider still not available after initialization attempt');
        print('  ERROR: Init error: ${rivetProvider.initError}');
      }
      
    } catch (e) {
      print('  Failed to create RIVET event for entry ${entry.id}: $e');
    }
  }
  
  /// Get current user phase
  Future<String?> _getCurrentUserPhase() async {
    try {
      // Import UserPhaseService
      final currentPhase = await UserPhaseService.getCurrentPhase();
      return currentPhase;
    } catch (e) {
      print('  Error getting current user phase: $e');
      return null;
    }
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

  /// Process photo placeholders in content and reconstruct media items
  Future<String> _processPhotoPlaceholders(String content, McpNode node) async {
    // For now, just return the content as-is
    // The placeholders will be processed by the timeline display
    return content;
  }

  /// Extract media items from photo placeholders in content
  Future<List<MediaItem>> _extractMediaFromPlaceholders(String content, McpNode node) async {
    final mediaItems = <MediaItem>[];

    print('🔍 MCP Import: Extracting media from placeholders for node ${node.id}');
    
    // Try to get media from root level (captured in metadata)
    if (node.metadata != null && node.metadata!.containsKey('media')) {
      final mediaData = node.metadata!['media'] as List?;
      if (mediaData != null && mediaData.isNotEmpty) {
        print('🔄 Found ${mediaData.length} media items at root level');
        
        // Group by type for validation
        final mediaByType = <String, int>{};
        int newMediaCount = 0;
        int reusedMediaCount = 0;
        
        for (int i = 0; i < mediaData.length; i++) {
          final mediaJson = mediaData[i];
          if (mediaJson is Map<String, dynamic>) {
            try {
              print('🔍 Media $i JSON: $mediaJson');
              final uri = mediaJson['uri'] as String;
              
              // Check if we already have this media item (deduplication)
              if (_mediaCache.containsKey(uri)) {
                final cachedMediaItem = _mediaCache[uri]!;
                mediaItems.add(cachedMediaItem);
                reusedMediaCount++;
                print('♻️ Reusing cached media: ${cachedMediaItem.id} -> $uri');
              } else {
                // Create new media item and cache it
                final mediaItem = await _parseMediaItemFromJson(mediaJson, node);
                _mediaCache[uri] = mediaItem;
                mediaItems.add(mediaItem);
                newMediaCount++;
                
                // Track by type
                mediaByType[mediaItem.type.name] = (mediaByType[mediaItem.type.name] ?? 0) + 1;
                
                // Validate URI preservation
                final originalUri = mediaJson['uri'] as String;
                if (mediaItem.uri != originalUri) {
                  print('⚠️ WARNING: URI mismatch for media ${mediaItem.id}');
                  print('⚠️   Expected: $originalUri');
                  print('⚠️   Got: ${mediaItem.uri}');
                }
                
                print('✅ Created new ${mediaItem.type.name}: ${mediaItem.id} -> ${mediaItem.uri}');
              }
            } catch (e) {
              print('⚠️ Failed to parse media item $i: $e');
            }
          }
        }
        
        print('🔍 MCP Import: Successfully extracted ${mediaItems.length} media items (${newMediaCount} new, ${reusedMediaCount} reused) by type: $mediaByType');
        return mediaItems;
      }
    }

    // Also check for media in journal_entry metadata (legacy support)
    if (node.metadata != null && node.metadata!.containsKey('journal_entry')) {
      final journalMeta = node.metadata!['journal_entry'] as Map<String, dynamic>?;
      if (journalMeta != null && journalMeta.containsKey('media')) {
        final mediaData = journalMeta['media'] as List?;
        if (mediaData != null && mediaData.isNotEmpty) {
          print('🔄 DEBUG: Found ${mediaData.length} media items in journal_entry metadata');
          int newMediaCount = 0;
          int reusedMediaCount = 0;
          
          for (int i = 0; i < mediaData.length; i++) {
            final mediaJson = mediaData[i];
            if (mediaJson is Map<String, dynamic>) {
              try {
                print('🔍 Journal Media $i JSON: $mediaJson');
                final uri = mediaJson['uri'] as String;
                
                // Check if we already have this media item (deduplication)
                if (_mediaCache.containsKey(uri)) {
                  final cachedMediaItem = _mediaCache[uri]!;
                  mediaItems.add(cachedMediaItem);
                  reusedMediaCount++;
                  print('♻️ Reusing cached journal media: ${cachedMediaItem.id} -> $uri');
                } else {
                  // Create new media item and cache it
                  final mediaItem = await _parseMediaItemFromJson(mediaJson, node);
                  _mediaCache[uri] = mediaItem;
                  mediaItems.add(mediaItem);
                  newMediaCount++;
                  print('✅ Created new journal media: ${mediaItem.id} -> ${mediaItem.uri}');
                }
              } catch (e) {
                print('⚠️ DEBUG: Failed to parse journal media item $i: $e');
              }
            }
          }
          print('🔍 MCP Import: Successfully extracted ${mediaItems.length} media items (${newMediaCount} new, ${reusedMediaCount} reused) from journal_entry metadata');
          return mediaItems;
        }
      }
    }

    // Fallback: Find photo placeholders in content and try to match with metadata
    final photoPlaceholderRegex = RegExp(r'\[PHOTO:([^\]]+)\]');
    final matches = photoPlaceholderRegex.allMatches(content);

    for (final match in matches) {
      final photoId = match.group(1)!;

      // Try to find corresponding media in node metadata
      final mediaItem = await _findMediaForPhotoId(photoId, node);
      if (mediaItem != null) {
        mediaItems.add(mediaItem);
        print('🔄 DEBUG: Reconstructed media item for photo ID: $photoId');
      } else {
        print('⚠️ DEBUG: Could not find media for photo ID: $photoId');
      }
    }

    return mediaItems;
  }

  /// Parse MediaItem from JSON export format
  Future<MediaItem> _parseMediaItemFromJson(Map<String, dynamic> json, McpNode node) async {
    print('🔍 MCP Import: Parsing media item: ${json['id']} (${json['type']})');
    print('🔍 MCP Import: Media URI: ${json['uri']}');
    
    String finalUri = json['uri'] as String;
    String? localThumbPath;
    
    // Check if this media item has MCP media fields
    final sha256 = json['sha256'] as String?;
    final thumbUri = json['thumbUri'] as String?;
    final fullRef = json['fullRef'] as String?;
    
    // If we have a MediaLinkResolver and SHA-256, get the local thumbnail path
    if (_mediaLinkResolver != null && sha256 != null) {
      localThumbPath = _mediaLinkResolver!.getThumbnailPath(sha256);
      if (localThumbPath != null) {
        print('✅ MCP Import: Found local thumbnail for SHA-256: $sha256');
      }
    }
    
         // If this is a ph:// URI, try robust relinking
         if (finalUri.startsWith('ph://')) {
           try {
             print('🔄 MCP Import: Attempting robust relink for ${json['id']}');
             print('🔄 MCP Import: Original URI: $finalUri');
             
             // Create PhotoMetadata from available data
             final photoMetadata = PhotoMetadata(
               localIdentifier: finalUri.replaceFirst('ph://', ''),
               cloudIdentifier: json['cloud_identifier'] as String?,
               creationDate: json['created_at'] != null 
                   ? DateTime.parse(json['created_at'] as String)
                   : node.timestamp,
               filename: json['original_filename'] as String?,
               pixelWidth: json['analysis_data']?['params']?['width'] as int?,
               pixelHeight: json['analysis_data']?['params']?['height'] as int?,
               perceptualHash: json['analysis_data']?['features']?['phash'] as String?,
             );
             
             // Use robust relinking algorithm
             final relinkedUri = await PhotoLibraryService.robustPhotoRelink(photoMetadata);
             
             if (relinkedUri != null) {
               finalUri = relinkedUri;
               print('✅ MCP Import: Robust relink successful: $relinkedUri');
             } else {
               print('⚠️ MCP Import: Robust relink failed, keeping original URI: $finalUri');
             }
             
           } catch (e) {
             print('⚠️ MCP Import: Error in robust relink: $e');
             // Fall back to original URI
           }
         } else {
           print('🔍 MCP Import: Non-ph:// URI: $finalUri');
         }
    
    final mediaItem = MediaItem(
      id: json['id'] as String,
      uri: finalUri, // Updated URI (new ph:// or temp file)
      type: _parseMediaType(json['type'] as String?),
      duration: json['duration'] != null 
        ? Duration(seconds: json['duration'] as int) 
        : null,
      sizeBytes: json['size_bytes'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : node.timestamp,
      transcript: json['transcript'] as String?,
      altText: json['alt_text'] as String?,
      ocrText: json['ocr_text'] as String?,
      analysisData: json['analysis_data'] as Map<String, dynamic>?,
      sha256: sha256,
      thumbUri: localThumbPath ?? thumbUri, // Use local path if available
      fullRef: fullRef,
    );

    print('✅ MCP Import: Created MediaItem with final URI: ${mediaItem.uri}');
    if (mediaItem.isMcpMedia) {
      print('✅ MCP Import: Media is MCP media with SHA-256: ${mediaItem.sha256}');
      print('✅ MCP Import: Thumbnail URI: ${mediaItem.thumbUri}');
    }
    return mediaItem;
  }

  /// Parse MediaType from string
  MediaType _parseMediaType(String? typeString) {
    switch (typeString?.toLowerCase()) {
      case 'image':
        return MediaType.image;
      case 'audio':
        return MediaType.audio;
      case 'video':
        return MediaType.video;
      case 'file':
        return MediaType.file;
      default:
        return MediaType.image; // Default to image
    }
  }

  /// Find media item for a photo ID from node metadata
  Future<MediaItem?> _findMediaForPhotoId(String photoId, McpNode node) async {
    print('🔍 MCP Import: Looking for photo ID: $photoId');
    
    // First, try to find photo pointer
    if (_photoPointers.containsKey(photoId)) {
      final pointer = _photoPointers[photoId]!;
      print('🔍 MCP Import: Found photo pointer for $photoId');
      
      // Create MediaItem from pointer
      final mediaItem = MediaItem(
        id: photoId,
        uri: pointer.sourceUri ?? 'placeholder://$photoId',
        type: _parseMediaType(pointer.mediaType),
        createdAt: pointer.integrity.createdAt,
        sizeBytes: pointer.integrity.bytes,
        altText: pointer.descriptor.metadata['alt_text'] as String?,
        ocrText: pointer.descriptor.metadata['ocr_text'] as String?,
        analysisData: pointer.descriptor.metadata['analysis_data'] as Map<String, dynamic>?,
      );
      
      // Try to relink the photo
      final relinkedItem = await _relinkPhotoFromPointer(mediaItem, pointer);
      return relinkedItem;
    }
    
    // Try to find media in node metadata by matching photo ID
    if (node.metadata != null && node.metadata!.containsKey('media')) {
      final mediaData = node.metadata!['media'] as List?;
      if (mediaData != null) {
        for (final mediaJson in mediaData) {
          if (mediaJson is Map<String, dynamic>) {
            final mediaId = mediaJson['id'] as String?;
            if (mediaId == photoId) {
              print('🔍 MCP Import: Found media in metadata.media for $photoId');
              return await _parseMediaItemFromJson(mediaJson, node);
            }
          }
        }
      }
    }

    // Legacy support: Extract from node metadata if no photo pointer exists
    print('🔍 MCP Import: No photo pointer found, trying legacy metadata extraction');
    return await _extractMediaFromLegacyNode(photoId, node);
  }

  /// Extract media from legacy node metadata (for MCP files without photo pointers)
  Future<MediaItem?> _extractMediaFromLegacyNode(String photoId, McpNode node) async {
    print('🔍 MCP Import: Extracting media from legacy node for $photoId');

    // Try to find media in node metadata by matching photo ID
    if (node.metadata != null && node.metadata!.containsKey('media')) {
      final mediaData = node.metadata!['media'] as List?;
      if (mediaData != null) {
        for (final mediaJson in mediaData) {
          if (mediaJson is Map<String, dynamic>) {
            final mediaId = mediaJson['id'] as String?;
            if (mediaId == photoId) {
              print('🔍 MCP Import: Found media in metadata.media for $photoId');
              return await _parseMediaItemFromJson(mediaJson, node);
            }
          }
        }
      }
    }

    // Try photos array
    if (node.metadata != null && node.metadata!.containsKey('photos')) {
      final photosData = node.metadata!['photos'] as List?;
      if (photosData != null) {
        for (final photoJson in photosData) {
          if (photoJson is Map<String, dynamic>) {
            final placeholderId = photoJson['placeholder_id'] as String?;
            if (placeholderId == photoId) {
              print('🔍 MCP Import: Found photo metadata for $photoId');
              return await _reconstructFromPlaceholder(photoId, photoJson, node);
            }
          }
        }
      }
    }

    // If no metadata found, try to reconstruct using timestamp fallback
    print('🔍 MCP Import: No metadata found for $photoId, trying timestamp fallback');
    final fallbackMetadata = metaFromPlaceholder(photoId);
    return await _reconstructFromPlaceholder(photoId, fallbackMetadata, node);
  }

         /// Relink photo from pointer metadata using robust 4-step algorithm
         Future<MediaItem> _relinkPhotoFromPointer(MediaItem mediaItem, McpPointer pointer) async {
           print('🔄 MCP Import: Attempting robust relink for photo: ${mediaItem.id}');

           // Create PhotoMetadata from pointer metadata
           final metadata = pointer.descriptor.metadata;
           final photoMetadata = PhotoMetadata(
             localIdentifier: metadata['local_identifier'] as String? ?? 
                 (mediaItem.uri.startsWith('ph://') ? mediaItem.uri.replaceFirst('ph://', '') : ''),
             cloudIdentifier: metadata['cloud_identifier'] as String?,
             creationDate: mediaItem.createdAt,
             filename: metadata['original_filename'] as String?,
             pixelWidth: metadata['analysis_data']?['params']?['width'] as int?,
             pixelHeight: metadata['analysis_data']?['params']?['height'] as int?,
             perceptualHash: metadata['analysis_data']?['features']?['phash'] as String?,
           );

           // Use robust relinking algorithm
           final relinkedUri = await PhotoLibraryService.robustPhotoRelink(photoMetadata);
           
           if (relinkedUri != null) {
             print('✅ MCP Import: Robust relink successful: $relinkedUri');
             return MediaItem(
               id: mediaItem.id,
               uri: relinkedUri,
               type: mediaItem.type,
               createdAt: mediaItem.createdAt,
               sizeBytes: mediaItem.sizeBytes,
               altText: mediaItem.altText,
               ocrText: mediaItem.ocrText,
               analysisData: mediaItem.analysisData,
             );
           } else {
             print('⚠️ MCP Import: Robust relink failed, keeping original URI: ${mediaItem.uri}');
             return mediaItem;
           }
         }

  /// Extract metadata from placeholder timestamp
  Map<String, dynamic> metaFromPlaceholder(String placeholderId) {
    // placeholderId: "photo_1760654962279"
    final parts = placeholderId.split('_');
    if (parts.length == 2) {
      final ms = int.tryParse(parts[1]);
      if (ms != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
        return {
          'placeholder_id': placeholderId,
          'creation_date': dt.toIso8601String(),
          'local_identifier': null,
          'pixel_width': null,
          'pixel_height': null,
          'filename': null,
          'uniform_type_identifier': null,
          'perceptual_hash': null,
        };
      }
    }
    return {'placeholder_id': placeholderId};
  }

  /// Reconstruct media from placeholder using photo metadata
  Future<MediaItem> _reconstructFromPlaceholder(
    String placeholderId,
    Map<String, dynamic> photoMetadata,
    McpNode node,
  ) async {
    print('🔄 MCP Import: Attempting to reconnect photo $placeholderId using metadata');
    
    String? uri; // final media URI we will store

    // Use fallback metadata if the provided metadata is empty or only has placeholder_id
    Map<String, dynamic> effectiveMetadata = photoMetadata;
    if (photoMetadata.isEmpty || (photoMetadata.length == 1 && photoMetadata.containsKey('placeholder_id'))) {
      print('🔍 MCP Import: Using timestamp-derived metadata for $placeholderId');
      effectiveMetadata = metaFromPlaceholder(placeholderId);
    }

    // 1) Fast path: local_identifier present
    final localId = effectiveMetadata['local_identifier'] as String?;
    if (localId != null && localId.isNotEmpty) {
      print('🔍 MCP Import: Checking if original photo exists: ph://$localId');
      final exists = await PhotoLibraryService.photoExistsInLibrary('ph://$localId');
      if (exists) {
        uri = 'ph://$localId';
        print('✅ MCP Import: Original photo still exists: $uri');
      } else {
        print('⚠️ MCP Import: Original photo not found, will try metadata search');
      }
    }

    // 2) Relink by metadata (date → dims → filename → pHash)
    if (uri == null && effectiveMetadata.isNotEmpty) {
      print('🔍 MCP Import: Attempting metadata-based reconnection');
      try {
        final photoMetadataObj = PhotoMetadata.fromJson(effectiveMetadata);
        final resolved = await PhotoLibraryService.findPhotoByMetadata(photoMetadataObj);
        if (resolved != null && resolved.startsWith('ph://')) {
          uri = resolved;
          print('✅ MCP Import: Found photo by metadata: $uri');
        } else {
          print('⚠️ MCP Import: Could not find photo by metadata');
        }
      } catch (e) {
        print('⚠️ MCP Import: Error creating PhotoMetadata object: $e');
      }
    }

    // 3) Last resort: keep as placeholder (UI will show relink affordance)
    uri ??= 'placeholder://$placeholderId';
    print('🔍 MCP Import: Final URI for $placeholderId: $uri');

    return MediaItem(
      id: placeholderId,
      type: MediaType.image,
      uri: uri,
      createdAt: node.timestamp,
      altText: uri.startsWith('ph://')
          ? 'Photo reconnected'
          : 'Photo unavailable - tap to relink',
      analysisData: uri.startsWith('ph://')
          ? {'photo_id': placeholderId, 'imported': true, 'placeholder': false}
          : {'photo_id': placeholderId, 'imported': true, 'placeholder': true, 'unavailable': true},
    );
  }

}
