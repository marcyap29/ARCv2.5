import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/platform/photo_bridge.dart';
import 'package:my_app/prism/mcp/utils/image_processing.dart';
import 'package:my_app/prism/mcp/models/journal_manifest.dart';
import 'package:my_app/prism/mcp/models/media_pack_manifest.dart';
import 'package:my_app/prism/mcp/models/media_pack_metadata.dart';
import 'package:my_app/prism/mcp/zip/mcp_zip_writer.dart';

/// MCP media export service with rolling media packs
class McpMediaExportService {
  final String _bundleId;
  final ThumbnailConfig _thumbnailConfig;
  final MediaPackConfig _mediaPackConfig;
  final String _outputDir;
  
  // Current media pack state
  MediaPackWriter? _currentMediaPack;
  String? _currentPackId;
  DateTime? _currentPackStart;
  
  // Pack tracking
  final List<MediaPackMetadata> _createdPacks = [];
  int _currentPackFileCount = 0;
  int _currentPackSizeBytes = 0;

  McpMediaExportService({
    required String bundleId,
    required String outputDir,
    ThumbnailConfig? thumbnailConfig,
    MediaPackConfig? mediaPackConfig,
  }) : _bundleId = bundleId,
       _outputDir = outputDir,
       _thumbnailConfig = thumbnailConfig ?? ThumbnailConfig.defaultConfig,
       _mediaPackConfig = mediaPackConfig ?? MediaPackConfig.defaultConfig;

  /// Export journal entries with content-addressed media
  Future<ContentAddressedExportResult> exportJournal({
    required List<JournalEntry> entries,
    bool createMediaPacks = true,
  }) async {
    try {
      // Initialize current media pack if needed
      if (createMediaPacks) {
        await _initializeCurrentMediaPack();
      }

      // Process each entry
      final processedEntries = <Map<String, dynamic>>[];
      final journalWriter = McpZipWriter(outputPath: '$_outputDir/journal_v1.mcp.zip');
      
      for (final entry in entries) {
        final processedEntry = await _processJournalEntry(entry, journalWriter);
        processedEntries.add(processedEntry);
      }

      // Create journal manifest
      final journalManifest = JournalManifest(
        version: 1,
        createdAt: DateTime.now(),
        mediaPacks: _getMediaPackReferences(),
        thumbnails: _thumbnailConfig,
      );

      journalWriter.addJournalManifest(journalManifest);
      await journalWriter.write();

      // Finalize current media pack
      if (_currentMediaPack != null) {
        await _currentMediaPack!.finalize();
        
        // Create pack metadata
        final packMetadata = MediaPackMetadata(
          packId: _currentPackId!,
          createdAt: _currentPackStart!,
          fileCount: _currentPackFileCount,
          totalSizeBytes: _currentPackSizeBytes,
          dateFrom: _currentPackStart!,
          dateTo: DateTime.now(),
          status: MediaPackStatus.active,
          storagePath: '$_outputDir/$_currentPackId.zip',
          description: 'Media pack for ${_currentPackStart!.month}/${_currentPackStart!.year}',
        );
        
        _createdPacks.add(packMetadata);
        print('📦 Created pack metadata: ${packMetadata.packId} (${packMetadata.fileCount} files, ${packMetadata.formattedSize})');
      }

      // Generate legacy MCP Memory Bundle format files for import compatibility
      await _generateLegacyMcpFiles(processedEntries);

      return ContentAddressedExportResult(
        success: true,
        journalPath: '$_outputDir/journal_v1.mcp.zip',
        mediaPackPaths: _getMediaPackPaths(),
        processedEntries: processedEntries.length,
        totalMediaItems: _countTotalMediaItems(processedEntries),
      );
    } catch (e) {
      return ContentAddressedExportResult(
        success: false,
        error: e.toString(),
        journalPath: null,
        mediaPackPaths: [],
        processedEntries: 0,
        totalMediaItems: 0,
      );
    }
  }

