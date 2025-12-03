import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/platform/photo_bridge.dart';
import 'package:my_app/core/services/photo_library_service.dart';
import 'package:my_app/mira/store/mcp/utils/image_processing.dart' show sha256Hex, reencodeFull;
import 'package:my_app/arc/chat/chat/chat_repo.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/arc/chat/services/favorites_service.dart';
import 'package:my_app/prism/atlas/rivet/rivet_storage.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart' as rivet_models;
import 'package:my_app/models/arcform_snapshot_model.dart';
import 'package:hive/hive.dart';
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
  final ChatRepo? _chatRepo;
  final PhaseRegimeService? _phaseRegimeService;

  McpPackExportService({
    required String bundleId,
    required String outputPath,
    bool isDebugMode = false,
    ChatRepo? chatRepo,
    PhaseRegimeService? phaseRegimeService,
  }) : _bundleId = bundleId,
       _outputPath = outputPath,
       _isDebugMode = isDebugMode,
       _chatRepo = chatRepo,
       _phaseRegimeService = phaseRegimeService;

  /// Export journal entries to MCP package format
  Future<McpExportResult> exportJournal({
    required List<JournalEntry> entries,
    bool includePhotos = true,
    bool reducePhotoSize = false,
    bool includeChats = true, // Default to true to ensure chats are exported
    bool includeArchivedChats = false,
    Set<String>? chatDatesFilter, // Optional: filter chats by journal entry dates
    int mediaPackTargetSizeMB = 200, // Media pack target size in MB (default 200MB)
  }) async {
    Directory? tempDir;
    try {
      print('📦 Starting MCP export to: $_outputPath');
      print('📦 MCP Export: Received ${entries.length} entries to export');
      
      // Validate entries list
      if (entries.isEmpty) {
        print('❌ MCP Export: No entries provided for export');
        return McpExportResult(
          success: false,
          error: 'No entries to export. Please ensure you have journal entries and that your date range selection includes entries.',
          outputPath: null,
          totalEntries: 0,
          totalPhotos: 0,
          isDebugMode: _isDebugMode,
        );
      }

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
      await Directory(path.join(mcpDir.path, 'nodes', 'chat', 'session')).create(recursive: true);
      await Directory(path.join(mcpDir.path, 'nodes', 'chat', 'message')).create(recursive: true);
      // Create media packs directory structure if using packs
      if (includePhotos && mediaPackTargetSizeMB > 0) {
        await Directory(path.join(mcpDir.path, 'Media', 'packs')).create(recursive: true);
      } else {
        // Legacy: direct media directories
        await Directory(path.join(mcpDir.path, 'media', 'photos')).create(recursive: true);
        await Directory(path.join(mcpDir.path, 'media', 'videos')).create(recursive: true);
        await Directory(path.join(mcpDir.path, 'media', 'audio')).create(recursive: true);
        await Directory(path.join(mcpDir.path, 'media', 'files')).create(recursive: true);
      }
      await Directory(path.join(mcpDir.path, 'streams', 'health')).create(recursive: true);
      
      // Extract journal entry dates for health filtering
      final journalDates = _extractJournalEntryDates(entries);
      print('📦 MCP Export: Found ${journalDates.length} unique journal entry dates');

      // Copy health streams from app documents if they exist - filtered by journal entry dates
      final sourceAppDir = await getApplicationDocumentsDirectory();
      final sourceHealthDir = Directory(path.join(sourceAppDir.path, 'mcp', 'streams', 'health'));
      if (await sourceHealthDir.exists()) {
        print('📦 MCP Export: Copying filtered health streams for journal dates...');
        await _copyFilteredHealthStreams(sourceHealthDir, Directory(path.join(mcpDir.path, 'streams', 'health')), journalDates);
      }
      
      // Process each entry (collect media metadata but don't write files yet if using packs)
      final processedEntries = <Map<String, dynamic>>[];
      final allMediaItems = <MediaItem>[]; // Collect all media items for pack organization
      int totalPhotos = 0;
      
      for (int i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final processedEntry = await _processJournalEntry(
          entry, 
          i, 
          mcpDir, 
          includePhotos, 
          reducePhotoSize,
          usePacks: includePhotos && mediaPackTargetSizeMB > 0,
        );
        processedEntries.add(processedEntry);
        
        // Collect media items for pack organization
        if (includePhotos && mediaPackTargetSizeMB > 0) {
          for (final media in entry.media) {
            if (!allMediaItems.any((m) => m.id == media.id)) {
              allMediaItems.add(media);
            }
          }
        }
        
        // Count photos in this entry
        final media = processedEntry['media'] as List<dynamic>;
        // Media kind uses MediaType.name which is 'image' for photos, not 'photo'
        totalPhotos += media.where((m) => m['kind'] == 'image' || m['kind'] == 'photo').length;
      }
      
      // Export media with packs if enabled
      if (includePhotos && mediaPackTargetSizeMB > 0 && allMediaItems.isNotEmpty) {
        print('📦 MCP Export: Organizing ${allMediaItems.length} media items into packs...');
        await _exportMediaWithPacks(
          mediaItems: allMediaItems,
          mcpDir: mcpDir,
          packTargetSizeMB: mediaPackTargetSizeMB,
          reducePhotoSize: reducePhotoSize,
        );
      }

      // Export chat data if requested
      int chatSessionCount = 0;
      int chatMessageCount = 0;
      if (includeChats && _chatRepo != null) {
        try {
          final chatData = await _exportChatData(mcpDir, includeArchivedChats, chatDatesFilter);
          chatSessionCount = chatData['sessionCount'] as int;
          chatMessageCount = chatData['messageCount'] as int;
          print('📱 MCP Export: Exported $chatSessionCount chat sessions, $chatMessageCount messages');
        } catch (e) {
          print('⚠️ MCP Export: Failed to export chat data: $e');
        }
      }

      // Export extended data (Phase Regimes, Rivet, Sentinel, ArcForm, Favorites)
      // These are placed in mcp/extensions/ to maintain backward compatibility while adding new data
      try {
        await _exportExtendedData(mcpDir);
      } catch (e) {
        print('⚠️ MCP Export: Failed to export extended data: $e');
      }

      // Create manifest
      final manifest = McpManifest.journal(
        entryCount: entries.length,
        photoCount: totalPhotos,
        metadata: {
          'bundle_id': _bundleId,
          'include_photos': includePhotos,
          'reduce_photo_size': reducePhotoSize,
          'include_chats': includeChats,
          'chat_session_count': chatSessionCount,
          'chat_message_count': chatMessageCount,
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
          totalChatSessions: chatSessionCount,
          totalChatMessages: chatMessageCount,
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
          totalChatSessions: chatSessionCount,
          totalChatMessages: chatMessageCount,
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
    bool reducePhotoSize, {
    bool usePacks = false, // If true, only create metadata, don't write files
  }) async {
    final processedMedia = <Map<String, dynamic>>[];

    if (includePhotos) {
      print('McpPackExportService: Processing entry ${entry.id} with ${entry.media.length} media items');
      for (final media in entry.media) {
        try {
          print('McpPackExportService: Processing media ${media.id} with URI: ${media.uri}');
          if (usePacks) {
            // When using packs, only create metadata - files will be written later in packs
            final mediaMetadata = await _createMediaMetadata(media, reducePhotoSize);
            if (mediaMetadata != null) {
              processedMedia.add(mediaMetadata);
              print('McpPackExportService: ✓ Created metadata for media ${media.id} (will be packed later)');
            }
          } else {
            // Legacy: write files directly
            final processedMediaItem = await _processMediaItem(media, mcpDir, reducePhotoSize);
            if (processedMediaItem != null) {
              processedMedia.add(processedMediaItem);
              print('McpPackExportService: ✓ Successfully processed media ${media.id}');
            } else {
              print('McpPackExportService: ⚠️ Failed to process media ${media.id} - photo will NOT be included in export');
              print('McpPackExportService:   URI: ${media.uri}');
              print('McpPackExportService:   Type: ${media.type}');
            }
          }
        } catch (e, stackTrace) {
          print('McpPackExportService: ✗ Error processing media ${media.id}: $e');
          print('McpPackExportService: Stack trace: $stackTrace');
        }
      }
      final successfulCount = processedMedia.length;
      final failedCount = entry.media.length - successfulCount;
      print('McpPackExportService: Entry ${entry.id} - Successfully processed: $successfulCount, Failed: $failedCount');
      print('McpPackExportService: Entry ${entry.id} will have ${processedMedia.length} media items in export');
    } else {
      print('McpPackExportService: Skipping photos for entry ${entry.id} (includePhotos=false)');
    }

    // Create health association for this entry's date
    final entryDate = '${entry.createdAt.year.toString().padLeft(4, '0')}-'
                     '${entry.createdAt.month.toString().padLeft(2, '0')}-'
                     '${entry.createdAt.day.toString().padLeft(2, '0')}';

    final healthAssociation = {
      'date': entryDate,
      'health_data_available': true,
      'stream_reference': 'streams/health/${entryDate.substring(0, 7)}.jsonl',
      'metrics_included': [
        'steps', 'active_energy', 'resting_energy', 'sleep_total_minutes',
        'resting_hr', 'avg_hr', 'hrv_sdnn'
      ],
      'association_created_at': DateTime.now().toUtc().toIso8601String(),
    };

    // Create processed entry with properly formatted timestamp and health association
    final processedEntry = {
      'id': entry.id,
      'timestamp': _formatTimestamp(entry.createdAt),
      'content': entry.content,
      'media': processedMedia,
      'emotion': entry.emotion,
      'emotionReason': entry.emotionReason,
      'phase': entry.phase, // Legacy field for backward compatibility
      'keywords': entry.keywords,
      // New phase detection fields
      'autoPhase': entry.autoPhase,
      'autoPhaseConfidence': entry.autoPhaseConfidence,
      'userPhaseOverride': entry.userPhaseOverride,
      'isPhaseLocked': entry.isPhaseLocked,
      'legacyPhaseTag': entry.legacyPhaseTag,
      'importSource': entry.importSource,
      'phaseInferenceVersion': entry.phaseInferenceVersion,
      'phaseMigrationStatus': entry.phaseMigrationStatus,
      'metadata': entry.metadata,
      'health_association': healthAssociation,
      // LUMARA blocks in new format (migrated from legacy inlineBlocks)
      'lumaraBlocks': entry.lumaraBlocks.map((block) => block.toJson()).toList(),
    };

    // Write entry JSON
    final entryFile = File(path.join(mcpDir.path, 'nodes', 'journal', 'entry_$index.json'));
    await entryFile.writeAsString(jsonEncode(processedEntry));

    return processedEntry;
  }

  /// Process a single media item (photos, videos, audio, files)
  Future<Map<String, dynamic>?> _processMediaItem(
    MediaItem media,
    Directory mcpDir,
    bool reducePhotoSize,
  ) async {
    // Get original bytes from file path
    Uint8List? originalBytes;
    String? originalFormat;
    final mediaType = media.type; // image, video, audio, file

    // Check if this is a permanent file path
    // Try file path first if it doesn't start with ph://, placeholder://, or mcp://
    final isUriScheme = media.uri.startsWith('ph://') || 
                       media.uri.startsWith('placeholder://') || 
                       media.uri.startsWith('mcp://') ||
                       media.uri.startsWith('file://');
    
    if (!isUriScheme) {
      // This is a file path (absolute or relative)
      final file = File(media.uri);
      if (await file.exists()) {
        try {
        originalBytes = await file.readAsBytes();
        originalFormat = _getFileExtension(media.uri);
        print('McpPackExportService: ✓ Got bytes from file path: ${media.uri} (${originalBytes.length} bytes)');
        } catch (e) {
          print('McpPackExportService: ⚠️ Error reading file ${media.uri}: $e');
        }
      } else {
        print('McpPackExportService: ⚠️ File does not exist: ${media.uri}');
        // Try to find the file by basename in Documents/photos directory
        if (mediaType == MediaType.image && media.uri.contains('/photos/')) {
          try {
            final appDir = await getApplicationDocumentsDirectory();
            final photosDir = Directory(path.join(appDir.path, 'photos'));
            if (await photosDir.exists()) {
              final fileName = path.basename(media.uri);
              final possibleFile = File(path.join(photosDir.path, fileName));
              if (await possibleFile.exists()) {
                originalBytes = await possibleFile.readAsBytes();
                originalFormat = _getFileExtension(fileName);
                print('McpPackExportService: ✓ Found photo in Documents/photos: $fileName (${originalBytes.length} bytes)');
              }
            }
          } catch (e) {
            print('McpPackExportService: ⚠️ Error searching for photo in Documents/photos: $e');
          }
        }
      }
    } else if (media.uri.startsWith('file://')) {
      // Handle file:// URI scheme
      final filePath = media.uri.replaceFirst('file://', '');
      final file = File(filePath);
      if (await file.exists()) {
        try {
        originalBytes = await file.readAsBytes();
        originalFormat = _getFileExtension(filePath);
        print('McpPackExportService: ✓ Got bytes from file:// URI: $filePath (${originalBytes.length} bytes)');
        } catch (e) {
          print('McpPackExportService: ⚠️ Error reading file:// URI $filePath: $e');
        }
      } else {
        print('McpPackExportService: ⚠️ File does not exist: $filePath');
      }
    } else if (PhotoBridge.isPhotoLibraryUri(media.uri)) {
      // Get bytes from photo library (for photos and videos)
      final localId = PhotoBridge.extractLocalIdentifier(media.uri);
      if (localId != null) {
        if (mediaType == MediaType.image) {
        final photoData = await PhotoBridge.getPhotoBytes(localId);
        if (photoData != null) {
          originalBytes = photoData['bytes'] as Uint8List;
          originalFormat = photoData['ext'] as String;
            print('McpPackExportService: ✓ Got bytes from PhotoBridge for ph:// URI (${originalBytes.length} bytes)');
          } else {
            // Fallback: Try PhotoLibraryService thumbnail
            print('McpPackExportService: PhotoBridge returned null, trying PhotoLibraryService...');
            try {
              final thumbnailPath = await PhotoLibraryService.getPhotoThumbnail(media.uri, size: 1920);
              if (thumbnailPath != null) {
                final thumbFile = File(thumbnailPath);
                if (await thumbFile.exists()) {
                  originalBytes = await thumbFile.readAsBytes();
                  originalFormat = 'jpg';
                  print('McpPackExportService: ✓ Got bytes from PhotoLibraryService thumbnail (${originalBytes.length} bytes)');
                }
              }
            } catch (e) {
              print('McpPackExportService: ⚠️ PhotoLibraryService thumbnail failed: $e');
            }
          }
        } else if (mediaType == MediaType.video) {
          // For videos from photo library, we need to handle differently
          // Try to get the file path directly if possible
          try {
            final file = File(media.uri);
            if (await file.exists()) {
              originalBytes = await file.readAsBytes();
              originalFormat = _getFileExtension(media.uri);
            }
          } catch (e) {
            print('McpPackExportService: Could not read video from photo library URI: $e');
          }
        }
      }
    }

    // Final fallback: If still no bytes and this is an image, try to find it in Documents/photos
    if (originalBytes == null && mediaType == MediaType.image) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final photosDir = Directory(path.join(appDir.path, 'photos'));
        if (await photosDir.exists()) {
          // Try to find by media ID or filename
          final fileName = path.basename(media.uri);
          final possibleFile = File(path.join(photosDir.path, fileName));
          if (await possibleFile.exists()) {
            originalBytes = await possibleFile.readAsBytes();
            originalFormat = _getFileExtension(fileName);
            print('McpPackExportService: ✓ Found photo via fallback search: $fileName (${originalBytes.length} bytes)');
          } else {
            // Try searching by media ID
            final files = await photosDir.list().toList();
            for (final file in files) {
              if (file is File && file.path.contains(media.id)) {
                originalBytes = await file.readAsBytes();
                originalFormat = _getFileExtension(file.path);
                print('McpPackExportService: ✓ Found photo by ID search: ${file.path} (${originalBytes.length} bytes)');
                break;
              }
            }
          }
        }
      } catch (e) {
        print('McpPackExportService: ⚠️ Fallback photo search failed: $e');
      }
    }

    if (originalBytes == null) {
      print('McpPackExportService: ⚠️ Could not get bytes for media ${media.id} (URI: ${media.uri}, Type: ${mediaType.name})');
      print('McpPackExportService: ⚠️ This photo will NOT be included in the export');
      // Return null so the caller knows this photo failed and can handle it appropriately
      return null;
    }

    // Use existing SHA-256 hash if available, otherwise compute it
    String sha;
    if (media.sha256 != null && media.sha256!.isNotEmpty) {
      sha = media.sha256!;
    } else {
      sha = sha256Hex(originalBytes);
    }

    // Determine media directory and file extension based on type
    String mediaSubDir;
    String defaultExt;
    switch (mediaType) {
      case MediaType.video:
        mediaSubDir = 'videos';
        defaultExt = 'mp4';
        break;
      case MediaType.audio:
        mediaSubDir = 'audio';
        defaultExt = 'm4a';
        break;
      case MediaType.file:
        mediaSubDir = 'files';
        defaultExt = originalFormat ?? 'bin';
        break;
      case MediaType.image:
        mediaSubDir = 'photos';
        defaultExt = 'jpg';
        break;
    }

    // Process photo based on size reduction setting (only for images)
    Uint8List finalBytes = originalBytes;
    bool wasReduced = false;
    if (mediaType == MediaType.image && reducePhotoSize) {
      final reencoded = reencodeFull(originalBytes, maxEdge: 1920, quality: 85);
      finalBytes = reencoded.bytes;
      wasReduced = true;
    }

    // Add media to appropriate directory
    final mediaFileName = '$sha.${originalFormat ?? defaultExt}';
    final mediaSubDirectory = Directory(path.join(mcpDir.path, 'media', mediaSubDir));
    await mediaSubDirectory.create(recursive: true);
    final mediaFile = File(path.join(mediaSubDirectory.path, mediaFileName));
    await mediaFile.writeAsBytes(finalBytes);
    
    print('📹 Added ${mediaType.name}: $mediaFileName (${originalBytes.length} bytes)');

    // Create media node JSON
    final mediaNode = {
      'id': media.id,
      'kind': mediaType.name, // 'photo', 'video', 'audio', 'file'
      'type': mediaType.name,
      'sha256': sha,
      'filename': mediaFileName,
      'createdAt': media.createdAt.toIso8601String(),
      'originalPath': media.uri,
      if (media.duration != null) 'duration': media.duration!.inSeconds,
      if (media.sizeBytes != null) 'sizeBytes': media.sizeBytes,
      if (media.altText != null) 'altText': media.altText,
      if (media.ocrText != null) 'ocrText': media.ocrText,
      if (media.transcript != null) 'transcript': media.transcript,
      if (media.analysisData != null) 'analysisData': media.analysisData,
      if (mediaType == MediaType.image && wasReduced) 'reduced': true,
    };

    // Write media node JSON to appropriate directory
    final mediaNodeSubDir = Directory(path.join(mcpDir.path, 'nodes', 'media', mediaSubDir));
    await mediaNodeSubDir.create(recursive: true);
    final mediaNodeFile = File(path.join(mediaNodeSubDir.path, '${media.id}.json'));
    await mediaNodeFile.writeAsString(jsonEncode(mediaNode));

    return mediaNode;
  }


  /// Extract unique dates from journal entries
  Set<String> _extractJournalEntryDates(List<JournalEntry> entries) {
    final dates = <String>{};
    for (final entry in entries) {
      // Convert DateTime to YYYY-MM-DD format for matching with health data
      final dateKey = '${entry.createdAt.year.toString().padLeft(4, '0')}-'
                     '${entry.createdAt.month.toString().padLeft(2, '0')}-'
                     '${entry.createdAt.day.toString().padLeft(2, '0')}';
      dates.add(dateKey);
    }
    return dates;
  }

  /// Copy health stream JSONL files filtered by journal entry dates
  Future<void> _copyFilteredHealthStreams(Directory sourceDir, Directory destDir, Set<String> journalDates) async {
    if (!await sourceDir.exists()) return;

    int fileCount = 0;
    int totalLines = 0;
    int filteredLines = 0;

    await for (final entity in sourceDir.list()) {
      if (entity is File && entity.path.endsWith('.jsonl')) {
        final filename = path.basename(entity.path);
        final destFile = File(path.join(destDir.path, filename));

        // Read source file and filter lines by journal entry dates
        final sourceLines = await entity.readAsLines();
        final filteredHealthData = <String>[];

        for (final line in sourceLines) {
          if (line.trim().isEmpty) continue;
          totalLines++;

          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            final timeslice = json['timeslice'] as Map<String, dynamic>?;
            final startStr = timeslice?['start'] as String?;

            if (startStr != null) {
              // Extract date from timeslice start (format: YYYY-MM-DDTHH:MM:SSZ)
              final date = startStr.substring(0, 10); // Extract YYYY-MM-DD part

              if (journalDates.contains(date)) {
                // Add health pointer/association to the health data
                final enhancedJson = Map<String, dynamic>.from(json);
                enhancedJson['journal_association'] = {
                  'date': date,
                  'has_journal_entry': true,
                  'exported_at': DateTime.now().toUtc().toIso8601String(),
                };

                filteredHealthData.add(jsonEncode(enhancedJson));
                filteredLines++;
              }
            }
          } catch (e) {
            print('📦 MCP Export: Warning - Could not parse health data line: $e');
          }
        }

        // Write filtered data if any lines matched
        if (filteredHealthData.isNotEmpty) {
          await destFile.writeAsString(filteredHealthData.join('\n') + '\n');
          fileCount++;
          print('📦 MCP Export: Filtered health stream: $filename (${filteredHealthData.length} lines)');
        }
      }
    }

    if (fileCount > 0) {
      print('📦 MCP Export: ✓ Copied $fileCount filtered health file(s) ($filteredLines/$totalLines lines)');
    } else {
      print('📦 MCP Export: ✓ No health data matched journal entry dates');
    }
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

  /// Export chat data (sessions and messages)
  Future<Map<String, int>> _exportChatData(
    Directory mcpDir,
    bool includeArchived,
    Set<String>? datesFilter,
  ) async {
    if (_chatRepo == null) return {'sessionCount': 0, 'messageCount': 0};

    try {
      // Get all sessions
      final sessions = await _chatRepo!.listAll(includeArchived: includeArchived);
      final edges = <Map<String, dynamic>>[];
      int messageCount = 0;
      int sessionCount = 0;

      for (final session in sessions) {
        // Filter by date if datesFilter is provided (match session created date)
        if (datesFilter != null) {
          final sessionDate = '${session.createdAt.year.toString().padLeft(4, '0')}-'
                            '${session.createdAt.month.toString().padLeft(2, '0')}-'
                            '${session.createdAt.day.toString().padLeft(2, '0')}';
          if (!datesFilter.contains(sessionDate)) {
            continue;
          }
        }

        // Get messages for this session
        final messages = await _chatRepo!.getMessages(session.id);
        
        // Filter messages by date if datesFilter is provided
        final filteredMessages = datesFilter != null
            ? messages.where((msg) {
                final msgDate = '${msg.createdAt.year.toString().padLeft(4, '0')}-'
                              '${msg.createdAt.month.toString().padLeft(2, '0')}-'
                              '${msg.createdAt.day.toString().padLeft(2, '0')}';
                return datesFilter.contains(msgDate);
              }).toList()
            : messages;

        if (filteredMessages.isEmpty && datesFilter != null) {
          continue; // Skip session if no messages match date filter
        }

        // Create session node
        final sessionNode = {
          'id': 'session:${session.id}',
          'type': 'ChatSession',
          'title': session.subject,
          'createdAt': _formatTimestamp(session.createdAt),
          'tags': session.tags,
          'isArchived': session.isArchived,
          'isPinned': session.isPinned,
        };
        final sessionFile = File(path.join(mcpDir.path, 'nodes', 'chat', 'session', '${session.id}.json'));
        await sessionFile.writeAsString(jsonEncode(sessionNode));
        sessionCount++;

        // Create message nodes and edges
        for (int i = 0; i < filteredMessages.length; i++) {
          final message = filteredMessages[i];
          final messageNode = {
            'id': 'message:${message.id}',
            'type': 'ChatMessage',
            'role': message.role,
            'text': message.content,
            'createdAt': _formatTimestamp(message.createdAt),
          };
          final messageFile = File(path.join(mcpDir.path, 'nodes', 'chat', 'message', '${message.id}.json'));
          await messageFile.writeAsString(jsonEncode(messageNode));
          messageCount++;

          // Create contains edge
          edges.add({
            'source': 'session:${session.id}',
            'target': 'message:${message.id}',
            'relation': 'contains',
            'timestamp': _formatTimestamp(message.createdAt),
            'order': i,
          });
        }
      }

      // Write edges file if any edges exist (append if file already exists)
      if (edges.isNotEmpty) {
        final edgesFile = File(path.join(mcpDir.path, 'edges.jsonl'));
        final existingEdges = <String>[];
        
        // Read existing edges if file exists
        if (await edgesFile.exists()) {
          existingEdges.addAll(await edgesFile.readAsLines());
        }
        
        // Add new edges
        final edgesLines = edges.map((e) => jsonEncode(e)).toList();
        final allEdges = [...existingEdges, ...edgesLines];
        await edgesFile.writeAsString(allEdges.join('\n') + '\n');
      }

      return {'sessionCount': sessionCount, 'messageCount': messageCount};
    } catch (e) {
      print('❌ Chat export failed: $e');
      return {'sessionCount': 0, 'messageCount': 0};
    }
  }

  /// Export extended data (Phase Regimes, Rivet, etc.)
  Future<void> _exportExtendedData(Directory mcpDir) async {
    final extensionsDir = Directory(path.join(mcpDir.path, 'extensions'));
    await extensionsDir.create(recursive: true);

    // 1. Phase Regimes
    if (_phaseRegimeService != null) {
      try {
        final regimes = _phaseRegimeService!.allRegimes;
        if (regimes.isNotEmpty) {
          final exportData = _phaseRegimeService!.exportForMcp();
          final phaseRegimesFile = File(path.join(extensionsDir.path, 'phase_regimes.json'));
          await phaseRegimesFile.writeAsString(
            const JsonEncoder.withIndent('  ').convert(exportData)
          );
          print('📦 MCP Export: Exported ${regimes.length} phase regimes');
        }
      } catch (e) {
        print('⚠️ MCP Export: Failed to export phase regimes: $e');
      }
    }

    // 2. RIVET State
    try {
      if (!Hive.isBoxOpen(RivetBox.boxName)) {
        await Hive.openBox(RivetBox.boxName);
      }
      
      final stateBox = Hive.box(RivetBox.boxName);
      final eventsBox = Hive.isBoxOpen(RivetBox.eventsBoxName) 
          ? Hive.box(RivetBox.eventsBoxName)
          : await Hive.openBox(RivetBox.eventsBoxName);

      final rivetStates = <String, dynamic>{};
      
      for (final userId in stateBox.keys) {
        final stateData = stateBox.get(userId);
        if (stateData == null) continue;

        final rivetState = rivet_models.RivetState.fromJson(
          stateData is Map<String, dynamic> 
              ? stateData 
              : Map<String, dynamic>.from(stateData as Map),
        );

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
              // Skip invalid events
            }
          }
        }

        rivetStates[userId.toString()] = {
          'state': rivetState.toJson(),
          'events': events.map((e) => e.toJson()).toList(),
          'exported_at': DateTime.now().toIso8601String(),
        };
      }

      if (rivetStates.isNotEmpty) {
        final rivetStateFile = File(path.join(extensionsDir.path, 'rivet_state.json'));
        await rivetStateFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'rivet_states': rivetStates,
            'exported_at': DateTime.now().toIso8601String(),
            'version': '1.0',
          })
        );
        print('📦 MCP Export: Exported RIVET state');
      }
    } catch (e) {
      print('⚠️ MCP Export: Failed to export RIVET state: $e');
    }

    // 3. Sentinel State
    try {
      final sentinelStateFile = File(path.join(extensionsDir.path, 'sentinel_state.json'));
      await sentinelStateFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'sentinel_state': {
            'state': 'ok',
            'notes': [],
            'exported_at': DateTime.now().toIso8601String(),
            'note': 'Sentinel state is computed dynamically. This export represents the system state at export time.',
          },
          'exported_at': DateTime.now().toIso8601String(),
          'version': '1.0',
        })
      );
    } catch (e) {
      print('⚠️ MCP Export: Failed to export Sentinel state: $e');
    }

    // 4. ArcForm Timeline
    try {
      if (!Hive.isBoxOpen('arcform_snapshots')) {
        await Hive.openBox<ArcformSnapshot>('arcform_snapshots');
      }

      final box = Hive.box<ArcformSnapshot>('arcform_snapshots');
      final snapshots = box.values.toList();

      if (snapshots.isNotEmpty) {
        final arcformTimelineFile = File(path.join(extensionsDir.path, 'arcform_timeline.json'));
        await arcformTimelineFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'arcform_snapshots': snapshots.map((s) => s.toJson()).toList(),
            'exported_at': DateTime.now().toIso8601String(),
            'version': '1.0',
          })
        );
        print('📦 MCP Export: Exported ${snapshots.length} ArcForm snapshots');
      }
    } catch (e) {
      print('⚠️ MCP Export: Failed to export ArcForm timeline: $e');
    }

    // 5. LUMARA Favorites
    try {
      final favoritesService = FavoritesService.instance;
      await favoritesService.initialize();
      final allFavorites = await favoritesService.getAllFavorites();

      if (allFavorites.isNotEmpty) {
        final favoritesFile = File(path.join(extensionsDir.path, 'lumara_favorites.json'));
        await favoritesFile.writeAsString(
          JsonEncoder.withIndent('  ').convert({
            'lumara_favorites': allFavorites.map((f) {
              final map = <String, dynamic>{
                'id': f.id,
                'content': f.content,
                'timestamp': f.timestamp.toIso8601String(),
                'source_id': f.sourceId,
                'source_type': f.sourceType,
                'metadata': f.metadata,
                'category': f.category,
              };
              if (f.sessionId != null) map['session_id'] = f.sessionId;
              if (f.entryId != null) map['entry_id'] = f.entryId;
              return map;
            }).toList(),
            'exported_at': DateTime.now().toIso8601String(),
            'version': '1.1',
          })
        );
        print('📦 MCP Export: Exported ${allFavorites.length} LUMARA favorites');
      }
    } catch (e) {
      print('⚠️ MCP Export: Failed to export LUMARA favorites: $e');
    }
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

  /// Create media metadata without writing files (for pack mode)
  Future<Map<String, dynamic>?> _createMediaMetadata(
    MediaItem media,
    bool reducePhotoSize,
  ) async {
    // Get original bytes to compute hash and determine file info
    Uint8List? originalBytes;
    String? originalFormat;
    final mediaType = media.type;

    // Try to get bytes (same logic as _processMediaItem but don't write)
    final isUriScheme = media.uri.startsWith('ph://') || 
                       media.uri.startsWith('placeholder://') || 
                       media.uri.startsWith('mcp://') ||
                       media.uri.startsWith('file://');
    
    if (!isUriScheme) {
      final file = File(media.uri);
      if (await file.exists()) {
        try {
          originalBytes = await file.readAsBytes();
          originalFormat = _getFileExtension(media.uri);
        } catch (e) {
          print('McpPackExportService: ⚠️ Error reading file ${media.uri}: $e');
        }
      }
    } else if (media.uri.startsWith('file://')) {
      final filePath = media.uri.replaceFirst('file://', '');
      final file = File(filePath);
      if (await file.exists()) {
        try {
          originalBytes = await file.readAsBytes();
          originalFormat = _getFileExtension(filePath);
        } catch (e) {
          print('McpPackExportService: ⚠️ Error reading file:// URI $filePath: $e');
        }
      }
    } else if (PhotoBridge.isPhotoLibraryUri(media.uri)) {
      final localId = PhotoBridge.extractLocalIdentifier(media.uri);
      if (localId != null && mediaType == MediaType.image) {
        final photoData = await PhotoBridge.getPhotoBytes(localId);
        if (photoData != null) {
          originalBytes = photoData['bytes'] as Uint8List;
          originalFormat = photoData['ext'] as String;
        }
      }
    }

    if (originalBytes == null) {
      return null; // Can't create metadata without bytes
    }

    // Compute hash
    String sha;
    if (media.sha256 != null && media.sha256!.isNotEmpty) {
      sha = media.sha256!;
    } else {
      sha = sha256Hex(originalBytes);
    }

    // Determine file extension
    String defaultExt;
    switch (mediaType) {
      case MediaType.video:
        defaultExt = 'mp4';
        break;
      case MediaType.audio:
        defaultExt = 'm4a';
        break;
      case MediaType.file:
        defaultExt = originalFormat ?? 'bin';
        break;
      case MediaType.image:
        defaultExt = 'jpg';
        break;
    }

    // Create metadata (pack will be assigned later)
    return {
      'id': media.id,
      'kind': mediaType.name,
      'type': mediaType.name,
      'sha256': sha,
      'filename': '$sha.${originalFormat ?? defaultExt}',
      'createdAt': media.createdAt.toIso8601String(),
      'originalPath': media.uri,
      'bytes': originalBytes.length,
      if (media.duration != null) 'duration': media.duration!.inSeconds,
      if (media.sizeBytes != null) 'sizeBytes': media.sizeBytes,
      if (media.altText != null) 'altText': media.altText,
      if (media.ocrText != null) 'ocrText': media.ocrText,
      if (media.transcript != null) 'transcript': media.transcript,
      if (media.analysisData != null) 'analysisData': media.analysisData,
    };
  }

  /// Export media with packs to /Media/packs/pack-XXX/ and /Media/media_index.json
  Future<void> _exportMediaWithPacks({
    required List<MediaItem> mediaItems,
    required Directory mcpDir,
    required int packTargetSizeMB,
    required bool reducePhotoSize,
  }) async {
    if (mediaItems.isEmpty) return;

    final mediaDir = Directory(path.join(mcpDir.path, 'Media'));
    await mediaDir.create(recursive: true);
    final packsDir = Directory(path.join(mediaDir.path, 'packs'));
    await packsDir.create(recursive: true);

    final mediaIndex = <String, dynamic>{
      'packs': <Map<String, dynamic>>[],
      'total_media_items': 0,
      'total_bytes': 0,
      'items': <Map<String, dynamic>>[],
    };

    final packTargetSizeBytes = packTargetSizeMB * 1024 * 1024;
    final packs = <Map<String, dynamic>>[];
    final currentPack = <Map<String, dynamic>>[];
    int currentPackSize = 0;
    int packNumber = 1;
    int totalMediaBytes = 0;
    final seenMediaHashes = <String, String>{};

    for (int i = 0; i < mediaItems.length; i++) {
      final mediaItem = mediaItems[i];
      print('📦 MCP Export: Processing media ${i + 1}/${mediaItems.length} for packs...');

      try {
        // Get media bytes (same logic as _processMediaItem)
        Uint8List? originalBytes;
        String? originalFormat;
        final mediaType = mediaItem.type;

        final isUriScheme = mediaItem.uri.startsWith('ph://') || 
                           mediaItem.uri.startsWith('placeholder://') || 
                           mediaItem.uri.startsWith('mcp://') ||
                           mediaItem.uri.startsWith('file://');
        
        if (!isUriScheme) {
          final file = File(mediaItem.uri);
          if (await file.exists()) {
            try {
              originalBytes = await file.readAsBytes();
              originalFormat = _getFileExtension(mediaItem.uri);
            } catch (e) {
              print('McpPackExportService: ⚠️ Error reading file ${mediaItem.uri}: $e');
            }
          }
        } else if (mediaItem.uri.startsWith('file://')) {
          final filePath = mediaItem.uri.replaceFirst('file://', '');
          final file = File(filePath);
          if (await file.exists()) {
            try {
              originalBytes = await file.readAsBytes();
              originalFormat = _getFileExtension(filePath);
            } catch (e) {
              print('McpPackExportService: ⚠️ Error reading file:// URI $filePath: $e');
            }
          }
        } else if (PhotoBridge.isPhotoLibraryUri(mediaItem.uri)) {
          final localId = PhotoBridge.extractLocalIdentifier(mediaItem.uri);
          if (localId != null && mediaType == MediaType.image) {
            final photoData = await PhotoBridge.getPhotoBytes(localId);
            if (photoData != null) {
              originalBytes = photoData['bytes'] as Uint8List;
              originalFormat = photoData['ext'] as String;
            }
          }
        }

        if (originalBytes == null) {
          print('McpPackExportService: ⚠️ Could not get bytes for media ${mediaItem.id}');
          continue;
        }

        // Process photo based on size reduction setting
        Uint8List finalBytes = originalBytes;
        bool wasReduced = false;
        if (mediaType == MediaType.image && reducePhotoSize) {
          final reencoded = reencodeFull(originalBytes, maxEdge: 1920, quality: 85);
          finalBytes = reencoded.bytes;
          wasReduced = true;
        }

        final mediaHash = sha256.convert(finalBytes).toString();

        // Deduplicate
        if (seenMediaHashes.containsKey(mediaHash)) {
          print('McpPackExportService: Skipping duplicate media (hash: ${mediaHash.substring(0, 8)}...)');
          final existingId = seenMediaHashes[mediaHash]!;
          (mediaIndex['items'] as List<Map<String, dynamic>>).add({
            'id': mediaItem.id,
            'type': 'media',
            'origin': 'upload',
            'created_at': mediaItem.createdAt.toUtc().toIso8601String(),
            'pack': 'existing',
            'filename': path.basename(mediaItem.uri),
            'bytes': finalBytes.length,
            'duplicate_of': existingId,
          });
          continue;
        }

        seenMediaHashes[mediaHash] = mediaItem.id;

        // Check if we need a new pack
        if (currentPackSize + finalBytes.length > packTargetSizeBytes && currentPack.isNotEmpty) {
          // Finalize current pack
          final packName = 'pack-${packNumber.toString().padLeft(3, '0')}';
          await _finalizeMcpPack(
            packName: packName,
            packItems: currentPack,
            packsDir: packsDir,
            mediaIndex: mediaIndex,
            prevPack: packs.isNotEmpty ? packs.last['name'] as String? : null,
          );

          if (packs.isNotEmpty) {
            packs.last['next'] = packName;
          }

          packs.add({
            'name': packName,
            'prev': packs.isNotEmpty ? packs.last['name'] : null,
            'next': null,
            'total_bytes': currentPackSize,
            'items': currentPack.map((item) => item['id'] as String).toList(),
          });

          currentPack.clear();
          currentPackSize = 0;
          packNumber++;
        }

        // Copy media file to current pack
        final packName = 'pack-${packNumber.toString().padLeft(3, '0')}';
        final packDir = Directory(path.join(packsDir.path, packName));
        await packDir.create(recursive: true);

        String defaultExt;
        switch (mediaType) {
          case MediaType.video:
            defaultExt = 'mp4';
            break;
          case MediaType.audio:
            defaultExt = 'm4a';
            break;
          case MediaType.file:
            defaultExt = originalFormat ?? 'bin';
            break;
          case MediaType.image:
            defaultExt = 'jpg';
            break;
        }

        final fileName = '${mediaHash.substring(0, 16)}.${originalFormat ?? defaultExt}';
        final destFile = File(path.join(packDir.path, fileName));
        await destFile.writeAsBytes(finalBytes);

        // Add to current pack
        currentPack.add({
          'id': mediaItem.id,
          'type': 'media',
          'origin': 'upload',
          'created_at': mediaItem.createdAt.toUtc().toIso8601String(),
          'pack': packName,
          'filename': fileName,
          'bytes': finalBytes.length,
          'sha256': mediaHash,
        });

        currentPackSize += finalBytes.length;
        totalMediaBytes += finalBytes.length;

        // Also create media node JSON
        final mediaNodeSubDir = Directory(path.join(mcpDir.path, 'nodes', 'media', mediaType.name == 'image' ? 'photo' : mediaType.name));
        await mediaNodeSubDir.create(recursive: true);
        final mediaNodeFile = File(path.join(mediaNodeSubDir.path, '${mediaItem.id}.json'));
        await mediaNodeFile.writeAsString(jsonEncode({
          'id': mediaItem.id,
          'kind': mediaType.name,
          'type': mediaType.name,
          'sha256': mediaHash,
          'filename': fileName,
          'pack': packName,
          'createdAt': mediaItem.createdAt.toIso8601String(),
          'originalPath': mediaItem.uri,
          if (mediaItem.duration != null) 'duration': mediaItem.duration!.inSeconds,
          if (mediaItem.sizeBytes != null) 'sizeBytes': mediaItem.sizeBytes,
          if (mediaItem.altText != null) 'altText': mediaItem.altText,
          if (mediaItem.ocrText != null) 'ocrText': mediaItem.ocrText,
          if (mediaItem.transcript != null) 'transcript': mediaItem.transcript,
          if (mediaItem.analysisData != null) 'analysisData': mediaItem.analysisData,
          if (wasReduced) 'reduced': true,
        }));

      } catch (e) {
        print('McpPackExportService: Error exporting media ${mediaItem.id}: $e');
      }
    }

    // Finalize last pack
    if (currentPack.isNotEmpty) {
      final packName = 'pack-${packNumber.toString().padLeft(3, '0')}';
      await _finalizeMcpPack(
        packName: packName,
        packItems: currentPack,
        packsDir: packsDir,
        mediaIndex: mediaIndex,
        prevPack: packs.isNotEmpty ? packs.last['name'] as String? : null,
      );

      if (packs.isNotEmpty) {
        packs.last['next'] = packName;
      }

      packs.add({
        'name': packName,
        'prev': packs.isNotEmpty ? packs.last['name'] : null,
        'next': null,
        'total_bytes': currentPackSize,
        'items': currentPack.map((item) => item['id'] as String).toList(),
      });
    }

    // Update media index
    mediaIndex['packs'] = packs;
    mediaIndex['total_media_items'] = (mediaIndex['items'] as List).length;
    mediaIndex['total_bytes'] = totalMediaBytes;

    // Write media index
    final mediaIndexFile = File(path.join(mediaDir.path, 'media_index.json'));
    await mediaIndexFile.writeAsString(jsonEncode(mediaIndex));

    print('📦 MCP Export: Exported ${(mediaIndex['items'] as List).length} media items in ${packs.length} packs');
  }

  /// Finalize a media pack
  Future<void> _finalizeMcpPack({
    required String packName,
    required List<Map<String, dynamic>> packItems,
    required Directory packsDir,
    required Map<String, dynamic> mediaIndex,
    String? prevPack,
  }) async {
    // Add items to media index
    for (final item in packItems) {
      (mediaIndex['items'] as List<Map<String, dynamic>>).add(item);
    }
  }

}

/// Result of an MCP export operation
class McpExportResult {
  final bool success;
  final String? outputPath;
  final int totalEntries;
  final int totalPhotos;
  final int totalChatSessions;
  final int totalChatMessages;
  final bool isDebugMode;
  final String? error;

  McpExportResult({
    required this.success,
    this.outputPath,
    required this.totalEntries,
    required this.totalPhotos,
    this.totalChatSessions = 0,
    this.totalChatMessages = 0,
    required this.isDebugMode,
    this.error,
  });
}
