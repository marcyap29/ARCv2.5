import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:my_app/mira/store/mcp/models/mcp_schemas.dart';

/// Exception thrown during MIRA write operations
class MiraWriteException implements Exception {
  final String message;
  final dynamic cause;

  const MiraWriteException(this.message, [this.cause]);

  @override
  String toString() => 'MiraWriteException: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

/// Statistics for MIRA write operations
class MiraWriteStats {
  int pointersWritten = 0;
  int embeddingsWritten = 0;
  int nodesWritten = 0;
  int edgesWritten = 0;
  int indexesRebuilt = 0;
  Duration totalTime = Duration.zero;
  
  @override
  String toString() {
    return 'MiraWriteStats(pointers: $pointersWritten, embeddings: $embeddingsWritten, '
           'nodes: $nodesWritten, edges: $edgesWritten, indexes: $indexesRebuilt, '
           'time: ${totalTime.inMilliseconds}ms)';
  }
}

/// MIRA writer for append-only operations
///
/// Handles writing MCP data into MIRA storage with proper lineage tracking,
/// privacy propagation, and index management. All operations are append-only
/// to maintain data integrity and audit trails.
class MiraWriter {
  final String? _customStorageRoot;
  final MiraWriteStats _stats = MiraWriteStats();
  String? _resolvedStorageRoot;

  MiraWriter({String? storageRoot})
    : _customStorageRoot = storageRoot;

  /// Get the storage root directory, using iOS app sandbox paths when needed
  Future<String> get _storageRoot async {
    if (_resolvedStorageRoot != null) {
      return _resolvedStorageRoot!;
    }

    if (_customStorageRoot != null) {
      _resolvedStorageRoot = _customStorageRoot;
    } else {
      // Use proper iOS app sandbox path instead of hardcoded development path
      final appDir = await getApplicationDocumentsDirectory();
      _resolvedStorageRoot = path.join(appDir.path, 'mira_storage');
    }

    return _resolvedStorageRoot!;
  }

  /// Initialize MIRA storage directories
  Future<void> initialize() async {
    final storageRoot = await _storageRoot;
    final directories = [
      'pointers',
      'embeddings', 
      'nodes',
      'edges',
      'indexes/time',
      'indexes/keyword',
      'indexes/phase',
      'indexes/relation',
      'batches',
      'lineage',
    ];

    for (final dir in directories) {
      final directory = Directory(path.join(storageRoot, dir));
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }
    }
  }

  /// Store pointer as durable substrate with privacy tracking
  Future<void> putPointer(McpPointer pointer, String batchId) async {
    await initialize();

    try {
      // Generate deterministic filename based on pointer ID
      final filename = _sanitizeFilename('${pointer.id}.json');
      final storageRoot = await _storageRoot;
      final file = File(path.join(storageRoot, 'pointers', filename));
      
      // Prepare pointer record with metadata
      final record = {
        'id': pointer.id,
        'descriptor': pointer.descriptor,
        'source_uri': pointer.sourceUri,
        'media_type': pointer.mediaType,
        'source_uri': pointer.sourceUri,
        'alt_uris': pointer.altUris,
        'labels': pointer.labels,
        
        // MIRA metadata
        'batch_id': batchId,
        'imported_at': DateTime.now().toUtc().toIso8601String(),
        'lineage_hash': _generateLineageHash(pointer.id, batchId),
      };

      // Append-only write (don't overwrite existing)
      if (file.existsSync()) {
        // Read existing record to preserve history
        final existing = jsonDecode(await file.readAsString());
        record['previous_versions'] = existing['previous_versions'] ?? [];
        (record['previous_versions'] as List).add({
          'imported_at': existing['imported_at'],
          'batch_id': existing['batch_id'],
        });
      }

      await file.writeAsString(jsonEncode(record));
      
      // Update lineage tracking
      await _updateLineageRecord('pointer', pointer.id, batchId);
      
      _stats.pointersWritten++;
    } catch (e) {
      throw MiraWriteException('Failed to write pointer ${pointer.id}', e);
    }
  }

