/// Import Options Sheet
///
/// Bottom sheet presented from the welcome screen for users who already have
/// journal data. For LUMARA/ARCX/zip backups, delegates to the existing
/// proven import architecture (ARCXImportServiceV2 / McpPackImportService
/// via ImportExportFolderView). For third-party formats (Day One, Journey,
/// text, CSV), uses UniversalImporterService.

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/ui/settings/settings_view.dart';
import 'package:my_app/arc/unified_feed/services/universal_importer_service.dart';

class ImportOptionsSheet extends StatefulWidget {
  const ImportOptionsSheet({super.key});

  @override
  State<ImportOptionsSheet> createState() => _ImportOptionsSheetState();
}

class _ImportOptionsSheetState extends State<ImportOptionsSheet> {
  bool _importing = false;
  double _progress = 0.0;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Import Your Data',
                    style: TextStyle(
                      color: kcPrimaryTextColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close,
                      color: kcSecondaryTextColor.withOpacity(0.6)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Divider(color: kcBorderColor.withOpacity(0.3)),

          if (_importing) ...[
            // Progress view (for third-party imports only)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            kcPrimaryColor),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _statusMessage ?? 'Importing entries...',
                      style: const TextStyle(
                        color: kcPrimaryTextColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: TextStyle(
                        color: kcSecondaryTextColor.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Import options list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Choose your import source:',
                    style: TextStyle(
                      color: kcSecondaryTextColor.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // LUMARA / ARCX backup — delegates to existing import infra
                  _buildImportOption(
                    icon: Icons.backup_outlined,
                    title: 'LUMARA Backup',
                    subtitle:
                        'Restore from .zip, .arcx, or .mcpkg backup files',
                    onTap: _openLumaraImport,
                  ),
                  const SizedBox(height: 12),

                  // Day One
                  _buildImportOption(
                    icon: Icons.book_outlined,
                    title: 'Day One',
                    subtitle: 'Import from Day One JSON export',
                    onTap: () => _pickAndImport(
                      extensions: ['json'],
                      importType: ImportType.dayOne,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Journey
                  _buildImportOption(
                    icon: Icons.explore_outlined,
                    title: 'Journey',
                    subtitle: 'Import from Journey backup',
                    onTap: () => _pickAndImport(
                      extensions: ['json'],
                      importType: ImportType.journey,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Plain text / Markdown
                  _buildImportOption(
                    icon: Icons.text_snippet_outlined,
                    title: 'Text Files',
                    subtitle: 'Import from plain text or markdown files',
                    onTap: () => _pickAndImport(
                      extensions: ['txt', 'md'],
                      importType: ImportType.plainText,
                      allowMultiple: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // CSV / Excel
                  _buildImportOption(
                    icon: Icons.table_chart_outlined,
                    title: 'CSV / Excel',
                    subtitle: 'Import from spreadsheet exports',
                    onTap: () => _pickAndImport(
                      extensions: ['csv', 'xlsx', 'xls'],
                      importType: ImportType.spreadsheet,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withOpacity(0.25),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFF60A5FA),
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your entries will be imported and CHRONICLE will '
                            'automatically build your temporal intelligence from them.',
                            style: TextStyle(
                              color: Color(0xFF93C5FD),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kcSurfaceAltColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kcBorderColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kcPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: kcPrimaryColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: kcPrimaryTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: kcSecondaryTextColor.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: kcSecondaryTextColor.withOpacity(0.3),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ─── LUMARA Backup: delegate to existing proven import architecture ──

  /// Opens the existing Import & Export folder view which handles
  /// .zip, .arcx, and .mcpkg files via ARCXImportServiceV2 and
  /// McpPackImportService — the same flow as Settings → Import & Export.
  void _openLumaraImport() {
    Navigator.pop(context); // Close this sheet first
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ImportExportFolderView(),
      ),
    );
  }

  // ─── Third-party formats: use UniversalImporterService ──────────────

  Future<void> _pickAndImport({
    required List<String> extensions,
    required ImportType importType,
    bool allowMultiple = false,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: allowMultiple,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _importing = true;
      _progress = 0.0;
      _statusMessage = 'Reading file...';
    });

    try {
      final importer = UniversalImporterService();

      await importer.importFromFile(
        filePath: result.files.first.path!,
        importType: importType,
        onProgress: (progress, message) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _statusMessage = message;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _statusMessage = 'Import complete!';
        });

        // Brief pause to show completion, then close
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _importing = false;
          _statusMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: kcDangerColor,
          ),
        );
      }
    }
  }
}
