import 'dart:io';
import 'package:my_app/prism/mcp/media_resolver.dart';
import 'package:my_app/services/media_pack_tracking_service.dart';
import 'package:my_app/prism/mcp/models/media_pack_metadata.dart';

/// App-level service for managing MediaResolver instance
///
/// This service provides a singleton MediaResolver that can be accessed
/// throughout the app for loading content-addressed media.
///
/// Usage:
/// ```dart
/// // Initialize at app startup
/// MediaResolverService.instance.initialize(
///   journalPath: '/path/to/journal_v1.mcp.zip',
///   mediaPackPaths: ['/path/to/mcp_media_2025_01.zip'],
/// );
///
/// // Use in widgets
/// final resolver = MediaResolverService.instance.resolver;
/// if (resolver != null) {
///   final thumbnail = await resolver.loadThumbnail(sha256);
/// }
/// ```
class MediaResolverService {
  static MediaResolverService? _instance;
  static MediaResolverService get instance => _instance ??= MediaResolverService._();

  MediaResolverService._();

  MediaResolver? _resolver;
  String? _currentJournalPath;
  List<String> _currentMediaPackPaths = [];

  /// Initialize the media resolver with journal and media pack paths
  Future<void> initialize({
    required String journalPath,
    required List<String> mediaPackPaths,
  }) async {
    _currentJournalPath = journalPath;
    _currentMediaPackPaths = List.from(mediaPackPaths);

    _resolver = MediaResolver(
      journalPath: journalPath,
      mediaPackPaths: mediaPackPaths,
    );

    // Build cache for fast lookups
    await _resolver!.buildCache();

    print('📦 MediaResolverService initialized');
    print('   Journal: $journalPath');
    print('   Media packs: ${mediaPackPaths.length}');
    print('   Cache: ${_resolver!.cacheStats}');
  }

  /// Get the current resolver instance
  MediaResolver? get resolver => _resolver;

  /// Check if the service is initialized
  bool get isInitialized => _resolver != null;

  /// Mount a new media pack
  Future<void> mountPack(String packPath) async {
    if (_resolver == null) {
      throw Exception('MediaResolverService not initialized');
    }

    if (_currentMediaPackPaths.contains(packPath)) {
      print('⚠️ Media pack already mounted: $packPath');
      return;
    }

    // Verify pack exists
    final file = File(packPath);
    if (!await file.exists()) {
      throw Exception('Media pack not found: $packPath');
    }

    // Add to resolver
    _resolver!.addMediaPack(packPath);
    _currentMediaPackPaths.add(packPath);

    // Register pack metadata if not already registered
    await _registerPackMetadata(packPath);

    // Rebuild cache
    await _resolver!.buildCache();

    print('✅ Mounted media pack: $packPath');
    print('   Cache: ${_resolver!.cacheStats}');
  }

  /// Unmount a media pack
  Future<void> unmountPack(String packPath) async {
    if (_resolver == null) {
      throw Exception('MediaResolverService not initialized');
    }

    if (!_currentMediaPackPaths.contains(packPath)) {
      print('⚠️ Media pack not mounted: $packPath');
      return;
    }

    // Remove from resolver
    _resolver!.removeMediaPack(packPath);
    _currentMediaPackPaths.remove(packPath);

    // Rebuild cache
    await _resolver!.buildCache();

    print('🗑️ Unmounted media pack: $packPath');
    print('   Cache: ${_resolver!.cacheStats}');
  }

  /// Get list of currently mounted media packs
  List<String> get mountedPacks => List.unmodifiable(_currentMediaPackPaths);

  /// Get current journal path
  String? get journalPath => _currentJournalPath;

  /// Update journal path (e.g., after import/export)
  Future<void> updateJournalPath(String newJournalPath) async {
    if (_resolver == null) {
      throw Exception('MediaResolverService not initialized');
    }

    // Verify journal exists
    final file = File(newJournalPath);
    if (!await file.exists()) {
      throw Exception('Journal not found: $newJournalPath');
    }

    // Reinitialize with new journal path
    await initialize(
      journalPath: newJournalPath,
      mediaPackPaths: _currentMediaPackPaths,
    );

    print('🔄 Updated journal path: $newJournalPath');
  }

  /// Get resolver statistics
  Map<String, dynamic> get stats {
    if (_resolver == null) {
      return {
        'initialized': false,
        'journalPath': null,
        'mountedPacks': 0,
        'cachedShas': 0,
      };
    }

    final cacheStats = _resolver!.cacheStats;
    final trackingStats = MediaPackTrackingService.instance.getStorageStats();
    
    return {
      'initialized': true,
      'journalPath': _currentJournalPath,
      'mountedPacks': _currentMediaPackPaths.length,
      'cachedShas': cacheStats['cachedShas'] ?? 0,
      'availablePacks': cacheStats['availablePacks'] ?? 0,
      'trackingStats': trackingStats,
    };
  }

  /// Register pack metadata with tracking service
  Future<void> _registerPackMetadata(String packPath) async {
    try {
      // Extract pack ID from filename
      final fileName = packPath.split('/').last;
      final packId = fileName.replaceAll('.zip', '');
      
      // Check if already registered
      final existingPack = MediaPackTrackingService.instance.getPackMetadata(packId);
      if (existingPack != null) {
        print('📦 Pack already registered: $packId');
        return;
      }
      
      // Get file stats
      final file = File(packPath);
      final fileStat = await file.stat();
      final fileSize = fileStat.size;
      
      // Create basic metadata (we'll need to read the actual pack for more details)
      final packMetadata = MediaPackMetadata(
        packId: packId,
        createdAt: fileStat.modified,
        fileCount: 0, // Will be updated when pack is read
        totalSizeBytes: fileSize,
        dateFrom: fileStat.modified,
        dateTo: fileStat.modified,
        status: MediaPackStatus.active,
        storagePath: packPath,
        description: 'Media pack mounted from $packPath',
      );
      
      await MediaPackTrackingService.instance.registerPack(packMetadata);
    } catch (e) {
      print('⚠️ Error registering pack metadata for $packPath: $e');
    }
  }

  /// Reset the service (useful for testing or logout)
  void reset() {
    _resolver = null;
    _currentJournalPath = null;
    _currentMediaPackPaths.clear();
    print('🔄 MediaResolverService reset');
  }

  /// Auto-discover and mount media packs in a directory
  Future<int> autoDiscoverPacks(String directory) async {
    if (_resolver == null) {
      throw Exception('MediaResolverService not initialized');
    }

    final dir = Directory(directory);
    if (!await dir.exists()) {
      throw Exception('Directory not found: $directory');
    }

    int mountedCount = 0;

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.zip')) {
        final fileName = entity.path.split('/').last;

        // Check if it looks like a media pack (mcp_media_*.zip)
        if (fileName.startsWith('mcp_media_') || fileName.contains('media_pack')) {
          try {
            await mountPack(entity.path);
            mountedCount++;
          } catch (e) {
            print('⚠️ Failed to mount $fileName: $e');
          }
        }
      }
    }

    print('🔍 Auto-discovered $mountedCount media pack(s) in $directory');
    return mountedCount;
  }

  /// Validate all mounted packs are accessible
  Future<Map<String, bool>> validatePacks() async {
    final results = <String, bool>{};

    for (final packPath in _currentMediaPackPaths) {
      final file = File(packPath);
      results[packPath] = await file.exists();
    }

    final failedCount = results.values.where((exists) => !exists).length;
    if (failedCount > 0) {
      print('⚠️ $failedCount media pack(s) not accessible');
    }

    return results;
  }
}
