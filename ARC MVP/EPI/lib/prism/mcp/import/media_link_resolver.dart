import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/services/media_resolver_service.dart';
import 'package:my_app/services/media_pack_tracking_service.dart';
import 'package:my_app/prism/mcp/models/media_pack_metadata.dart';

/// Resolves media links during import by extracting thumbnails and mounting media packs
class MediaLinkResolver {
  final String _bundleDir;
  final Map<String, String> _photoIdToSha = {}; // Maps [PHOTO:photo_ID] to SHA-256
  final Map<String, String> _shaTothumbPath = {}; // Maps SHA-256 to local thumbnail path
  
  MediaLinkResolver({required String bundleDir}) : _bundleDir = bundleDir;

  /// Initialize the resolver by processing the journal ZIP structure
  Future<void> initialize() async {
    print('🔗 MediaLinkResolver: Initializing...');
    
    // Check if journal_v1.mcp.zip exists
    final journalZip = File('$_bundleDir/journal_v1.mcp.zip');
    if (await journalZip.exists()) {
      print('📦 Found journal_v1.mcp.zip, extracting structured data...');
      await _processJournalZip(journalZip);
    } else {
      print('⚠️ No journal_v1.mcp.zip found, falling back to nodes.jsonl only');
    }
    
    // Auto-mount any media pack ZIPs
    await _autoMountMediaPacks();
    
    print('✅ MediaLinkResolver: Initialization complete');
    print('   - Photo ID mappings: ${_photoIdToSha.length}');
    print('   - Thumbnail paths: ${_shaTothumbPath.length}');
  }

  /// Process journal ZIP to extract entry files and thumbnails
  Future<void> _processJournalZip(File journalZip) async {
    try {
      // Extract journal ZIP to a temporary directory
      final tempDir = Directory('${_bundleDir}/journal_extracted');
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      await tempDir.create(recursive: true);

      print('📂 Extracting journal ZIP to: ${tempDir.path}');
      await extractFileToDisk(journalZip.path, tempDir.path);

      // Extract thumbnails and build SHA mappings
      await _extractThumbnails(tempDir);
      
      // Read entry files to build photo ID to SHA mappings
      await _buildPhotoIdMappings(tempDir);
      
      print('✅ Journal ZIP processed successfully');
    } catch (e, st) {
      print('❌ Error processing journal ZIP: $e');
      print('Stack trace: $st');
    }
  }

  /// Extract thumbnails from journal ZIP to app storage
  Future<void> _extractThumbnails(Directory journalExtracted) async {
    try {
      final thumbsDir = Directory('${journalExtracted.path}/assets/thumbs');
      if (!await thumbsDir.exists()) {
        print('⚠️ No assets/thumbs directory found in journal ZIP');
        return;
      }

      // Get app documents directory for storing thumbnails
      final appDocs = await getApplicationDocumentsDirectory();
      final targetThumbsDir = Directory('${appDocs.path}/thumbnails');
      if (!await targetThumbsDir.exists()) {
        await targetThumbsDir.create(recursive: true);
      }

      print('📸 Extracting thumbnails to: ${targetThumbsDir.path}');
      
      int count = 0;
      await for (final thumbFile in thumbsDir.list()) {
        if (thumbFile is File && thumbFile.path.endsWith('.jpg')) {
          final fileName = thumbFile.path.split('/').last;
          final sha256 = fileName.replaceAll('.jpg', '');
          
          // Copy thumbnail to app storage
          final targetPath = '${targetThumbsDir.path}/$fileName';
          await thumbFile.copy(targetPath);
          
          _shaTothumbPath[sha256] = targetPath;
          count++;
        }
      }
      
      print('✅ Extracted $count thumbnails');
    } catch (e, st) {
      print('❌ Error extracting thumbnails: $e');
      print('Stack trace: $st');
    }
  }

