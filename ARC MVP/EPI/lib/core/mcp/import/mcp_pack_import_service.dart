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

  // Media deduplication cache - maps URI to MediaItem to prevent duplicates
  final Map<String, MediaItem> _mediaCache = {};

  McpPackImportService({
    JournalRepository? journalRepo,
  }) : _journalRepo = journalRepo;
  
  /// Clear the media cache (call before starting a new import)
  void clearMediaCache() {
    _mediaCache.clear();
    print('🧹 Cleared media cache for new import');
  }

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

      // Clear media cache for this import
      clearMediaCache();

      // Import all media (photos, videos, audio, files) first
      final mediaMapping = await _importAllMedia(mcpDir);
      print('📸 Imported ${mediaMapping.length} media items (photos, videos, audio, files)');

      // Load photo metadata files for enhanced matching
      final photoMetadataMap = await _loadPhotoMetadata(mcpDir);
      print('📋 Loaded ${photoMetadataMap.length} photo metadata files');

      // Import journal entries
      final entriesImported = await _importJournalEntries(mcpDir, mediaMapping, photoMetadataMap);
      print('📝 Imported $entriesImported journal entries');
      
      // Log media cache statistics
      print('📊 Media Cache Statistics:');
      print('   Total unique media items cached: ${_mediaCache.length}');
      final mediaByType = <String, int>{};
      for (final item in _mediaCache.values) {
        mediaByType[item.type.name] = (mediaByType[item.type.name] ?? 0) + 1;
      }
      for (final entry in mediaByType.entries) {
        print('   - ${entry.key}: ${entry.value}');
      }

      // Clean up temporary directory (always extracted from ZIP)
      await mcpDir.parent.delete(recursive: true);

      return McpImportResult(
        success: true,
        totalEntries: entriesImported,
        totalPhotos: mediaMapping.length, // Includes photos, videos, audio, files
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

  /// Import all media (photos, videos, audio, files) from MCP package to app storage
  Future<Map<String, String>> _importAllMedia(Directory mcpDir) async {
    final mediaMapping = <String, String>{};
    
    // Get app documents directory for permanent storage
    final appDir = await getApplicationDocumentsDirectory();
    
    // Import photos
    await _importMediaType(mcpDir, appDir, 'photos', 'photos', mediaMapping);
    
    // Import videos
    await _importMediaType(mcpDir, appDir, 'videos', 'videos', mediaMapping);
    
    // Import audio
    await _importMediaType(mcpDir, appDir, 'audio', 'audio', mediaMapping);
    
    // Import files
    await _importMediaType(mcpDir, appDir, 'files', 'files', mediaMapping);

    return mediaMapping;
  }

  /// Import a specific media type from MCP package
  Future<void> _importMediaType(
    Directory mcpDir,
    Directory appDir,
    String sourceSubDir,
    String targetSubDir,
    Map<String, String> mediaMapping,
  ) async {
    final sourceDir = Directory(path.join(mcpDir.path, 'media', sourceSubDir));
    if (!await sourceDir.exists()) {
      return; // Directory doesn't exist, skip silently
    }

    final permanentDir = Directory(path.join(appDir.path, targetSubDir));
    await permanentDir.create(recursive: true);

    await for (final mediaFile in sourceDir.list()) {
      if (mediaFile is File) {
        try {
          // Copy media file to permanent storage
          final fileName = path.basename(mediaFile.path);
          final permanentPath = path.join(permanentDir.path, fileName);
          await mediaFile.copy(permanentPath);
          
          // Map filename to permanent path
          mediaMapping[fileName] = permanentPath;
          
          final icon = sourceSubDir == 'videos' ? '📹' : 
                      sourceSubDir == 'audio' ? '🎵' :
                      sourceSubDir == 'files' ? '📄' : '📸';
          print('$icon Copied $sourceSubDir: $fileName');
        } catch (e) {
          print('⚠️ Failed to copy $sourceSubDir ${mediaFile.path}: $e');
        }
      }
    }
  }

  /// Load photo metadata files from nodes/media/photo directory
  Future<Map<String, Map<String, dynamic>>> _loadPhotoMetadata(Directory mcpDir) async {
    final metadataMap = <String, Map<String, dynamic>>{};
    
    final photoMetadataDir = Directory(path.join(mcpDir.path, 'nodes', 'media', 'photo'));
    if (!await photoMetadataDir.exists()) {
      print('⚠️ No photo metadata directory found');
      return metadataMap;
    }

    await for (final file in photoMetadataDir.list()) {
      if (file is File && file.path.endsWith('.json')) {
        try {
          final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
          final photoId = json['id'] as String? ?? path.basenameWithoutExtension(file.path);
          if (photoId.isNotEmpty) {
            metadataMap[photoId] = json;
          }
        } catch (e) {
          print('⚠️ Failed to load photo metadata from ${file.path}: $e');
        }
      }
    }

    return metadataMap;
  }

  /// Import journal entries from MCP package
  Future<int> _importJournalEntries(
    Directory mcpDir,
    Map<String, String> photoMapping,
    Map<String, Map<String, dynamic>> photoMetadataMap,
  ) async {
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
          // Check multiple locations for media (robust fallback)
          final mediaItems = <MediaItem>[];
          List<dynamic>? mediaData = entryJson['media'] as List<dynamic>?;
          
          // Fallback 1: Check metadata.media
          if (mediaData == null || mediaData.isEmpty) {
            final metadata = entryJson['metadata'] as Map<String, dynamic>?;
            if (metadata != null) {
              mediaData = metadata['media'] as List<dynamic>?;
              if (mediaData != null && mediaData.isNotEmpty) {
                print('📝 Found ${mediaData.length} media items in metadata.media for entry ${entryJson['id']}');
              }
            }
          }
          
          // Fallback 2: Check metadata.journal_entry.media
          if (mediaData == null || mediaData.isEmpty) {
            final metadata = entryJson['metadata'] as Map<String, dynamic>?;
            if (metadata != null) {
              final journalEntryMeta = metadata['journal_entry'] as Map<String, dynamic>?;
              if (journalEntryMeta != null) {
                mediaData = journalEntryMeta['media'] as List<dynamic>?;
                if (mediaData != null && mediaData.isNotEmpty) {
                  print('📝 Found ${mediaData.length} media items in metadata.journal_entry.media for entry ${entryJson['id']}');
                }
              }
            }
          }
          
          // Fallback 3: Check metadata.photos
          if (mediaData == null || mediaData.isEmpty) {
            final metadata = entryJson['metadata'] as Map<String, dynamic>?;
            if (metadata != null) {
              final photosData = metadata['photos'] as List<dynamic>?;
              if (photosData != null && photosData.isNotEmpty) {
                print('📝 Found ${photosData.length} photos in metadata.photos for entry ${entryJson['id']}');
                // Convert photos array to media format
                mediaData = photosData.map((photo) {
                  if (photo is Map<String, dynamic>) {
                    return {
                      'id': photo['id'] ?? photo['placeholder_id'] ?? '',
                      'filename': photo['filename'],
                      'originalPath': photo['uri'] ?? photo['path'],
                      'createdAt': photo['createdAt'] ?? photo['created_at'],
                      'analysisData': photo['analysisData'] ?? photo['analysis_data'],
                      'altText': photo['altText'] ?? photo['alt_text'],
                      'ocrText': photo['ocrText'] ?? photo['ocr_text'],
                      'sha256': photo['sha256'],
                    };
                  }
                  return photo;
                }).toList();
              }
            }
          }
          
          mediaData ??= [];
          
          if (mediaData.isNotEmpty) {
            entriesWithMedia++;
            print('📝 Processing entry ${entryJson['id']} with ${mediaData.length} media items');
          } else {
            print('📝 Processing entry ${entryJson['id']} with NO media items');
          }
          
          for (final mediaJson in mediaData) {
            if (mediaJson is Map<String, dynamic>) {
              try {
                // Try to enhance media JSON with photo metadata if available
                final mediaId = mediaJson['id'] as String?;
                Map<String, dynamic> enhancedMediaJson = mediaJson;
                if (mediaId != null && photoMetadataMap.containsKey(mediaId)) {
                  final metadata = photoMetadataMap[mediaId]!;
                  // Merge metadata into mediaJson, preferring metadata values
                  enhancedMediaJson = {
                    ...mediaJson,
                    // Use metadata values if mediaJson doesn't have them
                    'filename': mediaJson['filename'] ?? metadata['filename'],
                    'sha256': mediaJson['sha256'] ?? metadata['sha256'],
                    'originalPath': mediaJson['originalPath'] ?? metadata['originalPath'],
                    'createdAt': mediaJson['createdAt'] ?? metadata['createdAt'],
                    'analysisData': mediaJson['analysisData'] ?? metadata['analysisData'],
                    'altText': mediaJson['altText'] ?? metadata['altText'],
                    'ocrText': mediaJson['ocrText'] ?? metadata['ocrText'],
                  };
                  print('📋 Enhanced media ${mediaId} with metadata from photo metadata file');
                }
                
                final mediaItem = await _createMediaItemFromJson(enhancedMediaJson, photoMapping, entryJson['id'] as String? ?? 'unknown');
              if (mediaItem != null) {
                  // Check cache for deduplication
                  final cacheKey = mediaItem.uri;
                  if (_mediaCache.containsKey(cacheKey)) {
                    final cachedMediaItem = _mediaCache[cacheKey]!;
                    mediaItems.add(cachedMediaItem);
                    print('♻️ Reusing cached media: ${cachedMediaItem.id} -> $cacheKey');
                  } else {
                    _mediaCache[cacheKey] = mediaItem;
                mediaItems.add(mediaItem);
                    print('✅ Added media item ${mediaItem.id} to entry ${entryJson['id']}');
                  }
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
          final entryId = entryJson['id'] as String? ?? 'unknown';
          print('📝 Creating journal entry $entryId with ${mediaItems.length}/${mediaData.length} media items');
          
          // Special logging for entries 23, 24, 25
          if (entryId.contains('da055a24') || entryId.contains('ee12c32f') || entryId.contains('f25f9d72')) {
            print('🔍 DEBUG: Processing entry $entryId (entry 23/24/25)');
            print('   Media items processed: ${mediaItems.length}');
            print('   Media items data: ${mediaData.length}');
            for (int i = 0; i < mediaItems.length; i++) {
              print('   Media[$i]: id=${mediaItems[i].id}, uri=${mediaItems[i].uri}');
            }
          }

          // Create journal entry
          JournalEntry journalEntry;
          try {
            journalEntry = JournalEntry(
              id: entryId,
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
                'original_mcp_id': entryId,
              'import_timestamp': DateTime.now().toIso8601String(),
              'phase': entryJson['phase'],
              ...?entryJson['metadata'] as Map<String, dynamic>?,
            },
          );
            print('✅ Successfully created JournalEntry object for $entryId');
          } catch (e, stackTrace) {
            print('❌ ERROR: Failed to create JournalEntry object for $entryId: $e');
            print('   Stack trace: $stackTrace');
            rethrow; // Re-throw to be caught by outer try-catch
          }

          // Save to journal repository
          if (_journalRepo != null) {
            try {
              // Special logging for entries 23, 24, 25
              if (entryId.contains('da055a24') || entryId.contains('ee12c32f') || entryId.contains('f25f9d72')) {
                print('🔍 DEBUG: About to save entry $entryId to repository');
                print('   Entry has ${journalEntry.media.length} media items');
              }
              
            await _journalRepo!.createJournalEntry(journalEntry);
            entriesImported++;
              
              // Special logging for entries 23, 24, 25
              if (entryId.contains('da055a24') || entryId.contains('ee12c32f') || entryId.contains('f25f9d72')) {
                print('🔍 DEBUG: Successfully saved entry $entryId to repository');
              }
              
              print('✅ Successfully imported entry ${journalEntry.id}: ${journalEntry.title} (${mediaItems.length} media items)');
            } catch (e, stackTrace) {
              print('❌ ERROR: Failed to save entry ${journalEntry.id} to repository: $e');
              print('   Stack trace: $stackTrace');
              
              // Special logging for entries 23, 24, 25
              if (entryId.contains('da055a24') || entryId.contains('ee12c32f') || entryId.contains('f25f9d72')) {
                print('🔍 DEBUG: Entry $entryId FAILED to save - this is entry 23/24/25!');
                print('   Exception type: ${e.runtimeType}');
                print('   Exception message: $e');
              }
              
              // Continue processing other entries even if this one fails
            }
          } else {
            print('⚠️ Warning: No journal repository available, skipping entry ${journalEntry.id}');
            
            // Special logging for entries 23, 24, 25
            if (entryId.contains('da055a24') || entryId.contains('ee12c32f') || entryId.contains('f25f9d72')) {
              print('🔍 DEBUG: Entry $entryId skipped - NO JOURNAL REPOSITORY!');
            }
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

  /// Create MediaItem from JSON with photo mapping (robust version with multiple fallbacks)
  Future<MediaItem?> _createMediaItemFromJson(
    Map<String, dynamic> mediaJson,
    Map<String, String> photoMapping,
    String entryId,
  ) async {
    try {
      // Extract media ID (try multiple field names)
      final mediaId = mediaJson['id'] as String? ?? 
                      mediaJson['photo_id'] as String? ?? 
                      mediaJson['placeholder_id'] as String? ?? 
                      '';
      
      if (mediaId.isEmpty) {
        print('⚠️ Media item missing ID field for entry $entryId');
        print('   Available keys: ${mediaJson.keys.join(', ')}');
      }
      
      // Try multiple ways to find the filename
      String? filename = mediaJson['filename'] as String?;
      if (filename == null || filename.isEmpty) {
        // Try alternative field names
        filename = mediaJson['file_name'] as String?;
        if (filename == null || filename.isEmpty) {
          filename = mediaJson['name'] as String?;
        }
      }

      // Extract media type FIRST (support multiple field names: 'kind', 'type', default to 'image')
      // Must extract early as it's used in URI determination
      MediaType mediaType = MediaType.image;
      final kindStr = mediaJson['kind'] as String?;
      final typeStr = mediaJson['type'] as String?;
      if (kindStr != null) {
        switch (kindStr.toLowerCase()) {
          case 'video':
            mediaType = MediaType.video;
            break;
          case 'audio':
            mediaType = MediaType.audio;
            break;
          case 'file':
            mediaType = MediaType.file;
            break;
          case 'image':
          case 'photo':
            mediaType = MediaType.image;
            break;
        }
      } else if (typeStr != null) {
        switch (typeStr.toLowerCase()) {
          case 'video':
            mediaType = MediaType.video;
            break;
          case 'audio':
            mediaType = MediaType.audio;
            break;
          case 'file':
            mediaType = MediaType.file;
            break;
          case 'image':
          case 'photo':
            mediaType = MediaType.image;
            break;
        }
      }

      // Try to get permanent path from mapping
      String? permanentPath;
      if (filename != null && filename.isNotEmpty) {
        permanentPath = photoMapping[filename];
        if (permanentPath == null) {
          // Try matching by SHA-256 if filename doesn't match
          final sha256 = mediaJson['sha256'] as String?;
          if (sha256 != null && sha256.isNotEmpty) {
            // Look for media file that matches SHA-256
            for (final entry in photoMapping.entries) {
              if (entry.key.contains(sha256.substring(0, 8))) {
                permanentPath = entry.value;
                print('🔗 Matched media by SHA-256 prefix: ${sha256.substring(0, 8)}...');
                break;
              }
            }
          }
        }
      }

      // Determine final URI (try multiple fallbacks)
      String finalUri;
      if (permanentPath != null) {
        finalUri = permanentPath;
      } else {
        // Fallback 1: Try originalPath
        final originalPath = mediaJson['originalPath'] as String? ?? 
                             mediaJson['original_path'] as String? ??
                             mediaJson['uri'] as String? ??
                             mediaJson['path'] as String?;
        
        if (originalPath != null && originalPath.isNotEmpty) {
          finalUri = originalPath;
          print('   Using originalPath/uri as fallback: $originalPath');
        } else {
          // Fallback 2: Try to construct from filename if available
          if (filename != null && filename.isNotEmpty) {
            final appDir = await getApplicationDocumentsDirectory();
            // Check appropriate directory based on media type
            String mediaSubDir;
            switch (mediaType) {
              case MediaType.video:
                mediaSubDir = 'videos';
                break;
              case MediaType.audio:
                mediaSubDir = 'audio';
                break;
              case MediaType.file:
                mediaSubDir = 'files';
                break;
              case MediaType.image:
                mediaSubDir = 'photos';
                break;
            }
            final mediaDir = Directory(path.join(appDir.path, mediaSubDir));
            final constructedPath = path.join(mediaDir.path, filename);
            if (await File(constructedPath).exists()) {
              finalUri = constructedPath;
              print('   Found media at constructed path: $constructedPath');
            } else {
              // Last resort: placeholder URI
              finalUri = 'placeholder://$mediaId';
              print('⚠️ Could not find media file, using placeholder: $finalUri');
            }
          } else {
            // Last resort: placeholder URI
            finalUri = 'placeholder://$mediaId';
            print('⚠️ No filename or path found, using placeholder: $finalUri');
          }
        }
      }

      // Extract analysis data (try multiple field names)
      Map<String, dynamic>? analysisData = mediaJson['analysisData'] as Map<String, dynamic>?;
      if (analysisData == null) {
        analysisData = mediaJson['analysis_data'] as Map<String, dynamic>?;
      }
      if (analysisData == null && mediaJson.containsKey('features')) {
        analysisData = {'features': mediaJson['features']};
      }

      // Extract duration (for video/audio)
      Duration? duration;
      if (mediaJson['duration'] != null) {
        final dur = mediaJson['duration'];
        if (dur is int) {
          duration = Duration(seconds: dur);
        } else if (dur is String) {
          duration = Duration(seconds: int.tryParse(dur) ?? 0);
        }
      }

      // Extract sizeBytes
      int? sizeBytes = mediaJson['sizeBytes'] as int?;
      if (sizeBytes == null) {
        sizeBytes = mediaJson['size_bytes'] as int?;
      }
      if (sizeBytes == null && mediaJson['size'] != null) {
        sizeBytes = mediaJson['size'] as int?;
      }

      return MediaItem(
        id: mediaId,
        type: mediaType, // Use detected type (image, video, audio, file)
        uri: finalUri,
        createdAt: _parseMediaTimestamp(
          mediaJson['createdAt'] as String? ?? 
          mediaJson['created_at'] as String?
        ),
        duration: duration,
        sizeBytes: sizeBytes,
        analysisData: analysisData,
        altText: mediaJson['altText'] as String? ?? 
                 mediaJson['alt_text'] as String?,
        ocrText: mediaJson['ocrText'] as String? ?? 
                 mediaJson['ocr_text'] as String?,
        transcript: mediaJson['transcript'] as String?,
        sha256: mediaJson['sha256'] as String?,
      );
    } catch (e, stackTrace) {
      print('⚠️ Failed to create MediaItem: $e');
      print('   Stack trace: $stackTrace');
      print('   Media JSON keys: ${mediaJson.keys.join(', ')}');
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

