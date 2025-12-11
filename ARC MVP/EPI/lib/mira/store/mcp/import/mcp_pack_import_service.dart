import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import '../models/mcp_manifest.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/core/utils/timestamp_parser.dart';
import 'package:my_app/core/utils/title_generator.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/arc/chat/services/favorites_service.dart';
import 'package:my_app/arc/chat/data/models/lumara_favorite.dart';
import 'package:my_app/prism/atlas/rivet/rivet_storage.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart' as rivet_models;
import 'package:my_app/models/arcform_snapshot_model.dart';
import 'package:hive/hive.dart';
import 'package:my_app/prism/atlas/phase/phase_inference_service.dart';
import 'package:my_app/models/user_profile_model.dart';
import 'package:my_app/state/journal_entry_state.dart';
import 'package:my_app/arc/chat/chat/chat_repo.dart';

/// MCP Pack Import Service for .zip files only
class McpPackImportService {
  final JournalRepository? _journalRepo;
  final PhaseRegimeService? _phaseRegimeService;
  final ChatRepo? _chatRepo;

  // Media deduplication cache - maps URI to MediaItem to prevent duplicates
  final Map<String, MediaItem> _mediaCache = {};

  McpPackImportService({
    JournalRepository? journalRepo,
    PhaseRegimeService? phaseRegimeService,
    ChatRepo? chatRepo,
  }) : _journalRepo = journalRepo,
       _phaseRegimeService = phaseRegimeService,
       _chatRepo = chatRepo;
  
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
      final entryImportResult = await _importJournalEntries(mcpDir, mediaMapping, photoMetadataMap);
      final entriesImported = entryImportResult['imported'] as int;
      final entriesTotal = entryImportResult['total'] as int;
      print('📝 Imported $entriesImported/$entriesTotal journal entries');
      
      // Import chat data (sessions and messages)
      int chatSessionCount = 0;
      int chatMessageCount = 0;
      if (_chatRepo != null) {
        try {
          final chatData = await _importChatData(mcpDir);
          chatSessionCount = chatData['sessionCount'] as int;
          chatMessageCount = chatData['messageCount'] as int;
          print('📱 MCP Import: Imported $chatSessionCount chat sessions, $chatMessageCount messages');
        } catch (e) {
          print('⚠️ MCP Import: Failed to import chat data: $e');
        }
      }

      // Import extended data (Phase Regimes, Rivet, Sentinel, ArcForm, Favorites)
      try {
        await _importExtendedData(mcpDir);
      } catch (e) {
        print('⚠️ MCP Import: Failed to import extended data: $e');
      }
      
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

      // Rebuild phase regimes using 10-day rolling windows for imported entries
      if (entriesImported > 0 && _journalRepo != null) {
        try {
          print('🔄 Rebuilding phase regimes for imported entries...');
          final allEntries = _journalRepo!.getAllJournalEntriesSync();
          final analyticsService = AnalyticsService();
          final rivetSweepService = RivetSweepService(analyticsService);
          final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
          await phaseRegimeService.initialize();
          await phaseRegimeService.rebuildRegimesFromEntries(allEntries, windowDays: 10);
          print('✅ Phase regimes rebuilt using 10-day rolling windows');
        } catch (e) {
          print('⚠️ Failed to rebuild phase regimes: $e');
        }
      }