  /// Build mappings from photo IDs to SHA-256 hashes by reading entry files
  Future<void> _buildPhotoIdMappings(Directory journalExtracted) async {
    try {
      final entriesDir = Directory('${journalExtracted.path}/entries');
      if (!await entriesDir.exists()) {
        print('⚠️ No entries directory found in journal ZIP');
        return;
      }

      print('🔍 Building photo ID to SHA mappings...');
      
      int entryCount = 0;
      int mediaCount = 0;
      
      await for (final entryFile in entriesDir.list()) {
        if (entryFile is File && entryFile.path.endsWith('.json')) {
          try {
            final contents = await entryFile.readAsString();
            final entryJson = jsonDecode(contents) as Map<String, dynamic>;
            
            // Extract media array
            final mediaArray = entryJson['media'] as List<dynamic>?;
            if (mediaArray != null) {
              for (final mediaJson in mediaArray) {
                if (mediaJson is Map<String, dynamic>) {
                  final photoId = mediaJson['id'] as String?;
                  final sha256 = mediaJson['sha256'] as String?;
                  
                  if (photoId != null && sha256 != null) {
                    _photoIdToSha[photoId] = sha256;
                    mediaCount++;
                  }
                }
              }
            }
            entryCount++;
          } catch (e) {
            print('⚠️ Error reading entry file ${entryFile.path}: $e');
          }
        }
      }
      
      print('✅ Processed $entryCount entries with $mediaCount media items');
    } catch (e, st) {
      print('❌ Error building photo ID mappings: $e');
      print('Stack trace: $st');
    }
  }

  /// Auto-mount media pack ZIPs found in the bundle
  Future<void> _autoMountMediaPacks() async {
    try {
      final bundleDir = Directory(_bundleDir);
      if (!await bundleDir.exists()) {
        print('⚠️ Bundle directory does not exist: $_bundleDir');
        return;
      }

      print('🔍 Scanning for media packs in: $_bundleDir');
      
      final appDocs = await getApplicationDocumentsDirectory();
      final mediaPacksDir = Directory('${appDocs.path}/media_packs');
      if (!await mediaPacksDir.exists()) {
        await mediaPacksDir.create(recursive: true);
      }

      int mountedCount = 0;
      
      await for (final file in bundleDir.list()) {
        if (file is File && file.path.contains('mcp_media_') && file.path.endsWith('.zip')) {
          try {
            final fileName = file.path.split('/').last;
            print('📦 Found media pack: $fileName');
            
            // Copy media pack to app storage
            final targetPath = '${mediaPacksDir.path}/$fileName';
            await file.copy(targetPath);
            
            // Extract pack ID from filename
            final packId = fileName.replaceAll('.zip', '');
            
            // Get file stats for metadata
            final fileStat = await File(targetPath).stat();
            
            // Register with tracking service
            final packMetadata = MediaPackMetadata(
              packId: packId,
              createdAt: fileStat.modified,
              fileCount: 0, // Will be updated when pack is read
              totalSizeBytes: fileStat.size,
              dateFrom: fileStat.modified,
              dateTo: fileStat.modified,
              status: MediaPackStatus.active,
              storagePath: targetPath,
              description: 'Imported media pack from MCP bundle',
            );
            
            await MediaPackTrackingService.instance.registerPack(packMetadata);
            print('📝 Registered media pack with tracking service: $packId');
            
            // Mount with MediaResolverService
            await MediaResolverService.instance.mountPack(targetPath);
            print('🔗 Mounted media pack: $packId');
            
            mountedCount++;
          } catch (e, st) {
            print('❌ Error mounting media pack ${file.path}: $e');
            print('Stack trace: $st');
          }
        }
      }
      
      print('✅ Auto-mounted $mountedCount media packs');
    } catch (e, st) {
      print('❌ Error auto-mounting media packs: $e');
      print('Stack trace: $st');
    }
  }

  /// Resolve a media item from JSON, enriching it with thumbnail and full-res paths
  Future<MediaItem> resolveMediaItem(Map<String, dynamic> mediaJson) async {
    try {
      final sha256 = mediaJson['sha256'] as String?;
      
      // Build local thumbnail path if we have it
      String? localThumbPath;
      if (sha256 != null && _shaTothumbPath.containsKey(sha256)) {
        localThumbPath = _shaTothumbPath[sha256];
      }
      
      // Create MediaItem with all the enriched data
      final mediaItem = MediaItem.fromJson(mediaJson);
      
      // If we extracted a local thumbnail, update the thumbUri to point to it
      if (localThumbPath != null) {
        return mediaItem.copyWith(
          thumbUri: localThumbPath,
        );
      }
      
      return mediaItem;
    } catch (e, st) {
      print('❌ Error resolving media item: $e');
      print('Stack trace: $st');
      rethrow;
    }
  }

  /// Get the SHA-256 hash for a photo ID
  String? getShaForPhotoId(String photoId) {
    return _photoIdToSha[photoId];
  }

  /// Get the local thumbnail path for a SHA-256 hash
  String? getThumbnailPath(String sha256) {
    return _shaTothumbPath[sha256];
  }

  /// Check if a thumbnail exists for a SHA-256 hash
  bool hasThumbnail(String sha256) {
    return _shaTothumbPath.containsKey(sha256);
  }
}

