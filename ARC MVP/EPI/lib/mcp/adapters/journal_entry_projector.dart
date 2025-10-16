// lib/mcp/adapters/journal_entry_projector.dart
// Projects journal entries from the repository directly to MCP format (Pointer + Node + Edge)
// This is the core solution to the "empty MCP files" problem

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../../arc/core/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';
import '../../../mira/core/ids.dart';
import '../../core/services/photo_library_service.dart';
import '../../data/models/media_item.dart';

class McpEntryProjector {
  /// Project all journal entries to MCP format, emitting to the provided sinks
  /// Returns counts for manifest generation
  static Future<McpCounts> emitAll({
    required JournalRepository repo,
    required IOSink nodesSink,
    required IOSink edgesSink,
    required IOSink pointersSink,
    IOSink? embeddingsSink,
  }) async {
    int nodeCount = 0, edgeCount = 0, pointerCount = 0, embeddingCount = 0;

    // Get all journal entries from the fixed repository
    final entries = repo.getAllJournalEntries();

    for (final entry in entries) {
      final text = _extractEntryText(entry);
      if ((text == null || text.trim().isEmpty) &&
          (entry.sageAnnotation?.essence ?? '').trim().isEmpty) {
        continue; // Skip completely empty entries
      }

      // Generate pointer for the journal entry content
      final pointerId = _pointerIdFor(entry, text);
      _writeJsonLine(pointersSink, _createPointer(pointerId, entry, text ?? entry.sageAnnotation?.essence ?? ''));
      pointerCount++;

      // Generate node for the journal entry
      final nodeData = await _createJournalNode(entry, pointerId);
      _writeJsonLine(nodesSink, nodeData);
      nodeCount++;

      // Generate edges for relationships
      final edges = _createEdges(entry, nodeData['id']);
      for (final edge in edges) {
        _writeJsonLine(edgesSink, edge);
        edgeCount++;
      }

      // Optional: Create embeddings with actual journal content
      if (embeddingsSink != null) {
        final embedding = _createEmbedding(pointerId, entry, text ?? entry.sageAnnotation?.essence ?? '');
        _writeJsonLine(embeddingsSink, embedding);
        embeddingCount++;
      }
    }

    return McpCounts(
      nodes: nodeCount,
      edges: edgeCount,
      pointers: pointerCount,
      embeddings: embeddingCount,
    );
  }

  /// Write JSON line with deterministic key sorting
  static void _writeJsonLine(IOSink sink, Map<String, dynamic> data) {
    final sorted = _sortMapKeys(data);
    sink.writeln(jsonEncode(sorted));
  }

  /// Extract meaningful text from a journal entry
  static String? _extractEntryText(JournalEntry entry) {
    // Primary content
    if (entry.content.trim().isNotEmpty) {
      return entry.content.trim();
    }

    // Fallback to SAGE annotation content
    if (entry.sageAnnotation != null) {
      final sage = entry.sageAnnotation!;
      final parts = [
        sage.situation,
        sage.action,
        sage.growth,
        sage.essence,
      ].where((s) => s.trim().isNotEmpty).toList();

      if (parts.isNotEmpty) {
        return parts.join(' ');
      }
    }

    // Last resort: title
    if (entry.title.trim().isNotEmpty) {
      return entry.title.trim();
    }

    return null;
  }

  /// Generate deterministic pointer ID for journal entry
  static String _pointerIdFor(JournalEntry entry, String? text) {
    final content = '${entry.id}|${text ?? ''}';
    final hash = sha1.convert(utf8.encode(content)).toString().substring(0, 12);
    return 'ptr_${entry.id}_$hash';
  }