  /// Process a single journal entry
  Future<Map<String, dynamic>> _processJournalEntry(
    JournalEntry entry,
    McpZipWriter journalWriter,
  ) async {
    final processedMedia = <Map<String, dynamic>>[];

    for (final media in entry.media) {
      try {
        final processedMediaItem = await _processMediaItem(media, journalWriter);
        if (processedMediaItem != null) {
          processedMedia.add(processedMediaItem);
        }
      } catch (e) {
        print('ContentAddressedExportService: Error processing media ${media.id}: $e');
        // Add a placeholder for failed media
        processedMedia.add({
          'id': media.id,
          'kind': 'photo',
          'sha256': '',
          'thumbUri': 'assets/thumbs/error.jpg',
          'fullRef': 'mcp://photo/error',
          'createdAt': media.createdAt.toIso8601String(),
          'error': e.toString(),
        });
      }
    }

    // Create processed entry
    final processedEntry = {
      'id': entry.id,
      'timestamp': entry.createdAt.toIso8601String(),
      'content': entry.content,
      'media': processedMedia,
      'emotion': entry.emotion,
      'emotionReason': entry.emotionReason,
      'phase': entry.phase,
      'metadata': entry.metadata,
    };

    // Add entry to journal
    journalWriter.addJournalEntry(entry.id, processedEntry);

    return processedEntry;
  }

  /// Process a single media item
  Future<Map<String, dynamic>?> _processMediaItem(
    MediaItem media,
    McpZipWriter journalWriter,
  ) async {
    // Get original bytes
    Uint8List? originalBytes;
    String? originalFormat;

    if (PhotoBridge.isPhotoLibraryUri(media.uri)) {
      // Get bytes from photo library
      final localId = PhotoBridge.extractLocalIdentifier(media.uri);
      if (localId != null) {
        final photoData = await PhotoBridge.getPhotoBytes(localId);
        if (photoData != null) {
          originalBytes = photoData['bytes'] as Uint8List;
          originalFormat = photoData['ext'] as String;
        }
      }
    } else if (PhotoBridge.isFilePath(media.uri)) {
      // Get bytes from file
      final file = File(media.uri);
      if (await file.exists()) {
        originalBytes = await file.readAsBytes();
        originalFormat = _getFileExtension(media.uri);
      }
    }

    if (originalBytes == null) {
      print('ContentAddressedExportService: Could not get bytes for media ${media.id}');
      return null;
    }

    // Compute SHA-256 hash
    final sha = sha256Hex(originalBytes);

    // Check if we already have this media in current pack
    if (_currentMediaPack != null && _currentMediaPack!.hasFile('photos/$sha.${originalFormat ?? 'jpg'}')) {
      // Media already exists, just create reference
      return _createMediaReference(media, sha, originalFormat ?? 'jpg');
    }

    // Process full-resolution image
    final reencoded = reencodeFull(
      originalBytes,
      maxEdge: _mediaPackConfig.maxEdge,
      quality: _mediaPackConfig.quality,
    );

    // Add to current media pack
    if (_currentMediaPack != null) {
      _currentMediaPack!.addPhoto(sha, reencoded.ext, reencoded.bytes);
      _currentPackFileCount++;
      _currentPackSizeBytes += reencoded.bytes.length;
    }

    // Create thumbnail
    final thumbnailBytes = makeThumbnail(
      originalBytes,
      maxEdge: _thumbnailConfig.size,
    );

    // Add thumbnail to journal
    journalWriter.addThumbnail(sha, thumbnailBytes);

    return _createMediaReference(media, sha, reencoded.ext);
  }

  /// Create media reference for processed media
  Map<String, dynamic> _createMediaReference(
    MediaItem originalMedia,
    String sha,
    String format,
  ) {
    return {
      'id': originalMedia.id,
      'kind': 'photo',
      'sha256': sha,
      'thumbUri': 'assets/thumbs/$sha.jpg',
      'fullRef': 'mcp://photo/$sha',
      'createdAt': originalMedia.createdAt.toIso8601String(),
      'altText': originalMedia.altText,
      'ocrText': originalMedia.ocrText,
      'analysisData': originalMedia.analysisData,
    };
  }

