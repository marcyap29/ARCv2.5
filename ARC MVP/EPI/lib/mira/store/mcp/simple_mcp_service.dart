// lib/mcp/simple_mcp_service.dart
// Simplified MCP service that handles all export/import operations

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:path/path.dart' as path;
import 'package:my_app/mira/core/mira_repo.dart';
import 'package:my_app/mira/core/schema.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/arc/core/sage_annotation_model.dart';
import 'adapters/journal_entry_projector.dart';
import 'package:my_app/mira/store/mcp/adapters/from_mira.dart' as mira_adapter;

/// Simplified MCP service that handles all export/import operations
class SimpleMcpService {
  final MiraRepo _miraRepo;
  final JournalRepository _journalRepo;

  SimpleMcpService({
    required MiraRepo miraRepo,
    required JournalRepository journalRepo,
  }) : _miraRepo = miraRepo, _journalRepo = journalRepo;

  /// Export all journal entries to MCP format
  Future<Directory> exportToMcp({
    required Directory outputDir,
    String storageProfile = 'hi_fidelity',
    bool includeEvents = false,
  }) async {
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final nodesSink = File(path.join(outputDir.path, 'nodes.jsonl')).openWrite();
    final edgesSink = File(path.join(outputDir.path, 'edges.jsonl')).openWrite();
    final pointersSink = File(path.join(outputDir.path, 'pointers.jsonl')).openWrite();
    final embeddingsSink = File(path.join(outputDir.path, 'embeddings.jsonl')).openWrite();

    final nodesDigest = AccumulatorSink<Digest>();
    final edgesDigest = AccumulatorSink<Digest>();
    final pointersDigest = AccumulatorSink<Digest>();
    final embeddingsDigest = AccumulatorSink<Digest>();
    
    final nodesHashSink = sha256.startChunkedConversion(nodesDigest);
    final edgesHashSink = sha256.startChunkedConversion(edgesDigest);
    final pointersHashSink = sha256.startChunkedConversion(pointersDigest);
    final embeddingsHashSink = sha256.startChunkedConversion(embeddingsDigest);

    int nodesCount = 0, edgesCount = 0, pointersCount = 0, embeddingsCount = 0;
    int nodesBytes = 0, edgesBytes = 0, pointersBytes = 0, embeddingsBytes = 0;

    final emittedIds = <String>{}; // Track IDs already emitted by projector

    try {
      print('🔍 Simple MCP: Starting export to: ${outputDir.path}');

      // Check if we have any journal entries to export
      final journalRepo = JournalRepository();
      final allEntries = journalRepo.getAllJournalEntries();
      
      if (allEntries.isEmpty) {
        print('🔍 Simple MCP: No journal entries found, creating minimal export');
        
        // Create minimal manifest
        final manifest = {
          'bundle_id': 'mcp_${DateTime.now().millisecondsSinceEpoch}',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'schema_version': '1.0.0',
          'storage_profile': storageProfile,
          'include_events': includeEvents,
          'files': {
            'nodes': {
              'path': 'nodes.jsonl',
              'count': 0,
              'bytes': 0,
              'sha256': hex.encode(sha256.convert(utf8.encode('')).bytes),
            },
            'edges': {
              'path': 'edges.jsonl',
              'count': 0,
              'bytes': 0,
              'sha256': hex.encode(sha256.convert(utf8.encode('')).bytes),
            },
            'pointers': {
              'path': 'pointers.jsonl',
              'count': 0,
              'bytes': 0,
              'sha256': hex.encode(sha256.convert(utf8.encode('')).bytes),
            },
            'embeddings': {
              'path': 'embeddings.jsonl',
              'count': 0,
              'bytes': 0,
              'sha256': hex.encode(sha256.convert(utf8.encode('')).bytes),
            },
          },
        };

        final manifestFile = File(path.join(outputDir.path, 'manifest.json'));
        await manifestFile.writeAsString(
          JsonEncoder.withIndent('  ').convert(manifest),
        );
        
        print('🔍 Simple MCP: Created minimal export with no journal entries');
        return outputDir;
      }
      
      // 1. Project journal entries using McpEntryProjector
      print('🔍 Simple MCP: Projecting journal entries...');
      final projected = await McpEntryProjector.projectAll();
      print('🔍 Simple MCP: Projected ${projected.length} records');

      for (final rec in projected) {
        final kind = rec['kind'];
        final line = '${JsonEncoder.withIndent(null, (o) => o).convert(_sortKeys(rec))}\n';
        final bytes = utf8.encode(line);
        final id = rec['id'] as String?;
        if (id != null) emittedIds.add(id);

        print('🔍 Simple MCP: Writing record kind=$kind, id=$id, size=${bytes.length} bytes');

        switch (kind) {
          case 'node':
            nodesSink.add(bytes);
            nodesHashSink.add(bytes);
            nodesBytes += bytes.length;
            nodesCount++;
            break;
          case 'edge':
            edgesSink.add(bytes);
            edgesHashSink.add(bytes);
            edgesBytes += bytes.length;
            edgesCount++;
            break;
          case 'pointer':
            pointersSink.add(bytes);
            pointersHashSink.add(bytes);
            pointersBytes += bytes.length;
            pointersCount++;
            break;
          case 'embedding':
            embeddingsSink.add(bytes);
            embeddingsHashSink.add(bytes);
            embeddingsBytes += bytes.length;
            embeddingsCount++;
            break;
        }
      }

      // 2. Process additional MIRA data (if any)
      print('🔍 Simple MCP: Processing additional MIRA data...');
      try {
        // Use exportAll() to get any additional MIRA data
        bool hasMiraData = false;
        await for (final rec in _miraRepo.exportAll()) {
          hasMiraData = true;
          final kind = rec['kind'];
          final String? recId = rec['id'] as String?;
          
          if (recId != null && emittedIds.contains(recId)) {
            print('🔍 Simple MCP: Skipping already emitted record: $recId');
            continue; // Skip journal entries already processed by McpEntryProjector
          }

          Map<String, dynamic> outRec = rec;
          
          if (kind == 'node') {
            final nodeId = rec['id'] as String?;
            if (nodeId != null && nodeId.startsWith('je_')) {
              // Skip journal entry nodes already processed by projector
              continue;
            }
            
            try {
              final node = MiraNode(
                id: rec['id'] as String,
                type: NodeType.values[(rec['type'] as num).toInt()],
                schemaVersion: (rec['schemaVersion'] as num).toInt(),
                data: Map<String, dynamic>.from(rec['data'] ?? const <String, dynamic>{}),
                createdAt: DateTime.parse(rec['createdAt'] as String).toUtc(),
                updatedAt: DateTime.parse(rec['updatedAt'] as String).toUtc(),
              );
              outRec = mira_adapter.MiraToMcpAdapter.nodeToMcp(node);
            } catch (e) {
              print('⚠️ Simple MCP: Error processing MIRA node: $e');
              outRec = rec;
            }
          } else if (kind == 'edge') {
            try {
              final edge = MiraEdge(
                id: rec['id'] as String,
                src: rec['src'] as String,
                dst: rec['dst'] as String,
                label: EdgeType.values[(rec['label'] as num).toInt()],
                schemaVersion: (rec['schemaVersion'] as num).toInt(),
                data: Map<String, dynamic>.from(rec['data'] ?? const <String, dynamic>{}),
                createdAt: DateTime.parse(rec['createdAt'] as String).toUtc(),
              );
              outRec = mira_adapter.MiraToMcpAdapter.edgeToMcp(edge);
            } catch (e) {
              print('⚠️ Simple MCP: Error processing MIRA edge: $e');
              outRec = rec;
            }
          }

          // Write the processed record
          final line = '${JsonEncoder.withIndent(null, (o) => o).convert(_sortKeys(outRec))}\n';
          final bytes = utf8.encode(line);
          final id = outRec['id'] as String?;
          if (id != null) emittedIds.add(id);

          print('🔍 Simple MCP: Writing MIRA record kind=$kind, id=$id, size=${bytes.length} bytes');

          switch (kind) {
            case 'node':
              nodesSink.add(bytes);
              nodesHashSink.add(bytes);
              nodesBytes += bytes.length;
              nodesCount++;
              break;
            case 'edge':
              edgesSink.add(bytes);
              edgesHashSink.add(bytes);
              edgesBytes += bytes.length;
              edgesCount++;
              break;
            case 'pointer':
              pointersSink.add(bytes);
              pointersHashSink.add(bytes);
              pointersBytes += bytes.length;
              pointersCount++;
              break;
            case 'embedding':
              embeddingsSink.add(bytes);
              embeddingsHashSink.add(bytes);
              embeddingsBytes += bytes.length;
              embeddingsCount++;
              break;
          }
        }
        
        if (!hasMiraData) {
          print('🔍 Simple MCP: No additional MIRA data found');
        }
      } catch (e) {
        print('⚠️ Simple MCP: Error accessing MIRA data: $e - continuing with journal entries only');
      }

    } catch (e, stackTrace) {
      print('🔍 Simple MCP: Error during export: $e');
      print('🔍 Stack trace: $stackTrace');
    } finally {
      // Close all streams
      await nodesSink.close();
      await edgesSink.close();
      await pointersSink.close();
      await embeddingsSink.close();
    }

    // Generate manifest
    final manifest = {
      'bundle_id': 'mcp_${DateTime.now().millisecondsSinceEpoch}',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'schema_version': '1.0.0',
      'storage_profile': storageProfile,
      'include_events': includeEvents,
      'files': {
        'nodes': {
          'path': 'nodes.jsonl',
          'count': nodesCount,
          'bytes': nodesBytes,
          'sha256': nodesDigest.events.isNotEmpty
              ? hex.encode(nodesDigest.events.first.bytes)
              : hex.encode(sha256.convert(utf8.encode('')).bytes),
        },
        'edges': {
          'path': 'edges.jsonl',
          'count': edgesCount,
          'bytes': edgesBytes,
          'sha256': edgesDigest.events.isNotEmpty
              ? hex.encode(edgesDigest.events.first.bytes)
              : hex.encode(sha256.convert(utf8.encode('')).bytes),
        },
        'pointers': {
          'path': 'pointers.jsonl',
          'count': pointersCount,
          'bytes': pointersBytes,
          'sha256': pointersDigest.events.isNotEmpty
              ? hex.encode(pointersDigest.events.first.bytes)
              : hex.encode(sha256.convert(utf8.encode('')).bytes),
        },
        'embeddings': {
          'path': 'embeddings.jsonl',
          'count': embeddingsCount,
          'bytes': embeddingsBytes,
          'sha256': embeddingsDigest.events.isNotEmpty
              ? hex.encode(embeddingsDigest.events.first.bytes)
              : hex.encode(sha256.convert(utf8.encode('')).bytes),
        },
      },
    };

    nodesHashSink.close();
    edgesHashSink.close();
    pointersHashSink.close();
    embeddingsHashSink.close();

    final manifestFile = File(path.join(outputDir.path, 'manifest.json'));
    await manifestFile.writeAsString(
      JsonEncoder.withIndent('  ').convert(manifest),
    );

    print('🔍 Simple MCP: Export completed');
    print('🔍 Simple MCP: nodes=$nodesCount bytes=$nodesBytes, edges=$edgesCount bytes=$edgesBytes, pointers=$pointersCount bytes=$pointersBytes, embeddings=$embeddingsCount bytes=$embeddingsBytes');

    return outputDir;
  }

