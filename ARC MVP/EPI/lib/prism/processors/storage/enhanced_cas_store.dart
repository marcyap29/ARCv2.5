import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../crypto/hash_utils.dart';

/// Enhanced CAS store with backup exclusion and retention policies
class EnhancedCASStore {
  static const String _casDirectoryName = 'cas';
  static const String _metadataFileName = '.cas_metadata.json';
  
  /// Get the CAS root directory (excluded from backups)
  static Future<Directory> get _casDirectory async {
    Directory casDir;
    
    if (Platform.isIOS) {
      // Use Library/Caches directory which is excluded from backups
      final appDir = await getLibraryDirectory();
      casDir = Directory(path.join(appDir.path, 'Caches', _casDirectoryName));
    } else if (Platform.isAndroid) {
      // Use cache directory or no_backup subdirectory
      final cacheDir = await getTemporaryDirectory();
      casDir = Directory(path.join(cacheDir.path, 'no_backup', _casDirectoryName));
    } else {
      // Fallback for other platforms
      final appDir = await getApplicationSupportDirectory();
      casDir = Directory(path.join(appDir.path, _casDirectoryName));
    }
    
    if (!await casDir.exists()) {
      await casDir.create(recursive: true);
      await _excludeFromBackup(casDir);
    }
    
    return casDir;
  }

  /// Store content in CAS with metadata tracking
  static Future<String> store(String type, String size, Uint8List data) async {
    final hash = HashUtils.sha256Hash(data);
    final uri = CASStore.generateCASUri(type, size, hash);
    final file = await _getFileForCASUri(uri);
    
    // Only write if file doesn't exist (content-addressed deduplication)
    if (!await file.exists()) {
      await file.writeAsBytes(data);
      await _excludeFromBackup(file);
      await _updateMetadata(uri, data.length);
    } else {
      // Update last accessed time for retention
      await _updateLastAccessed(uri);
    }
    
    return uri;
  }

  /// Store content with streaming for large files
  static Future<String> storeStream(
    String type, 
    String size, 
    Stream<List<int>> dataStream,
  ) async {
    final chunks = <List<int>>[];
    await for (final chunk in dataStream) {
      chunks.add(chunk);
    }
    
    final data = Uint8List.fromList(chunks.expand((chunk) => chunk).toList());
    return await store(type, size, data);
  }

  /// Retrieve content from CAS
  static Future<Uint8List?> retrieve(String uri) async {
    try {
      final file = await _getFileForCASUri(uri);
      
      if (!await file.exists()) {
        return null;
      }
      
      await _updateLastAccessed(uri);
      return await file.readAsBytes();
    } catch (e) {
      print('EnhancedCASStore: Error retrieving $uri: $e');
      return null;
    }
  }

  /// Get file for CAS URI
  static Future<File> _getFileForCASUri(String uri) async {
    final components = CASStore.parseCASUri(uri);
    if (components == null) {
      throw ArgumentError('Invalid CAS URI: $uri');
    }
    
    final casDir = await _casDirectory;
    final typePath = path.join(casDir.path, components.type);
    final sizePath = path.join(typePath, components.size);
    
    // Ensure directories exist
    await Directory(sizePath).create(recursive: true);
    
    final filePath = path.join(sizePath, components.hash);
    return File(filePath);
  }

  /// Update metadata for a CAS entry
  static Future<void> _updateMetadata(String uri, int sizeBytes) async {
    final metadata = CASEntryMetadata(
      uri: uri,
      sizeBytes: sizeBytes,
      createdAt: DateTime.now(),
      lastAccessed: DateTime.now(),
      accessCount: 1,
    );
    
    await _saveMetadata(metadata);
  }

  /// Update last accessed time
  static Future<void> _updateLastAccessed(String uri) async {
    final metadata = await _loadMetadata(uri);
    if (metadata != null) {
      final updatedMetadata = metadata.copyWith(
        lastAccessed: DateTime.now(),
        accessCount: metadata.accessCount + 1,
      );
      await _saveMetadata(updatedMetadata);
    }
  }