  /// Initialize current media pack with date-based naming and monthly rotation
  Future<void> _initializeCurrentMediaPack() async {
    final now = DateTime.now();
    
    // Generate date-based pack ID: mcp_media_YYYYMMDD_NNN
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    
    // Check if we need a new pack for this month
    final currentMonth = '${now.year}${now.month.toString().padLeft(2, '0')}';
    final lastPackMonth = _createdPacks.isNotEmpty 
        ? _createdPacks.last.packId.substring(9, 15) // Extract YYYYMM from pack ID
        : null;
    
    // If month changed or no packs exist, start new pack
    if (lastPackMonth != currentMonth) {
      _currentPackId = 'mcp_media_${dateStr}_001';
    } else {
      // Same month, increment sequence
      final lastPackId = _createdPacks.last.packId;
      final lastSequence = int.tryParse(lastPackId.substring(16)) ?? 0;
      final newSequence = (lastSequence + 1).toString().padLeft(3, '0');
      _currentPackId = 'mcp_media_${dateStr}_$newSequence';
    }
    
    _currentPackStart = now;
    _currentPackFileCount = 0;
    _currentPackSizeBytes = 0;
    
    final packPath = '$_outputDir/$_currentPackId.zip';
    _currentMediaPack = MediaPackWriter(
      outputPath: packPath,
      packId: _currentPackId!,
      from: _currentPackStart!,
      to: now,
    );
    
    print('📦 Initialized media pack: $_currentPackId');
  }

  /// Get media pack references for journal manifest
  List<MediaPackRef> _getMediaPackReferences() {
    final refs = <MediaPackRef>[];
    
    if (_currentMediaPack != null) {
      refs.add(MediaPackRef(
        id: _currentPackId!,
        filename: 'mcp_media_$_currentPackId.zip',
        from: _currentPackStart!,
        to: DateTime.now(),
      ));
    }
    
    return refs;
  }

  /// Get media pack file paths
  List<String> _getMediaPackPaths() {
    final paths = <String>[];
    
    if (_currentMediaPack != null) {
      paths.add('$_outputDir/mcp_media_$_currentPackId.zip');
    }
    
    return paths;
  }

  /// Count total media items in processed entries
  int _countTotalMediaItems(List<Map<String, dynamic>> entries) {
    return entries.fold(0, (sum, entry) {
      final media = entry['media'] as List<dynamic>? ?? [];
      return sum + media.length;
    });
  }

  /// Get file extension from path
  String _getFileExtension(String path) {
    final parts = path.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return 'jpg';
  }

  /// Get metadata for all created packs
  List<MediaPackMetadata> get createdPacks => List.unmodifiable(_createdPacks);

  /// Generate legacy MCP Memory Bundle format files for import compatibility
  Future<void> _generateLegacyMcpFiles(List<Map<String, dynamic>> processedEntries) async {
    try {
      // Generate manifest.json
      final manifest = {
        'version': '1.0.0',
        'created_at': DateTime.now().toIso8601String(),
        'bundle_id': _bundleId,
        'type': 'memory_bundle',
        'entries_count': processedEntries.length,
        'description': 'MCP Media Export with Legacy MCP Compatibility',
      };
      
      final manifestFile = File('$_outputDir/manifest.json');
      await manifestFile.writeAsString(jsonEncode(manifest));
      
      // Generate nodes.jsonl
      final nodesFile = File('$_outputDir/nodes.jsonl');
      final nodesSink = nodesFile.openWrite();
      
      for (final entry in processedEntries) {
        final node = {
          'id': entry['id'],
          'type': 'journal_entry',
          'content': entry['content'],
          'created_at': entry['created_at'],
          'metadata': entry['metadata'] ?? {},
          'media_count': (entry['media'] as List<dynamic>? ?? []).length,
          'media': entry['media'] ?? [], // Include full media array with SHA-256 references
        };
        nodesSink.writeln(jsonEncode(node));
      }
      await nodesSink.close();
      
      // Generate edges.jsonl (empty for now, but structure exists for future relationships)
      final edgesFile = File('$_outputDir/edges.jsonl');
      await edgesFile.writeAsString(''); // Empty for now, but file exists for compatibility
      
      print('✅ Generated legacy MCP files: manifest.json, nodes.jsonl, edges.jsonl');
    } catch (e) {
      print('❌ Error generating legacy MCP files: $e');
      // Don't throw - this is for compatibility, not critical
    }
  }
}

/// Result of content-addressed export
class ContentAddressedExportResult {
  final bool success;
  final String? error;
  final String? journalPath;
  final List<String> mediaPackPaths;
  final int processedEntries;
  final int totalMediaItems;

  const ContentAddressedExportResult({
    required this.success,
    this.error,
    this.journalPath,
    required this.mediaPackPaths,
    required this.processedEntries,
    required this.totalMediaItems,
  });
}
