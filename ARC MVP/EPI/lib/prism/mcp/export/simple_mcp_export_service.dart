import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/platform/photo_bridge.dart';
import 'package:my_app/prism/mcp/utils/image_processing.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';

/// Simplified MCP export service - everything in one ZIP file
class SimpleMcpExportService {
  final String _bundleId;
  final String _outputPath;

  SimpleMcpExportService({
    required String bundleId,
    required String outputPath,
  }) : _bundleId = bundleId,
       _outputPath = outputPath;

  /// Export journal entries with photos in a single ZIP file
  Future<SimpleExportResult> exportJournal({
    required List<JournalEntry> entries,
  }) async {
    try {
      print('📦 Starting simple MCP export to: $_outputPath');
      
      // Create the main ZIP archive
      final archive = Archive();
      
      // Process each entry
      final processedEntries = <Map<String, dynamic>>[];
      int totalPhotos = 0;
      
      for (final entry in entries) {
        final processedEntry = await _processJournalEntry(entry, archive);
        processedEntries.add(processedEntry);
        
        // Count photos in this entry
        final media = processedEntry['media'] as List<dynamic>;
        totalPhotos += media.where((m) => m['kind'] == 'photo').length;
      }

      // Create manifest
      final manifest = {
        'version': '1.0',
        'created_at': DateTime.now().toIso8601String(),
        'bundle_id': _bundleId,
        'total_entries': entries.length,
        'total_photos': totalPhotos,
        'format': 'simple_mcp',
      };
      
      // Add manifest to archive
      archive.addFile(ArchiveFile('manifest.json', jsonEncode(manifest).length, jsonEncode(manifest)));

      // Add entries to archive
      for (int i = 0; i < processedEntries.length; i++) {
        final entry = processedEntries[i];
        final entryJson = jsonEncode(entry);
        archive.addFile(ArchiveFile('entries/entry_$i.json', entryJson.length, entryJson));
      }

      // Write the ZIP file
      final zipFile = File(_outputPath);
      await zipFile.writeAsBytes(ZipEncoder().encode(archive)!);
      
      print('✅ Simple MCP export complete: ${processedEntries.length} entries, $totalPhotos photos');
      
      return SimpleExportResult(
        success: true,
        outputPath: _outputPath,
        totalEntries: processedEntries.length,
        totalPhotos: totalPhotos,
      );
      
    } catch (e) {
      print('❌ Simple MCP export failed: $e');
      return SimpleExportResult(
        success: false,
        error: e.toString(),
        outputPath: null,
        totalEntries: 0,
        totalPhotos: 0,
      );
    }
  }

  /// Process a single journal entry
  Future<Map<String, dynamic>> _processJournalEntry(
    JournalEntry entry,
    Archive archive,
  ) async {
    final processedMedia = <Map<String, dynamic>>[];

    for (final media in entry.media) {
      try {
        final processedMediaItem = await _processMediaItem(media, archive);
        if (processedMediaItem != null) {
          processedMedia.add(processedMediaItem);
        }
      } catch (e) {
        print('SimpleMcpExportService: Error processing media ${media.id}: $e');
        // Add a placeholder for failed media
        processedMedia.add({
          'id': media.id,
          'kind': 'photo',
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
      'keywords': entry.keywords,
      'metadata': entry.metadata,
    };

    return processedEntry;
  }

  /// Process a single media item
  Future<Map<String, dynamic>?> _processMediaItem(
    MediaItem media,
    Archive archive,
  ) async {
    // Get original bytes from file path
    Uint8List? originalBytes;
    String? originalFormat;

    // Check if this is a permanent file path
    if (media.uri.startsWith('/') && !media.uri.startsWith('ph://')) {
      // This is a permanent file path
      final file = File(media.uri);
      if (await file.exists()) {
        originalBytes = await file.readAsBytes();
        originalFormat = _getFileExtension(media.uri);
      }
    } else if (PhotoBridge.isPhotoLibraryUri(media.uri)) {
      // Get bytes from photo library (fallback for old entries)
      final localId = PhotoBridge.extractLocalIdentifier(media.uri);
      if (localId != null) {
        final photoData = await PhotoBridge.getPhotoBytes(localId);
        if (photoData != null) {
          originalBytes = photoData['bytes'] as Uint8List;
          originalFormat = photoData['ext'] as String;
        }
      }
    }

    if (originalBytes == null) {
      print('SimpleMcpExportService: Could not get bytes for media ${media.id}');
      return null;
    }

    // Use existing SHA-256 hash if available, otherwise compute it
    String sha;
    if (media.sha256 != null && media.sha256!.isNotEmpty) {
      sha = media.sha256!;
    } else {
      sha = sha256Hex(originalBytes);
    }

    // Add full-resolution photo to archive
    final photoFileName = 'photos/$sha.${originalFormat ?? 'jpg'}';
    
    // Check if photo already exists in archive (deduplication)
    if (!archive.files.any((file) => file.name == photoFileName)) {
      archive.addFile(ArchiveFile(photoFileName, originalBytes.length, originalBytes));
      print('📸 Added photo to archive: $photoFileName');
    }

    // Create thumbnail
    final thumbnailBytes = makeThumbnail(originalBytes, maxEdge: 200);
    final thumbnailFileName = 'thumbnails/$sha.jpg';
    
    // Check if thumbnail already exists in archive
    if (!archive.files.any((file) => file.name == thumbnailFileName)) {
      archive.addFile(ArchiveFile(thumbnailFileName, thumbnailBytes.length, thumbnailBytes));
      print('🖼️ Added thumbnail to archive: $thumbnailFileName');
    }

    // Create media reference
    return {
      'id': media.id,
      'kind': 'photo',
      'sha256': sha,
      'filename': photoFileName,
      'thumbnail': thumbnailFileName,
      'createdAt': media.createdAt.toIso8601String(),
      'altText': media.altText,
      'ocrText': media.ocrText,
      'analysisData': media.analysisData,
      'originalPath': media.uri, // Store original path for reference
    };
  }

  /// Get file extension from path
  String _getFileExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1) return 'jpg';
    return path.substring(lastDot + 1).toLowerCase();
  }
}

/// Result of a simple MCP export
class SimpleExportResult {
  final bool success;
  final String? outputPath;
  final int totalEntries;
  final int totalPhotos;
  final String? error;

  SimpleExportResult({
    required this.success,
    this.outputPath,
    required this.totalEntries,
    required this.totalPhotos,
    this.error,
  });
}
