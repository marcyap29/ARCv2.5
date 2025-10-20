import 'dart:io';
import 'package:my_app/prism/mcp/export/content_addressed_export_service.dart';
import 'package:my_app/prism/mcp/import/content_addressed_import_service.dart';
import 'package:my_app/prism/mcp/migration/photo_migration_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';

/// Example usage of the content-addressed media system
class ContentAddressedExample {
  static Future<void> runExample() async {
    print('🚀 Content-Addressed Media System Example');
    
    // Initialize services
    final journalRepository = JournalRepository();
    final outputDir = '/tmp/mcp_export';
    
    // Create migration service
    final migrationService = PhotoMigrationService(
      journalRepository: journalRepository,
      outputDir: outputDir,
    );
    
    // Analyze current data
    print('📊 Analyzing current data...');
    final analysis = await migrationService.analyzeMigration();
    print('Analysis: ${analysis.toJson()}');
    
    // Migrate all entries
    print('🔄 Migrating entries...');
    final migrationResult = await migrationService.migrateAllEntries();
    
    if (migrationResult.success) {
      print('✅ Migration successful!');
      print('Journal: ${migrationResult.journalPath}');
      print('Media packs: ${migrationResult.mediaPackPaths}');
      
      // Test import
      print('📥 Testing import...');
      final importService = ContentAddressedImportService(
        journalPath: migrationResult.journalPath!,
        mediaPackPaths: migrationResult.mediaPackPaths,
        journalRepository: journalRepository,
      );
      
      final importResult = await importService.importJournal();
      if (importResult.success) {
        print('✅ Import successful!');
        print('Imported ${importResult.importedEntries} entries with ${importResult.importedMedia} media items');
      } else {
        print('❌ Import failed: ${importResult.error}');
      }
    } else {
      print('❌ Migration failed: ${migrationResult.message}');
    }
  }
}