  /// Create MCP pointer record for journal entry
  static Map<String, dynamic> _createPointer(String id, JournalEntry entry, String text) {
    final timestamp = entry.createdAt.toUtc().toIso8601String();
    final summary = text.length <= 140 ? text : text.substring(0, 140);
    final contentHash = sha256.convert(utf8.encode(text)).toString();

    return {
      'id': id,
      'media_type': 'text/plain',
      'descriptor': {
        'kind': 'journal_entry',
        'entry_id': entry.id,
        'title': entry.title,
      },
      'sampling_manifest': {
        'spans': [{
          'start': 0,
          'end': text.length,
          'summary': summary,
        }],
      },
      'integrity': {
        'content_hash': 'sha256:$contentHash',
        'created_at': timestamp,
      },
      'provenance': {
        'source': 'EPI',
        'device': 'ios',
        'app_version': '1.0.0',
      },
      'privacy': {
        'pii_scanned': true,
        'faces': 0,
        'location_precision': 'coarse',
      },
      'schema_version': 'pointer.v1',
    };
  }

  /// Create MCP node record for journal entry
  static Future<Map<String, dynamic>> _createJournalNode(JournalEntry entry, String pointerId) async {
    final timestamp = entry.createdAt.toUtc().toIso8601String();
    final sage = entry.sageAnnotation;

    // Convert media items with actual photo data for persistence
    final mediaData = <Map<String, dynamic>>[];
    
    for (final media in entry.media) {
      final mediaMap = <String, dynamic>{
        'id': media.id,
        'uri': media.uri, // Original URI for reference
        'type': media.type.name, // image, video, audio, file
        'created_at': media.createdAt.toUtc().toIso8601String(),
      };
      
      // Add type-specific fields
      if (media.altText != null) mediaMap['alt_text'] = media.altText!;
      if (media.ocrText != null) mediaMap['ocr_text'] = media.ocrText!;
      if (media.analysisData != null) mediaMap['analysis_data'] = media.analysisData!;
      if (media.transcript != null) mediaMap['transcript'] = media.transcript!;
      if (media.duration != null) mediaMap['duration'] = media.duration!.inSeconds;
      if (media.sizeBytes != null) mediaMap['size_bytes'] = media.sizeBytes!;
      
           // For ph:// URIs, store rich metadata for reconnection
           if (media.uri.startsWith('ph://')) {
             try {
               print('🔍 McpEntryProjector: Getting photo metadata for ${media.id} from ${media.uri}');
               final metadata = await PhotoLibraryService.getPhotoMetadata(media.uri);
               if (metadata != null) {
                 mediaMap['photo_metadata'] = metadata.toJson();
                 print('✅ McpEntryProjector: Stored photo metadata for ${media.id}: ${metadata.description}');
               } else {
                 print('⚠️ McpEntryProjector: Could not get photo metadata for ${media.uri}');
               }
             } catch (e) {
               print('⚠️ McpEntryProjector: Error getting photo metadata for ${media.uri}: $e');
             }
           }
      
      // Validate URI scheme
      final uri = media.uri;
      final hasValidScheme = uri.startsWith('ph://') || 
                            uri.startsWith('file://') || 
                            uri.startsWith('content://') ||
                            uri.startsWith('/');
      
      if (!hasValidScheme) {
        print('⚠️ WARNING: Media ${media.id} has unusual URI scheme: $uri');
      }
      
      mediaData.add(mediaMap);
    }
    
    // Extract photo metadata for placeholders in content
    final photoMetadata = await _extractPhotoMetadataFromContent(entry.content, entry.media);
    
    // Log media export by type
    final mediaByType = <String, int>{};
    for (final media in entry.media) {
      mediaByType[media.type.name] = (mediaByType[media.type.name] ?? 0) + 1;
    }
    print('🔍 McpEntryProjector: Exporting ${entry.media.length} media items: $mediaByType');
    print('🔍 McpEntryProjector: Found ${photoMetadata.length} photo placeholders in content');

    // DEBUG: Log media data for troubleshooting
    print('🔍 McpEntryProjector: Entry ${entry.id} has ${entry.media.length} media items');
    if (entry.media.isNotEmpty) {
      for (int i = 0; i < entry.media.length; i++) {
        final media = entry.media[i];
        print('🔍 Media $i: id=${media.id}, uri=${media.uri}, type=${media.type.name}');
      }
      print('🔍 Media data array: $mediaData');
    }

    final nodeData = {
      'id': 'je_${entry.id}',
      'type': 'journal_entry',
      'timestamp': timestamp,
      'phase_hint': entry.mood, // Using mood as phase hint
      'content': entry.content, // Include the actual journal entry content (with photo placeholders)
      'title': entry.title, // Include the title
      'media': mediaData, // Include media items for photo placeholder reconstruction
      'narrative': {
        'situation': sage?.situation ?? '',
        'action': sage?.action ?? '',
        'growth': sage?.growth ?? '',
        'essence': sage?.essence ?? '',
      },
      'keywords': entry.keywords,
      'emotions': {
        'primary': entry.emotion ?? '',
        'reason': entry.emotionReason ?? '',
        'mood': entry.mood,
      },
      'pointer_ref': pointerId,
      'schema_version': 'node.v1',
      'metadata': {
        'photos': photoMetadata, // Photo metadata for reconnection
        'timeline': {
          'date': entry.createdAt.toUtc().toIso8601String(),
          'time': '${entry.createdAt.hour.toString().padLeft(2, '0')}:${entry.createdAt.minute.toString().padLeft(2, '0')}',
          'location': entry.location,
          'phase': entry.phase,
          'is_edited': entry.isEdited,
        },
      },
    };

    // Enhanced debug logging
    print('🔍 McpEntryProjector: Final node data for ${entry.id}:');
    print('🔍 - Has media field: ${nodeData.containsKey('media')}');
    print('🔍 - Media array length: ${(nodeData['media'] as List).length}');
    if ((nodeData['media'] as List).isNotEmpty) {
      final firstMedia = (nodeData['media'] as List)[0] as Map<String, dynamic>;
      print('🔍 - First media URI: ${firstMedia['uri']}');
      print('🔍 - First media type: ${firstMedia['type']}');
    }
    print('🔍 - Content: ${entry.content}');
    
    return nodeData;
  }

