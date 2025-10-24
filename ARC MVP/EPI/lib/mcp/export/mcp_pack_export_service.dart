import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/platform/photo_bridge.dart';
import 'package:my_app/prism/mcp/utils/image_processing.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/mcp_manifest.dart';

/// MCP Pack Export Service for .mcpkg and .mcp/ formats
class McpPackExportService {
  final String _bundleId;
  final String _outputPath;
  final bool _isDebugMode;

  McpPackExportService({
    required String bundleId,
    required String outputPath,
    bool isDebugMode = false,
  }) : _bundleId = bundleId,
       _outputPath = outputPath,
       _isDebugMode = isDebugMode;

  /// Export journal entries to MCP package format
  Future<McpExportResult> exportJournal({
    required List<JournalEntry> entries,
    bool includePhotos = true,
    bool reducePhotoSize = false,
  }) async {
    Directory? tempDir;
    try {
      print('📦 Starting MCP export to: $_outputPath');

      // Create temporary directory for MCP structure
      // Use getApplicationDocumentsDirectory instead of systemTemp for iOS compatibility
      final appDir = await getApplicationDocumentsDirectory();
      final tempDirPath = path.join(appDir.path, 'tmp', 'mcp_export_${DateTime.now().millisecondsSinceEpoch}');
      tempDir = Directory(tempDirPath);

      // Ensure temp directory exists
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      await tempDir.create(recursive: true);

      final mcpDir = Directory(path.join(tempDir.path, 'mcp'));
      await mcpDir.create(recursive: true);
      
      // Create MCP directory structure
      await Directory(path.join(mcpDir.path, 'nodes', 'journal')).create(recursive: true);
      await Directory(path.join(mcpDir.path, 'nodes', 'media', 'photo')).create(recursive: true);
      await Directory(path.join(mcpDir.path, 'media', 'photos')).create(recursive: true);
      
      // Process each entry
      final processedEntries = <Map<String, dynamic>>[];
      int totalPhotos = 0;
      
      for (int i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final processedEntry = await _processJournalEntry(entry, i, mcpDir, includePhotos, reducePhotoSize);
        processedEntries.add(processedEntry);
        
        // Count photos in this entry
        final media = processedEntry['media'] as List<dynamic>;
        totalPhotos += media.where((m) => m['kind'] == 'photo').length;
      }

      // Create manifest
      final manifest = McpManifest.journal(
        entryCount: entries.length,
        photoCount: totalPhotos,
        metadata: {
          'bundle_id': _bundleId,
          'include_photos': includePhotos,
          'reduce_photo_size': reducePhotoSize,
        },
      );
      
      // Write manifest
      final manifestFile = File(path.join(mcpDir.path, 'manifest.json'));
      await manifestFile.writeAsString(manifest.toJsonString());
      
      print('📋 Created manifest: ${manifest.entryCount} entries, ${manifest.photoCount} photos');

      // Create final output
      if (_isDebugMode) {
        // Debug mode: output as .mcp/ folder
        final outputDir = Directory(_outputPath);
        if (await outputDir.exists()) {
          await outputDir.delete(recursive: true);
        }
        await mcpDir.rename(outputDir.path);
        
        print('📁 Debug mode: Created MCP folder at $_outputPath');
        
        return McpExportResult(
          success: true,
          outputPath: _outputPath,
          totalEntries: entries.length,
          totalPhotos: totalPhotos,
          isDebugMode: true,
        );
      } else {
        // User mode: create .mcpkg ZIP file
        final archive = Archive();
        
        // Add all files from MCP directory to archive
        await _addDirectoryToArchive(archive, mcpDir, '');
        
        // Write ZIP file
        final zipFile = File(_outputPath);
        await zipFile.writeAsBytes(ZipEncoder().encode(archive)!);
        
        // Clean up temp directory
        await tempDir.delete(recursive: true);
        
        print('📦 User mode: Created MCP package at $_outputPath');
        
        return McpExportResult(
          success: true,
          outputPath: _outputPath,
          totalEntries: entries.length,
          totalPhotos: totalPhotos,
          isDebugMode: false,
        );
      }
      
    } catch (e) {
      print('❌ MCP export failed: $e');

      // Clean up temp directory on error
      if (tempDir != null) {
        try {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
            print('🗑️ Cleaned up temp directory after error');
          }
        } catch (cleanupError) {
          print('⚠️ Warning: Failed to clean up temp directory: $cleanupError');
        }
      }

      return McpExportResult(
        success: false,
        error: e.toString(),
        outputPath: null,
        totalEntries: 0,
        totalPhotos: 0,
        isDebugMode: _isDebugMode,
      );
    }
  }

  /// Process a single journal entry
  Future<Map<String, dynamic>> _processJournalEntry(
    JournalEntry entry,
    int index,
    Directory mcpDir,
    bool includePhotos,
    bool reducePhotoSize,
  ) async {
    final processedMedia = <Map<String, dynamic>>[];

    if (includePhotos) {
      for (final media in entry.media) {
        try {
          final processedMediaItem = await _processMediaItem(media, mcpDir, reducePhotoSize);
          if (processedMediaItem != null) {
            processedMedia.add(processedMediaItem);
          }
        } catch (e) {
          print('McpPackExportService: Error processing media ${media.id}: $e');
          // Add a placeholder for failed media
          processedMedia.add({
            'id': media.id,
            'kind': 'photo',
            'error': e.toString(),
          });
        }
      }
    }

    // Create processed entry with properly formatted timestamp
    final processedEntry = {
      'id': entry.id,
      'timestamp': _formatTimestamp(entry.createdAt),
      'content': entry.content,
      'media': processedMedia,
      'emotion': entry.emotion,
      'emotionReason': entry.emotionReason,
      'phase': entry.phase,
      'keywords': entry.keywords,
      'metadata': entry.metadata,
    };

    // Write entry JSON
    final entryFile = File(path.join(mcpDir.path, 'nodes', 'journal', 'entry_$index.json'));
    await entryFile.writeAsString(jsonEncode(processedEntry));

    return processedEntry;
  }

  /// Process a single media item
  Future<Map<String, dynamic>?> _processMediaItem(
    MediaItem media,
    Directory mcpDir,
    bool reducePhotoSize,
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
      print('McpPackExportService: Could not get bytes for media ${media.id}');
      return null;
    }

    // Use existing SHA-256 hash if available, otherwise compute it
    String sha;
    if (media.sha256 != null && media.sha256!.isNotEmpty) {
      sha = media.sha256!;
    } else {
      sha = sha256Hex(originalBytes);
    }

    // Process photo based on size reduction setting
    Uint8List finalBytes = originalBytes;
    if (reducePhotoSize) {
      final reencoded = reencodeFull(originalBytes, maxEdge: 1920, quality: 85);
      finalBytes = reencoded.bytes;
    }

    // Add photo to media directory
    final photoFileName = '$sha.${originalFormat ?? 'jpg'}';
    final photoFile = File(path.join(mcpDir.path, 'media', 'photos', photoFileName));
    await photoFile.writeAsBytes(finalBytes);
    
    print('📸 Added photo: $photoFileName');

    // Create media node JSON
    final mediaNode = {
      'id': media.id,
      'kind': 'photo',
      'sha256': sha,
      'filename': photoFileName,
      'createdAt': media.createdAt.toIso8601String(),
      'altText': media.altText,
      'ocrText': media.ocrText,
      'analysisData': media.analysisData,
      'originalPath': media.uri,
      'reduced': reducePhotoSize,
    };

    // Write media node JSON
    final mediaNodeFile = File(path.join(mcpDir.path, 'nodes', 'media', 'photo', '${media.id}.json'));
    await mediaNodeFile.writeAsString(jsonEncode(mediaNode));

    return mediaNode;
  }

  /// Add directory contents to archive recursively
  Future<void> _addDirectoryToArchive(Archive archive, Directory dir, String prefix) async {
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = path.relative(entity.path, from: dir.path);
        final archivePath = prefix.isEmpty ? relativePath : path.join(prefix, relativePath);
        
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
      }
    }
  }

  /// Get file extension from path
  String _getFileExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1) return 'jpg';
    return path.substring(lastDot + 1).toLowerCase();
  }

  /// Format timestamp to ensure consistent ISO 8601 format with Z suffix
  String _formatTimestamp(DateTime dateTime) {
    // Ensure the timestamp is in UTC and has the Z suffix
    final utcDateTime = dateTime.toUtc();
    final isoString = utcDateTime.toIso8601String();
    
    // Ensure it ends with 'Z' for UTC timezone
    if (isoString.endsWith('Z')) {
      return isoString;
    } else {
      return '${isoString}Z';
    }
  }
}

/// Result of an MCP export operation
class McpExportResult {
  final bool success;
  final String? outputPath;
  final int totalEntries;
  final int totalPhotos;
  final bool isDebugMode;
  final String? error;

  McpExportResult({
    required this.success,
    this.outputPath,
    required this.totalEntries,
    required this.totalPhotos,
    required this.isDebugMode,
    this.error,
  });
}