      return McpImportResult(
        success: true,
        totalEntries: entriesImported,
        totalEntriesFound: entriesTotal,
        totalPhotos: mediaMapping.length, // Includes photos, videos, audio, files
        totalPhotosFound: mediaMapping.length, // All media items were found and mapped
        manifest: manifest,
      );

    } catch (e) {
      print('❌ MCP import failed: $e');
      return McpImportResult(
        success: false,
        error: e.toString(),
        totalEntries: 0,
        totalEntriesFound: 0,
        totalPhotos: 0,
        totalPhotosFound: 0,
      );
    }
  }

  /// Import all media (photos, videos, audio, files) from MCP package to app storage
  Future<Map<String, String>> _importAllMedia(Directory mcpDir) async {
    final mediaMapping = <String, String>{};

    // Get app documents directory for permanent storage
    final appDir = await getApplicationDocumentsDirectory();
    int importedFromPacks = 0;

    // New format: /Media/packs + media_index.json
    final mediaPacksDir = Directory(path.join(mcpDir.path, 'Media'));
    if (await mediaPacksDir.exists()) {
      importedFromPacks = await _importMediaFromPacks(
        mediaDir: mediaPacksDir,
        appDir: appDir,
        mediaMapping: mediaMapping,
      );
    }
    
    // Legacy format fallback: /media/{photos,videos,...}
    if (importedFromPacks == 0) {
      await _importMediaType(mcpDir, appDir, 'photos', 'photos', mediaMapping);
      await _importMediaType(mcpDir, appDir, 'videos', 'videos', mediaMapping);
      await _importMediaType(mcpDir, appDir, 'audio', 'audio', mediaMapping);
      await _importMediaType(mcpDir, appDir, 'files', 'files', mediaMapping);
    }

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

  /// Import media from /Media/packs using media_index.json (new MCP pack format)
  Future<int> _importMediaFromPacks({
    required Directory mediaDir,
    required Directory appDir,
    required Map<String, String> mediaMapping,
  }) async {
    final mediaIndexFile = File(path.join(mediaDir.path, 'media_index.json'));
    if (!await mediaIndexFile.exists()) {
      print('📦 MCP Import: No media_index.json found in Media directory');
      return 0;
    }

    final packsDir = Directory(path.join(mediaDir.path, 'packs'));
    if (!await packsDir.exists()) {
      print('📦 MCP Import: No packs directory found inside Media');
      return 0;
    }

    final mediaIndexJson = jsonDecode(await mediaIndexFile.readAsString()) as Map<String, dynamic>;
    final items = mediaIndexJson['items'] as List<dynamic>? ?? [];

    if (items.isEmpty) {
      print('📦 MCP Import: media_index.json contained no media items');
      return 0;
    }

    int imported = 0;

    for (final rawItem in items) {
      if (rawItem is! Map<String, dynamic>) continue;

      final filename = rawItem['filename'] as String?;
      final packName = rawItem['pack'] as String?;

      if (filename == null || filename.isEmpty || packName == null || packName.isEmpty) {
        continue;
      }

      final sourceFile = File(path.join(packsDir.path, packName, filename));
      if (!await sourceFile.exists()) {
        print('📦 MCP Import: Missing file $filename in pack $packName');
        continue;
      }

      final contentType = rawItem['content_type'] as String? ?? 'image/jpeg';
      final targetSubDir = _targetSubDirForContentType(contentType);
      final permanentDir = Directory(path.join(appDir.path, targetSubDir));
      await permanentDir.create(recursive: true);

      final destFile = File(path.join(permanentDir.path, filename));
      try {
        await sourceFile.copy(destFile.path);
        mediaMapping[filename] = destFile.path;
        imported++;
      } catch (e) {
        print('📦 MCP Import: Failed to copy $filename from pack $packName: $e');
      }
    }

    print('📦 MCP Import: Imported $imported media items from Media packs');
    return imported;
  }

  String _targetSubDirForContentType(String contentType) {
    if (contentType.startsWith('video/')) {
      return 'videos';
    }
    if (contentType.startsWith('audio/')) {
      return 'audio';
    }
    if (contentType.startsWith('image/')) {
      return 'photos';
    }
    return 'files';
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
  /// Returns a map with 'imported' (successful) and 'total' (found) counts
  Future<Map<String, int>> _importJournalEntries(
    Directory mcpDir,
    Map<String, String> photoMapping,
    Map<String, Map<String, dynamic>> photoMetadataMap,
  ) async {
    int entriesImported = 0;
    
    final journalDir = Directory(path.join(mcpDir.path, 'nodes', 'journal'));
    if (!await journalDir.exists()) {
      print('⚠️ No journal directory found');
      return {'imported': entriesImported, 'total': 0};
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
                  print('⚠️ Skipped media item ${mediaId} - file not found during import');
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

          // Read phase fields from imported JSON (new versioned phase system)
          final autoPhase = entryJson['autoPhase'] as String?;
          final autoPhaseConfidence = (entryJson['autoPhaseConfidence'] as num?)?.toDouble();
          final userPhaseOverride = entryJson['userPhaseOverride'] as String?;
          final isPhaseLocked = entryJson['isPhaseLocked'] as bool? ?? false;
          final legacyPhaseTag = entryJson['legacyPhaseTag'] as String? ?? entryJson['phase'] as String?;
          final importSource = entryJson['importSource'] as String? ?? 'ZIP';
          final phaseInferenceVersion = entryJson['phaseInferenceVersion'] as int?;
          final phaseMigrationStatus = entryJson['phaseMigrationStatus'] as String?;
          
          // Determine migration status
          final migrationStatus = phaseMigrationStatus ?? 
              (phaseInferenceVersion == null || phaseInferenceVersion < CURRENT_PHASE_INFERENCE_VERSION 
                  ? 'PENDING' 
                  : 'DONE');
          
          // Parse LUMARA blocks from JSON
          final List<InlineBlock> lumaraBlocks = [];
          final lumaraBlocksJson = entryJson['lumaraBlocks'] as List<dynamic>? ?? [];
          for (final blockJson in lumaraBlocksJson) {
            if (blockJson is Map<String, dynamic>) {
              try {
                final inlineBlock = InlineBlock.fromJson(blockJson);
                lumaraBlocks.add(inlineBlock);
                print('✅ Parsed LUMARA block: ${inlineBlock.type} - ${inlineBlock.content?.substring(0, 50) ?? 'No content'}...');
              } catch (e) {
                print('⚠️ Failed to parse LUMARA block: $e');
                print('   Block JSON: $blockJson');
                // Continue with other blocks - don't let one failure stop the import
              }
            }
          }

          if (lumaraBlocks.isNotEmpty) {
            print('📝 Entry $entryId: Found ${lumaraBlocks.length} LUMARA blocks');
          }

          // Create journal entry
          JournalEntry journalEntry;
          try {
            // Use exported title if available, otherwise generate from content
            final exportedTitle = entryJson['title'] as String?;
            final title = (exportedTitle != null && exportedTitle.isNotEmpty)
                ? exportedTitle
                : TitleGenerator.forImportedEntry(entryJson['content'] as String? ?? '');
            
            journalEntry = JournalEntry(
              id: entryId,
            title: title,
            content: entryJson['content'] as String? ?? '',
            createdAt: () {
              final timestampResult = TimestampParser.parseEntryTimestamp(entryJson['timestamp'] as String);
              if (!timestampResult.isSuccess) {
                throw Exception(timestampResult.error ?? 'Failed to parse timestamp');
              }
              return timestampResult.value!;
            }(),
            updatedAt: () {
              final timestampResult = TimestampParser.parseEntryTimestamp(entryJson['timestamp'] as String);
              if (!timestampResult.isSuccess) {
                throw Exception(timestampResult.error ?? 'Failed to parse timestamp');
              }
              return timestampResult.value!;
            }(),
            media: mediaItems,
            tags: (entryJson['keywords'] as List<dynamic>? ?? []).cast<String>(),
            keywords: (entryJson['keywords'] as List<dynamic>? ?? []).cast<String>(),
            mood: entryJson['emotion'] as String? ?? 'Neutral',
            emotion: entryJson['emotion'] as String?,
            emotionReason: entryJson['emotionReason'] as String?,
            phase: legacyPhaseTag, // Keep old phase field for backward compatibility
            autoPhase: autoPhase,
            autoPhaseConfidence: autoPhaseConfidence,
            userPhaseOverride: userPhaseOverride,
            isPhaseLocked: isPhaseLocked,
            legacyPhaseTag: legacyPhaseTag,
            importSource: importSource,
            phaseInferenceVersion: phaseInferenceVersion,
            phaseMigrationStatus: migrationStatus,
            lumaraBlocks: lumaraBlocks, // Import LUMARA blocks from JSON
            metadata: {
              'imported_from_mcp': true,
                'original_mcp_id': entryId,
              'import_timestamp': DateTime.now().toIso8601String(),
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
              
              // If entry needs phase inference, run it after import
              if (journalEntry.phaseMigrationStatus == 'PENDING' && !journalEntry.isPhaseLocked) {
                _inferPhaseForImportedEntry(journalEntry);
              }
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

    return {'imported': entriesImported, 'total': totalEntriesFound};
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
              // Media file not found - skip this media item instead of creating broken reference
              print('⚠️ Could not find media file for $mediaId, skipping import');
              return null;
            }
          } else {
            // No filename or path found - skip this media item
            print('⚠️ No filename or path found for $mediaId, skipping import');
            return null;
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


  /// Parse media timestamp with robust handling (can be null)
  DateTime _parseMediaTimestamp(String? timestamp) {
    return TimestampParser.parseMediaTimestamp(timestamp);
  }

  /// Import extended data from extensions/ directory
  Future<void> _importExtendedData(Directory mcpDir) async {
    final extensionsDir = Directory(path.join(mcpDir.path, 'extensions'));
    if (!await extensionsDir.exists()) {
      print('📦 MCP Import: No extensions directory found (legacy format)');
      return;
    }

    // 1. Phase Regimes
    if (_phaseRegimeService != null) {
      try {
        final phaseRegimesFile = File(path.join(extensionsDir.path, 'phase_regimes.json'));
        if (await phaseRegimesFile.exists()) {
          final content = await phaseRegimesFile.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          await _phaseRegimeService!.importFromMcp(data);
          final regimes = data['phase_regimes'] as List? ?? [];
          print('📦 MCP Import: ✓ Imported ${regimes.length} phase regimes');
        }
      } catch (e) {
        print('⚠️ MCP Import: Failed to import phase regimes: $e');
      }
    }

    // 2. RIVET State
    try {
      final rivetStateFile = File(path.join(extensionsDir.path, 'rivet_state.json'));
      if (await rivetStateFile.exists()) {
        final content = await rivetStateFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final rivetStates = data['rivet_states'] as Map<String, dynamic>? ?? {};
        
        if (!Hive.isBoxOpen(RivetBox.boxName)) {
          await Hive.openBox(RivetBox.boxName);
        }
        if (!Hive.isBoxOpen(RivetBox.eventsBoxName)) {
          await Hive.openBox(RivetBox.eventsBoxName);
        }
        
        final stateBox = Hive.box(RivetBox.boxName);
        final eventsBox = Hive.box(RivetBox.eventsBoxName);
        
        int importedCount = 0;
        for (final entry in rivetStates.entries) {
          final userId = entry.key;
          final userData = entry.value as Map<String, dynamic>;
          
          final stateJson = userData['state'] as Map<String, dynamic>;
          final rivetState = rivet_models.RivetState.fromJson(stateJson);
          
          await stateBox.put(userId, rivetState.toJson());
          
          final eventsJson = userData['events'] as List<dynamic>? ?? [];
          if (eventsJson.isNotEmpty) {
            final events = eventsJson
                .map((e) => rivet_models.RivetEvent.fromJson(e as Map<String, dynamic>))
                .toList();
            await eventsBox.put(userId, events.map((e) => e.toJson()).toList());
          }
          
          importedCount++;
        }
        
        print('📦 MCP Import: ✓ Imported RIVET state for $importedCount users');
      }
    } catch (e) {
      print('⚠️ MCP Import: Failed to import RIVET state: $e');
    }

    // 3. Sentinel State (read-only, informational)
    try {
      final sentinelStateFile = File(path.join(extensionsDir.path, 'sentinel_state.json'));
      if (await sentinelStateFile.exists()) {
        print('📦 MCP Import: ✓ Found Sentinel state (informational only)');
      }
    } catch (e) {
      print('⚠️ MCP Import: Failed to read Sentinel state: $e');
    }

    // 4. ArcForm Timeline
    try {
      final arcformTimelineFile = File(path.join(extensionsDir.path, 'arcform_timeline.json'));
      if (await arcformTimelineFile.exists()) {
        final content = await arcformTimelineFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final snapshotsJson = data['arcform_snapshots'] as List<dynamic>? ?? [];
        
        if (!Hive.isBoxOpen('arcform_snapshots')) {
          await Hive.openBox<ArcformSnapshot>('arcform_snapshots');
        }
        
        final box = Hive.box<ArcformSnapshot>('arcform_snapshots');
        int importedCount = 0;
        
        for (final snapshotJson in snapshotsJson) {
          try {
            final snapshot = ArcformSnapshot.fromJson(snapshotJson as Map<String, dynamic>);
            await box.put(snapshot.id, snapshot);
            importedCount++;
          } catch (e) {
            print('⚠️ MCP Import: Failed to import ArcForm snapshot: $e');
          }
        }
        
        print('📦 MCP Import: ✓ Imported $importedCount ArcForm snapshots');
      }
    } catch (e) {
      print('⚠️ MCP Import: Failed to import ArcForm timeline: $e');
    }

    // 5. LUMARA Favorites
    try {
      final favoritesFile = File(path.join(extensionsDir.path, 'lumara_favorites.json'));
      if (await favoritesFile.exists()) {
        final content = await favoritesFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final favoritesJson = data['lumara_favorites'] as List<dynamic>? ?? [];
        
        final favoritesService = FavoritesService.instance;
        await favoritesService.initialize();
        
        int importedCount = 0;
        for (final favJson in favoritesJson) {
          try {
            final favoriteMap = favJson as Map<String, dynamic>;
            
            // Preserve all fields including category, sessionId, and entryId
            final favorite = LumaraFavorite(
              id: favoriteMap['id'] as String,
              content: favoriteMap['content'] as String,
              timestamp: DateTime.parse(favoriteMap['timestamp'] as String),
              sourceId: favoriteMap['source_id'] as String?,
              sourceType: favoriteMap['source_type'] as String?,
              metadata: favoriteMap['metadata'] as Map<String, dynamic>? ?? {},
              category: favoriteMap['category'] as String? ?? 'answer', // Preserve category (answer, chat, journal_entry)
              sessionId: favoriteMap['session_id'] as String?, // For saved chats
              entryId: favoriteMap['entry_id'] as String?, // For favorite journal entries
            );
            
            // Check if favorite already exists
            bool shouldImport = true;
            if (favorite.sourceId != null) {
              final existing = await favoritesService.findFavoriteBySourceId(favorite.sourceId!);
              if (existing != null) {
                shouldImport = false;
              }
            }
            
            // Check category-specific capacity (not just total capacity)
            if (shouldImport) {
              final category = favorite.category;
              if (await favoritesService.isCategoryAtCapacity(category)) {
                final limit = favoritesService.getCategoryLimit(category);
                print('⚠️ MCP Import: Category $category at capacity ($limit), skipping favorite');
                shouldImport = false;
              }
            }
            
            if (shouldImport) {
              final added = await favoritesService.addFavorite(favorite);
              if (added) {
                importedCount++;
                print('📦 MCP Import: ✓ Imported favorite ${favorite.id} (category: ${favorite.category})');
              } else {
                print('⚠️ MCP Import: Failed to add favorite ${favorite.id} (category: ${favorite.category})');
              }
            }
          } catch (e) {
            print('⚠️ MCP Import: Failed to import favorite: $e');
          }
        }
        
        print('📦 MCP Import: ✓ Imported $importedCount LUMARA favorites');
      }
    } catch (e) {
      print('⚠️ MCP Import: Failed to import LUMARA favorites: $e');
    }
  }
  
  /// Infer phase for an imported entry that needs migration
  Future<void> _inferPhaseForImportedEntry(JournalEntry entry) async {
    try {
      if (_journalRepo == null) return;
      
      // Get recent entries for context
      final allEntries = await _journalRepo!.getAllJournalEntries();
      allEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final recentEntries = allEntries.take(7).toList();
      
      // Get user profile for userId
      final userBox = await Hive.openBox<UserProfile>('user_profile');
      final userProfile = userBox.get('profile');
      final userId = userProfile?.id ?? '';
      
      // Run phase inference
      final inferenceResult = await PhaseInferenceService.inferPhaseForEntry(
        entryContent: entry.content,
        userId: userId,
        createdAt: entry.createdAt,
        recentEntries: recentEntries,
        emotion: entry.emotion,
        emotionReason: entry.emotionReason,
        selectedKeywords: entry.keywords,
      );
      
      // Update entry with phase fields
      final updatedEntry = entry.copyWith(
        autoPhase: inferenceResult.phase,
        autoPhaseConfidence: inferenceResult.confidence,
        phaseInferenceVersion: CURRENT_PHASE_INFERENCE_VERSION,
        phaseMigrationStatus: 'DONE',
      );
      
      // Save updated entry
      await _journalRepo!.updateJournalEntry(updatedEntry);
      
      print('MCP Import: ✓ Phase inference completed for entry ${entry.id}: ${inferenceResult.phase} (confidence: ${inferenceResult.confidence.toStringAsFixed(3)})');
    } catch (e) {
      print('MCP Import: ✗ Phase inference failed for entry ${entry.id}: $e');
    }
  }

  /// Import chat data (sessions and messages) from MCP package
  Future<Map<String, int>> _importChatData(Directory mcpDir) async {
    if (_chatRepo == null) return {'sessionCount': 0, 'messageCount': 0};

    try {
      // Initialize chat repo if needed
      await _chatRepo!.initialize();

      final sessionDir = Directory(path.join(mcpDir.path, 'nodes', 'chat', 'session'));
      final messageDir = Directory(path.join(mcpDir.path, 'nodes', 'chat', 'message'));
      final edgesFile = File(path.join(mcpDir.path, 'edges.jsonl'));

      // Check if chat directories exist
      if (!await sessionDir.exists() || !await messageDir.exists()) {
        print('📱 MCP Import: No chat data found (nodes/chat directories missing)');
        return {'sessionCount': 0, 'messageCount': 0};
      }

      // Map to store MCP session ID -> new session ID mapping
      final sessionIdMap = <String, String>{};
      int sessionCount = 0;
      int messageCount = 0;

      // Step 1: Import all sessions
      await for (final sessionFile in sessionDir.list()) {
        if (sessionFile is File && sessionFile.path.endsWith('.json')) {
          try {
            final sessionJson = jsonDecode(await sessionFile.readAsString()) as Map<String, dynamic>;
            
            // Extract session ID from JSON (format: "session:{sessionId}" or just "{sessionId}")
            // Also use filename as fallback (filename is {sessionId}.json)
            final mcpSessionIdFromJson = sessionJson['id'] as String?;
            final filenameSessionId = path.basenameWithoutExtension(sessionFile.path);
            
            // Determine the MCP session ID (prefer JSON, fallback to filename)
            String mcpSessionId;
            if (mcpSessionIdFromJson != null) {
              mcpSessionId = mcpSessionIdFromJson.startsWith('session:') 
                  ? mcpSessionIdFromJson 
                  : 'session:$mcpSessionIdFromJson';
            } else {
              mcpSessionId = 'session:$filenameSessionId';
            }
            
            // Extract session data
            final title = sessionJson['title'] as String? ?? 'Imported Chat';
            final tags = (sessionJson['tags'] as List<dynamic>?)?.cast<String>() ?? [];
            final isArchived = sessionJson['isArchived'] as bool? ?? false;
            final isPinned = sessionJson['isPinned'] as bool? ?? false;
            final metadata = sessionJson['metadata'] as Map<String, dynamic>?;
            
            // Create session
            final newSessionId = await _chatRepo!.createSession(
              subject: title,
              tags: tags,
            );
            
            // Store mapping (use the full "session:{id}" format)
            sessionIdMap[mcpSessionId] = newSessionId;
            
            // Update session with metadata if present (preserves fork relationships, etc.)
            if (metadata != null && metadata.isNotEmpty) {
              final session = await _chatRepo!.getSession(newSessionId);
              if (session != null) {
                // Update fork metadata to point to new session IDs if forked
                Map<String, dynamic> updatedMetadata = Map<String, dynamic>.from(metadata);
                if (updatedMetadata.containsKey('forkedFrom')) {
                  final originalForkedFrom = updatedMetadata['forkedFrom'] as String?;
                  if (originalForkedFrom != null) {
                    // Map original forkedFrom ID to new session ID if it exists
                    final mcpForkedFromId = originalForkedFrom.startsWith('session:')
                        ? originalForkedFrom
                        : 'session:$originalForkedFrom';
                    final newForkedFromId = sessionIdMap[mcpForkedFromId];
                    if (newForkedFromId != null) {
                      updatedMetadata['forkedFrom'] = newForkedFromId;
                    } else {
                      // Keep original but mark as unresolved
                      updatedMetadata['forkedFromOriginal'] = originalForkedFrom;
                      updatedMetadata['forkedFrom'] = null;
                    }
                  }
                }
                
                // Update session with metadata
                await _chatRepo!.updateSessionMetadata(newSessionId, updatedMetadata);
              }
            }
            
            // Set archived/pinned status if needed
            if (isArchived) {
              await _chatRepo!.archiveSession(newSessionId, true);
            }
            if (isPinned) {
              await _chatRepo!.pinSession(newSessionId, true);
            }
            
            sessionCount++;
            print('📱 MCP Import: ✓ Imported chat session: $title (MCP ID: $mcpSessionId -> New ID: $newSessionId)');
          } catch (e) {
            print('⚠️ MCP Import: Failed to import chat session from ${sessionFile.path}: $e');
          }
        }
      }

      // Step 2: Read edges to map messages to sessions
      final messageToSessionMap = <String, String>{};
      if (await edgesFile.exists()) {
        try {
          final edgesLines = await edgesFile.readAsLines();
          for (final line in edgesLines) {
            if (line.trim().isEmpty) continue;
            try {
              final edge = jsonDecode(line) as Map<String, dynamic>;
              final relation = edge['relation'] as String?;
              if (relation == 'contains') {
                final source = edge['source'] as String?; // "session:{sessionId}"
                final target = edge['target'] as String?; // "message:{messageId}"
                if (source != null && target != null) {
                  // Map message ID to session ID
                  messageToSessionMap[target] = source;
                }
              }
            } catch (e) {
              print('⚠️ MCP Import: Failed to parse edge: $e');
            }
          }
        } catch (e) {
          print('⚠️ MCP Import: Failed to read edges.jsonl: $e');
        }
      }

      // Step 3: Import all messages
      final messagesBySession = <String, List<Map<String, dynamic>>>{};
      
      await for (final messageFile in messageDir.list()) {
        if (messageFile is File && messageFile.path.endsWith('.json')) {
          try {
            final messageJson = jsonDecode(await messageFile.readAsString()) as Map<String, dynamic>;
            
            // Extract message ID from JSON (format: "message:{messageId}" or just "{messageId}")
            // Also use filename as fallback (filename is {messageId}.json)
            final mcpMessageIdFromJson = messageJson['id'] as String?;
            final filenameMessageId = path.basenameWithoutExtension(messageFile.path);
            
            // Determine the MCP message ID (prefer JSON, fallback to filename)
            String mcpMessageId;
            if (mcpMessageIdFromJson != null) {
              mcpMessageId = mcpMessageIdFromJson.startsWith('message:') 
                  ? mcpMessageIdFromJson 
                  : 'message:$mcpMessageIdFromJson';
            } else {
              mcpMessageId = 'message:$filenameMessageId';
            }
            
            // Find which session this message belongs to
            final sessionSource = messageToSessionMap[mcpMessageId];
            if (sessionSource == null) {
              print('⚠️ MCP Import: No session found for message $mcpMessageId (checked edges.jsonl), skipping');
              continue;
            }
            
            // Get the new session ID
            final newSessionId = sessionIdMap[sessionSource];
            if (newSessionId == null) {
              print('⚠️ MCP Import: Session mapping not found for $sessionSource, skipping message $mcpMessageId');
              print('   Available session mappings: ${sessionIdMap.keys.join(', ')}');
              continue;
            }
            
            // Extract message data
            final role = messageJson['role'] as String? ?? 'user';
            final text = messageJson['text'] as String? ?? messageJson['content'] as String? ?? '';
            final createdAtStr = messageJson['createdAt'] as String?;
            DateTime? createdAt;
            if (createdAtStr != null) {
              try {
                createdAt = TimestampParser.parseEntryTimestamp(createdAtStr).value;
              } catch (e) {
                print('⚠️ MCP Import: Failed to parse message timestamp, using current time: $e');
                createdAt = DateTime.now();
              }
            } else {
              createdAt = DateTime.now();
            }
            
            // Extract actual message ID for preservation
            final actualMessageId = mcpMessageId.startsWith('message:') 
                ? mcpMessageId.substring(8) 
                : mcpMessageId;
            
            // Store message for later import (we'll sort by timestamp)
            if (!messagesBySession.containsKey(newSessionId)) {
              messagesBySession[newSessionId] = [];
            }
            messagesBySession[newSessionId]!.add({
              'role': role,
              'text': text,
              'createdAt': createdAt,
              'messageId': actualMessageId,
              'order': messageJson['order'] as int?,
            });
          } catch (e) {
            print('⚠️ MCP Import: Failed to import chat message from ${messageFile.path}: $e');
          }
        }
      }

      // Step 4: Add messages to sessions in order
      for (final entry in messagesBySession.entries) {
        final sessionId = entry.key;
        final messages = entry.value;
        
        // Sort messages by order field or timestamp
        messages.sort((a, b) {
          final orderA = a['order'] as int?;
          final orderB = b['order'] as int?;
          if (orderA != null && orderB != null) {
            return orderA.compareTo(orderB);
          }
          final timeA = a['createdAt'] as DateTime;
          final timeB = b['createdAt'] as DateTime;
          return timeA.compareTo(timeB);
        });
        
        // Add messages to session
        for (final msg in messages) {
          try {
            await _chatRepo!.addMessage(
              sessionId: sessionId,
              role: msg['role'] as String,
              content: msg['text'] as String,
              messageId: msg['messageId'] as String?,
              timestamp: msg['createdAt'] as DateTime?,
            );
            messageCount++;
          } catch (e) {
            print('⚠️ MCP Import: Failed to add message to session $sessionId: $e');
          }
        }
      }

      print('📱 MCP Import: ✓ Imported $sessionCount chat sessions, $messageCount messages');
      return {'sessionCount': sessionCount, 'messageCount': messageCount};
    } catch (e) {
      print('❌ Chat import failed: $e');
      return {'sessionCount': 0, 'messageCount': 0};
    }
  }
}

/// Result of an MCP import operation
class McpImportResult {
  final bool success;
  final int totalEntries; // Successfully imported
  final int totalEntriesFound; // Total found in package
  final int totalPhotos; // Successfully imported
  final int totalPhotosFound; // Total found in package
  final McpManifest? manifest;
  final String? error;

  McpImportResult({
    required this.success,
    required this.totalEntries,
    this.totalEntriesFound = 0,
    required this.totalPhotos,
    this.totalPhotosFound = 0,
    this.manifest,
    this.error,
  });
}

