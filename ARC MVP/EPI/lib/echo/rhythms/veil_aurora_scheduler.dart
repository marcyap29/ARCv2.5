import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../core/mcp/export/chat_mcp_exporter.dart';
import '../../core/mcp/models/mcp_schemas.dart';

/// VEIL/AURORA rhythm scheduler for nightly tasks
class VeilAuroraScheduler {
  static Timer? _nightlyTimer;
  static bool _isRunning = false;
  
  // Configuration
  static const Duration _nightlyInterval = Duration(hours: 24);
  static const int _archiveRetentionDays = 30;
  static const int _maxCacheSizeMB = 100;

  /// Start the nightly scheduler
  static Future<void> start() async {
    if (_isRunning) return;
    
    _isRunning = true;
    
    // Calculate time until next midnight
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = nextMidnight.difference(now);
    
    // Schedule first run at midnight, then every 24 hours
    _nightlyTimer = Timer.periodic(_nightlyInterval, (_) {
      _runNightlyTasks();
    });
    
    // Run first task after calculated delay
    Timer(timeUntilMidnight, () {
      _runNightlyTasks();
    });
    
    print('VEIL/AURORA Scheduler: Started with first run at ${nextMidnight.toIso8601String()}');
  }

  /// Stop the nightly scheduler
  static void stop() {
    _nightlyTimer?.cancel();
    _nightlyTimer = null;
    _isRunning = false;
    print('VEIL/AURORA Scheduler: Stopped');
  }

  /// Run nightly maintenance tasks
  static Future<void> _runNightlyTasks() async {
    print('VEIL/AURORA Scheduler: Starting nightly tasks at ${DateTime.now().toIso8601String()}');
    
    try {
      // 1. Archive rotation
      await _rotateArchives();
      
      // 2. Cache cleanup
      await _cleanupCaches();
      
      // 3. PRISM integration
      await _integratePrismExtracts();
      
      // 4. RIVET snapshot
      await _createRivetSnapshot();
      
      // 5. Adapter updates (future-proofing)
      await _checkAdapterUpdates();
      
      print('VEIL/AURORA Scheduler: Nightly tasks completed successfully');
    } catch (e) {
      print('VEIL/AURORA Scheduler: Error during nightly tasks - $e');
    }
  }

  /// Rotate chat archives
  static Future<void> _rotateArchives() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final chatDir = Directory(path.join(docsDir.path, 'chat_archives'));
      
      if (!await chatDir.exists()) {
        await chatDir.create(recursive: true);
        return;
      }
      
      // Create monthly archive
      final now = DateTime.now();
      final archiveName = 'mcp_chats_${now.year}-${now.month.toString().padLeft(2, '0')}.jsonl';
      
      // Export current chat data to archive
      final exporter = ChatMcpExporter(
        outputDir: Directory(path.join(chatDir.path, 'temp_export')),
        storageProfile: McpStorageProfile.archival,
        notes: 'Monthly archive for ${now.year}-${now.month}',
      );
      
      // TODO: Get actual chat data from repository
      final result = await exporter.exportChats(
        sessions: [], // Will be populated from actual data
        messages: [], // Will be populated from actual data
        scope: ChatMcpExportScope.all,
      );
      
      if (result.success) {
        print('VEIL/AURORA: Created monthly archive $archiveName');
      }
      
