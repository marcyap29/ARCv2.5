import 'package:equatable/equatable.dart';

/// Status of a media pack
enum MediaPackStatus {
  active,
  archived,
  deleted,
}

/// Metadata for a media pack containing full-resolution photos
class MediaPackMetadata extends Equatable {
  final String packId;
  final DateTime createdAt;
  final int fileCount;
  final int totalSizeBytes;
  final DateTime dateFrom;
  final DateTime dateTo;
  final MediaPackStatus status;
  final String storagePath;
  final String? description;

  const MediaPackMetadata({
    required this.packId,
    required this.createdAt,
    required this.fileCount,
    required this.totalSizeBytes,
    required this.dateFrom,
    required this.dateTo,
    required this.status,
    required this.storagePath,
    this.description,
  });

  factory MediaPackMetadata.fromJson(Map<String, dynamic> json) {
    return MediaPackMetadata(
      packId: json['packId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      fileCount: json['fileCount'] as int,
      totalSizeBytes: json['totalSizeBytes'] as int,
      dateFrom: DateTime.parse(json['dateFrom'] as String),
      dateTo: DateTime.parse(json['dateTo'] as String),
      status: MediaPackStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MediaPackStatus.active,
      ),
      storagePath: json['storagePath'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'packId': packId,
      'createdAt': createdAt.toIso8601String(),
      'fileCount': fileCount,
      'totalSizeBytes': totalSizeBytes,
      'dateFrom': dateFrom.toIso8601String(),
      'dateTo': dateTo.toIso8601String(),
      'status': status.name,
      'storagePath': storagePath,
      'description': description,
    };
  }

  /// Get human-readable size (e.g., "15.2 MB")
  String get formattedSize {
    if (totalSizeBytes < 1024) {
      return '$totalSizeBytes B';
    } else if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else if (totalSizeBytes < 1024 * 1024 * 1024) {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Get human-readable date range (e.g., "Jan 15 - Jan 19, 2025")
  String get formattedDateRange {
    final fromMonth = _getMonthName(dateFrom.month);
    final toMonth = _getMonthName(dateTo.month);
    final year = dateFrom.year;
    
    if (dateFrom.month == dateTo.month && dateFrom.year == dateTo.year) {
      return '$fromMonth ${dateFrom.day}-${dateTo.day}, $year';
    } else if (dateFrom.year == dateTo.year) {
      return '$fromMonth ${dateFrom.day} - $toMonth ${dateTo.day}, $year';
    } else {
      return '$fromMonth ${dateFrom.day}, ${dateFrom.year} - $toMonth ${dateTo.day}, ${dateTo.year}';
    }
  }

  /// Get human-readable creation date (e.g., "Jan 19, 2025")
  String get formattedCreatedAt {
    final month = _getMonthName(createdAt.month);
    return '$month ${createdAt.day}, ${createdAt.year}';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  /// Check if pack is older than specified months
  bool isOlderThan(int months) {
    final cutoffDate = DateTime.now().subtract(Duration(days: months * 30));
    return createdAt.isBefore(cutoffDate);
  }

  /// Create a copy with updated status
  MediaPackMetadata copyWith({
    String? packId,
    DateTime? createdAt,
    int? fileCount,
    int? totalSizeBytes,
    DateTime? dateFrom,
    DateTime? dateTo,
    MediaPackStatus? status,
    String? storagePath,
    String? description,
  }) {
    return MediaPackMetadata(
      packId: packId ?? this.packId,
      createdAt: createdAt ?? this.createdAt,
      fileCount: fileCount ?? this.fileCount,
      totalSizeBytes: totalSizeBytes ?? this.totalSizeBytes,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      status: status ?? this.status,
      storagePath: storagePath ?? this.storagePath,
      description: description ?? this.description,
    );
  }

  @override
  List<Object?> get props => [
        packId,
        createdAt,
        fileCount,
        totalSizeBytes,
        dateFrom,
        dateTo,
        status,
        storagePath,
        description,
      ];
}

/// Registry for managing collection of media packs
class MediaPackRegistry extends Equatable {
  final Map<String, MediaPackMetadata> _packs;
  final DateTime lastUpdated;

  const MediaPackRegistry({
    Map<String, MediaPackMetadata>? packs,
    required this.lastUpdated,
  }) : _packs = packs ?? const {};

  factory MediaPackRegistry.fromJson(Map<String, dynamic> json) {
    final packsMap = <String, MediaPackMetadata>{};
    final packsJson = json['packs'] as Map<String, dynamic>? ?? {};
    
    for (final entry in packsJson.entries) {
      packsMap[entry.key] = MediaPackMetadata.fromJson(entry.value as Map<String, dynamic>);
    }

    return MediaPackRegistry(
      packs: packsMap,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'packs': _packs.map((key, value) => MapEntry(key, value.toJson())),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Get all packs
  List<MediaPackMetadata> get allPacks => _packs.values.toList();

  /// Get packs by status
  List<MediaPackMetadata> getPacksByStatus(MediaPackStatus status) {
    return _packs.values.where((pack) => pack.status == status).toList();
  }

  /// Get active packs
  List<MediaPackMetadata> get activePacks => getPacksByStatus(MediaPackStatus.active);

  /// Get archived packs
  List<MediaPackMetadata> get archivedPacks => getPacksByStatus(MediaPackStatus.archived);

  /// Get deleted packs
  List<MediaPackMetadata> get deletedPacks => getPacksByStatus(MediaPackStatus.deleted);

  /// Get pack by ID
  MediaPackMetadata? getPack(String packId) => _packs[packId];

  /// Add or update pack
  MediaPackRegistry addPack(MediaPackMetadata pack) {
    final newPacks = Map<String, MediaPackMetadata>.from(_packs);
    newPacks[pack.packId] = pack;
    
    return MediaPackRegistry(
      packs: newPacks,
      lastUpdated: DateTime.now(),
    );
  }

  /// Remove pack
  MediaPackRegistry removePack(String packId) {
    final newPacks = Map<String, MediaPackMetadata>.from(_packs);
    newPacks.remove(packId);
    
    return MediaPackRegistry(
      packs: newPacks,
      lastUpdated: DateTime.now(),
    );
  }

  /// Update pack status
  MediaPackRegistry updatePackStatus(String packId, MediaPackStatus status) {
    final pack = _packs[packId];
    if (pack == null) return this;
    
    return addPack(pack.copyWith(status: status));
  }

  /// Get total storage usage
  int get totalStorageBytes {
    return _packs.values.fold(0, (sum, pack) => sum + pack.totalSizeBytes);
  }

  /// Get total file count
  int get totalFileCount {
    return _packs.values.fold(0, (sum, pack) => sum + pack.fileCount);
  }

  /// Get packs older than specified months
  List<MediaPackMetadata> getPacksOlderThan(int months) {
    return _packs.values.where((pack) => pack.isOlderThan(months)).toList();
  }

  /// Get packs by month (for timeline view)
  Map<String, List<MediaPackMetadata>> getPacksByMonth() {
    final monthGroups = <String, List<MediaPackMetadata>>{};
    
    for (final pack in _packs.values) {
      final monthKey = '${pack.createdAt.year}-${pack.createdAt.month.toString().padLeft(2, '0')}';
      monthGroups.putIfAbsent(monthKey, () => []).add(pack);
    }
    
    // Sort packs within each month by creation date
    for (final packs in monthGroups.values) {
      packs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    
    return monthGroups;
  }

  @override
  List<Object?> get props => [_packs, lastUpdated];
}