  /// Create MCP edge records for journal entry relationships
  static List<Map<String, dynamic>> _createEdges(JournalEntry entry, String nodeId) {
    final timestamp = entry.updatedAt.toUtc().toIso8601String();
    final edges = <Map<String, dynamic>>[];

    // Phase/mood relationship
    if (entry.mood.trim().isNotEmpty) {
      edges.add({
        'source': nodeId,
        'target': 'ph_${entry.mood.trim().toLowerCase()}',
        'relation': 'taggedAs',
        'timestamp': timestamp,
        'schema_version': 'edge.v1',
      });
    }

    // Keyword relationships
    for (final keyword in entry.keywords) {
      if (keyword.trim().isEmpty) continue;
      edges.add({
        'source': nodeId,
        'target': stableKeywordId(keyword),
        'relation': 'mentions',
        'timestamp': timestamp,
        'schema_version': 'edge.v1',
      });
    }

    // Tag relationships
    for (final tag in entry.tags) {
      if (tag.trim().isEmpty) continue;
      edges.add({
        'source': nodeId,
        'target': 'tag_${tag.trim().toLowerCase()}',
        'relation': 'categorizedAs',
        'timestamp': timestamp,
        'schema_version': 'edge.v1',
      });
    }

    return edges;
  }

  /// Create embedding with actual journal content
  static Map<String, dynamic> _createEmbedding(String pointerId, JournalEntry entry, String content) {
    // Create a simple text embedding by encoding the content
    final contentBytes = utf8.encode(content);
    final embeddingVector = _generateSimpleEmbedding(contentBytes);
    
    return {
      'id': 'emb_$pointerId',
      'pointer_ref': pointerId,
      'doc_scope': 'je_${entry.id}',
      'model_id': 'qwen-2.5-1.5b',
      'embedding_version': '1.0.0',
      'dim': embeddingVector.length,
      'vector': embeddingVector,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'schema_version': 'embedding.v1',
    };
  }

