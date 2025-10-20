import 'package:flutter/material.dart';
import 'package:my_app/ui/widgets/photo_migration_dialog.dart';
import 'package:my_app/ui/widgets/media_pack_management_dialog.dart';
import 'package:my_app/ui/widgets/media_pack_dashboard.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/services/media_resolver_service.dart';
import 'package:my_app/services/media_pack_tracking_service.dart';
import 'package:my_app/prism/mcp/export/mcp_media_export_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive_io.dart';
import 'dart:io';

/// Screen for managing MCP (Memory Core Protocol) operations
///
/// Provides access to:
/// - Export journal and media packs
/// - Import MCP archives
/// - Manage mounted media packs
/// - Migrate legacy photos to content-addressed format
class McpManagementScreen extends StatelessWidget {
  final JournalRepository journalRepository;

  const McpManagementScreen({
    super.key,
    required this.journalRepository,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Pack Manager'),
        backgroundColor: Colors.blue[700],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader('Export & Backup'),
          const SizedBox(height: 12),
          _buildExportCard(context),
          const SizedBox(height: 24),

          _buildHeader('Media Library'),
          const SizedBox(height: 12),
          _buildMediaPackDashboardCard(context),
          const SizedBox(height: 24),

          _buildHeader('Photo Migration'),
          const SizedBox(height: 12),
          _buildMigrationCard(context),
          const SizedBox(height: 24),

          _buildHeader('System Status'),
          const SizedBox(height: 12),
          _buildStatusCard(context),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildExportCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_upload, color: Colors.blue[700], size: 32),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export Journal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Create portable archive with your entries and photos',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Export your journal to a portable MCP format with content-addressed photos. Includes thumbnails in the journal and full-resolution photos in separate media packs.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _exportContentAddressedMedia(context),
                  icon: const Icon(Icons.upload),
                  label: const Text('Export Now'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPackDashboardCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard, color: Colors.green[700], size: 32),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Media Pack Dashboard',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Track, manage, and organize your media packs',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'View storage statistics, manage pack lifecycle, and monitor your media library. Packs are automatically organized by date and can be archived or deleted as needed.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400, // Fixed height for the dashboard
              child: const MediaPackDashboard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMigrationCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sync_alt, color: Colors.orange[700], size: 32),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Migrate Legacy Photos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Convert ph:// references to content-addressed format',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Migrate photos from the device photo library (ph:// URIs) to durable content-addressed format.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => PhotoMigrationDialog(
                        journalRepository: journalRepository,
                        outputDir: '/Users/Shared/EPI_Exports',
                      ),
                    );
                  },
                  icon: const Icon(Icons.sync),
                  label: const Text('Migrate Photos'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final stats = MediaResolverService.instance.stats;
    final isInitialized = stats['initialized'] as bool;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isInitialized ? Icons.check_circle : Icons.warning,
                  color: isInitialized ? Colors.green[700] : Colors.orange[700],
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Text(
                  'MediaResolver Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusRow(
              'Status',
              isInitialized ? 'Initialized' : 'Not Initialized',
              isInitialized ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              'Mounted Packs',
              '${stats['mountedPacks'] ?? 0}',
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              'Cached Photos',
              '${stats['cachedShas'] ?? 0}',
              Colors.blue,
            ),
            if (stats['journalPath'] != null) ...[
              const SizedBox(height: 8),
              _buildStatusRow(
                'Journal',
                stats['journalPath'] as String,
                Colors.grey,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  /// Simple export function that matches the "Export MCP Memory Bundle" pattern
  Future<void> _exportContentAddressedMedia(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final rootDir = Directory('${directory.path}/mcp_exports');
      if (!await rootDir.exists()) {
        await rootDir.create(recursive: true);
      }
      
      // Unique folder per export
      final runDir = Directory('${rootDir.path}/${DateTime.now().millisecondsSinceEpoch}');
      await runDir.create(recursive: true);
      
      // Export using the MCP media export service
      final bundleId = 'mcp_media_${DateTime.now().millisecondsSinceEpoch}';
            final exportService = McpMediaExportService(
        bundleId: bundleId,
        outputDir: runDir.path,
      );
      
      // Get all journal entries
      final entries = await journalRepository.getAllJournalEntries();
      final result = await exportService.exportJournal(
        entries: entries,
        createMediaPacks: true,
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (result.success) {
        // Generate a bundle ID with readable date and time
        final now = DateTime.now();
        final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
        final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
              final zipBundleId = 'mcp_media_${dateStr}_${timeStr}';

        // Create ZIP of the export directory
        final zipFile = File('${runDir.path}/../$zipBundleId.zip');
        await _zipDirectory(runDir, zipFile);
        
        // Open iOS share sheet so user can save to Files
        await Share.shareXFiles([
          XFile(
            zipFile.path,
            mimeType: 'application/zip',
            name: '$zipBundleId.zip',
          ),
        ]);

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export saved: $zipBundleId.zip'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        throw Exception(result.error ?? 'Export failed');
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Simple ZIP creation function
  Future<void> _zipDirectory(Directory sourceDir, File zipFile) async {
    final files = <File>[];
    await for (final entity in sourceDir.list(recursive: true)) {
      if (entity is File) {
        files.add(entity);
      }
    }

    // Create ZIP file
    final zip = ZipFileEncoder();
    zip.create(zipFile.path);
    
    for (final file in files) {
      final relativePath = file.path.substring(sourceDir.path.length + 1);
      zip.addFile(file, relativePath);
    }
    
    zip.close();
  }
}