  /// Save metadata for a CAS entry
  static Future<void> _saveMetadata(CASEntryMetadata metadata) async {
    try {
      final casDir = await _casDirectory;
      final components = CASStore.parseCASUri(metadata.uri);
      if (components == null) return;
      
      final metadataDir = Directory(path.join(
        casDir.path, 
        components.type, 
        components.size,
        '.metadata',
      ));
      
      if (!await metadataDir.exists()) {
        await metadataDir.create(recursive: true);
      }
      
      final metadataFile = File(path.join(metadataDir.path, '${components.hash}.json'));
      await metadataFile.writeAsString(metadata.toJson());
    } catch (e) {
      print('EnhancedCASStore: Error saving metadata: $e');
    }
  }

  /// Load metadata for a CAS entry
  static Future<CASEntryMetadata?> _loadMetadata(String uri) async {
    try {
      final casDir = await _casDirectory;
      final components = CASStore.parseCASUri(uri);
      if (components == null) return null;
      
      final metadataFile = File(path.join(
        casDir.path,
        components.type,
        components.size,
        '.metadata',
        '${components.hash}.json',
      ));
      
      if (!await metadataFile.exists()) return null;
      
      final jsonString = await metadataFile.readAsString();
      return CASEntryMetadata.fromJson(jsonString);
    } catch (e) {
      return null;
    }
  }

  /// Exclude file or directory from backups (platform-specific)
  static Future<void> _excludeFromBackup(FileSystemEntity entity) async {
    if (Platform.isIOS) {
      await _excludeFromBackupIOS(entity);
    } else if (Platform.isAndroid) {
      // Android: Files in cache directories are automatically excluded
      // For additional control, we could use the .nomedia file
      if (entity is Directory) {
        final nomediaFile = File(path.join(entity.path, '.nomedia'));
        if (!await nomediaFile.exists()) {
          await nomediaFile.create();
        }
      }
    }
  }

  /// iOS-specific backup exclusion
  static Future<void> _excludeFromBackupIOS(FileSystemEntity entity) async {
    // This would require native iOS code to set NSURLIsExcludedFromBackupKey
    // For now, we rely on using the correct directory (Caches)
    print('iOS: Excluding ${entity.path} from backup (via Caches directory)');
  }

  /// Run retention policy based on device state and storage profile
  static Future<RetentionResult> runRetentionPolicy({
    required RetentionPolicy policy,
    bool deviceIdle = false,
    bool deviceCharging = false,
    bool forceRun = false,
  }) async {
    if (!forceRun && (!deviceIdle || !deviceCharging)) {
      return const RetentionResult(
        filesProcessed: 0,
        bytesFreed: 0,
        errors: ['Skipped: device not idle or charging'],
      );
    }

    print('EnhancedCASStore: Running retention policy: ${policy.name}');
    
    final casDir = await _casDirectory;
    final allMetadata = await _getAllMetadata();
    final cutoffDate = DateTime.now().subtract(Duration(days: policy.retentionDays));
    
    int filesProcessed = 0;
    int bytesFreed = 0;
    final errors = <String>[];
    
    for (final metadata in allMetadata) {
      try {
        final shouldDelete = _shouldDeleteEntry(metadata, cutoffDate, policy);
        
        if (shouldDelete) {
          final file = await _getFileForCASUri(metadata.uri);
          if (await file.exists()) {
            final size = await file.length();
            await file.delete();
            await _deleteMetadata(metadata.uri);
            
            filesProcessed++;
            bytesFreed += size;
            
            if (filesProcessed % 100 == 0) {
              print('EnhancedCASStore: Processed $filesProcessed files...');
            }
          }
        }
      } catch (e) {
        errors.add('Error processing ${metadata.uri}: $e');
      }
    }
    
    print('EnhancedCASStore: Retention complete - $filesProcessed files deleted, ${(bytesFreed / 1024 / 1024).toStringAsFixed(1)} MB freed');
    
    return RetentionResult(
      filesProcessed: filesProcessed,
      bytesFreed: bytesFreed,
      errors: errors,
    );
  }