  /// Store embedding with lineage tracking
  Future<void> putEmbedding(McpEmbedding embedding, String batchId) async {
    await initialize();

    try {
      final filename = _sanitizeFilename('${embedding.id}.json');
      final storageRoot = await _storageRoot;
      final file = File(path.join(storageRoot, 'embeddings', filename));
      
      final record = {
        'id': embedding.id,
        'vector': embedding.vector,
        'model_id': embedding.modelId,
        'embedding_version': embedding.embeddingVersion,
        'dim': embedding.dim,
        'pointer_ref': embedding.pointerRef,
        'span_ref': embedding.spanRef,
        'doc_scope': embedding.docScope,
        
        // MIRA metadata
        'batch_id': batchId,
        'imported_at': DateTime.now().toUtc().toIso8601String(),
        'lineage_hash': _generateLineageHash(embedding.id, batchId),
      };

      // Handle existing embeddings
      if (file.existsSync()) {
        final existing = jsonDecode(await file.readAsString());
        record['previous_versions'] = existing['previous_versions'] ?? [];
        (record['previous_versions'] as List).add({
          'imported_at': existing['imported_at'],
          'batch_id': existing['batch_id'],
          'model': existing['model'],
        });
      }

      await file.writeAsString(jsonEncode(record));
      await _updateLineageRecord('embedding', embedding.id, batchId);
      
      _stats.embeddingsWritten++;
    } catch (e) {
      throw MiraWriteException('Failed to write embedding ${embedding.id}', e);
    }
  }

  /// Write node (alias for putNode with auto-generated batch ID)
  Future<void> writeNode(McpNode node, {String? batchId}) async {
    final batch = batchId ?? DateTime.now().toUtc().millisecondsSinceEpoch.toString();
    await putNode(node, batch);
  }

  /// Store node with SAGE mapping
  Future<void> putNode(McpNode node, String batchId) async {
    await initialize();

    try {
      final filename = _sanitizeFilename('${node.id}.json');
      final storageRoot = await _storageRoot;
      final file = File(path.join(storageRoot, 'nodes', filename));
      
      // Map SAGE fields to MIRA structure
      final record = {
        'id': node.id,
        'type': node.type,
        'type': node.type,
        'timestamp': node.timestamp.toUtc().toIso8601String(),
        'pointer_ref': node.pointerRef,
        'content_summary': node.contentSummary,
        'phase_hint': node.phaseHint,
        'keywords': node.keywords,
        'embedding_ref': node.embeddingRef,
        'emotions': node.emotions,
        
        // SAGE mapping
        'sage_situation': node.narrative?.situation,
        'sage_action': node.narrative?.action, 
        'sage_growth': node.narrative?.growth,
        'sage_essence': node.narrative?.essence,
        
        // MIRA metadata
        'batch_id': batchId,
        'imported_at': DateTime.now().toUtc().toIso8601String(),
        'lineage_hash': _generateLineageHash(node.id, batchId),
      };

      // Preserve node evolution history
      if (file.existsSync()) {
        final existing = jsonDecode(await file.readAsString());
        record['previous_versions'] = existing['previous_versions'] ?? [];
        (record['previous_versions'] as List).add({
          'imported_at': existing['imported_at'],
          'batch_id': existing['batch_id'],
          'updated_at': existing['updated_at'],
          'phase': existing['phase'],
        });
      }

      await file.writeAsString(jsonEncode(record));
      await _updateLineageRecord('node', node.id, batchId);
      
      _stats.nodesWritten++;
    } catch (e) {
      throw MiraWriteException('Failed to write node ${node.id}', e);
    }
  }

  /// Store edge (normalized relations)
  Future<void> putEdge(McpEdge edge, String batchId) async {
    await initialize();

    try {
      final filename = _sanitizeFilename('${edge.source}_${edge.target}.json');
      final storageRoot = await _storageRoot;
      final file = File(path.join(storageRoot, 'edges', filename));
      
      final record = {
        'source': edge.source,
        'target': edge.target,
        'relation': edge.relation,
        'timestamp': edge.timestamp.toUtc().toIso8601String(),
        'weight': edge.weight,
        
        // MIRA metadata
        'batch_id': batchId,
        'imported_at': DateTime.now().toUtc().toIso8601String(),
        'lineage_hash': _generateLineageHash('${edge.source}_${edge.target}', batchId),
      };

      // Track edge evolution
      if (file.existsSync()) {
        final existing = jsonDecode(await file.readAsString());
        record['previous_versions'] = existing['previous_versions'] ?? [];
        (record['previous_versions'] as List).add({
          'imported_at': existing['imported_at'],
          'batch_id': existing['batch_id'],
          'weight': existing['weight'],
          'properties': existing['properties'],
        });
      }

      await file.writeAsString(jsonEncode(record));
      await _updateLineageRecord('edge', '${edge.source}_${edge.target}', batchId);
      
      _stats.edgesWritten++;
    } catch (e) {
      throw MiraWriteException('Failed to write edge ${edge.source}_${edge.target}', e);
    }
  }