  /// Import journal entries from MCP format
  Future<int> importFromMcp(Directory inputDir) async {
    print('🔍 Simple MCP: Starting import from: ${inputDir.path}');

    final nodesFile = File(path.join(inputDir.path, 'nodes.jsonl'));
    if (!await nodesFile.exists()) {
      print('🔍 Simple MCP: No nodes.jsonl found, skipping import');
      return 0;
    }

    final lines = await nodesFile.readAsLines();
    int importedCount = 0;

    for (int i = 0; i < lines.length; i++) {
      try {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final nodeData = jsonDecode(line) as Map<String, dynamic>;
        final nodeType = nodeData['type'] as String?;

        print('🔍 Simple MCP: Processing node type: $nodeType');

        if (nodeType == 'journal_entry') {
          // Import journal entry
          final success = await _importJournalEntry(nodeData);
          if (success) {
            importedCount++;
            print('🔍 Simple MCP: ✅ Successfully imported journal entry');
          } else {
            print('🔍 Simple MCP: ❌ Failed to import journal entry');
          }
        } else if (nodeType == 'ChatMessage') {
          // TODO: Import LUMARA chat message - requires direct Hive access
          print('🔍 Simple MCP: Skipping chat message import (not implemented yet)');
        } else if (nodeType == 'ChatSession') {
          // TODO: Import LUMARA chat session - requires direct Hive access
          print('🔍 Simple MCP: Skipping chat session import (not implemented yet)');
        } else {
          print('🔍 Simple MCP: Skipping unsupported node type: $nodeType');
        }
      } catch (e) {
        print('🔍 Simple MCP: Error processing line ${i + 1}: $e');
      }
    }

    print('🔍 Simple MCP: Import completed, imported $importedCount entries');
    return importedCount;
  }

