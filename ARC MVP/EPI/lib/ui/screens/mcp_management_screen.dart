import 'package:flutter/material.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/ui/export_import/mcp_export_screen.dart';
import 'package:my_app/ui/export_import/mcp_import_screen.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

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
        title: Text(
          'MCP Management',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                    'Create portable packages containing all your journal entries and photos. Export to .mcpkg files or .mcp/ folders for easy backup and sharing.',
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
                  title: 'Restore from MCP Package',
                  subtitle: 'Import journal entries and photos from a .mcpkg file or .mcp/ folder',
                  icon: Icons.cloud_download,
                  color: Colors.green,
                  onTap: () => _navigateToImport(context),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Info Section
            _buildSection(
              context,
              title: 'About MCP',
              children: [
                _buildInfoCard(
                  context,
                  title: 'What is MCP?',
                  content: 'MCP is a standardized format for storing journal entries and photos together. It ensures your data is portable and can be restored on any device.',
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  context,
                  title: 'File Formats',
                  content: '• .mcpkg - Zipped package (recommended for sharing)\n• .mcp/ - Folder format (useful for debugging)',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Navigate to export screen
  void _navigateToExport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const McpExportScreen(),
      ),
    );
  }

  /// Navigate to import screen
  void _navigateToImport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const McpImportScreen(),
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

  /// Build an info card
  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return Container(
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
            title,
            style: heading3Style(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}