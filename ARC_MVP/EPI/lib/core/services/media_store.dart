import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:my_app/data/models/media_item.dart';

/// Service for managing media files in the app sandbox
/// Handles storage, retrieval, and deletion of media items
class MediaStore {
  static const String _mediaDirectoryName = 'media';
  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10MB limit
  
  final Uuid _uuid = const Uuid();
  
  /// Get the media directory path
  Future<Directory> get _mediaDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/$_mediaDirectoryName');
    
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    
    return mediaDir;
  }
  
  /// Store audio data and return MediaItem
  Future<MediaItem> storeAudio({
    required Uint8List audioData,
    required Duration duration,
    String? transcript,
  }) async {
    try {
      // Validate file size
      if (audioData.length > _maxFileSizeBytes) {
        throw MediaStoreException('Audio file too large: ${audioData.length} bytes (max: $_maxFileSizeBytes)');
      }
      
      final mediaDir = await _mediaDirectory;
      final fileName = '${_uuid.v4()}.m4a';
      final filePath = '${mediaDir.path}/$fileName';
      
      // Write audio data to file
      final file = File(filePath);
      await file.writeAsBytes(audioData);
      
      // Create MediaItem
      final mediaItem = MediaItem(
        id: _uuid.v4(),
        uri: filePath,
        type: MediaType.audio,
        duration: duration,
        sizeBytes: audioData.length,
        createdAt: DateTime.now(),
        transcript: transcript,
      );
      
      print('MediaStore: Stored audio file: $filePath (${audioData.length} bytes)');
      return mediaItem;
      
    } catch (e) {
      print('MediaStore: Error storing audio: $e');
      throw MediaStoreException('Failed to store audio: $e');
    }
  }
  
  /// Store image data and return MediaItem
  Future<MediaItem> storeImage({
    required Uint8List imageData,
    String? ocrText,
  }) async {
    try {
      // Validate file size
      if (imageData.length > _maxFileSizeBytes) {
        throw MediaStoreException('Image file too large: ${imageData.length} bytes (max: $_maxFileSizeBytes)');
      }
      
      final mediaDir = await _mediaDirectory;
      final fileName = '${_uuid.v4()}.jpg';
      final filePath = '${mediaDir.path}/$fileName';
      
      // Write image data to file
      final file = File(filePath);
      await file.writeAsBytes(imageData);
      
      // Create MediaItem
      final mediaItem = MediaItem(
        id: _uuid.v4(),
        uri: filePath,
        type: MediaType.image,
        sizeBytes: imageData.length,
        createdAt: DateTime.now(),
        ocrText: ocrText,
      );
      
      print('MediaStore: Stored image file: $filePath (${imageData.length} bytes)');
      return mediaItem;
      
    } catch (e) {
      print('MediaStore: Error storing image: $e');
      throw MediaStoreException('Failed to store image: $e');
    }
  }
  
  /// Store video data and return MediaItem
  Future<MediaItem> storeVideo({
    required Uint8List videoData,
    required Duration duration,
  }) async {
    try {
      // Validate file size
      if (videoData.length > _maxFileSizeBytes) {
        throw MediaStoreException('Video file too large: ${videoData.length} bytes (max: $_maxFileSizeBytes)');
      }
      
      final mediaDir = await _mediaDirectory;
      final fileName = '${_uuid.v4()}.mp4';
      final filePath = '${mediaDir.path}/$fileName';
      
      // Write video data to file
      final file = File(filePath);
      await file.writeAsBytes(videoData);
      
      // Create MediaItem
      final mediaItem = MediaItem(
        id: _uuid.v4(),
        uri: filePath,
        type: MediaType.video,
        duration: duration,
        sizeBytes: videoData.length,
        createdAt: DateTime.now(),
      );
      
      print('MediaStore: Stored video file: $filePath (${videoData.length} bytes)');
      return mediaItem;
      
    } catch (e) {
      print('MediaStore: Error storing video: $e');
      throw MediaStoreException('Failed to store video: $e');
    }
  }
  
  /// Store file data and return MediaItem
  Future<MediaItem> storeFile({
    required Uint8List fileData,
    required String extension,
  }) async {
    try {
      // Validate file size
      if (fileData.length > _maxFileSizeBytes) {
        throw MediaStoreException('File too large: ${fileData.length} bytes (max: $_maxFileSizeBytes)');
      }
      
      final mediaDir = await _mediaDirectory;
      final fileName = '${_uuid.v4()}.$extension';
      final filePath = '${mediaDir.path}/$fileName';
      
      // Write file data to file
      final file = File(filePath);
      await file.writeAsBytes(fileData);
      
      // Create MediaItem
      final mediaItem = MediaItem(
        id: _uuid.v4(),
        uri: filePath,
        type: MediaType.file,
        sizeBytes: fileData.length,
        createdAt: DateTime.now(),
      );
      
      print('MediaStore: Stored file: $filePath (${fileData.length} bytes)');
      return mediaItem;
      
    } catch (e) {
      print('MediaStore: Error storing file: $e');
      throw MediaStoreException('Failed to store file: $e');
    }
  }
  
  /// Delete a media file by URI
  Future<void> deleteMedia(String uri) async {
    try {
      final file = File(uri);
      if (await file.exists()) {
        await file.delete();
        print('MediaStore: Deleted media file: $uri');
      } else {
        print('MediaStore: Media file not found: $uri');
      }
    } catch (e) {
      print('MediaStore: Error deleting media file $uri: $e');
      throw MediaStoreException('Failed to delete media file: $e');
    }
  }
  
  /// Delete multiple media files
  Future<void> deleteMultipleMedia(List<String> uris) async {
    for (final uri in uris) {
      try {
        await deleteMedia(uri);
      } catch (e) {
        print('MediaStore: Error deleting media file $uri: $e');
        // Continue with other files even if one fails
      }
    }
  }
  
  /// Get file size for a media URI
  Future<int> getFileSize(String uri) async {
    try {
      final file = File(uri);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      print('MediaStore: Error getting file size for $uri: $e');
      return 0;
    }
  }
  
  /// Check if a media file exists
  Future<bool> fileExists(String uri) async {
    try {
      final file = File(uri);
      return await file.exists();
    } catch (e) {
      print('MediaStore: Error checking file existence for $uri: $e');
      return false;
    }
  }
  
  /// Get total storage usage for all media files
  Future<int> getTotalStorageUsage() async {
    try {
      final mediaDir = await _mediaDirectory;
      int totalSize = 0;
      
      await for (final entity in mediaDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      print('MediaStore: Error calculating storage usage: $e');
      return 0;
    }
  }
  
  /// Clean up orphaned media files (files not referenced by any journal entry)
  Future<int> cleanupOrphanedFiles(List<MediaItem> referencedMedia) async {
    try {
      final mediaDir = await _mediaDirectory;
      final referencedUris = referencedMedia.map((m) => m.uri).toSet();
      int cleanedCount = 0;
      
      await for (final entity in mediaDir.list(recursive: true)) {
        if (entity is File && !referencedUris.contains(entity.path)) {
          try {
            await entity.delete();
            cleanedCount++;
            print('MediaStore: Cleaned up orphaned file: ${entity.path}');
          } catch (e) {
            print('MediaStore: Error cleaning up file ${entity.path}: $e');
          }
        }
      }
      
      print('MediaStore: Cleaned up $cleanedCount orphaned files');
      return cleanedCount;
    } catch (e) {
      print('MediaStore: Error during cleanup: $e');
      return 0;
    }
  }
}

/// Exception thrown by MediaStore operations
class MediaStoreException implements Exception {
  final String message;
  const MediaStoreException(this.message);
  
  @override
  String toString() => 'MediaStoreException: $message';
}
