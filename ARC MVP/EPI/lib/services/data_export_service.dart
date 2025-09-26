import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/services/arcform_service.dart';

class DataExportService {
  static Future<void> exportAllData({
    required JournalRepository journalRepository,
    required Function(String) onProgress,
    required Function(String) onError,
    required Function(String) onSuccess,
  }) async {
    try {
      onProgress('Preparing data for export...');
      
      // Get all journal entries
      final entries = journalRepository.getAllJournalEntries();
      onProgress('Found ${entries.length} journal entries');
      
      // Get all arcform snapshots
      final arcformService = ArcformService();
      final snapshots = await arcformService.getAllSnapshots();
      onProgress('Found ${snapshots.length} arcform snapshots');
      
      // Create export data structure
      final exportData = {
        'export_info': {
          'timestamp': DateTime.now().toIso8601String(),
          'version': '1.0',
          'app_name': 'EPI ARC MVP',
        },
        'journal_entries': entries.map((entry) => entry.toJson()).toList(),
        'arcform_snapshots': snapshots.map((snapshot) => snapshot.toJson()).toList(),
        'summary': {
          'total_entries': entries.length,
          'total_snapshots': snapshots.length,
          'date_range': {
            'earliest': entries.isNotEmpty 
                ? entries.map((e) => e.createdAt).reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String()
                : null,
            'latest': entries.isNotEmpty 
                ? entries.map((e) => e.createdAt).reduce((a, b) => a.isAfter(b) ? a : b).toIso8601String()
                : null,
          },
        },
      };
      
      onProgress('Generating JSON file...');
      
      // Convert to JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      
      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'epi_data_export_$timestamp.json';
      final file = File('${tempDir.path}/$fileName');
      
      await file.writeAsString(jsonString);
      onProgress('File saved: $fileName');
      
      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'EPI Data Export - ${entries.length} entries, ${snapshots.length} snapshots',
        subject: 'EPI Data Export',
      );
      
      onSuccess('Data exported successfully!');
      
    } catch (e) {
      onError('Export failed: $e');
    }
  }
  
  static Future<Map<String, dynamic>> getStorageInfo({
    required JournalRepository journalRepository,
  }) async {
    try {
      final entries = journalRepository.getAllJournalEntries();
      final arcformService = ArcformService();
      final snapshots = await arcformService.getAllSnapshots();
      
      // Calculate storage usage (rough estimate)
      final entriesSize = entries.length * 500; // ~500 bytes per entry
      final snapshotsSize = snapshots.length * 200; // ~200 bytes per snapshot
      final totalSizeBytes = entriesSize + snapshotsSize;
      
      return {
        'total_entries': entries.length,
        'total_snapshots': snapshots.length,
        'estimated_size_bytes': totalSizeBytes,
        'estimated_size_mb': (totalSizeBytes / (1024 * 1024)).toStringAsFixed(2),
        'date_range': {
          'earliest': entries.isNotEmpty 
              ? entries.map((e) => e.createdAt).reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String()
              : null,
          'latest': entries.isNotEmpty 
              ? entries.map((e) => e.createdAt).reduce((a, b) => a.isAfter(b) ? a : b).toIso8601String()
              : null,
        },
      };
    } catch (e) {
      return {
        'error': 'Failed to get storage info: $e',
        'total_entries': 0,
        'total_snapshots': 0,
        'estimated_size_bytes': 0,
        'estimated_size_mb': '0.00',
      };
    }
  }
}
