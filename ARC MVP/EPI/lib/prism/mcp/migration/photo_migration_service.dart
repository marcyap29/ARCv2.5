import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/platform/photo_bridge.dart';
import 'package:my_app/prism/mcp/export/mcp_media_export_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';

/// Service for migrating existing photo references to content-addressed format
class PhotoMigrationService {
  final JournalRepository _journalRepository;
  final String _outputDir;

  PhotoMigrationService({
    required JournalRepository journalRepository,
    required String outputDir,
  }) : _journalRepository = journalRepository,
       _outputDir = outputDir;

  /// Migrate all journal entries to content-addressed format
  Future<PhotoMigrationResult> migrateAllEntries() async {
    try {
      // Get all journal entries
      final allEntries = await _journalRepository.getAllJournalEntries();
      
      // Filter entries that have media
      final entriesWithMedia = allEntries.where((entry) => entry.media.isNotEmpty).toList();
      
      if (entriesWithMedia.isEmpty) {
        return PhotoMigrationResult(
          success: true,
          message: 'No entries with media found to migrate',
          migratedEntries: 0,
          migratedMedia: 0,
          errors: [],
        );
      }

      // Create content-addressed export service
      final exportService = McpMediaExportService(
        bundleId: 'migration_${DateTime.now().millisecondsSinceEpoch}',
        outputDir: _outputDir,
      );

      // Export with content-addressed media
      final exportResult = await exportService.exportJournal(
        entries: entriesWithMedia,
        createMediaPacks: true,
      );

      if (!exportResult.success) {
        return PhotoMigrationResult(
          success: false,
          message: 'Export failed: ${exportResult.error}',
          migratedEntries: 0,
          migratedMedia: 0,
          errors: [exportResult.error ?? 'Unknown export error'],
        );
      }

      return PhotoMigrationResult(
        success: true,
        message: 'Successfully migrated ${exportResult.processedEntries} entries with ${exportResult.totalMediaItems} media items',
        migratedEntries: exportResult.processedEntries,
        migratedMedia: exportResult.totalMediaItems,
        errors: [],
        journalPath: exportResult.journalPath,
        mediaPackPaths: exportResult.mediaPackPaths,
      );
    } catch (e) {
      return PhotoMigrationResult(
        success: false,
        message: 'Migration failed: $e',
        migratedEntries: 0,
        migratedMedia: 0,
        errors: [e.toString()],
      );
    }
  }

  /// Migrate a single journal entry
  Future<PhotoMigrationResult> migrateEntry(JournalEntry entry) async {
    try {
      if (entry.media.isEmpty) {
        return PhotoMigrationResult(
          success: true,
          message: 'Entry has no media to migrate',
          migratedEntries: 0,
          migratedMedia: 0,
          errors: [],
        );
      }

      // Create content-addressed export service
      final exportService = McpMediaExportService(
        bundleId: 'migration_${entry.id}_${DateTime.now().millisecondsSinceEpoch}',
        outputDir: _outputDir,
      );

      // Export single entry
      final exportResult = await exportService.exportJournal(
        entries: [entry],
        createMediaPacks: true,
      );

      if (!exportResult.success) {
        return PhotoMigrationResult(
          success: false,
          message: 'Export failed: ${exportResult.error}',
          migratedEntries: 0,
          migratedMedia: 0,
          errors: [exportResult.error ?? 'Unknown export error'],
        );
      }

      return PhotoMigrationResult(
        success: true,
        message: 'Successfully migrated entry ${entry.id}',
        migratedEntries: 1,
        migratedMedia: entry.media.length,
        errors: [],
        journalPath: exportResult.journalPath,
        mediaPackPaths: exportResult.mediaPackPaths,
      );
    } catch (e) {
      return PhotoMigrationResult(
        success: false,
        message: 'Migration failed: $e',
        migratedEntries: 0,
        migratedMedia: 0,
        errors: [e.toString()],
      );
    }
  }

  /// Analyze entries for migration (dry run)
  Future<PhotoMigrationAnalysis> analyzeMigration() async {
    try {
      final allEntries = await _journalRepository.getAllJournalEntries();
      final entriesWithMedia = allEntries.where((entry) => entry.media.isNotEmpty).toList();
      
      int totalMedia = 0;
      int photoLibraryMedia = 0;
      int filePathMedia = 0;
      int networkMedia = 0;
      final errors = <String>[];

      for (final entry in entriesWithMedia) {
        for (final media in entry.media) {
          totalMedia++;
          
          if (PhotoBridge.isPhotoLibraryUri(media.uri)) {
            photoLibraryMedia++;
          } else if (PhotoBridge.isFilePath(media.uri)) {
            filePathMedia++;
          } else if (PhotoBridge.isNetworkUrl(media.uri)) {
            networkMedia++;
          } else {
            errors.add('Unknown media URI format: ${media.uri}');
          }
        }
      }

      return PhotoMigrationAnalysis(
        totalEntries: allEntries.length,
        entriesWithMedia: entriesWithMedia.length,
        totalMedia: totalMedia,
        photoLibraryMedia: photoLibraryMedia,
        filePathMedia: filePathMedia,
        networkMedia: networkMedia,
        errors: errors,
      );
    } catch (e) {
      return PhotoMigrationAnalysis(
        totalEntries: 0,
        entriesWithMedia: 0,
        totalMedia: 0,
        photoLibraryMedia: 0,
        filePathMedia: 0,
        networkMedia: 0,
        errors: [e.toString()],
      );
    }
  }
}

/// Result of photo migration
class PhotoMigrationResult {
  final bool success;
  final String message;
  final int migratedEntries;
  final int migratedMedia;
  final List<String> errors;
  final String? journalPath;
  final List<String> mediaPackPaths;

  const PhotoMigrationResult({
    required this.success,
    required this.message,
    required this.migratedEntries,
    required this.migratedMedia,
    required this.errors,
    this.journalPath,
    this.mediaPackPaths = const [],
  });
}

/// Analysis of migration requirements
class PhotoMigrationAnalysis {
  final int totalEntries;
  final int entriesWithMedia;
  final int totalMedia;
  final int photoLibraryMedia;
  final int filePathMedia;
  final int networkMedia;
  final List<String> errors;

  const PhotoMigrationAnalysis({
    required this.totalEntries,
    required this.entriesWithMedia,
    required this.totalMedia,
    required this.photoLibraryMedia,
    required this.filePathMedia,
    required this.networkMedia,
    required this.errors,
  });

  Map<String, dynamic> toJson() => {
    'totalEntries': totalEntries,
    'entriesWithMedia': entriesWithMedia,
    'totalMedia': totalMedia,
    'photoLibraryMedia': photoLibraryMedia,
    'filePathMedia': filePathMedia,
    'networkMedia': networkMedia,
    'errors': errors,
  };
}
