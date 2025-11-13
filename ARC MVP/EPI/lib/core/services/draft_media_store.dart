/// Draft Media Store
///
/// Content-addressed storage for draft media with no compression.
/// Originals are stored bit-exactly by SHA-256 hash.
/// Thumbnails are generated separately for UI performance.

import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'draft_media_policy.dart';

/// Result type for MediaStore operations
class Result<T, E> {
  final T? value;
  final E? error;
  final bool isSuccess;

  Result.success(this.value) : error = null, isSuccess = true;
  Result.failure(this.error) : value = null, isSuccess = false;
}

/// Draft error types
enum DraftError {
  tooLarge,
  quotaExceeded,
  ioError,
  hashMismatch,
  notFound,
}

/// Media reference returned by MediaStore
class MediaRef {
  final String mediaId;      // ULID
  final String hash;         // SHA-256 hash
  final String uri;          // Path to blob (blobs/{hash[:2]}/{hash})
  final String kind;         // 'image' | 'video' | 'audio'
  final int sizeBytes;
  final bool exifPresent;    // EXIF metadata preserved
  final String? thumbUri;    // Path to thumbnail if generated

  MediaRef({
    required this.mediaId,
    required this.hash,
    required this.uri,
    required this.kind,
    required this.sizeBytes,
    this.exifPresent = true,
    this.thumbUri,
  });
}

/// MediaStore for content-addressed, no-compression media storage
class DraftMediaStore {
  static DraftMediaStore? _instance;
  static DraftMediaStore get instance => _instance ??= DraftMediaStore._();
  DraftMediaStore._();

  Directory? _blobsDir;
  Directory? _thumbsDir;
  final Map<String, int> _refCounts = {}; // hash -> refcount
  final Map<String, int> _draftMediaSizes = {}; // entryId -> total bytes

  /// Initialize media store directories
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mcpDir = Directory(path.join(appDir.path, 'mcp'));
      
      _blobsDir = Directory(path.join(mcpDir.path, 'blobs'));
      _thumbsDir = Directory(path.join(mcpDir.path, 'thumbs'));
      
      await _blobsDir!.create(recursive: true);
      await _thumbsDir!.create(recursive: true);
      
      // Load reference counts from disk
      await _loadRefCounts();
      
