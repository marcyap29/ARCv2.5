/// MCP Export Service
/// 
/// High-level orchestrator for exporting MIRA memory into MCP Memory Bundle format.
/// Handles SAGE-to-Node mapping, pointer creation, embedding generation, and edge derivation.
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../models/mcp_schemas.dart';

// Export commonly used models and enums for convenience
export '../models/mcp_schemas.dart' show McpExportScope, McpStorageProfile;
import '../validation/mcp_validator.dart';
import 'ndjson_writer.dart';
import 'manifest_builder.dart';
import 'checksum_utils.dart';
import 'chat_exporter.dart';
import 'package:my_app/arc/chat/chat/chat_repo.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/core/services/photo_library_service.dart';
import 'package:my_app/platform/photo_bridge.dart';
import 'package:my_app/services/phase_index.dart';
import 'package:my_app/prism/atlas/rivet/rivet_storage.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart' as rivet_models;
import 'package:my_app/models/arcform_snapshot_model.dart';
import 'package:my_app/arc/chat/services/favorites_service.dart';
import 'package:my_app/arc/chat/services/lumara_reflection_settings_service.dart';
import 'package:hive/hive.dart';

class McpExportService {
  final String bundleId;
  final McpStorageProfile storageProfile;
  final String? notes;
  final ChatRepo? chatRepo;
  final ChatMcpExporter? _chatExporter;

  McpExportService({
    String? bundleId,
    this.storageProfile = McpStorageProfile.balanced,
    this.notes,
    this.chatRepo,
  }) : bundleId = bundleId ?? McpManifestBuilder.generateBundleId(),
       _chatExporter = chatRepo != null ? ChatMcpExporter(chatRepo) : null;

  /// Export MIRA memory to MCP bundle (including chat data and phase regimes)
  Future<McpExportResult> exportToMcp({
    required Directory outputDir,
    required McpExportScope scope,
    required List<JournalEntry> journalEntries,
    List<MediaItem>? mediaFiles,
    Map<String, dynamic>? customScope,
    bool includeChats = true,
    bool includeArchivedChats = true,
    PhaseIndex? phaseIndex,
  }) async {
    try {
      // Ensure output directory exists
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // Filter entries based on scope
      final filteredEntries = _filterEntriesByScope(journalEntries, scope, customScope);
      
      // Convert journal entries to MCP nodes (SAGE mapping)
      final nodes = await _convertJournalEntriesToNodes(filteredEntries);

      // Create pointers for media files
      final pointers = await _createPointersFromMedia(mediaFiles ?? []);

      // Extract photo references from journal entries and create pointers
      final photoPointers = await _extractPhotoReferencesFromEntries(filteredEntries);
      pointers.addAll(photoPointers);

      // Export chat data if chat repository is available
      final chatData = await _exportChatData(scope, customScope, includeChats, includeArchivedChats);

      // Export phase regimes, RIVET state, Sentinel state, and ArcForm timeline if available
      final phaseData = await _exportPhaseRegimes(phaseIndex);
      final rivetData = await _exportRivetState();
      final sentinelData = await _exportSentinelState();
      final arcformData = await _exportArcFormTimeline();
      
      // Export LUMARA favorites and settings
      final lumaraFavoritesData = await _exportLumaraFavorites();
      final lumaraSettingsData = await _exportLumaraSettings();

      // Combine all nodes, edges, and pointers
      final allNodes = <McpNode>[
        ...nodes, 
        ...chatData.nodes, 
        ...phaseData.nodes,
        ...rivetData.nodes,
        ...sentinelData.nodes,
        ...arcformData.nodes,
        ...lumaraFavoritesData.nodes,
        ...lumaraSettingsData.nodes,
      ];
      final allEdges = <McpEdge>[
        ...chatData.edges, 
        ...phaseData.edges,
        ...rivetData.edges,
        ...sentinelData.edges,
        ...arcformData.edges,
        ...lumaraFavoritesData.edges,
        ...lumaraSettingsData.edges,
      ];
      final allPointers = <McpPointer>[
        ...pointers, 
        ...chatData.pointers, 
        ...phaseData.pointers,
        ...rivetData.pointers,
        ...sentinelData.pointers,
        ...arcformData.pointers,
        ...lumaraFavoritesData.pointers,
        ...lumaraSettingsData.pointers,
      ];

      // Generate embeddings for nodes and pointers
      final embeddings = await _generateEmbeddings(allNodes, allPointers);

      // Derive edges from relationships (journal entries)
      final journalEdges = await _deriveEdges(nodes, embeddings);
      final allCombinedEdges = <McpEdge>[...allEdges, ...journalEdges];
      
      // Validate all records
      final validationResult = await _validateRecords(allNodes, allCombinedEdges, allPointers, embeddings);
      if (!validationResult.isValid) {
        throw McpExportException('Validation failed: ${validationResult.errors.join(', ')}');
      }

      // Write NDJSON files
      final ndjsonWriter = McpNdjsonWriter(outputDir: outputDir);
      final ndjsonFiles = await ndjsonWriter.writeAll(
        nodes: allNodes,
        edges: allCombinedEdges,
        pointers: allPointers,
        embeddings: embeddings,
      );
      
      // Build and write manifest
      final manifestBuilder = McpManifestBuilder(
        bundleId: bundleId,
        storageProfile: storageProfile,
        notes: notes,
      );
      
      final counts = McpCounts(
        nodes: allNodes.length,
        edges: allCombinedEdges.length,
        pointers: allPointers.length,
        embeddings: embeddings.length,
      );
      
      final encoderRegistry = McpManifestBuilder.createEncoderRegistry(embeddings);
      
      final manifestFile = await manifestBuilder.buildAndWriteManifest(
        outputDir: outputDir,
        ndjsonFiles: ndjsonFiles,
        counts: counts,
        encoderRegistry: encoderRegistry,
      );
      
      return McpExportResult(
        success: true,
        bundleId: bundleId,
        outputDir: outputDir,
        manifestFile: manifestFile,
        ndjsonFiles: ndjsonFiles,
        counts: counts,
        encoderRegistry: encoderRegistry,
        nodes: allNodes,
      );
      
    } catch (e) {
      return McpExportResult(
        success: false,
        error: e.toString(),
        bundleId: bundleId,
        outputDir: outputDir,
      );
    }
  }

