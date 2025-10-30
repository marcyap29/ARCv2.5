import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import '../models/mcp_manifest.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/arc/core/journal_repository.dart';

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

    int totalEntriesFound = 0;
    int entriesWithMedia = 0;
    
    await for (final entryFile in journalDir.list()) {
      if (entryFile is File && entryFile.path.endsWith('.json')) {
        totalEntriesFound++;
        try {
          final entryJson = jsonDecode(await entryFile.readAsString()) as Map<String, dynamic>;
          
          // Process media items and link to permanent photo paths
          final mediaItems = <MediaItem>[];
          final mediaData = entryJson['media'] as List<dynamic>? ?? [];
          
          if (mediaData.isNotEmpty) {
            entriesWithMedia++;
            print('📝 Processing entry ${entryJson['id']} with ${mediaData.length} media items');
          } else {
            print('📝 Processing entry ${entryJson['id']} with NO media items');
          }
          
          for (final mediaJson in mediaData) {
            if (mediaJson is Map<String, dynamic>) {
              try {
                final mediaItem = await _createMediaItemFromJson(mediaJson, photoMapping);
                if (mediaItem != null) {
                  mediaItems.add(mediaItem);
                  print('✅ Added media item ${mediaItem.id} to entry ${entryJson['id']}');
                } else {
                  print('⚠️ Failed to create media item for entry ${entryJson['id']}');
                }
              } catch (e, stackTrace) {
                print('⚠️ ERROR creating media item for entry ${entryJson['id']}: $e');
                print('   Stack trace: $stackTrace');
                // Continue processing other media items - don't let one failure stop the entry
              }
            }
          }
          
          if (mediaData.length > 0 && mediaItems.isEmpty) {
            print('⚠️ Entry ${entryJson['id']} had ${mediaData.length} media items but none could be mapped!');
            print('   Photo mapping contains ${photoMapping.length} photos');
            print('   First media item filename: ${mediaData[0] is Map ? (mediaData[0] as Map<String, dynamic>)['filename'] : 'N/A'}');
          }
          
          // IMPORTANT: Always import the entry, even if media items failed
          print('📝 Creating journal entry ${entryJson['id']} with ${mediaItems.length}/${mediaData.length} media items');

          // Create journal entry
          final journalEntry = JournalEntry(
            id: entryJson['id'] as String,
            title: _generateTitle(entryJson['content'] as String? ?? ''),
            content: entryJson['content'] as String? ?? '',
            createdAt: _parseTimestamp(entryJson['timestamp'] as String),
            updatedAt: _parseTimestamp(entryJson['timestamp'] as String),
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
            try {
              await _journalRepo!.createJournalEntry(journalEntry);
              entriesImported++;
              print('✅ Successfully imported entry ${journalEntry.id}: ${journalEntry.title} (${mediaItems.length} media items)');
            } catch (e, stackTrace) {
              print('❌ ERROR: Failed to save entry ${journalEntry.id} to repository: $e');
              print('   Stack trace: $stackTrace');
              // Continue processing other entries even if this one fails
            }
          } else {
            print('⚠️ Warning: No journal repository available, skipping entry ${journalEntry.id}');
          }

        } catch (e, stackTrace) {
          print('❌ ERROR: Failed to import entry ${entryFile.path}: $e');
          print('   Stack trace: $stackTrace');
          // Even if import fails, continue with other entries
          // Don't let one bad entry stop the entire import
        }
      }
    }

    print('📊 Import Summary:');
    print('   Total entries found: $totalEntriesFound');
    print('   Entries with media: $entriesWithMedia');
    print('   Entries successfully imported: $entriesImported');
    
    if (entriesImported < totalEntriesFound) {
      print('⚠️ WARNING: ${totalEntriesFound - entriesImported} entries were NOT imported!');
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
      if (filename == null) {
        print('⚠️ Media item missing filename field');
        return null;
      }

      // Get permanent path from mapping
      final permanentPath = photoMapping[filename];
      if (permanentPath == null) {
        print('⚠️ No permanent path found for photo: $filename');
        print('   Available photo filenames in mapping: ${photoMapping.keys.take(5).join(', ')}...');
        // Still try to create MediaItem with the original filename/path if available
        final originalPath = mediaJson['originalPath'] as String?;
        if (originalPath != null) {
          print('   Using originalPath as fallback: $originalPath');
          return MediaItem(
            id: mediaJson['id'] as String,
            type: MediaType.image,
            uri: originalPath,
            createdAt: _parseMediaTimestamp(mediaJson['createdAt'] as String?),
            analysisData: mediaJson['analysisData'] as Map<String, dynamic>?,
            altText: mediaJson['altText'] as String?,
            ocrText: mediaJson['ocrText'] as String?,
            sha256: mediaJson['sha256'] as String?,
          );
        }
        return null;
      }

      return MediaItem(
        id: mediaJson['id'] as String,
        type: MediaType.image,
        uri: permanentPath,
        createdAt: _parseMediaTimestamp(mediaJson['createdAt'] as String?),
        analysisData: mediaJson['analysisData'] as Map<String, dynamic>?,
        altText: mediaJson['altText'] as String?,
        ocrText: mediaJson['ocrText'] as String?,
        sha256: mediaJson['sha256'] as String?,
      );
    } catch (e) {
      print('⚠️ Failed to create MediaItem: $e');
      print('   Media JSON: ${mediaJson.keys}');
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

  /// Parse timestamp with robust handling of different formats
  DateTime _parseTimestamp(String timestamp) {
    try {
      // Handle malformed timestamps missing 'Z' suffix
      if (timestamp.endsWith('.000') && !timestamp.endsWith('Z')) {
        // Add 'Z' suffix for UTC timezone
        timestamp = '${timestamp}Z';
      } else if (!timestamp.endsWith('Z') && !timestamp.contains('+') && !timestamp.contains('-', 10)) {
        // If no timezone indicator, assume UTC and add 'Z'
        timestamp = '${timestamp}Z';
      }
      
      return DateTime.parse(timestamp);
    } catch (e) {
      print('⚠️ Failed to parse timestamp "$timestamp": $e');
      // Fallback to current time if parsing fails
      return DateTime.now();
    }
  }

  /// Parse media timestamp with robust handling (can be null)
  DateTime _parseMediaTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) {
      return DateTime.now();
    }
    try {
      return _parseTimestamp(timestamp);
    } catch (e) {
      print('⚠️ Failed to parse media timestamp "$timestamp": $e, using current time');
      return DateTime.now();
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
