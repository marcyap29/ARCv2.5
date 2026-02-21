import 'package:flutter/material.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/ui/export_import/mcp_export_screen.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

/// Screen for advanced export options
///
/// Provides access to:
/// - Custom exports with date range filtering
/// - Multi-select specific entries
/// - Password-based encryption
/// - Export strategy options
/// - Share exports directly
///
/// Note: For regular automated backups, use "Local Backup" in Settings.
/// For importing data, use "Import Data" in Settings.
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
                    'Advanced Export Options',
                    style: heading2Style(context).copyWith(
                      color: kcPrimaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create custom exports with advanced options:\n\n'
                    '• Date range filtering (last 30/90 days, custom range)\n'
                    '• Multi-select specific entries\n'
                    '• Password-based encryption\n'
                    '• Export strategy options\n'
                    '• Share exports directly\n\n'
                    'For regular automated backups, use "Local Backup" in Settings.',
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
              title: 'Export Options',
              children: [
                _buildActionCard(
                  context,
                  title: 'Create ARCX Secure Package',
                  subtitle: 'Export to encrypted .arcx file with AES-256-GCM encryption and Ed25519 digital signatures. Includes date filtering, multi-select, and password options.',
                  icon: Icons.cloud_upload,
                  color: kcAccentColor,
                  onTap: () => _navigateToExport(context),
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  title: 'Export Zip File',
                  subtitle: 'Export to unencrypted ZIP file with all journal entries, media, chats, and extended data. Includes date filtering and multi-select options.',
                  icon: Icons.archive,
                  color: Colors.blue,
                  onTap: () => _navigateToZipExport(context),
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  title: 'Export as Text (.txt)',
                  subtitle: 'Export journal entries as plain .txt files. One file per entry; good for sync or sharing individual documents.',
                  icon: Icons.description,
                  color: Colors.teal,
                  onTap: () => _navigateToTxtExport(context),
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

  /// Navigate to export screen (.txt format)
  void _navigateToTxtExport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const McpExportScreen(initialFormat: 'txt'),
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