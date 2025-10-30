import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:my_app/core/mcp/models/media_pack_manifest.dart';

/// Resolves media content by SHA-256 hash from journal and media packs
class MediaResolver {
  final String _journalPath;
  final List<String> _mediaPackPaths;
  final Map<String, String> _shaToPackId = {}; // Cache for quick lookups

  MediaResolver({
    required String journalPath,
    List<String> mediaPackPaths = const [],
  }) : _journalPath = journalPath,
       _mediaPackPaths = mediaPackPaths;

  /// Load thumbnail from journal bundle
  Future<Uint8List?> loadThumbnail(String sha) async {
    try {
      final journalFile = File(_journalPath);
      if (!await journalFile.exists()) {
        print('MediaResolver: Journal file not found: $_journalPath');
        return null;
      }

      final bytes = await journalFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      final thumbPath = 'assets/thumbs/$sha.jpg';
      final thumbEntry = archive.findFile(thumbPath);
      
      if (thumbEntry != null) {
        return Uint8List.fromList(thumbEntry.content);
      }
      
      print('MediaResolver: Thumbnail not found: $thumbPath');
      return null;
    } catch (e) {
      print('MediaResolver: Error loading thumbnail $sha: $e');
      return null;
    }
  }

  /// Load full-resolution image from media pack
  Future<Uint8List?> loadFullImage(String sha) async {
    try {
      // Check cache first
      final packId = _shaToPackId[sha];
      if (packId != null) {
        return await _loadFromPack(packId, sha);
      }

      // Scan all media packs to find the SHA
      for (final packPath in _mediaPackPaths) {
        final packId = path.basenameWithoutExtension(packPath);
        final imageData = await _loadFromPack(packId, sha);
        if (imageData != null) {
          // Cache the result
          _shaToPackId[sha] = packId;
          return imageData;
        }
      }

      print('MediaResolver: Full image not found in any pack: $sha');
      return null;
    } catch (e) {
      print('MediaResolver: Error loading full image $sha: $e');
      return null;
    }
  }

  /// Load image from specific media pack
  Future<Uint8List?> _loadFromPack(String packId, String sha) async {
    try {
      final packFile = File(_mediaPackPaths.firstWhere(
        (p) => path.basenameWithoutExtension(p) == packId,
        orElse: () => '',
      ));

      if (!await packFile.exists()) {
        return null;
      }

      final bytes = await packFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      // Read manifest to find the correct path
      final manifestEntry = archive.findFile('manifest.json');
      if (manifestEntry == null) {
        return null;
      }

      final manifestJson = String.fromCharCodes(manifestEntry.content);
      final manifest = MediaPackManifest.fromJson(
        jsonDecode(manifestJson) as Map<String, dynamic>
      );

      final item = manifest.items[sha];
      if (item == null) {
        return null;
      }

      final imageEntry = archive.findFile(item.path);
      if (imageEntry != null) {
        return Uint8List.fromList(imageEntry.content);
      }

      return null;
    } catch (e) {
      print('MediaResolver: Error loading from pack $packId: $e');
      return null;
    }
  }

  /// Build cache of SHA to pack ID mappings
  Future<void> buildCache() async {
    _shaToPackId.clear();
    
    for (final packPath in _mediaPackPaths) {
      try {
        final packFile = File(packPath);
        if (!await packFile.exists()) continue;

        final bytes = await packFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        
        final manifestEntry = archive.findFile('manifest.json');
        if (manifestEntry == null) continue;

        final manifestJson = String.fromCharCodes(manifestEntry.content);
        final manifest = MediaPackManifest.fromJson(
          jsonDecode(manifestJson) as Map<String, dynamic>
        );
        
        final packId = path.basenameWithoutExtension(packPath);
        
        // Cache all SHAs in this pack
        for (final sha in manifest.items.keys) {
          _shaToPackId[sha] = packId;
        }
      } catch (e) {
        print('MediaResolver: Error building cache for pack $packPath: $e');
      }
    }
  }

  /// Add a new media pack to the resolver
  void addMediaPack(String packPath) {
    if (!_mediaPackPaths.contains(packPath)) {
      _mediaPackPaths.add(packPath);
    }
  }

  /// Remove a media pack from the resolver
  void removeMediaPack(String packPath) {
    _mediaPackPaths.remove(packPath);
    // Remove cached entries for this pack
    _shaToPackId.removeWhere((sha, packId) => packId == path.basenameWithoutExtension(packPath));
  }

  /// Get list of available media packs
  List<String> get availablePacks => List.unmodifiable(_mediaPackPaths);

  /// Get cache statistics
  Map<String, dynamic> get cacheStats => {
    'cachedShas': _shaToPackId.length,
    'availablePacks': _mediaPackPaths.length,
  };
}