  /// Filter journal entries based on export scope
  List<JournalEntry> _filterEntriesByScope(
    List<JournalEntry> entries,
    McpExportScope scope,
    Map<String, dynamic>? customScope,
  ) {
    final now = DateTime.now();
    
    switch (scope) {
      case McpExportScope.last30Days:
        final cutoff = now.subtract(const Duration(days: 30));
        return entries.where((e) => e.createdAt.isAfter(cutoff)).toList();
        
      case McpExportScope.last90Days:
        final cutoff = now.subtract(const Duration(days: 90));
        return entries.where((e) => e.createdAt.isAfter(cutoff)).toList();
        
      case McpExportScope.lastYear:
        final cutoff = now.subtract(const Duration(days: 365));
        return entries.where((e) => e.createdAt.isAfter(cutoff)).toList();
        
      case McpExportScope.all:
        return entries;
        
      case McpExportScope.custom:
        if (customScope == null) return entries;
        
        final startDate = customScope['start_date'] as DateTime?;
        final endDate = customScope['end_date'] as DateTime?;
        final tags = customScope['tags'] as List<String>?;
        
        var filtered = entries;
        
        if (startDate != null) {
          filtered = filtered.where((e) => e.createdAt.isAfter(startDate)).toList();
        }
        if (endDate != null) {
          filtered = filtered.where((e) => e.createdAt.isBefore(endDate)).toList();
        }
        if (tags != null && tags.isNotEmpty) {
          filtered = filtered.where((e) => 
            e.tags.any((tag) => tags.contains(tag))).toList();
        }
        
        return filtered;
    }
  }

  /// Convert journal entries to MCP nodes with SAGE mapping
  Future<List<McpNode>> _convertJournalEntriesToNodes(List<JournalEntry> entries) async {
    final nodes = <McpNode>[];

    print('📝 Converting ${entries.length} journal entries to MCP nodes...');

    for (final entry in entries) {
      print('🔄 Processing entry: "${entry.title}" (${entry.content.length} chars)');

      // Extract SAGE narrative from journal content
      final narrative = _extractSageNarrative(entry);

      // Determine phase hint from entry metadata
      final phaseHint = _determinePhaseHint(entry);

      // Extract emotions from entry
      final emotions = _extractEmotions(entry);

      // Create node ID
      final nodeId = 'entry_${entry.createdAt.year}_${entry.createdAt.month.toString().padLeft(2, '0')}_${entry.createdAt.day.toString().padLeft(2, '0')}_${entry.id}';

      print('   Node ID: $nodeId');
      print('   Content preserved in: contentSummary (${entry.content.length} chars), narrative.situation (${entry.content.length} chars), metadata');
      print('   Tags: ${entry.tags}');
      print('   Phase: $phaseHint');
      
      final node = McpNode(
        id: nodeId,
        type: 'journal_entry',
        timestamp: entry.createdAt.toUtc(),
        contentSummary: _createContentSummary(entry),
        phaseHint: phaseHint,
        keywords: entry.tags,
        narrative: narrative,
        emotions: emotions,
        provenance: McpProvenance(
          source: 'ARC',
          device: Platform.operatingSystem,
          app: 'EPI',
          importMethod: 'journal_entry',
          userId: null, // JournalEntry doesn't have userId in the real model
        ),
        // Add metadata to preserve additional journal entry fields
        // Merge with existing metadata to preserve LUMARA blocks and other custom metadata
        metadata: {
          'journal_entry': {
            'id': entry.id,
            'title': entry.title,
            'content': entry.content, // Full content backup
            'mood': entry.mood,
            'emotion': entry.emotion,
            'emotion_reason': entry.emotionReason,
            'created_at': entry.createdAt.toIso8601String(),
            'updated_at': entry.updatedAt.toIso8601String(),
            'keywords': entry.keywords,
            'phase': entry.phase, // Legacy field for backward compatibility
            // New phase detection fields
            'autoPhase': entry.autoPhase,
            'autoPhaseConfidence': entry.autoPhaseConfidence,
            'userPhaseOverride': entry.userPhaseOverride,
            'isPhaseLocked': entry.isPhaseLocked,
            'legacyPhaseTag': entry.legacyPhaseTag,
            'importSource': entry.importSource,
            'phaseInferenceVersion': entry.phaseInferenceVersion,
            'phaseMigrationStatus': entry.phaseMigrationStatus,
            'media': entry.media.map((m) => {
              'id': m.id,
              'uri': m.uri,
              'type': m.type.name,
              'created_at': m.createdAt.toIso8601String(),
              'alt_text': m.altText,
              'ocr_text': m.ocrText,
              'analysis_data': m.analysisData,
            }).toList(),
          },
          'export_info': {
            'exported_at': DateTime.now().toIso8601String(),
            'content_length': entry.content.length,
            'has_full_content': true,
          },
          // Preserve original entry metadata (including inlineBlocks from LUMARA)
          ...?entry.metadata,
        },
      );

      print('✅ Created MCP node with enhanced metadata preservation');
      nodes.add(node);
    }

    print('✅ Converted all ${entries.length} journal entries to MCP nodes');
    return nodes;
  }

  /// Extract SAGE narrative from journal entry
  McpNarrative _extractSageNarrative(JournalEntry entry) {
    // Store the full content in the situation field to preserve it
    // This ensures complete content preservation for import restoration
    final content = entry.content;

    return McpNarrative(
      situation: content, // Store full content here for preservation
      action: _extractAction(content),
      growth: _extractGrowth(content),
      essence: _extractEssence(content),
    );
  }


  /// Extract action from journal content
  String? _extractAction(String content) {
    // Simplified: look for action keywords
    final actionKeywords = ['action', 'did', 'took', 'decided', 'chose'];
    for (final keyword in actionKeywords) {
      if (content.toLowerCase().contains(keyword)) {
        return 'Action extracted from journal entry';
      }
    }
    return null;
  }

  /// Extract growth from journal content
  String? _extractGrowth(String content) {
    // Simplified: look for growth keywords
    final growthKeywords = ['growth', 'learned', 'realized', 'understood', 'insight'];
    for (final keyword in growthKeywords) {
      if (content.toLowerCase().contains(keyword)) {
        return 'Growth extracted from journal entry';
      }
    }
    return null;
  }

