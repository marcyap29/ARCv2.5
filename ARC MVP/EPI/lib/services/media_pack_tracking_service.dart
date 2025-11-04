import 'package:hive/hive.dart';
import 'package:my_app/polymeta/store/mcp/models/media_pack_metadata.dart';

/// Service for tracking and managing media pack metadata
class MediaPackTrackingService {
  static MediaPackTrackingService? _instance;
  static MediaPackTrackingService get instance => _instance ??= MediaPackTrackingService._();
  
  MediaPackTrackingService._();

  static const String _boxName = 'media_pack_registry';
  Box<Map>? _box;
  MediaPackRegistry? _registry;

  /// Initialize the tracking service
  Future<void> initialize() async {
    try {
      _box = await Hive.openBox<Map>(_boxName);
      await _loadRegistry();
      print('✅ MediaPackTrackingService initialized');
    } catch (e) {
      print('❌ Error initializing MediaPackTrackingService: $e');
      _registry = MediaPackRegistry(lastUpdated: DateTime.now());
    }
  }

  /// Load registry from Hive storage
  Future<void> _loadRegistry() async {
    if (_box == null) return;
    
    final registryData = _box!.get('registry');
    if (registryData != null) {
      _registry = MediaPackRegistry.fromJson(Map<String, dynamic>.from(registryData));
    } else {
      _registry = MediaPackRegistry(lastUpdated: DateTime.now());
    }
  }

  /// Save registry to Hive storage
  Future<void> _saveRegistry() async {
    if (_box == null || _registry == null) return;
    
    await _box!.put('registry', _registry!.toJson());
  }

  /// Register a new media pack
  Future<void> registerPack(MediaPackMetadata pack) async {
    if (_registry == null) {
      await initialize();
    }
    
    _registry = _registry!.addPack(pack);
    await _saveRegistry();
    
    print('📦 Registered pack: ${pack.packId} (${pack.fileCount} files, ${pack.formattedSize})');
  }

  /// Get pack metadata by ID
  MediaPackMetadata? getPackMetadata(String packId) {
    return _registry?.getPack(packId);
  }

  /// Get all packs
  List<MediaPackMetadata> getAllPacks() {
    return _registry?.allPacks ?? [];
  }

  /// Get packs by status
  List<MediaPackMetadata> getPacksByStatus(MediaPackStatus status) {
    return _registry?.getPacksByStatus(status) ?? [];
  }

  /// Get active packs
  List<MediaPackMetadata> get activePacks => getPacksByStatus(MediaPackStatus.active);

  /// Get archived packs
  List<MediaPackMetadata> get archivedPacks => getPacksByStatus(MediaPackStatus.archived);

  /// Get deleted packs
  List<MediaPackMetadata> get deletedPacks => getPacksByStatus(MediaPackStatus.deleted);

  /// Archive a specific pack
  Future<void> archivePack(String packId) async {
    if (_registry == null) return;
    
    final pack = _registry!.getPack(packId);
    if (pack == null) {
      print('⚠️ Pack not found: $packId');
      return;
    }
    
    _registry = _registry!.updatePackStatus(packId, MediaPackStatus.archived);
    await _saveRegistry();
    
    print('📦 Archived pack: $packId');
  }

  /// Unarchive a pack
  Future<void> unarchivePack(String packId) async {
    if (_registry == null) return;
    
    final pack = _registry!.getPack(packId);
    if (pack == null) {
      print('⚠️ Pack not found: $packId');
      return;
    }
    
    _registry = _registry!.updatePackStatus(packId, MediaPackStatus.active);
    await _saveRegistry();
    
    print('📦 Unarchived pack: $packId');
  }

  /// Delete a pack (mark as deleted)
  Future<void> deletePack(String packId) async {
    if (_registry == null) return;
    
    final pack = _registry!.getPack(packId);
    if (pack == null) {
      print('⚠️ Pack not found: $packId');
      return;
    }
    
    _registry = _registry!.updatePackStatus(packId, MediaPackStatus.deleted);
    await _saveRegistry();
    
    print('🗑️ Deleted pack: $packId');
  }

  /// Permanently remove a pack from registry
  Future<void> removePack(String packId) async {
    if (_registry == null) return;
    
    _registry = _registry!.removePack(packId);
    await _saveRegistry();
    
    print('🗑️ Removed pack from registry: $packId');
  }

  /// Auto-archive packs older than specified months
  Future<List<MediaPackMetadata>> autoArchiveOldPacks(int ageThresholdMonths) async {
    if (_registry == null) return [];
    
    final oldPacks = _registry!.getPacksOlderThan(Duration(days: ageThresholdMonths * 30))
        .where((pack) => pack.status == MediaPackStatus.active)
        .toList();
    
    if (oldPacks.isEmpty) {
      print('📦 No packs to archive');
      return [];
    }
    
    print('📦 Auto-archiving ${oldPacks.length} packs older than $ageThresholdMonths months');
    
    for (final pack in oldPacks) {
      _registry = _registry!.updatePackStatus(pack.packId, MediaPackStatus.archived);
    }
    
    await _saveRegistry();
    
    print('✅ Auto-archived ${oldPacks.length} packs');
    return oldPacks;
  }

  /// Get storage statistics
  Map<String, dynamic> getStorageStats() {
    if (_registry == null) return {};
    
    final activePacks = _registry!.activePacks;
    final archivedPacks = _registry!.archivedPacks;
    
    final activeStorage = activePacks.fold(0, (sum, pack) => sum + pack.totalSizeBytes);
    final archivedStorage = archivedPacks.fold(0, (sum, pack) => sum + pack.totalSizeBytes);
    final totalStorage = activeStorage + archivedStorage;
    
    final activeFileCount = activePacks.fold(0, (sum, pack) => sum + pack.fileCount);
    final archivedFileCount = archivedPacks.fold(0, (sum, pack) => sum + pack.fileCount);
    final totalFileCount = activeFileCount + archivedFileCount;
    
    return {
      'totalPacks': _registry!.allPacks.length,
      'activePacks': activePacks.length,
      'archivedPacks': archivedPacks.length,
      'deletedPacks': _registry!.deletedPacks.length,
      'totalStorageBytes': totalStorage,
      'activeStorageBytes': activeStorage,
      'archivedStorageBytes': archivedStorage,
      'totalFileCount': totalFileCount,
      'activeFileCount': activeFileCount,
      'archivedFileCount': archivedFileCount,
    };
  }

  /// Get packs grouped by month for timeline view
  Map<String, List<MediaPackMetadata>> getPacksByMonth() {
    return _registry?.getPacksByMonth() ?? {};
  }

  /// Get packs for a specific month
  List<MediaPackMetadata> getPacksForMonth(int year, int month) {
    final monthKey = '$year-${month.toString().padLeft(2, '0')}';
    return getPacksByMonth()[monthKey] ?? [];
  }

  /// Check if service is initialized
  bool get isInitialized => _registry != null;

  /// Get registry last updated time
  DateTime? get lastUpdated => _registry?.lastUpdated;

  /// Clean up resources
  Future<void> dispose() async {
    await _box?.close();
    _box = null;
    _registry = null;
  }
}