  /// Import a single journal entry from MCP node data
  Future<bool> _importJournalEntry(Map<String, dynamic> nodeData) async {
    try {
      final content = nodeData['content'] as Map<String, dynamic>? ?? {};
      
      // Extract basic entry data
      final title = content['title'] as String? ?? 'Imported Entry';
      final text = content['text'] as String? ?? '';
      final timestamp = DateTime.parse(nodeData['timestamp'] as String);
      
      // Extract timeline data if available
      final timelineData = content['timeline'] as Map<String, dynamic>? ?? {};
      final location = timelineData['location'] as String?;
      final phase = timelineData['phase'] as String?;
      final customDate = timelineData['custom_date'] != null 
          ? DateTime.parse(timelineData['custom_date'] as String)
          : timestamp;
      
      // Extract SAGE annotation if present
      final narrative = content['narrative'] as Map<String, dynamic>?;
      SAGEAnnotation? sageAnnotation;
      if (narrative != null) {
        sageAnnotation = SAGEAnnotation(
          situation: narrative['situation'] as String? ?? '',
          action: narrative['action'] as String? ?? '',
          growth: narrative['growth'] as String? ?? '',
          essence: narrative['essence'] as String? ?? '',
          confidence: narrative['confidence'] as double? ?? 0.0,
        );
      }
      
      // Extract media items
      final mediaItems = <MediaItem>[];
      final mediaData = content['media'] as List<dynamic>? ?? [];
      for (final media in mediaData) {
        if (media is Map<String, dynamic>) {
          final mediaItem = MediaItem(
            id: media['id'] as String? ?? '',
            uri: media['uri'] as String? ?? media['path'] as String? ?? '', // Try uri first, fallback to path for compatibility
            type: _parseMediaType(media['type'] as String?),
            duration: media['duration'] != null 
                ? Duration(seconds: media['duration'] as int)
                : null,
            sizeBytes: media['size'] as int?,
            createdAt: media['createdAt'] != null 
                ? DateTime.parse(media['createdAt'] as String)
                : timestamp,
            transcript: media['transcript'] as String?,
            ocrText: media['ocrText'] as String?,
            analysisData: media['analysisData'] as Map<String, dynamic>?,
          );
          mediaItems.add(mediaItem);
        }
      }
      
      // Create journal entry
      final entry = JournalEntry(
        id: '',
        title: title,
        content: text,
        createdAt: customDate, // Use custom date if available
        updatedAt: customDate,
        tags: List<String>.from(content['tags'] as List? ?? []),
        mood: content['mood'] as String? ?? '',
        audioUri: null, // Legacy field
        media: mediaItems,
        sageAnnotation: sageAnnotation,
        keywords: List<String>.from(content['keywords'] as List? ?? []),
        emotion: content['emotion'] as String?,
        emotionReason: content['emotionReason'] as String?,
        location: location,
        phase: phase,
        metadata: content['metadata'] as Map<String, dynamic>?,
        isEdited: timelineData['is_edited'] as bool? ?? false,
      );
      
      // Save to repository
      await _journalRepo.createJournalEntry(entry);
      
      print('🔍 Simple MCP: ✅ Successfully imported entry: $title with ${mediaItems.length} media items');
      return true;
      
    } catch (e) {
      print('🔍 Simple MCP: ❌ Failed to import entry: $e');
      return false;
    }
  }

  /// Parse media type from string
  MediaType _parseMediaType(String? type) {
    switch (type?.toLowerCase()) {
      case 'image': return MediaType.image;
      case 'video': return MediaType.video;
      case 'audio': return MediaType.audio;
      case 'file': return MediaType.file;
      default: return MediaType.image;
    }
  }

  /// Sort map keys for consistent JSON output
  Map<String, dynamic> _sortKeys(Map<String, dynamic> map) {
    final sortedKeys = map.keys.toList()..sort();
    return Map.fromEntries(
      sortedKeys.map((key) => MapEntry(key, map[key])),
    );
  }
}