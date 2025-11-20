/// Media Pack Metadata Models
/// 
/// Models for tracking and managing MCP media pack metadata
library;

/// Status of a media pack
enum MediaPackStatus {
  active,
  archived,
  deleted,
}

/// Metadata for a media pack
class MediaPackMetadata {
  final String packId;
  final String name;
  final String path;
  final int fileCount;
  final int totalSizeBytes;
  final DateTime createdAt;
  final DateTime? lastAccessedAt;
  final MediaPackStatus status;
  final Map<String, dynamic> metadata;

  MediaPackMetadata({
    required this.packId,
    required this.name,
    required this.path,
    required this.fileCount,
    required this.totalSizeBytes,
    required this.createdAt,
    this.lastAccessedAt,
    this.status = MediaPackStatus.active,
    this.metadata = const {},
  });

  String get formattedSize {
    if (totalSizeBytes < 1024) return '${totalSizeBytes}B';
    if (totalSizeBytes < 1024 * 1024) return '${(totalSizeBytes / 1024).toStringAsFixed(1)}KB';
    if (totalSizeBytes < 1024 * 1024 * 1024) return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  Map<String, dynamic> toJson() => {
    'packId': packId,
    'name': name,
    'path': path,
    'fileCount': fileCount,
    'totalSizeBytes': totalSizeBytes,
    'createdAt': createdAt.toIso8601String(),
    'lastAccessedAt': lastAccessedAt?.toIso8601String(),
    'status': status.name,
    'metadata': metadata,
  };

  factory MediaPackMetadata.fromJson(Map<String, dynamic> json) => MediaPackMetadata(
    packId: json['packId'] as String,
    name: json['name'] as String,
    path: json['path'] as String,
    fileCount: json['fileCount'] as int,
    totalSizeBytes: json['totalSizeBytes'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastAccessedAt: json['lastAccessedAt'] != null 
        ? DateTime.parse(json['lastAccessedAt'] as String)
        : null,
    status: MediaPackStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => MediaPackStatus.active,
    ),
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );
}

/// Registry for managing multiple media packs
class MediaPackRegistry {
  final Map<String, MediaPackMetadata> _packs;
  final DateTime lastUpdated;

  MediaPackRegistry({
    Map<String, MediaPackMetadata>? packs,
    required this.lastUpdated,
  }) : _packs = packs ?? {};

  MediaPackRegistry addPack(MediaPackMetadata pack) {
    final newPacks = Map<String, MediaPackMetadata>.from(_packs);
    newPacks[pack.packId] = pack;
    return MediaPackRegistry(
      packs: newPacks,
      lastUpdated: DateTime.now(),
    );
  }

  MediaPackMetadata? getPack(String packId) => _packs[packId];

  List<MediaPackMetadata> get allPacks => _packs.values.toList();

  List<MediaPackMetadata> getPacksByStatus(MediaPackStatus status) {
    return _packs.values.where((pack) => pack.status == status).toList();
  }

  MediaPackRegistry updatePackStatus(String packId, MediaPackStatus status) {
    final pack = _packs[packId];
    if (pack == null) return this;
    
    final updatedPack = MediaPackMetadata(
      packId: pack.packId,
      name: pack.name,
      path: pack.path,
      fileCount: pack.fileCount,
      totalSizeBytes: pack.totalSizeBytes,
      createdAt: pack.createdAt,
      lastAccessedAt: pack.lastAccessedAt,
      status: status,
      metadata: pack.metadata,
    );
    
    return addPack(updatedPack);
  }

  MediaPackRegistry removePack(String packId) {
    final newPacks = Map<String, MediaPackMetadata>.from(_packs);
    newPacks.remove(packId);
    return MediaPackRegistry(
      packs: newPacks,
      lastUpdated: DateTime.now(),
    );
  }
  
  /// Get all active packs
  List<MediaPackMetadata> get activePacks =>
      _packs.values.where((pack) => pack.status == MediaPackStatus.active).toList();
  
  /// Get all archived packs
  List<MediaPackMetadata> get archivedPacks =>
      _packs.values.where((pack) => pack.status == MediaPackStatus.archived).toList();
  
  /// Get all deleted packs
  List<MediaPackMetadata> get deletedPacks =>
      _packs.values.where((pack) => pack.status == MediaPackStatus.deleted).toList();
  
  /// Get packs older than specified duration
  List<MediaPackMetadata> getPacksOlderThan(Duration age) {
    final cutoff = DateTime.now().subtract(age);
    return _packs.values.where((pack) => 
      pack.lastAccessedAt != null && pack.lastAccessedAt!.isBefore(cutoff)
    ).toList();
  }
  
  /// Get packs grouped by month for timeline view
  Map<String, List<MediaPackMetadata>> getPacksByMonth() {
    final grouped = <String, List<MediaPackMetadata>>{};
    
    for (final pack in _packs.values) {
      final year = pack.createdAt.year;
      final month = pack.createdAt.month;
      final monthKey = '$year-${month.toString().padLeft(2, '0')}';
      
      grouped.putIfAbsent(monthKey, () => []).add(pack);
    }
    
    // Sort packs within each month by creation date
    grouped.forEach((key, packs) {
      packs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
    
    return grouped;
  }

  Map<String, dynamic> toJson() => {
    'packs': _packs.map((key, value) => MapEntry(key, value.toJson())),
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory MediaPackRegistry.fromJson(Map<String, dynamic> json) {
    final packs = <String, MediaPackMetadata>{};
    if (json['packs'] != null) {
      final packsMap = json['packs'] as Map<String, dynamic>;
      packsMap.forEach((key, value) {
        packs[key] = MediaPackMetadata.fromJson(value as Map<String, dynamic>);
      });
    }
    
    return MediaPackRegistry(
      packs: packs,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }
}


