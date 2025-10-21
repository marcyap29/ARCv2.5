import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import '../models/mcp_manifest.dart';
import '../../models/journal_entry_model.dart';
import '../../data/models/media_item.dart';
import '../../arc/core/journal_repository.dart';

/// MCP Pack Import Service for .zip files only
class McpPackImportService {
  final JournalRepository? _journalRepo;

  McpPackImportService({
    JournalRepository? journalRepo,
  }) : _journalRepo = journalRepo;

  /// Import from MCP package (.zip) only
  Future<McpImportResult> importFromPath(String inputPath) async {
    try {
      print('📥 Starting MCP import from: $inputPath');
      
      // Only accept .zip files
      final inputFile = File(inputPath);
      
      if (!await inputFile.exists() || !inputPath.endsWith('.zip')) {
        throw Exception('Invalid input: must be .zip file');
      }
      
      // It's a .zip MCP package file
      print('📦 Detected MCP package (.zip)');
      
      // Extract to temporary directory
      final tempDir = Directory.systemTemp.createTempSync('mcp_import_');
      await extractFileToDisk(inputPath, tempDir.path);
      
      // The ZIP contains files directly in the root, not in a mcp/ subdirectory
      final mcpDir = tempDir;

      // Read and validate manifest
      final manifestFile = File(path.join(mcpDir.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        throw Exception('Invalid MCP package: manifest.json not found');
      }

      final manifestJson = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      final manifest = McpManifest.fromJson(manifestJson);
      
      if (!manifest.isValid()) {
        throw Exception('Invalid MCP manifest: ${manifest.toString()}');
      }

      print('📋 Manifest validated: ${manifest.entryCount} entries, ${manifest.photoCount} photos');

      // Import photos first
      final photoMapping = await _importPhotos(mcpDir);
      print('📸 Imported ${photoMapping.length} photos');

      // Import journal entries
      final entriesImported = await _importJournalEntries(mcpDir, photoMapping);
      print('📝 Imported $entriesImported journal entries');

      // Clean up temporary directory (always extracted from ZIP)
      await mcpDir.parent.delete(recursive: true);

      return McpImportResult(
        success: true,
        totalEntries: entriesImported,
        totalPhotos: photoMapping.length,
        manifest: manifest,
      );

    } catch (e) {
      print('❌ MCP import failed: $e');
      return McpImportResult(
        success: false,
        error: e.toString(),
        totalEntries: 0,
        totalPhotos: 0,
      );
    }
  }

  /// Import photos from MCP package to app storage
  Future<Map<String, String>> _importPhotos(Directory mcpDir) async {
    final photoMapping = <String, String>{};
    
    final photosDir = Directory(path.join(mcpDir.path, 'media', 'photos'));
    if (!await photosDir.exists()) {
      print('⚠️ No photos directory found');
      return photoMapping;
    }

    // Get app documents directory for permanent storage
    final appDir = await getApplicationDocumentsDirectory();
    final permanentPhotosDir = Directory(path.join(appDir.path, 'photos'));
    await permanentPhotosDir.create(recursive: true);

    await for (final photoFile in photosDir.list()) {
      if (photoFile is File) {
        try {
          // Copy photo to permanent storage
          final fileName = path.basename(photoFile.path);
          final permanentPath = path.join(permanentPhotosDir.path, fileName);
          await photoFile.copy(permanentPath);
          
          // Map filename to permanent path
          photoMapping[fileName] = permanentPath;
          
          print('📸 Copied photo: $fileName');
        } catch (e) {
          print('⚠️ Failed to copy photo ${photoFile.path}: $e');
        }
      }
    }

    return photoMapping;
  }

  /// Import journal entries from MCP package
  Future<int> _importJournalEntries(Directory mcpDir, Map<String, String> photoMapping) async {
    int entriesImported = 0;
    
    final journalDir = Directory(path.join(mcpDir.path, 'nodes', 'journal'));
    if (!await journalDir.exists()) {
      print('⚠️ No journal directory found');
      return entriesImported;
    }

    await for (final entryFile in journalDir.list()) {
      if (entryFile is File && entryFile.path.endsWith('.json')) {
        try {
          final entryJson = jsonDecode(await entryFile.readAsString()) as Map<String, dynamic>;
          
          // Process media items and link to permanent photo paths
          final mediaItems = <MediaItem>[];
          final mediaData = entryJson['media'] as List<dynamic>? ?? [];
          
          for (final mediaJson in mediaData) {
            if (mediaJson is Map<String, dynamic>) {
              final mediaItem = await _createMediaItemFromJson(mediaJson, photoMapping);
              if (mediaItem != null) {
                mediaItems.add(mediaItem);
              }
            }
          }

          // Create journal entry
          final journalEntry = JournalEntry(
            id: entryJson['id'] as String,
            title: _generateTitle(entryJson['content'] as String? ?? ''),
            content: entryJson['content'] as String? ?? '',
            createdAt: DateTime.parse(entryJson['timestamp'] as String),
            updatedAt: DateTime.parse(entryJson['timestamp'] as String),
            media: mediaItems,
            tags: (entryJson['keywords'] as List<dynamic>? ?? []).cast<String>(),
            keywords: (entryJson['keywords'] as List<dynamic>? ?? []).cast<String>(),
            mood: entryJson['emotion'] as String? ?? 'Neutral',
            emotion: entryJson['emotion'] as String?,
            emotionReason: entryJson['emotionReason'] as String?,
            metadata: {
              'imported_from_mcp': true,
              'original_mcp_id': entryJson['id'],
              'import_timestamp': DateTime.now().toIso8601String(),
              'phase': entryJson['phase'],
              ...?entryJson['metadata'] as Map<String, dynamic>?,
            },
          );

          // Save to journal repository
          if (_journalRepo != null) {
            await _journalRepo!.createJournalEntry(journalEntry);
            entriesImported++;
            print('📝 Imported entry: ${journalEntry.title}');
          }

        } catch (e) {
          print('⚠️ Failed to import entry ${entryFile.path}: $e');
        }
      }
    }

    return entriesImported;
  }

  /// Create MediaItem from JSON with photo mapping
  Future<MediaItem?> _createMediaItemFromJson(
    Map<String, dynamic> mediaJson,
    Map<String, String> photoMapping,
  ) async {
    try {
      final filename = mediaJson['filename'] as String?;
      if (filename == null) return null;

      // Get permanent path from mapping
      final permanentPath = photoMapping[filename];
      if (permanentPath == null) {
        print('⚠️ No permanent path found for photo: $filename');
        return null;
      }

      return MediaItem(
        id: mediaJson['id'] as String,
        type: MediaType.image,
        uri: permanentPath,
        createdAt: DateTime.parse(mediaJson['createdAt'] as String),
        analysisData: mediaJson['analysisData'] as Map<String, dynamic>?,
        altText: mediaJson['altText'] as String?,
        ocrText: mediaJson['ocrText'] as String?,
        sha256: mediaJson['sha256'] as String?,
      );
    } catch (e) {
      print('⚠️ Failed to create MediaItem: $e');
      return null;
    }
  }

  /// Generate title from content
  String _generateTitle(String content) {
    if (content.isEmpty) return 'Untitled Entry';
    
    // Take first line or first 50 characters
    final firstLine = content.split('\n').first.trim();
    if (firstLine.length <= 50) {
      return firstLine;
    } else {
      return '${firstLine.substring(0, 47)}...';
    }
  }
}

/// Result of an MCP import operation
class McpImportResult {
  final bool success;
  final int totalEntries;
  final int totalPhotos;
  final McpManifest? manifest;
  final String? error;

  McpImportResult({
    required this.success,
    required this.totalEntries,
    required this.totalPhotos,
    this.manifest,
    this.error,
  });
}