  /// Extract essence from journal content
  String? _extractEssence(String content) {
    // Simplified: look for essence keywords
    final essenceKeywords = ['essence', 'core', 'meaning', 'purpose', 'value'];
    for (final keyword in essenceKeywords) {
      if (content.toLowerCase().contains(keyword)) {
        return 'Essence extracted from journal entry';
      }
    }
    return null;
  }

  /// Determine phase hint from journal entry
  String? _determinePhaseHint(JournalEntry entry) {
    // This would integrate with your existing phase detection system
    // For now, return a default or extract from entry metadata
    return entry.metadata?['phase'] as String?;
  }

  /// Extract emotions from journal entry
  Map<String, double> _extractEmotions(JournalEntry entry) {
    // This would integrate with your existing emotion analysis
    // For now, return a simple mapping
    return {
      'calm': 0.6,
      'curious': 0.4,
    };
  }

  /// Create content summary from journal entry
  String _createContentSummary(JournalEntry entry) {
    // For journal entries, preserve the full content in contentSummary
    // This ensures complete content preservation during export/import cycle
    return entry.content;
  }

  /// Extract photo references from journal entries and create pointers
  Future<List<McpPointer>> _extractPhotoReferencesFromEntries(List<JournalEntry> entries) async {
    final pointers = <McpPointer>[];
    
    print('📷 Extracting photo references from journal entries...');
    
    for (final entry in entries) {
      // Extract photo references from entry content
      final photoRefs = _extractPhotoReferencesFromContent(entry.content);
      
      for (final photoRef in photoRefs) {
        // Find the corresponding media item
        MediaItem? mediaItem;
        try {
          mediaItem = entry.media.firstWhere(
            (media) => media.id == photoRef,
          );
        } catch (e) {
          mediaItem = null;
        }
        
        if (mediaItem != null) {
          print('📷 Creating pointer for photo: ${mediaItem.id} (${mediaItem.uri})');
          
                 // Get cloud identifier for cross-device stability
                 String? cloudIdentifier;
                 if (mediaItem.uri.startsWith('ph://')) {
                   final localId = mediaItem.uri.replaceFirst('ph://', '');
                   cloudIdentifier = await PhotoLibraryService.getCloudIdentifier(localId);
                   print('📷 Cloud identifier for ${mediaItem.id}: $cloudIdentifier');
                 }

                 // Create pointer for the actual photo file
                 final pointer = McpPointer(
                   id: 'ptr_photo_${mediaItem.id}',
                   mediaType: mediaItem.type.name,
                   sourceUri: mediaItem.uri,
                   descriptor: McpDescriptor(
                     language: 'en',
                     length: mediaItem.sizeBytes ?? 0,
                     mimeType: _getMimeTypeForMediaType(mediaItem.type),
                     metadata: {
                       'photo_id': mediaItem.id,
                       'local_identifier': mediaItem.uri.startsWith('ph://') 
                           ? mediaItem.uri.replaceFirst('ph://', '') 
                           : mediaItem.uri,
                       'cloud_identifier': cloudIdentifier,
                       'original_filename': mediaItem.uri.split('/').last,
                       'alt_text': mediaItem.altText,
                       'ocr_text': mediaItem.ocrText,
                       'analysis_data': mediaItem.analysisData,
                       'created_at': mediaItem.createdAt.toIso8601String(),
                       'journal_entry_id': entry.id,
                       'content_reference': '[PHOTO:${mediaItem.id}]',
                     },
                   ),
            samplingManifest: McpSamplingManifest(
              spans: _createSpansForMedia(mediaItem),
              keyframes: _createKeyframesForMedia(mediaItem),
              metadata: {
                'sampling_method': 'photo_export',
                'quality': 'high',
                'source': 'journal_entry',
              },
            ),
            integrity: McpIntegrity(
              contentHash: mediaItem.id, // Use ID as hash for now
              bytes: mediaItem.sizeBytes ?? 0,
              mime: _getMimeTypeForMediaType(mediaItem.type),
              createdAt: mediaItem.createdAt.toUtc(),
            ),
            provenance: McpProvenance(
              source: 'ARC',
              device: Platform.operatingSystem,
              app: 'EPI',
              importMethod: 'photo_export',
              userId: null,
            ),
            privacy: McpPrivacy(
              containsPii: false, // Will be updated by PRISM analysis
              facesDetected: mediaItem.analysisData?['faces'] != null,
              sharingPolicy: 'private',
            ),
            labels: ['photo', 'journal_media', 'exported_photo'],
          );
          
          pointers.add(pointer);
        } else {
          print('⚠️ Photo reference $photoRef not found in entry media');
        }
      }
    }
    
    print('📷 Created ${pointers.length} photo pointers from journal entries');
    return pointers;
  }

  /// Extract photo references from journal entry content
  List<String> _extractPhotoReferencesFromContent(String content) {
    final photoRefs = <String>[];
    final regex = RegExp(r'\[PHOTO:([^\]]+)\]');
    final matches = regex.allMatches(content);
    
    for (final match in matches) {
      final photoId = match.group(1);
      if (photoId != null) {
        photoRefs.add(photoId);
      }
    }
    
    return photoRefs;
  }