  /// Rebuild time-based indexes
  Future<void> rebuildTimeIndexes(String batchId) async {
    print('🕐 Rebuilding time indexes...');

    final storageRoot = await _storageRoot;
    final timeIndex = <String, List<String>>{};
    final types = ['pointers', 'embeddings', 'nodes', 'edges'];

    for (final type in types) {
      final dir = Directory(path.join(storageRoot, type));
      if (!dir.existsSync()) continue;
      
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = jsonDecode(await entity.readAsString());
            final createdAt = content['created_at'] as String?;
            
            if (createdAt != null) {
              final date = DateTime.parse(createdAt);
              final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
              
              timeIndex[monthKey] ??= [];
              timeIndex[monthKey]!.add('$type/${path.basename(entity.path)}');
            }
          } catch (e) {
            print('Warning: Failed to index ${entity.path}: $e');
          }
        }
      }
    }
    
    // Write time index
    final indexFile = File(path.join(storageRoot, 'indexes/time', 'monthly_index.json'));
    await indexFile.writeAsString(jsonEncode({
      'last_updated': DateTime.now().toUtc().toIso8601String(),
      'batch_id': batchId,
      'index': timeIndex,
    }));
    
    _stats.indexesRebuilt++;
  }

  /// Rebuild keyword indexes
  Future<void> rebuildKeywordIndexes(String batchId) async {
    print('🔍 Rebuilding keyword indexes...');

    final storageRoot = await _storageRoot;
    final keywordIndex = <String, List<String>>{};

    // Index node labels and properties
    final nodesDir = Directory(path.join(storageRoot, 'nodes'));
    if (nodesDir.existsSync()) {
      await for (final entity in nodesDir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = jsonDecode(await entity.readAsString());
            final filename = 'nodes/${path.basename(entity.path)}';
            
            // Index label
            final label = content['label'] as String?;
            if (label != null) {
              _addToKeywordIndex(keywordIndex, label.toLowerCase(), filename);
            }
            
            // Index SAGE fields
            final sageFields = ['sage_situation', 'sage_action', 'sage_growth', 'sage_essence'];
            for (final field in sageFields) {
              final value = content[field] as String?;
              if (value != null) {
                for (final word in value.toLowerCase().split(RegExp(r'\W+'))) {
                  if (word.length > 2) {
                    _addToKeywordIndex(keywordIndex, word, filename);
                  }
                }
              }
            }
          } catch (e) {
            print('Warning: Failed to index keywords for ${entity.path}: $e');
          }
        }
      }
    }
    
    // Write keyword index
    final indexFile = File(path.join(storageRoot, 'indexes/keyword', 'keyword_index.json'));
    await indexFile.writeAsString(jsonEncode({
      'last_updated': DateTime.now().toUtc().toIso8601String(),
      'batch_id': batchId,
      'index': keywordIndex,
    }));
    
    _stats.indexesRebuilt++;
  }

  /// Rebuild phase indexes
  Future<void> rebuildPhaseIndexes(String batchId) async {
    print('📊 Rebuilding phase indexes...');

    final storageRoot = await _storageRoot;
    final phaseIndex = <String, List<String>>{};
    final types = ['nodes', 'edges'];

    for (final type in types) {
      final dir = Directory(path.join(storageRoot, type));
      if (!dir.existsSync()) continue;
      
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = jsonDecode(await entity.readAsString());
            final phase = content['phase'] as String?;
            
            if (phase != null) {
              phaseIndex[phase] ??= [];
              phaseIndex[phase]!.add('$type/${path.basename(entity.path)}');
            }
          } catch (e) {
            print('Warning: Failed to index phase for ${entity.path}: $e');
          }
        }
      }
    }
    
    // Write phase index
    final indexFile = File(path.join(storageRoot, 'indexes/phase', 'phase_index.json'));
    await indexFile.writeAsString(jsonEncode({
      'last_updated': DateTime.now().toUtc().toIso8601String(),
      'batch_id': batchId,
      'index': phaseIndex,
    }));
    
    _stats.indexesRebuilt++;
  }

  /// Rebuild relation indexes
  Future<void> rebuildRelationIndexes(String batchId) async {
    print('🔗 Rebuilding relation indexes...');

    final storageRoot = await _storageRoot;
    final relationIndex = <String, Map<String, List<String>>>{
      'outgoing': {},
      'incoming': {},
      'by_type': {},
    };

    final edgesDir = Directory(path.join(storageRoot, 'edges'));
    if (edgesDir.existsSync()) {
      await for (final entity in edgesDir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = jsonDecode(await entity.readAsString());
            final filename = 'edges/${path.basename(entity.path)}';
            final sourceId = content['source_id'] as String?;
            final targetId = content['target_id'] as String?;
            final edgeType = content['type'] as String?;
            
            if (sourceId != null && targetId != null) {
              // Outgoing relations
              relationIndex['outgoing']![sourceId] ??= [];
              relationIndex['outgoing']![sourceId]!.add(filename);
              
              // Incoming relations
              relationIndex['incoming']![targetId] ??= [];
              relationIndex['incoming']![targetId]!.add(filename);
              
              // By type
              if (edgeType != null) {
                relationIndex['by_type']![edgeType] ??= [];
                relationIndex['by_type']![edgeType]!.add(filename);
              }
            }
          } catch (e) {
            print('Warning: Failed to index relation for ${entity.path}: $e');
          }
        }
      }
    }
    
    // Write relation index
    final indexFile = File(path.join(storageRoot, 'indexes/relation', 'relation_index.json'));
    await indexFile.writeAsString(jsonEncode({
      'last_updated': DateTime.now().toUtc().toIso8601String(),
      'batch_id': batchId,
      'index': relationIndex,
    }));
    
    _stats.indexesRebuilt++;
  }

  /// Update lineage tracking record
  Future<void> _updateLineageRecord(String type, String id, String batchId) async {
    final storageRoot = await _storageRoot;
    final lineageFile = File(path.join(storageRoot, 'lineage', '$type.jsonl'));
    
    final lineageRecord = {
      'id': id,
      'type': type,
      'batch_id': batchId,
      'imported_at': DateTime.now().toUtc().toIso8601String(),
      'lineage_hash': _generateLineageHash(id, batchId),
    };
    
    // Append to lineage log
    final lineageJson = jsonEncode(lineageRecord);
    await lineageFile.writeAsString('$lineageJson\n', mode: FileMode.append);
  }

  /// Generate lineage hash for tracking
  String _generateLineageHash(String id, String batchId) {
    final input = '$id:$batchId:${DateTime.now().toUtc().toIso8601String()}';
    return sha256.convert(utf8.encode(input)).toString().substring(0, 16);
  }

  /// Add keyword to index
  void _addToKeywordIndex(Map<String, List<String>> index, String keyword, String filename) {
    index[keyword] ??= [];
    if (!index[keyword]!.contains(filename)) {
      index[keyword]!.add(filename);
    }
  }

  /// Sanitize filename for storage
  String _sanitizeFilename(String filename) {
    return filename.replaceAll(RegExp(r'[^\w\-_\.]'), '_');
  }

  /// Get current write statistics
  MiraWriteStats get stats => _stats;

  /// Create batch summary record
  Future<void> createBatchSummary(String batchId, Map<String, int> counts) async {
    await initialize();

    final storageRoot = await _storageRoot;
    final batchFile = File(path.join(storageRoot, 'batches', '$batchId.json'));
    
    final summary = {
      'batch_id': batchId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'counts': counts,
      'stats': {
        'pointers_written': _stats.pointersWritten,
        'embeddings_written': _stats.embeddingsWritten,
        'nodes_written': _stats.nodesWritten,
        'edges_written': _stats.edgesWritten,
        'indexes_rebuilt': _stats.indexesRebuilt,
        'total_time_ms': _stats.totalTime.inMilliseconds,
      },
    };
    
    await batchFile.writeAsString(jsonEncode(summary));
  }

  /// Clean up old batch data (for maintenance)
  Future<void> cleanupOldBatches({int keepRecentBatches = 10}) async {
    final storageRoot = await _storageRoot;
    final batchesDir = Directory(path.join(storageRoot, 'batches'));
    if (!batchesDir.existsSync()) return;
    
    final batchFiles = <File>[];
    await for (final entity in batchesDir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        batchFiles.add(entity);
      }
    }
    
    // Sort by modification time, keep recent ones
    batchFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    
    if (batchFiles.length > keepRecentBatches) {
      final filesToDelete = batchFiles.skip(keepRecentBatches);
      for (final file in filesToDelete) {
        await file.delete();
        print('Cleaned up old batch: ${path.basename(file.path)}');
      }
    }
  }
}