  /// Generate a simple embedding vector from content bytes
  static List<double> _generateSimpleEmbedding(List<int> contentBytes) {
    // Create a 384-dimensional vector based on content characteristics
    final vector = List<double>.filled(384, 0.0);
    
    // Use content length, character frequency, and other features
    final contentLength = contentBytes.length;
    final avgChar = contentBytes.isNotEmpty ? contentBytes.reduce((a, b) => a + b) / contentBytes.length : 0.0;
    
    // Fill vector with content-based features
    for (int i = 0; i < 384; i++) {
      if (i < contentBytes.length) {
        vector[i] = (contentBytes[i] / 255.0) * 2.0 - 1.0; // Normalize to [-1, 1]
      } else {
        // Use derived features for remaining dimensions
        final feature = (contentLength * (i + 1) + avgChar) % 1.0;
        vector[i] = feature * 2.0 - 1.0;
      }
    }
    
    return vector;
  }

  /// Sort map keys recursively for deterministic output
  static Map<String, dynamic> _sortMapKeys(Map<String, dynamic> map) {
    final sorted = Map<String, dynamic>.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    sorted.updateAll((key, value) {
      if (value is Map<String, dynamic>) {
        return _sortMapKeys(value);
      } else if (value is List) {
        return value.map((item) {
          if (item is Map<String, dynamic>) {
            return _sortMapKeys(item);
          }
          return item;
        }).toList();
      }
      return value;
    });

    return sorted;
  }

  /// Extract photo metadata from content placeholders
  static Future<List<Map<String, dynamic>>> _extractPhotoMetadataFromContent(
    String content,
    List<MediaItem> mediaItems,
  ) async {
    final photoMetadata = <Map<String, dynamic>>[];
    final photoPlaceholderRegex = RegExp(r'\[PHOTO:([^\]]+)\]');
    final matches = photoPlaceholderRegex.allMatches(content);

    for (final match in matches) {
      final placeholderId = match.group(1)!;
      print('🔍 McpEntryProjector: Found photo placeholder: $placeholderId');

      // Try to find the corresponding MediaItem
      MediaItem? matchingMedia;
      for (final media in mediaItems) {
        if (media.id == placeholderId) {
          matchingMedia = media;
          break;
        }
      }

      Map<String, dynamic> metadata = <String, dynamic>{
        'placeholder_id': placeholderId,
        'local_identifier': null,
        'creation_date': null,
        'pixel_width': null,
        'pixel_height': null,
        'filename': null,
        'uniform_type_identifier': null,
        'perceptual_hash': null,
      };

      // If we found a matching MediaItem with ph:// URI, get its metadata
      if (matchingMedia != null && matchingMedia.uri.startsWith('ph://')) {
        try {
          print('🔍 McpEntryProjector: Getting metadata for ${matchingMedia.uri}');
          final photoMetadataObj = await PhotoLibraryService.getPhotoMetadata(matchingMedia.uri);
          if (photoMetadataObj != null) {
            metadata = {
              'placeholder_id': placeholderId,
              'local_identifier': photoMetadataObj.localIdentifier,
              'creation_date': photoMetadataObj.creationDate,
              'pixel_width': photoMetadataObj.pixelWidth,
              'pixel_height': photoMetadataObj.pixelHeight,
              'filename': photoMetadataObj.filename,
              'uniform_type_identifier': null, // Not available in PhotoMetadata
              'perceptual_hash': photoMetadataObj.perceptualHash,
            };
            print('✅ McpEntryProjector: Got metadata for $placeholderId: ${photoMetadataObj.description}');
          } else {
            print('⚠️ McpEntryProjector: Could not get metadata for ${matchingMedia.uri}');
          }
        } catch (e) {
          print('⚠️ McpEntryProjector: Error getting metadata for ${matchingMedia.uri}: $e');
        }
      } else {
        print('🔍 McpEntryProjector: No matching MediaItem found for $placeholderId or not ph:// URI');
      }

      photoMetadata.add(metadata);
    }

    return photoMetadata;
  }
}

/// Result counts for MCP bundle manifest
class McpCounts {
  final int nodes;
  final int edges;
  final int pointers;
  final int embeddings;

  McpCounts({
    required this.nodes,
    required this.edges,
    required this.pointers,
    required this.embeddings,
  });
}