  /// Create pointers from media files
  Future<List<McpPointer>> _createPointersFromMedia(List<MediaItem> mediaFiles) async {
    final pointers = <McpPointer>[];
    
    for (final mediaFile in mediaFiles) {
      final pointerId = 'ptr_${mediaFile.id}';
      
      // Try to get photo bytes - handle multiple sources
      Uint8List? contentBytes;
      
      // 1. Try direct file path
      final file = File(mediaFile.uri);
      if (await file.exists()) {
        try {
          contentBytes = await file.readAsBytes();
          print('✅ ARCX Export: Got photo bytes from file for: ${mediaFile.id}');
        } catch (e) {
          print('⚠️ ARCX Export: Could not read file: ${mediaFile.uri}: $e');
        }
      }
      
      // 2. Try PhotoBridge for ph:// URIs
      if (contentBytes == null && mediaFile.uri.startsWith('ph://')) {
        try {
          final localId = PhotoBridge.extractLocalIdentifier(mediaFile.uri);
          if (localId != null) {
            final photoData = await PhotoBridge.getPhotoBytes(localId);
            if (photoData != null) {
              contentBytes = photoData['bytes'] as Uint8List;
              print('✅ ARCX Export: Got photo bytes via PhotoBridge for: ${mediaFile.id}');
            }
          }
        } catch (e) {
          print('⚠️ ARCX Export: PhotoBridge failed for ${mediaFile.uri}: $e');
        }
      }
      
      // 2b. Alternative for ph:// URIs: Use PhotoLibraryService to get thumbnail path
      if (contentBytes == null && mediaFile.uri.startsWith('ph://')) {
        try {
          final thumbnailPath = await PhotoLibraryService.getPhotoThumbnail(mediaFile.uri, size: 1920);
          if (thumbnailPath != null) {
            final thumbFile = File(thumbnailPath);
            if (await thumbFile.exists()) {
              contentBytes = await thumbFile.readAsBytes();
              print('✅ ARCX Export: Got photo bytes via PhotoLibraryService thumbnail for: ${mediaFile.id}');
            }
          }
        } catch (e) {
          print('⚠️ ARCX Export: PhotoLibraryService thumbnail failed for ${mediaFile.uri}: $e');
        }
      }
      
      // 3. Fallback for legacy entries where files were never properly persisted
      if (contentBytes == null && mediaFile.uri.contains('/Documents/photos/')) {
        print('⚠️ ARCX Export: Legacy entry detected for: ${mediaFile.id}');
        print('   File path: ${mediaFile.uri}');
        print('   Photo was saved before the persistence fix and cannot be automatically recovered.');
        print('   The original photo still exists in the iOS Photo Library, but we cannot match it without the ph:// identifier.');
        print('   Recommendation: Re-add photos from Photo Library to a new journal entry for proper export.');
      }
      
      // If still no bytes, skip this photo (don't create invalid pointer)
      if (contentBytes == null) {
        print('⚠️ ARCX Export: No bytes available for media ${mediaFile.id} (uri: ${mediaFile.uri}), skipping photo export');
        continue;
      }
      
      // Create content hash
      final contentHash = sha256.convert(contentBytes).toString();
      
      // Create CAS URI
      final casUri = McpChecksumUtils.generateCasUri(contentBytes);
      
      final pointer = McpPointer(
        id: pointerId,
        mediaType: mediaFile.type.name,
        sourceUri: mediaFile.uri,
        altUris: [casUri],
        descriptor: McpDescriptor(
          language: 'en', // Default language
          length: contentBytes.length,
          mimeType: _getMimeTypeForMediaType(mediaFile.type),
          metadata: {
            'original_filename': mediaFile.uri.split('/').last,
            'duration': mediaFile.duration?.inMicroseconds,
            'size_bytes': mediaFile.sizeBytes,
            'transcript': mediaFile.transcript,
            'ocr_text': mediaFile.ocrText,
          },
        ),
        samplingManifest: McpSamplingManifest(
          spans: _createSpansForMedia(mediaFile),
          keyframes: _createKeyframesForMedia(mediaFile),
          metadata: {
            'sampling_method': 'automatic',
            'quality': 'balanced',
          },
        ),
        integrity: McpIntegrity(
          contentHash: contentHash,
          bytes: contentBytes.length,
          mime: _getMimeTypeForMediaType(mediaFile.type),
          createdAt: mediaFile.createdAt.toUtc(),
        ),
        provenance: McpProvenance(
          source: 'ARC',
          device: Platform.operatingSystem,
          app: 'EPI',
          importMethod: 'media_import',
          userId: null, // MediaItem doesn't have userId
        ),
        privacy: McpPrivacy(
          containsPii: _detectPii(mediaFile),
          facesDetected: _detectFaces(mediaFile),
          locationPrecision: _detectLocation(mediaFile),
          sharingPolicy: 'private',
        ),
        labels: [], // MediaItem doesn't have tags
      );
      
      pointers.add(pointer);
    }
    
    return pointers;
  }

  /// Get MIME type for MediaType
  String _getMimeTypeForMediaType(MediaType type) {
    switch (type) {
      case MediaType.audio:
        return 'audio/mpeg';
      case MediaType.image:
        return 'image/jpeg';
      case MediaType.video:
        return 'video/mp4';
      case MediaType.file:
        return 'application/octet-stream';
    }
  }

  /// Create spans for media file
  List<McpSpan> _createSpansForMedia(MediaItem mediaFile) {
    // This would create text spans for audio transcripts, video captions, etc.
    return [];
  }

  /// Create keyframes for media file
  List<McpKeyframe> _createKeyframesForMedia(MediaItem mediaFile) {
    // This would create keyframes for video files
    return [];
  }

  /// Detect PII in media file
  bool _detectPii(MediaItem mediaFile) {
    // This would use your existing PII detection
    return false;
  }

  /// Detect faces in media file
  bool _detectFaces(MediaItem mediaFile) {
    // This would use your existing face detection
    return false;
  }

  /// Detect location in media file
  String? _detectLocation(MediaItem mediaFile) {
    // This would use your existing location detection
    return null;
  }

  /// Generate embeddings for nodes and pointers
  Future<List<McpEmbedding>> _generateEmbeddings(
    List<McpNode> nodes,
    List<McpPointer> pointers,
  ) async {
    final embeddings = <McpEmbedding>[];
    
    // Generate embeddings for nodes only if they reference a valid pointer
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final String? ptr = node.pointerRef; // optional in schema
      if (ptr != null && ptr.isNotEmpty) {
        final embeddingId = 'emb_node_$i';
        final vector = await _generateEmbeddingVector(node.contentSummary ?? '');
        final embedding = McpEmbedding(
          id: embeddingId,
          pointerRef: ptr,
          docScope: node.id,
          vector: vector,
          modelId: 'qwen-2.5-1.5b',
          embeddingVersion: '1.0.0',
          dim: vector.length,
        );
        embeddings.add(embedding);
      }
    }
    
