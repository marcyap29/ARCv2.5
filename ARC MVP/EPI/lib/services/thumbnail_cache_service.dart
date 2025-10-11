import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class ThumbnailCacheService {
  static final ThumbnailCacheService _instance = ThumbnailCacheService._internal();
  factory ThumbnailCacheService() => _instance;
  ThumbnailCacheService._internal();

  final Map<String, Uint8List> _memoryCache = {};
  final Map<String, String> _fileCache = {};
  Directory? _cacheDirectory;

  Future<void> initialize() async {
    final tempDir = await getTemporaryDirectory();
    _cacheDirectory = Directory('${tempDir.path}/thumbnails');
    await _cacheDirectory!.create(recursive: true);
  }

  Future<Uint8List?> getThumbnail(String imagePath, {int size = 80}) async {
    final cacheKey = '${imagePath}_$size';
    
    // Check memory cache first
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }

    // Check file cache
    if (_fileCache.containsKey(cacheKey)) {
      final cachedFile = File(_fileCache[cacheKey]!);
      if (await cachedFile.exists()) {
        final bytes = await cachedFile.readAsBytes();
        _memoryCache[cacheKey] = bytes;
        return bytes;
      } else {
        _fileCache.remove(cacheKey);
      }
    }

    // Generate thumbnail
    try {
      final thumbnail = await _generateThumbnail(imagePath, size);
      if (thumbnail != null) {
        // Store in memory cache
        _memoryCache[cacheKey] = thumbnail;
        
        // Store in file cache
        if (_cacheDirectory != null) {
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_${imagePath.split('/').last}';
          final filePath = '${_cacheDirectory!.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(thumbnail);
          _fileCache[cacheKey] = filePath;
        }
        
        return thumbnail;
      }
    } catch (e) {
      print('DEBUG: Error generating thumbnail: $e');
    }

    return null;
  }

  Future<Uint8List?> _generateThumbnail(String imagePath, int size) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Calculate dimensions maintaining aspect ratio
      final aspectRatio = image.width / image.height;
      int width, height;
      
      if (aspectRatio > 1) {
        width = size;
        height = (size / aspectRatio).round();
      } else {
        height = size;
        width = (size * aspectRatio).round();
      }

      // Resize image
      final resized = img.copyResize(image, width: width, height: height);
      
      // Encode as JPEG
      final jpegBytes = img.encodeJpg(resized, quality: 85);
      return Uint8List.fromList(jpegBytes);
    } catch (e) {
      print('DEBUG: Error in _generateThumbnail: $e');
      return null;
    }
  }

  void clearThumbnail(String imagePath, {int size = 80}) {
    final cacheKey = '${imagePath}_$size';
    
    // Remove from memory cache
    _memoryCache.remove(cacheKey);
    
    // Remove from file cache
    if (_fileCache.containsKey(cacheKey)) {
      final file = File(_fileCache[cacheKey]!);
      file.delete().catchError((e) => print('DEBUG: Error deleting cached thumbnail: $e'));
      _fileCache.remove(cacheKey);
    }
  }

  void clearAllThumbnails() {
    // Clear memory cache
    _memoryCache.clear();
    
    // Clear file cache
    for (final filePath in _fileCache.values) {
      final file = File(filePath);
      file.delete().catchError((e) => print('DEBUG: Error deleting cached thumbnail: $e'));
    }
    _fileCache.clear();
  }

  void clearOldThumbnails({Duration maxAge = const Duration(hours: 24)}) {
    final cutoff = DateTime.now().subtract(maxAge);
    
    // Clear old file cache entries
    final keysToRemove = <String>[];
    for (final entry in _fileCache.entries) {
      final file = File(entry.value);
      if (file.existsSync()) {
        final stat = file.statSync();
        if (stat.modified.isBefore(cutoff)) {
          file.delete().catchError((e) => print('DEBUG: Error deleting old thumbnail: $e'));
          keysToRemove.add(entry.key);
        }
      } else {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _fileCache.remove(key);
      _memoryCache.remove(key);
    }
  }

  int get cacheSize => _memoryCache.length;
  int get fileCacheSize => _fileCache.length;
}