      // Clean up old archives
      await _cleanupOldArchives(chatDir);
      
    } catch (e) {
      print('VEIL/AURORA: Error rotating archives - $e');
    }
  }

  /// Clean up old archives
  static Future<void> _cleanupOldArchives(Directory chatDir) async {
    try {
      final files = await chatDir.list().toList();
      final now = DateTime.now();
      
      for (final file in files) {
        if (file is File && file.path.endsWith('.jsonl')) {
          final stat = await file.stat();
          final age = now.difference(stat.modified);
          
          if (age.inDays > _archiveRetentionDays) {
            await file.delete();
            print('VEIL/AURORA: Deleted old archive ${path.basename(file.path)}');
          }
        }
      }
    } catch (e) {
      print('VEIL/AURORA: Error cleaning up old archives - $e');
    }
  }

  /// Clean up caches
  static Future<void> _cleanupCaches() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(path.join(docsDir.path, 'caches'));
      
      if (!await cacheDir.exists()) return;
      
      // Calculate total cache size
      int totalSizeBytes = 0;
      final files = <File>[];
      
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSizeBytes += stat.size;
          files.add(entity);
        }
      }
      
      final totalSizeMB = totalSizeBytes / (1024 * 1024);
      
      // Track current size for cleanup
      int currentSizeBytes = totalSizeBytes;
      
      if (totalSizeMB > _maxCacheSizeMB) {
        // Sort files by modification time (oldest first)
        // Get stats for all files first to enable proper sorting
        final filesWithStats = <({File file, FileStat stat})>[];
        for (final file in files) {
          final stat = await file.stat();
          filesWithStats.add((file: file, stat: stat));
        }
        
        filesWithStats.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
        
        // Delete oldest files until under limit
        for (final fileStat in filesWithStats) {
          if (currentSizeBytes / (1024 * 1024) <= _maxCacheSizeMB) break;
          
          await fileStat.file.delete();
          currentSizeBytes -= fileStat.stat.size;
          print('VEIL/AURORA: Deleted cache file ${path.basename(fileStat.file.path)}');
        }
        
        print('VEIL/AURORA: Cache cleanup completed. Size: ${(currentSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB');
      } else {
        print('VEIL/AURORA: Cache size within limit. Size: ${totalSizeMB.toStringAsFixed(1)}MB');
      }
      
    } catch (e) {
      print('VEIL/AURORA: Error cleaning up caches - $e');
    }
  }

  /// Integrate PRISM extracts into reflective updates
  static Future<void> _integratePrismExtracts() async {
    try {
      // This would integrate PRISM analysis results into the user's reflective data
      // For now, just log the action
      print('VEIL/AURORA: Integrating PRISM extracts into reflective updates');
      
      // TODO: Implement actual PRISM integration
      // - Process accumulated PRISM summaries
      // - Update user profile with insights
      // - Generate reflective prompts based on patterns
      
    } catch (e) {
      print('VEIL/AURORA: Error integrating PRISM extracts - $e');
    }
  }

  /// Create RIVET snapshot for auditability
  static Future<void> _createRivetSnapshot() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final rivetDir = Directory(path.join(docsDir.path, 'rivet_snapshots'));
      
      if (!await rivetDir.exists()) {
        await rivetDir.create(recursive: true);
      }
      
      // Create snapshot file
      final now = DateTime.now();
      final snapshotName = 'rivet_snapshot_${now.year}-${now.month}-${now.day}.json';
      final snapshotFile = File(path.join(rivetDir.path, snapshotName));
      
      // TODO: Get actual RIVET data and create snapshot
      final snapshot = {
        'timestamp': now.toIso8601String(),
        'alignScore': 0.0, // Will be populated from actual data
        'traceScore': 0.0, // Will be populated from actual data
        'sustainmentCount': 0, // Will be populated from actual data
        'eventCount': 0, // Will be populated from actual data
        'metadata': {
          'version': '1.0',
          'source': 'veil_aurora_scheduler',
        },
      };
      
      await snapshotFile.writeAsString(jsonEncode(snapshot));
      print('VEIL/AURORA: Created RIVET snapshot $snapshotName');
      
    } catch (e) {
      print('VEIL/AURORA: Error creating RIVET snapshot - $e');
    }
  }

  /// Check for adapter updates (future-proofing)
  static Future<void> _checkAdapterUpdates() async {
    try {
      print('VEIL/AURORA: Checking for adapter updates');
      
      // TODO: Implement adapter update checking
      // - Check for new model versions
      // - Update adapter configurations
      // - Download new models if available
      
    } catch (e) {
      print('VEIL/AURORA: Error checking adapter updates - $e');
    }
  }

  /// Force run nightly tasks (for testing)
  static Future<void> forceRun() async {
    print('VEIL/AURORA Scheduler: Force running nightly tasks');
    await _runNightlyTasks();
  }

  /// Get scheduler status
  static Map<String, dynamic> getStatus() {
    return {
      'isRunning': _isRunning,
      'nextRun': _nightlyTimer?.isActive == true ? 'Scheduled' : 'Not scheduled',
      'interval': _nightlyInterval.inHours,
      'retentionDays': _archiveRetentionDays,
      'maxCacheSizeMB': _maxCacheSizeMB,
    };
  }
}