  /// Check if entry should be deleted based on retention policy
  static bool _shouldDeleteEntry(
    CASEntryMetadata metadata,
    DateTime cutoffDate,
    RetentionPolicy policy,
  ) {
    // Don't delete if accessed recently
    if (metadata.lastAccessed.isAfter(cutoffDate)) {
      return false;
    }
    
    // Apply policy-specific rules
    switch (policy.strategy) {
      case RetentionStrategy.lru:
        // Least recently used - already handled by cutoff date
        return true;
      
      case RetentionStrategy.lfu:
        // Least frequently used - delete if access count is low
        return metadata.accessCount < policy.minAccessCount;
      
      case RetentionStrategy.size:
        // Delete large files first if over size threshold
        return metadata.sizeBytes > policy.maxSizeBytes;
      
      case RetentionStrategy.age:
        // Delete by age regardless of access
        return metadata.createdAt.isBefore(cutoffDate);
    }
  }

  /// Get all metadata entries
  static Future<List<CASEntryMetadata>> _getAllMetadata() async {
    final metadata = <CASEntryMetadata>[];
    final casDir = await _casDirectory;
    
    try {
      await for (final entity in casDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final jsonString = await entity.readAsString();
            final entry = CASEntryMetadata.fromJson(jsonString);
            metadata.add(entry);
          } catch (e) {
            print('EnhancedCASStore: Error loading metadata from ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      print('EnhancedCASStore: Error scanning metadata: $e');
    }
    
    return metadata;
  }

  /// Delete metadata for a CAS entry
  static Future<void> _deleteMetadata(String uri) async {
    try {
      final casDir = await _casDirectory;
      final components = CASStore.parseCASUri(uri);
      if (components == null) return;
      
      final metadataFile = File(path.join(
        casDir.path,
        components.type,
        components.size,
        '.metadata',
        '${components.hash}.json',
      ));
      
      if (await metadataFile.exists()) {
        await metadataFile.delete();
      }
    } catch (e) {
      print('EnhancedCASStore: Error deleting metadata: $e');
    }
  }

  /// Get storage statistics
  static Future<CASStorageStats> getStorageStats() async {
    final allMetadata = await _getAllMetadata();
    
    int totalFiles = allMetadata.length;
    int totalBytes = allMetadata.fold<int>(0, (sum, m) => sum + m.sizeBytes);
    int totalAccesses = allMetadata.fold<int>(0, (sum, m) => sum + m.accessCount);
    
    final typeBreakdown = <String, int>{};
    for (final metadata in allMetadata) {
      final components = CASStore.parseCASUri(metadata.uri);
      if (components != null) {
        typeBreakdown[components.type] = (typeBreakdown[components.type] ?? 0) + metadata.sizeBytes;
      }
    }
    
    return CASStorageStats(
      totalFiles: totalFiles,
      totalBytes: totalBytes,
      totalAccesses: totalAccesses,
      typeBreakdown: typeBreakdown,
      oldestEntry: allMetadata.isEmpty ? null : 
          allMetadata.map((m) => m.createdAt).reduce((a, b) => a.isBefore(b) ? a : b),
      newestEntry: allMetadata.isEmpty ? null :
          allMetadata.map((m) => m.createdAt).reduce((a, b) => a.isAfter(b) ? a : b),
    );
  }
}

/// Metadata for a CAS entry
class CASEntryMetadata {
  final String uri;
  final int sizeBytes;
  final DateTime createdAt;
  final DateTime lastAccessed;
  final int accessCount;

  const CASEntryMetadata({
    required this.uri,
    required this.sizeBytes,
    required this.createdAt,
    required this.lastAccessed,
    required this.accessCount,
  });

  CASEntryMetadata copyWith({
    String? uri,
    int? sizeBytes,
    DateTime? createdAt,
    DateTime? lastAccessed,
    int? accessCount,
  }) {
    return CASEntryMetadata(
      uri: uri ?? this.uri,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      accessCount: accessCount ?? this.accessCount,
    );
  }

  String toJson() {
    return '''
{
  "uri": "$uri",
  "sizeBytes": $sizeBytes,
  "createdAt": "${createdAt.toIso8601String()}",
  "lastAccessed": "${lastAccessed.toIso8601String()}",
  "accessCount": $accessCount
}''';
  }

  factory CASEntryMetadata.fromJson(String jsonString) {
    final jsonMap = <String, dynamic>{};
    // Simple JSON parsing - in production would use proper JSON decoder
    final lines = jsonString.split('\n');
    for (final line in lines) {
      if (line.contains(':')) {
        final parts = line.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim().replaceAll('"', '').replaceAll('{', '').replaceAll(',', '');
          final value = parts.sublist(1).join(':').trim().replaceAll('"', '').replaceAll(',', '').replaceAll('}', '');
          jsonMap[key] = value;
        }
      }
    }
    
    return CASEntryMetadata(
      uri: jsonMap['uri'] ?? '',
      sizeBytes: int.tryParse(jsonMap['sizeBytes'] ?? '0') ?? 0,
      createdAt: DateTime.tryParse(jsonMap['createdAt'] ?? '') ?? DateTime.now(),
      lastAccessed: DateTime.tryParse(jsonMap['lastAccessed'] ?? '') ?? DateTime.now(),
      accessCount: int.tryParse(jsonMap['accessCount'] ?? '0') ?? 0,
    );
  }
}

/// Retention policy configuration
class RetentionPolicy {
  final String name;
  final int retentionDays;
  final RetentionStrategy strategy;
  final int minAccessCount;
  final int maxSizeBytes;