    // Generate embeddings for pointers
    for (int i = 0; i < pointers.length; i++) {
      final pointer = pointers[i];
      final embeddingId = 'emb_ptr_$i';
      
      // This would use your existing embedding service
      final vector = await _generateEmbeddingVector(pointer.descriptor.metadata.toString());
      
      final embedding = McpEmbedding(
        id: embeddingId,
        pointerRef: pointer.id,
        vector: vector,
        modelId: 'qwen-2.5-1.5b',
        embeddingVersion: '1.0.0',
        dim: vector.length,
      );
      
      embeddings.add(embedding);
    }
    
    return embeddings;
  }

  /// Generate embedding vector for text
  Future<List<double>> _generateEmbeddingVector(String text) async {
    // This would use your existing embedding service
    // For now, return a dummy vector
    return List.generate(384, (index) => (index * 0.01) % 1.0);
  }

  /// Derive edges from relationships
  Future<List<McpEdge>> _deriveEdges(
    List<McpNode> nodes,
    List<McpEmbedding> embeddings,
  ) async {
    final edges = <McpEdge>[];
    
    // Create time adjacency edges
    for (int i = 0; i < nodes.length - 1; i++) {
      final current = nodes[i];
      final next = nodes[i + 1];
      
      final edge = McpEdge(
        source: current.id,
        target: next.id,
        relation: 'time_adjacent',
        timestamp: current.timestamp,
        weight: 0.8,
      );
      
      edges.add(edge);
    }
    
    // Create theme similarity edges based on embeddings
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final node1 = nodes[i];
        final node2 = nodes[j];
        
        // Find embeddings for these nodes
        final emb1 = embeddings.where((e) => e.docScope == node1.id).cast<McpEmbedding?>().firstOrNull;
        final emb2 = embeddings.where((e) => e.docScope == node2.id).cast<McpEmbedding?>().firstOrNull;
        if (emb1 == null || emb2 == null) {
          continue;
        }
        
        // Calculate cosine similarity
        final similarity = _calculateCosineSimilarity(emb1.vector, emb2.vector);
        
        if (similarity > 0.7) {
          final edge = McpEdge(
            source: node1.id,
            target: node2.id,
            relation: 'theme_similar',
            timestamp: node1.timestamp,
            weight: similarity,
          );
          
          edges.add(edge);
        }
      }
    }
    
    return edges;
  }

  /// Calculate cosine similarity between two vectors
  double _calculateCosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    normA = sqrt(normA);
    normB = sqrt(normB);
    
    if (normA == 0.0 || normB == 0.0) return 0.0;
    
    return dotProduct / (normA * normB);
  }

  /// Export chat data to MCP format
  Future<ChatExportData> _exportChatData(
    McpExportScope scope,
    Map<String, dynamic>? customScope,
    bool includeChats,
    bool includeArchivedChats,
  ) async {
    if (!includeChats || _chatExporter == null) {
      return const ChatExportData(
        nodes: [],
        edges: [],
        pointers: [],
      );
    }

    try {
      // Apply date filtering based on scope for chats
      DateTime? since;
      DateTime? until;

      switch (scope) {
        case McpExportScope.last30Days:
          since = DateTime.now().subtract(const Duration(days: 30));
          break;
        case McpExportScope.last90Days:
          since = DateTime.now().subtract(const Duration(days: 90));
          break;
        case McpExportScope.lastYear:
          since = DateTime.now().subtract(const Duration(days: 365));
          break;
        case McpExportScope.custom:
          if (customScope != null) {
            since = customScope['start_date'] as DateTime?;
            until = customScope['end_date'] as DateTime?;
          }
          break;
        case McpExportScope.all:
          // No date filtering
          break;
      }

      // Get chat sessions and messages within scope
      final sessions = await chatRepo!.listAll(includeArchived: includeArchivedChats);

      // Filter sessions by date if specified
      final filteredSessions = sessions.where((session) {
        if (since != null && session.createdAt.isBefore(since)) return false;
        if (until != null && session.createdAt.isAfter(until)) return false;
        return true;
      }).toList();

      // Convert chat data to MCP format
      final chatNodes = <McpNode>[];
      final chatEdges = <McpEdge>[];
      final chatPointers = <McpPointer>[];

      for (final session in filteredSessions) {
        // Convert session to MCP node
        final sessionNode = await _convertChatSessionToNode(session);
        chatNodes.add(sessionNode);

        // Create session pointer for discoverability
        final sessionPointer = await _createChatSessionPointer(session);
        chatPointers.add(sessionPointer);

        // Get messages for this session
        final messages = await chatRepo!.getMessages(session.id, lazy: false);

        // Convert messages and create contains edges
        for (int i = 0; i < messages.length; i++) {
          final message = messages[i];

          // Convert message to MCP node
          final messageNode = await _convertChatMessageToNode(message);
          chatNodes.add(messageNode);

          // Create contains edge
          final containsEdge = await _createChatContainsEdge(session.id, message.id, message.createdAt, i);
          chatEdges.add(containsEdge);
        }
      }

      return ChatExportData(
        nodes: chatNodes,
        edges: chatEdges,
        pointers: chatPointers,
      );

    } catch (e) {
      print('Warning: Failed to export chat data: $e');
      return const ChatExportData(
        nodes: [],
        edges: [],
        pointers: [],
      );
    }
  }

  /// Convert ChatSession to MCP Node
  Future<McpNode> _convertChatSessionToNode(ChatSession session) async {
    return McpNode(
      id: 'session:${session.id}',
      type: 'ChatSession',
      timestamp: session.createdAt.toUtc(),
      contentSummary: session.subject,
      keywords: session.tags.toList(),
        narrative: McpNarrative(
          situation: session.subject,
        ),
      provenance: McpProvenance(
        source: 'LUMARA',
        device: Platform.operatingSystem,
        app: 'EPI',
        importMethod: 'chat_session',
        userId: null, // Chat sessions don't have individual user IDs in this model
      ),
    );
  }

  /// Convert ChatMessage to MCP Node
  Future<McpNode> _convertChatMessageToNode(ChatMessage message) async {
    return McpNode(
      id: 'msg:${message.id}',
      type: 'ChatMessage',
      timestamp: message.createdAt.toUtc(),
      contentSummary: message.textContent.length > 100
          ? '${message.textContent.substring(0, 100)}...'
          : message.textContent,
      keywords: [],
      narrative: McpNarrative(
        situation: message.textContent,
      ),
      provenance: McpProvenance(
        source: 'LUMARA',
        device: Platform.operatingSystem,
        app: 'EPI',
        importMethod: 'chat_message',
        userId: null,
      ),
    );
  }

  /// Create MCP Pointer for ChatSession
  Future<McpPointer> _createChatSessionPointer(ChatSession session) async {
    return McpPointer(
      id: 'ptr_session:${session.id}',
      mediaType: 'application/json',
      descriptor: McpDescriptor(
        language: 'en',
        length: session.subject.length,
        mimeType: 'application/json',
        metadata: {
          'session_id': session.id,
          'subject': session.subject,
          'message_count': session.messageCount,
          'is_archived': session.isArchived,
          'is_pinned': session.isPinned,
          'tags': session.tags,
        },
      ),
      samplingManifest: const McpSamplingManifest(
        spans: [],
        keyframes: [],
        metadata: {
          'sampling_method': 'none',
          'content_type': 'chat_session',
        },
      ),
      integrity: McpIntegrity(
        contentHash: 'dummy_hash_${session.id}',
        bytes: session.subject.length,
        mime: 'application/json',
        createdAt: session.createdAt.toUtc(),
      ),
      provenance: McpProvenance(
        source: 'LUMARA',
        device: Platform.operatingSystem,
        app: 'EPI',
        importMethod: 'chat_session_pointer',
        userId: null,
      ),
      privacy: const McpPrivacy(
        containsPii: false,
        facesDetected: false,
        locationPrecision: null,
        sharingPolicy: 'private',
      ),
      labels: ['chat_session', ...session.tags],
    );
  }

  /// Create contains edge between session and message
  Future<McpEdge> _createChatContainsEdge(String sessionId, String messageId, DateTime timestamp, int order) async {
    return McpEdge(
      source: 'session:$sessionId',
      target: 'msg:$messageId',
      relation: 'contains',
      timestamp: timestamp.toUtc(),
      weight: 1.0,
    );
  }

  /// Validate all records
  Future<ValidationResult> _validateRecords(
    List<McpNode> nodes,
    List<McpEdge> edges,
    List<McpPointer> pointers,
    List<McpEmbedding> embeddings,
  ) async {
    final allErrors = <String>[];
    
    // Validate nodes
    for (final node in nodes) {
      final result = McpValidator.validateNode(node);
      if (!result.isValid) {
        allErrors.addAll(result.errors.map((e) => 'Node ${node.id}: $e'));
      }
    }
    
    // Validate edges
    for (final edge in edges) {
      final result = McpValidator.validateEdge(edge);
      if (!result.isValid) {
        allErrors.addAll(result.errors.map((e) => 'Edge ${edge.source}->${edge.target}: $e'));
      }
    }
    
    // Validate pointers
    for (final pointer in pointers) {
      final result = McpValidator.validatePointer(pointer);
      if (!result.isValid) {
        allErrors.addAll(result.errors.map((e) => 'Pointer ${pointer.id}: $e'));
      }
    }
    
    // Validate embeddings
    for (final embedding in embeddings) {
      final result = McpValidator.validateEmbedding(embedding);
      if (!result.isValid) {
        allErrors.addAll(result.errors.map((e) => 'Embedding ${embedding.id}: $e'));
      }
    }
    
    return ValidationResult(
      isValid: allErrors.isEmpty,
      errors: allErrors,
    );
  }

  /// Export phase regimes to MCP format
  Future<PhaseExportData> _exportPhaseRegimes(PhaseIndex? phaseIndex) async {
    if (phaseIndex == null) {
      return const PhaseExportData(nodes: [], edges: [], pointers: []);
    }

    final nodes = <McpNode>[];
    final edges = <McpEdge>[];
    final pointers = <McpPointer>[];

    for (final regime in phaseIndex.allRegimes) {
      // Create phase regime node
      final regimeNode = McpNode(
        id: 'phase_regime_${regime.id}',
        type: 'phase_regime',
        timestamp: regime.start,
        contentSummary: 'Phase: ${regime.label.name}',
        phaseHint: regime.label.name,
        keywords: [regime.label.name],
        narrative: McpNarrative(
          situation: 'Phase regime from ${regime.start.toIso8601String()} to ${regime.end?.toIso8601String() ?? 'ongoing'}',
          action: 'Phase transition',
          growth: 'Life phase management',
          essence: 'Phase: ${regime.label.name}',
        ),
        emotions: {
          'confidence': regime.confidence ?? 1.0,
        },
        provenance: const McpProvenance(
          source: 'ARC',
          app: 'EPI',
          importMethod: 'phase_regime',
        ),
        metadata: {
          'phase_regime_id': regime.id,
          'phase_label': regime.label.name,
          'phase_source': regime.source.name,
          'confidence': regime.confidence,
          'inferred_at': regime.inferredAt?.toIso8601String(),
          'start_time': regime.start.toIso8601String(),
          'end_time': regime.end?.toIso8601String(),
          'is_ongoing': regime.isOngoing,
          'anchors': regime.anchors,
          'duration_days': regime.duration.inDays,
        },
      );

      nodes.add(regimeNode);

      // Create edges to anchored entries
      for (final entryId in regime.anchors) {
        final edge = McpEdge(
          id: 'edge_${regime.id}_$entryId',
          source: 'phase_regime_${regime.id}',
          target: 'entry_$entryId',
          relation: 'anchors',
          timestamp: regime.start,
          weight: 1.0,
          metadata: {
            'phase_regime_id': regime.id,
            'entry_id': entryId,
            'relationship_type': 'anchors',
          },
        );
        edges.add(edge);
      }
    }

    return PhaseExportData(
      nodes: nodes,
      edges: edges,
      pointers: pointers,
    );
  }

  /// Export RIVET state to MCP format
  Future<PhaseExportData> _exportRivetState() async {
    final nodes = <McpNode>[];
    final edges = <McpEdge>[];
    final pointers = <McpPointer>[];

    try {
      // Try to get user ID - we'll export all users' states if multiple exist
      if (!Hive.isBoxOpen(RivetBox.boxName)) {
        await Hive.openBox(RivetBox.boxName);
      }
      
      final stateBox = Hive.box(RivetBox.boxName);
      final eventsBox = Hive.isBoxOpen(RivetBox.eventsBoxName) 
          ? Hive.box(RivetBox.eventsBoxName)
          : await Hive.openBox(RivetBox.eventsBoxName);

      // Export all user states
      for (final userId in stateBox.keys) {
        final stateData = stateBox.get(userId);
        if (stateData == null) continue;

        final rivetState = rivet_models.RivetState.fromJson(
          stateData is Map<String, dynamic> 
              ? stateData 
              : Map<String, dynamic>.from(stateData as Map),
        );

        // Get events for this user
        final eventsData = eventsBox.get(userId, defaultValue: <dynamic>[]);
        final events = <rivet_models.RivetEvent>[];
        if (eventsData is List) {
          for (final eventData in eventsData) {
            try {
              final eventMap = eventData is Map<String, dynamic>
                  ? eventData
                  : Map<String, dynamic>.from(eventData as Map);
              events.add(rivet_models.RivetEvent.fromJson(eventMap));
            } catch (e) {
              print('MCP Export: Failed to parse RIVET event: $e');
            }
          }
        }

        // Prepare metadata with events if available
        final metadata = <String, dynamic>{
          'user_id': userId.toString(),
          'align': rivetState.align,
          'trace': rivetState.trace,
          'sustain_count': rivetState.sustainCount,
          'saw_independent_in_window': rivetState.sawIndependentInWindow,
          'event_count': events.length,
          'exported_at': DateTime.now().toIso8601String(),
        };

        // Add events as metadata if available
        if (events.isNotEmpty) {
          final recentEvents = events.take(10).toList(); // Export last 10 events
          metadata['recent_events'] = recentEvents.map((e) => e.toJson()).toList();
        }

        // Create RIVET state node
        final rivetNode = McpNode(
          id: 'rivet_state_$userId',
          type: 'rivet_state',
          timestamp: DateTime.now(),
          contentSummary: 'RIVET State: ALIGN=${rivetState.align.toStringAsFixed(3)}, TRACE=${rivetState.trace.toStringAsFixed(3)}',
          keywords: ['rivet', 'state', 'align', 'trace'],
          narrative: McpNarrative(
            situation: 'RIVET alignment and trace state',
            action: 'Phase readiness tracking',
            growth: 'Evidence accumulation',
            essence: 'ALIGN: ${rivetState.align.toStringAsFixed(3)}, TRACE: ${rivetState.trace.toStringAsFixed(3)}, Sustain: ${rivetState.sustainCount}',
          ),
          emotions: {
            'align': rivetState.align,
            'trace': rivetState.trace,
          },
          provenance: const McpProvenance(
            source: 'ARC',
            app: 'EPI',
            importMethod: 'rivet_state',
          ),
          metadata: metadata,
        );

        nodes.add(rivetNode);
      }
    } catch (e) {
      print('MCP Export: Error exporting RIVET state: $e');
      // Continue with export even if RIVET state fails
    }

    return PhaseExportData(
      nodes: nodes,
      edges: edges,
      pointers: pointers,
    );
  }

  /// Export Sentinel state to MCP format
  Future<PhaseExportData> _exportSentinelState() async {
    final nodes = <McpNode>[];
    final edges = <McpEdge>[];
    final pointers = <McpPointer>[];

    try {
      // Sentinel state may not be persistently stored - it's computed on the fly
      // For now, we'll create a placeholder node indicating Sentinel is active
      // In the future, if Sentinel state is stored, we can export it here
      
      final sentinelNode = McpNode(
        id: 'sentinel_state_current',
        type: 'sentinel_state',
        timestamp: DateTime.now(),
        contentSummary: 'Sentinel safety monitoring state',
        keywords: ['sentinel', 'safety', 'monitoring'],
        narrative: const McpNarrative(
          situation: 'Safety monitoring system state',
          action: 'Risk detection and alerting',
          growth: 'User safety protection',
          essence: 'Sentinel monitoring active',
        ),
        provenance: const McpProvenance(
          source: 'ARC',
          app: 'EPI',
          importMethod: 'sentinel_state',
        ),
        metadata: {
          'state': 'ok', // Default state - actual state would be computed
          'exported_at': DateTime.now().toIso8601String(),
          'note': 'Sentinel state is computed dynamically. This export represents the system state at export time.',
        },
      );

      nodes.add(sentinelNode);
    } catch (e) {
      print('MCP Export: Error exporting Sentinel state: $e');
    }

    return PhaseExportData(
      nodes: nodes,
      edges: edges,
      pointers: pointers,
    );
  }

  /// Export ArcForm timeline history to MCP format
  Future<PhaseExportData> _exportArcFormTimeline() async {
    final nodes = <McpNode>[];
    final edges = <McpEdge>[];
    final pointers = <McpPointer>[];

    try {
      if (!Hive.isBoxOpen('arcform_snapshots')) {
        await Hive.openBox<ArcformSnapshot>('arcform_snapshots');
      }

      final box = Hive.box<ArcformSnapshot>('arcform_snapshots');
      final snapshots = box.values.toList();

      for (final snapshot in snapshots) {
        // Create ArcForm snapshot node
        final arcformNode = McpNode(
          id: 'arcform_snapshot_${snapshot.id}',
          type: 'arcform_snapshot',
          timestamp: snapshot.timestamp,
          contentSummary: 'ArcForm snapshot: ${snapshot.arcformId}',
          phaseHint: snapshot.data['phase'] as String?,
          keywords: ['arcform', 'snapshot', 'timeline'],
          narrative: McpNarrative(
            situation: 'ArcForm visualization snapshot',
            action: 'Timeline visualization',
            growth: 'Visual pattern recognition',
            essence: snapshot.notes,
          ),
          provenance: const McpProvenance(
            source: 'ARC',
            app: 'EPI',
            importMethod: 'arcform_snapshot',
          ),
          metadata: {
            'arcform_id': snapshot.arcformId,
            'snapshot_id': snapshot.id,
            'notes': snapshot.notes,
            'data': snapshot.data,
            'exported_at': DateTime.now().toIso8601String(),
          },
        );

        nodes.add(arcformNode);

        // Create edge to journal entry if arcformId matches an entry
        final edge = McpEdge(
          id: 'edge_arcform_${snapshot.id}',
          source: 'arcform_snapshot_${snapshot.id}',
          target: 'entry_${snapshot.arcformId}',
          relation: 'visualizes',
          timestamp: snapshot.timestamp,
          weight: 1.0,
          metadata: {
            'arcform_snapshot_id': snapshot.id,
            'entry_id': snapshot.arcformId,
            'relationship_type': 'visualizes',
          },
        );
        edges.add(edge);
      }
    } catch (e) {
      print('MCP Export: Error exporting ArcForm timeline: $e');
      // Continue with export even if ArcForm timeline fails
    }

    return PhaseExportData(
      nodes: nodes,
      edges: edges,
      pointers: pointers,
    );
  }

  /// Export LUMARA favorites to MCP format
  Future<PhaseExportData> _exportLumaraFavorites() async {
    final nodes = <McpNode>[];
    final edges = <McpEdge>[];
    final pointers = <McpPointer>[];

    try {
      final favoritesService = FavoritesService.instance;
      await favoritesService.initialize();
      final favorites = await favoritesService.getAllFavorites();

      for (final favorite in favorites) {
        // Create favorite node
        final favoriteNode = McpNode(
          id: 'lumara_favorite_${favorite.id}',
          type: 'lumara_favorite',
          timestamp: favorite.timestamp.toUtc(),
          contentSummary: favorite.content.length > 100
              ? '${favorite.content.substring(0, 100)}...'
              : favorite.content,
          keywords: ['lumara', 'favorite', 'answer_style'],
          narrative: McpNarrative(
            situation: 'LUMARA favorite answer style',
            action: 'User-preferred response style',
            growth: 'Personalized AI interaction',
            essence: favorite.content,
          ),
          provenance: const McpProvenance(
            source: 'LUMARA',
            app: 'EPI',
            importMethod: 'lumara_favorite',
          ),
          metadata: {
            'favorite_id': favorite.id,
            'source_id': favorite.sourceId,
            'source_type': favorite.sourceType,
            'metadata': favorite.metadata,
            'exported_at': DateTime.now().toIso8601String(),
          },
        );

        nodes.add(favoriteNode);

        // Create edge to source if available
        if (favorite.sourceId != null) {
          final sourceNodeId = favorite.sourceType == 'chat'
              ? 'msg:${favorite.sourceId}'
              : 'entry:${favorite.sourceId}';
          
          final edge = McpEdge(
            source: 'lumara_favorite_${favorite.id}',
            target: sourceNodeId,
            relation: 'references',
            timestamp: favorite.timestamp.toUtc(),
            weight: 1.0,
            metadata: {
              'favorite_id': favorite.id,
              'source_id': favorite.sourceId,
              'source_type': favorite.sourceType,
            },
          );
          edges.add(edge);
        }
      }
    } catch (e) {
      print('MCP Export: Error exporting LUMARA favorites: $e');
      // Continue with export even if favorites fail
    }

    return PhaseExportData(
      nodes: nodes,
      edges: edges,
      pointers: pointers,
    );
  }

  /// Export LUMARA settings/preferences to MCP format
  Future<PhaseExportData> _exportLumaraSettings() async {
    final nodes = <McpNode>[];
    final edges = <McpEdge>[];
    final pointers = <McpPointer>[];

    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();
      final settings = await settingsService.loadAllSettings();

      // Create settings node
      final settingsNode = McpNode(
        id: 'lumara_settings_current',
        type: 'lumara_settings',
        timestamp: DateTime.now().toUtc(),
        contentSummary: 'LUMARA reflection and interaction settings',
        keywords: ['lumara', 'settings', 'preferences', 'reflection'],
        narrative: const McpNarrative(
          situation: 'LUMARA configuration and preferences',
          action: 'AI interaction customization',
          growth: 'Personalized reflection experience',
          essence: 'User preferences for LUMARA behavior',
        ),
        provenance: const McpProvenance(
          source: 'LUMARA',
          app: 'EPI',
          importMethod: 'lumara_settings',
        ),
        metadata: {
          'similarity_threshold': settings['similarityThreshold'],
          'lookback_years': settings['lookbackYears'],
          'max_matches': settings['maxMatches'],
          'cross_modal_enabled': settings['crossModalEnabled'],
          'therapeutic_presence_enabled': settings['therapeuticPresenceEnabled'],
          'therapeutic_depth_level': settings['therapeuticDepthLevel'],
          'exported_at': DateTime.now().toIso8601String(),
        },
      );

      nodes.add(settingsNode);
    } catch (e) {
      print('MCP Export: Error exporting LUMARA settings: $e');
      // Continue with export even if settings fail
    }

    return PhaseExportData(
      nodes: nodes,
      edges: edges,
      pointers: pointers,
    );
  }
}

/// MCP Export Result
class McpExportResult {
  final bool success;
  final String? error;
  final String bundleId;
  final Directory outputDir;
  final File? manifestFile;
  final Map<String, File>? ndjsonFiles;
  final McpCounts? counts;
  final List<McpEncoderRegistry>? encoderRegistry;
  final List<McpNode>? nodes;

  const McpExportResult({
    required this.success,
    this.error,
    required this.bundleId,
    required this.outputDir,
    this.manifestFile,
    this.ndjsonFiles,
    this.counts,
    this.encoderRegistry,
    this.nodes,
  });
}

/// MCP Export Exception
class McpExportException implements Exception {
  final String message;
  const McpExportException(this.message);
  
  @override
  String toString() => 'McpExportException: $message';
}

/// Container for phase export data
class PhaseExportData {
  final List<McpNode> nodes;
  final List<McpEdge> edges;
  final List<McpPointer> pointers;

  const PhaseExportData({
    required this.nodes,
    required this.edges,
    required this.pointers,
  });
}

/// Container for chat export data
class ChatExportData {
  final List<McpNode> nodes;
  final List<McpEdge> edges;
  final List<McpPointer> pointers;

  const ChatExportData({
    required this.nodes,
    required this.edges,
    required this.pointers,
  });
}