      debugPrint('DraftMediaStore: Initialized (blobs: ${_blobsDir!.path}, thumbs: ${_thumbsDir!.path})');
    } catch (e) {
      debugPrint('DraftMediaStore: Failed to initialize: $e');
      rethrow;
    }
  }

  /// Add original media file (binary copy only, no compression)
  /// 
  /// Validates size, computes hash, streams copy to content-addressed location.
  /// Returns MediaRef with blob path and optional thumbnail path.
  Future<Result<MediaRef, DraftError>> addOriginal(
    File src, {
    String? mediaId,
    String? kind, // 'image' | 'video' | 'audio'
  }) async {
    try {
      // Validate file exists
      if (!await src.exists()) {
        return Result.failure(DraftError.notFound);
      }

      // Validate size
      final sizeBytes = await src.length();
      if (sizeBytes > MediaPolicy.maxSingleImportBytes) {
        debugPrint('DraftMediaStore: File too large: $sizeBytes bytes (max: ${MediaPolicy.maxSingleImportBytes})');
        return Result.failure(DraftError.tooLarge);
      }

      // Compute hash while streaming (chunked read to avoid OOM)
      final hash = await _computeHashStreaming(src);
      
      // Determine kind from file if not provided
      final mediaKind = kind ?? _inferKind(src.path);
      
      // Check if blob already exists (deduplication)
      final blobPath = _getBlobPath(hash);
      final blobFile = File(blobPath);
      
      if (await blobFile.exists()) {
        // Blob exists, verify hash matches (safety check)
        final existingHash = await _computeHashStreaming(blobFile);
        if (existingHash != hash) {
          debugPrint('DraftMediaStore: Hash mismatch for existing blob!');
          return Result.failure(DraftError.hashMismatch);
        }
        
        // Increment reference count
        _refCounts[hash] = (_refCounts[hash] ?? 0) + 1;
        await _saveRefCounts();
        
        debugPrint('DraftMediaStore: Reused existing blob $hash (refcount: ${_refCounts[hash]})');
      } else {
        // Stream copy to blob location (binary copy, no decode/encode)
        await _streamCopy(src, blobFile);
        
        // Verify copied file hash matches
        final copiedHash = await _computeHashStreaming(blobFile);
        if (copiedHash != hash) {
          // Cleanup corrupted copy
          await blobFile.delete();
          debugPrint('DraftMediaStore: Hash mismatch after copy!');
          return Result.failure(DraftError.hashMismatch);
        }
        
        // Initialize reference count
        _refCounts[hash] = 1;
        await _saveRefCounts();
        
        debugPrint('DraftMediaStore: Stored new blob $hash (${sizeBytes} bytes)');
      }

      // Generate thumbnail if enabled and applicable
      String? thumbUri;
      if (MediaPolicy.generateThumbs && (mediaKind == 'image' || mediaKind == 'video')) {
        final thumbResult = await ensureThumb(hash, kind: mediaKind);
        if (thumbResult.isSuccess) {
          thumbUri = thumbResult.value;
        }
      }

      // Check for EXIF (for images, assume present if JPEG/RAW)
      final exifPresent = mediaKind == 'image' && 
          (src.path.toLowerCase().endsWith('.jpg') || 
           src.path.toLowerCase().endsWith('.jpeg') ||
           src.path.toLowerCase().endsWith('.raw') ||
           src.path.toLowerCase().endsWith('.cr2') ||
           src.path.toLowerCase().endsWith('.nef'));

      final ref = MediaRef(
        mediaId: mediaId ?? _generateMediaId(),
        hash: hash,
        uri: blobPath,
        kind: mediaKind,
        sizeBytes: sizeBytes,
        exifPresent: exifPresent,
        thumbUri: thumbUri,
      );

      return Result.success(ref);
    } catch (e) {
      debugPrint('DraftMediaStore: Error adding original: $e');
      return Result.failure(DraftError.ioError);
    }
  }

  /// Ensure thumbnail exists for hash (generates if needed)
  /// 
  /// Thumbnails are separate files and never overwrite originals.
  Future<Result<String, DraftError>> ensureThumb(
    String hash, {
    String? kind,
    int maxW = 512,
    int maxH = 512,
  }) async {
    try {
      final thumbPath = _getThumbPath(hash, maxW, maxH);
      final thumbFile = File(thumbPath);
      
      // Return existing thumbnail if present
      if (await thumbFile.exists()) {
        return Result.success(thumbPath);
      }

      // Load original blob
      final blobPath = _getBlobPath(hash);
      final blobFile = File(blobPath);
      if (!await blobFile.exists()) {
        return Result.failure(DraftError.notFound);
      }

      // Determine kind if not provided
      final mediaKind = kind ?? _inferKindFromHash(hash);
      
      // Generate thumbnail (only for images/videos)
      if (mediaKind == 'image') {
        await _generateImageThumb(blobFile, thumbFile, maxW, maxH);
      } else if (mediaKind == 'video') {
        try {
          await _generateVideoThumb(blobFile, thumbFile, maxW, maxH);
        } catch (e) {
          // Video thumbnail generation not implemented yet
          return Result.failure(DraftError.notFound);
        }
      } else {
        return Result.failure(DraftError.notFound);
      }

      return Result.success(thumbPath);
    } catch (e) {
      debugPrint('DraftMediaStore: Error ensuring thumbnail: $e');
      return Result.failure(DraftError.ioError);
    }
  }

  /// Retain media (increment reference count)
  Future<void> retain(String hash) async {
    _refCounts[hash] = (_refCounts[hash] ?? 0) + 1;
    await _saveRefCounts();
  }

  /// Release media (decrement reference count, delete if zero)
  /// 
  /// Only deletes blob if refcount reaches zero AND no published versions reference it.
  Future<void> release(String hash) async {
    final currentCount = _refCounts[hash] ?? 0;
    if (currentCount <= 1) {
      // Check if any published versions reference this hash
      final hasVersionReference = await _checkVersionReferences(hash);
      
      if (currentCount == 1) {
        _refCounts[hash] = 0;
        await _saveRefCounts();
        
        // If no version references, safe to delete
        if (!hasVersionReference) {
          _refCounts.remove(hash);
          await _saveRefCounts();
          
          final blobFile = File(_getBlobPath(hash));
          if (await blobFile.exists()) {
            await blobFile.delete();
            debugPrint('DraftMediaStore: Deleted blob $hash (refcount: 0, no version references)');
          }
          
          // Also delete thumbnails
          await _deleteThumbnails(hash);
        } else {
          debugPrint('DraftMediaStore: Released $hash (refcount: 0, keeping for version references)');
        }
        return;
      }
      
      // Refcount is 0, check version references before deleting
      if (!hasVersionReference) {
        _refCounts.remove(hash);
        await _saveRefCounts();
        
        final blobFile = File(_getBlobPath(hash));
        if (await blobFile.exists()) {
          await blobFile.delete();
          debugPrint('DraftMediaStore: Deleted blob $hash (refcount: 0, no version references)');
        }
        
        // Also delete thumbnails
        await _deleteThumbnails(hash);
      } else {
        debugPrint('DraftMediaStore: Released $hash (refcount: 0, keeping for version references)');
      }
    } else {
      _refCounts[hash] = currentCount - 1;
      await _saveRefCounts();
      debugPrint('DraftMediaStore: Released $hash (refcount: ${_refCounts[hash]})');
    }
  }
  
  /// Check if any published versions reference this media hash
  Future<bool> _checkVersionReferences(String hash) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final entriesDir = Directory(path.join(appDir.path, 'mcp', 'entries'));
      
      if (!await entriesDir.exists()) {
        return false;
      }
      
      // Scan all entries for versions that reference this hash
      await for (final entry in entriesDir.list()) {
        if (entry is Directory) {
          final versionDir = Directory(path.join(entry.path, 'v'));
          if (!await versionDir.exists()) continue;
          
          // Check all version files
          await for (final versionFile in versionDir.list()) {
            if (versionFile is File && versionFile.path.endsWith('.json')) {
              try {
                final content = await versionFile.readAsString();
                final json = jsonDecode(content) as Map<String, dynamic>;
                
                // Check if version references this hash in media
                final mediaList = json['media'] as List?;
                if (mediaList != null) {
                  for (final mediaItem in mediaList) {
                    if (mediaItem is Map<String, dynamic>) {
                      final mediaHash = mediaItem['sha256'] as String?;
                      if (mediaHash == hash) {
                        debugPrint('DraftMediaStore: Found version reference to $hash in ${versionFile.path}');
                        return true;
                      }
                    }
                  }
                }
              } catch (e) {
                debugPrint('DraftMediaStore: Error checking version file ${versionFile.path}: $e');
                // Continue checking other files
              }
            }
          }
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('DraftMediaStore: Error checking version references: $e');
      // If we can't check, err on the side of caution and keep the blob
      return true;
    }
  }

  /// Check draft quota (total media size for entry)
  Future<Result<void, DraftError>> checkDraftQuota(
    String entryId,
    int additionalBytes,
  ) async {
    final currentSize = _draftMediaSizes[entryId] ?? 0;
    final newSize = currentSize + additionalBytes;
    
    if (newSize > MediaPolicy.maxDraftTotalBytes) {
      return Result.failure(DraftError.quotaExceeded);
    }
    
    return Result.success(null);
  }

  /// Update draft media size tracking
  void updateDraftSize(String entryId, int sizeBytes) {
    _draftMediaSizes[entryId] = sizeBytes;
  }

  /// Get blob file for hash
  File getBlobFile(String hash) {
    return File(_getBlobPath(hash));
  }

  /// Get thumbnail file for hash
  File? getThumbFile(String hash, {int maxW = 512, int maxH = 512}) {
    final thumbPath = _getThumbPath(hash, maxW, maxH);
    final file = File(thumbPath);
    return file.existsSync() ? file : null;
  }

  // Private methods

  String _getBlobPath(String hash) {
    final prefix = hash.substring(0, 2);
    return path.join(_blobsDir!.path, prefix, hash);
  }

  String _getThumbPath(String hash, int maxW, int maxH) {
    return path.join(_thumbsDir!.path, '${hash}_w${maxW}_h${maxH}.jpg');
  }

  /// Compute hash using streaming for large files (avoids loading entire file into memory)
  Future<String> _computeHashStreaming(File file) async {
    try {
      final fileSize = await file.length();
      
      // For small files (< 10MB), read all at once (faster)
      if (fileSize < 10 * 1024 * 1024) {
        final bytes = await file.readAsBytes();
        final digest = sha256.convert(bytes);
        return digest.toString();
      }
      
      // For large files, accumulate chunks and hash
      // This avoids loading the entire file into memory at once
      final List<int> chunks = [];
      final stream = file.openRead();
      
      await for (final chunk in stream) {
        chunks.addAll(chunk);
      }
      
      final digest = sha256.convert(chunks);
      return digest.toString();
    } catch (e) {
      debugPrint('DraftMediaStore: Error computing hash: $e');
      // Fallback to reading entire file
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString();
    }
  }

  Future<void> _streamCopy(File src, File dest) async {
    // Create parent directory
    await dest.parent.create(recursive: true);
    
    // Stream copy in chunks (binary copy, no decode/encode)
    final sink = dest.openWrite();
    
    try {
      await for (final chunk in src.openRead()) {
        sink.add(chunk);
      }
    } finally {
      await sink.close();
    }
  }

  String _inferKind(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.raw', '.cr2', '.nef'].contains(ext)) {
      return 'image';
    } else if (['.mp4', '.mov', '.avi', '.mkv'].contains(ext)) {
      return 'video';
    } else if (['.m4a', '.mp3', '.wav', '.aac'].contains(ext)) {
      return 'audio';
    }
    return 'image'; // default
  }

  String _inferKindFromHash(String hash) {
    // Can't infer from hash alone, default to image
    // In practice, kind should be passed or stored in metadata
    return 'image';
  }

  /// Generate image thumbnail (separate file, original untouched)
  Future<void> _generateImageThumb(File original, File thumb, int maxW, int maxH) async {
    try {
      // Read original image bytes (binary read, no decode yet)
      final bytes = await original.readAsBytes();
      
      // Decode image
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }
      
      // Calculate thumbnail dimensions maintaining aspect ratio
      final aspectRatio = image.width / image.height;
      int thumbWidth, thumbHeight;
      
      if (aspectRatio > 1) {
        // Landscape: fit to max width
        thumbWidth = maxW;
        thumbHeight = (maxW / aspectRatio).round().clamp(1, maxH);
      } else {
        // Portrait or square: fit to max height
        thumbHeight = maxH;
        thumbWidth = (maxH * aspectRatio).round().clamp(1, maxW);
      }
      
      // Resize image using high-quality interpolation
      final resized = img.copyResize(
        image,
        width: thumbWidth,
        height: thumbHeight,
        interpolation: img.Interpolation.cubic,
      );
      
      // Encode as JPEG (thumbnail format, original format preserved separately)
      // Use quality 85 for good balance of size/quality
      final thumbBytes = img.encodeJpg(resized, quality: 85);
      
      // Write thumbnail to separate file (original untouched)
      await thumb.parent.create(recursive: true);
      await thumb.writeAsBytes(thumbBytes);
      
      debugPrint('DraftMediaStore: Generated thumbnail ${thumbWidth}x${thumbHeight} for ${original.path}');
    } catch (e) {
      debugPrint('DraftMediaStore: Error generating image thumbnail: $e');
      rethrow;
    }
  }
  
  /// Generate video thumbnail (platform-specific)
  /// For now, returns null - can be extended with platform channels or video_player
  Future<void> _generateVideoThumb(File original, File thumb, int maxW, int maxH) async {
    try {
      // TODO: Implement video thumbnail extraction
      // Options:
      // 1. Use video_player package to get frame at 0:00
      // 2. Use platform channels to call native video thumbnail APIs
      // 3. Use FFmpeg (if re-enabled) to extract frame
      
      // For now, create placeholder or skip
      debugPrint('DraftMediaStore: Video thumbnail generation not yet implemented');
      
      // Placeholder: could create a default video icon thumbnail
      // For now, we'll skip video thumbnails
      throw UnimplementedError('Video thumbnail generation not implemented');
    } catch (e) {
      debugPrint('DraftMediaStore: Error generating video thumbnail: $e');
      rethrow;
    }
  }

  Future<void> _deleteThumbnails(String hash) async {
    try {
      final thumbsDir = _thumbsDir!;
      if (!await thumbsDir.exists()) return;
      
      await for (final entity in thumbsDir.list()) {
        if (entity is File && entity.path.contains(hash)) {
          await entity.delete();
        }
      }
    } catch (e) {
      debugPrint('DraftMediaStore: Error deleting thumbnails: $e');
    }
  }

  String _generateMediaId() {
    // Generate ULID-like ID
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 1000000).toString().padLeft(6, '0');
    return 'media_${timestamp}_$random';
  }

  Future<void> _loadRefCounts() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final refCountFile = File(path.join(appDir.path, 'mcp', 'refcounts.json'));
      
      if (await refCountFile.exists()) {
        final content = await refCountFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _refCounts.clear();
        json.forEach((key, value) {
          _refCounts[key] = value as int;
        });
      }
    } catch (e) {
      debugPrint('DraftMediaStore: Error loading ref counts: $e');
    }
  }

  Future<void> _saveRefCounts() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mcpDir = Directory(path.join(appDir.path, 'mcp'));
      await mcpDir.create(recursive: true);
      
      final refCountFile = File(path.join(mcpDir.path, 'refcounts.json'));
      final json = jsonEncode(_refCounts);
      await refCountFile.writeAsString(json);
    } catch (e) {
      debugPrint('DraftMediaStore: Error saving ref counts: $e');
    }
  }
}