  const RetentionPolicy({
    required this.name,
    required this.retentionDays,
    required this.strategy,
    this.minAccessCount = 1,
    this.maxSizeBytes = 100 * 1024 * 1024, // 100MB
  });

  static const RetentionPolicy aggressive = RetentionPolicy(
    name: 'Aggressive',
    retentionDays: 7,
    strategy: RetentionStrategy.lru,
    minAccessCount: 2,
    maxSizeBytes: 50 * 1024 * 1024, // 50MB
  );

  static const RetentionPolicy balanced = RetentionPolicy(
    name: 'Balanced',
    retentionDays: 30,
    strategy: RetentionStrategy.lru,
    minAccessCount: 1,
    maxSizeBytes: 100 * 1024 * 1024, // 100MB
  );

  static const RetentionPolicy conservative = RetentionPolicy(
    name: 'Conservative',
    retentionDays: 90,
    strategy: RetentionStrategy.lfu,
    minAccessCount: 1,
    maxSizeBytes: 500 * 1024 * 1024, // 500MB
  );
}

enum RetentionStrategy {
  lru,  // Least Recently Used
  lfu,  // Least Frequently Used
  size, // Size-based
  age,  // Age-based
}

/// Result of retention policy execution
class RetentionResult {
  final int filesProcessed;
  final int bytesFreed;
  final List<String> errors;

  const RetentionResult({
    required this.filesProcessed,
    required this.bytesFreed,
    required this.errors,
  });

  double get mbFreed => bytesFreed / (1024 * 1024);
}

/// Storage statistics for CAS
class CASStorageStats {
  final int totalFiles;
  final int totalBytes;
  final int totalAccesses;
  final Map<String, int> typeBreakdown;
  final DateTime? oldestEntry;
  final DateTime? newestEntry;

  const CASStorageStats({
    required this.totalFiles,
    required this.totalBytes,
    required this.totalAccesses,
    required this.typeBreakdown,
    this.oldestEntry,
    this.newestEntry,
  });

  double get totalMB => totalBytes / (1024 * 1024);
  double get averageFileSize => totalFiles > 0 ? totalBytes / totalFiles : 0;
}