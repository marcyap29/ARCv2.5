import 'package:my_app/arc/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:hive/hive.dart';

/// Migration to convert legacy audioUri field to new media[] list
/// This migration runs on first launch after the P5-MM update
class MediaListMigration {
  static const String _migrationKey = 'media_list_migration_completed';
  
  /// Run the migration if not already completed
  static Future<void> runMigration() async {
    final prefs = await Hive.openBox('preferences');
    
    // Check if migration already completed
    if (prefs.get(_migrationKey, defaultValue: false) == true) {
      print('MediaListMigration: Migration already completed, skipping');
      return;
    }
    
    try {
      print('MediaListMigration: Starting migration...');
      
      // Open journal entries box
      final journalBox = Hive.box<JournalEntry>('journal_entries');
      final entries = journalBox.values.toList();
      
      int migratedCount = 0;
      int skippedCount = 0;
      
      for (final entry in entries) {
        try {
          // Check if entry has legacy audioUri but no media items
          if (entry.audioUri != null && entry.audioUri!.isNotEmpty && entry.media.isEmpty) {
            // Create MediaItem from legacy audioUri
            final mediaItem = MediaItem(
              id: 'migrated_${entry.id}_${DateTime.now().millisecondsSinceEpoch}',
              uri: entry.audioUri!,
              type: MediaType.audio,
              createdAt: entry.createdAt,
              // Note: We don't have duration or size info from legacy data
              // These will be null and can be populated later if needed
            );
            
            // Create updated entry with media list
            final updatedEntry = entry.copyWith(
              media: [mediaItem],
              // Keep audioUri for backward compatibility during transition
              audioUri: entry.audioUri,
            );
            
            // Save updated entry
            await journalBox.put(entry.id, updatedEntry);
            migratedCount++;
            
            print('MediaListMigration: Migrated entry ${entry.id} with audioUri: ${entry.audioUri}');
          } else {
            skippedCount++;
          }
        } catch (e) {
          print('MediaListMigration: Error migrating entry ${entry.id}: $e');
          // Continue with other entries even if one fails
        }
      }
      
      // Mark migration as completed
      await prefs.put(_migrationKey, true);
      
      print('MediaListMigration: Migration completed successfully');
      print('MediaListMigration: Migrated $migratedCount entries, skipped $skippedCount entries');
      
    } catch (e) {
      print('MediaListMigration: Migration failed: $e');
      // Don't mark as completed if there was an error
      // This allows the migration to retry on next launch
    } finally {
      await prefs.close();
    }
  }
  
  /// Check if migration is needed
  static Future<bool> isMigrationNeeded() async {
    try {
      final prefs = await Hive.openBox('preferences');
      final isCompleted = prefs.get(_migrationKey, defaultValue: false) == true;
      await prefs.close();
      return !isCompleted;
    } catch (e) {
      print('MediaListMigration: Error checking migration status: $e');
      return true; // Assume migration is needed if we can't check
    }
  }
  
  /// Reset migration status (for testing purposes)
  static Future<void> resetMigrationStatus() async {
    try {
      final prefs = await Hive.openBox('preferences');
      await prefs.delete(_migrationKey);
      await prefs.close();
      print('MediaListMigration: Migration status reset');
    } catch (e) {
      print('MediaListMigration: Error resetting migration status: $e');
    }
  }
}
