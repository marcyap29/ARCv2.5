import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/ui/export_import/mcp_export_screen.dart';
import 'package:my_app/mira/store/mcp/import/mcp_pack_import_service.dart';
import 'package:my_app/mira/store/arcx/ui/arcx_import_progress_screen.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/utils/file_utils.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/shared/ui/home/home_view.dart';

/// Screen for managing MCP (Memory Container Protocol) operations
///
/// Provides access to:
/// - Export journal entries and photos to MCP packages (.mcpkg)
/// - Import MCP packages and folders (.mcp/)
/// - Simple, reliable data backup and restore
class McpManagementScreen extends StatelessWidget {
  final JournalRepository journalRepository;

  const McpManagementScreen({
    super.key,
    required this.journalRepository,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Memory Container Protocol (MCP)',
                    style: heading2Style(context).copyWith(
                      color: kcPrimaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'MCP is a standardized format for storing journal entries, photos, chats, and extended data together. It ensures your data is portable and can be restored on any device.\n\n'
                    'Export formats:\n'
                    '• Secure Archive (.arcx) - Encrypted with AES-256-GCM and Ed25519 signatures for maximum security\n'
                    '• ZIP File (.zip) - Unencrypted standard ZIP format for compatibility and easy access',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Export Section
            _buildSection(
              context,
              title: 'Export Data',
              children: [
                _buildActionCard(
                  context,
                  title: 'Create MCP Package',
                  subtitle: 'Export all your journal entries and photos to a single portable file',
                  icon: Icons.cloud_upload,
                  color: kcAccentColor,
                  onTap: () => _navigateToExport(context),
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  title: 'Export Zip File',
                  subtitle: 'Export to unencrypted ZIP file with all journal entries, media, chats, and extended data',
                  icon: Icons.archive,
                  color: Colors.blue,
                  onTap: () => _navigateToZipExport(context),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Import Section
            _buildSection(
              context,
              title: 'Import Data',
              children: [
                _buildActionCard(
                  context,
                  title: 'Restore Data',
                  subtitle: 'Import journal entries and photos from a .zip, .mcpkg, or .arcx file',
                  icon: Icons.cloud_download,
                  color: Colors.green,
                  onTap: () => _restoreData(context),
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }

  /// Navigate to export screen (ARCX format)
  void _navigateToExport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const McpExportScreen(initialFormat: 'arcx'),
      ),
    );
  }

  /// Navigate to export screen (ZIP format)
  void _navigateToZipExport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const McpExportScreen(initialFormat: 'zip'),
      ),
    );
  }

  /// Restore data - directly open file picker and import
  Future<void> _restoreData(BuildContext context) async {
    try {
      // Open file picker directly
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'mcpkg', 'arcx'],
        allowMultiple: true, // Allow multiple files for separated packages
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final files = result.files.where((f) => f.path != null).map((f) => f.path!).toList();
      
      if (files.isEmpty) {
        return;
      }

      // Check file type and import accordingly
      final hasArcx = files.any((p) => p.endsWith('.arcx'));
      final hasZip = files.any((p) => p.endsWith('.zip') || p.endsWith('.mcpkg') || FileUtils.isMcpPackage(p));

      if (hasArcx) {
        // ARCX file(s) - navigate to ARCX import progress screen
        if (files.length == 1) {
          // Single ARCX file
          final arcxFile = File(files.first);
          if (!await arcxFile.exists()) {
            _showError(context, 'File not found');
            return;
          }

          // Find manifest file (sibling to .arcx)
          final manifestPath = files.first.replaceAll('.arcx', '.manifest.json');
          final manifestFile = File(manifestPath);
          String? actualManifestPath;
          
          if (await manifestFile.exists()) {
            actualManifestPath = manifestPath;
          }

          // Navigate to ARCX import progress screen
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ARCXImportProgressScreen(
                arcxPath: files.first,
                manifestPath: actualManifestPath,
                parentContext: context,
              ),
            ),
          ).then((result) {
            // Refresh timeline after ARCX import completes
            if (context.mounted && result != null) {
              try {
                context.read<TimelineCubit>().reloadAllEntries();
                print('✅ Timeline refreshed after ARCX import');
                
                // Navigate to timeline (Journal tab in HomeView)
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const HomeView(initialTab: 0), // Journal tab
                      ),
                      (route) => false, // Remove all previous routes
                    );
                  }
                });
              } catch (e) {
                print('⚠️ Could not refresh timeline: $e');
              }
            }
          });
        } else {
          // Multiple ARCX files - show error for now (separated packages need more complex handling)
          _showError(context, 'Multiple ARCX files selected. Please select one file at a time.');
        }
      } else if (hasZip) {
        // ZIP file(s) - use MCP pack import service
        if (files.length == 1) {
          // Single ZIP file
          final zipFile = File(files.first);
          if (!await zipFile.exists()) {
            _showError(context, 'File not found');
            return;
          }

          // Show loading indicator
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );

          try {
            // Initialize PhaseRegimeService for extended data import
            PhaseRegimeService? phaseRegimeService;
            try {
              final analyticsService = AnalyticsService();
              final rivetSweepService = RivetSweepService(analyticsService);
              phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
              await phaseRegimeService.initialize();
            } catch (e) {
              print('Warning: Could not initialize PhaseRegimeService: $e');
            }

            final importService = McpPackImportService(
              journalRepo: journalRepository,
              phaseRegimeService: phaseRegimeService,
            );

            final importResult = await importService.importFromPath(files.first);

            if (!context.mounted) return;
            Navigator.pop(context); // Close loading dialog

            if (importResult.success) {
              // Refresh timeline before showing success dialog
              try {
                context.read<TimelineCubit>().reloadAllEntries();
                print('✅ Timeline refreshed after import');
              } catch (e) {
                print('⚠️ Could not refresh timeline: $e');
              }
              
              // Show success dialog briefly, then navigate to timeline
              _showSuccess(
                context,
                'Import Complete',
                'Imported ${importResult.totalEntries} entries and ${importResult.totalPhotos} media items.',
              );
              
              // Navigate to timeline after a short delay (allows dialog to show)
              Future.delayed(const Duration(milliseconds: 500), () {
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const HomeView(initialTab: 0), // Journal tab
                    ),
                    (route) => false, // Remove all previous routes
                  );
                }
              });
            } else {
              _showError(context, importResult.error ?? 'Import failed');
            }
          } catch (e) {
            if (!context.mounted) return;
            Navigator.pop(context); // Close loading dialog
            _showError(context, 'Import failed: $e');
          }
        } else {
          _showError(context, 'Multiple ZIP files selected. Please select one file at a time.');
        }
      } else {
        _showError(context, 'Unsupported file format');
      }
    } catch (e) {
      _showError(context, 'Failed to select file: $e');
    }
  }

  /// Show error dialog
  void _showError(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show success dialog
  void _showSuccess(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Build a section with title and children
  Widget _buildSection(BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: heading2Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  /// Build an action card
  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(
          title,
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: kcSecondaryTextColor,
          size: 16,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

}