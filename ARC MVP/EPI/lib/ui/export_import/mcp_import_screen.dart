import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import '../../arc/core/journal_repository.dart';
import '../../mcp/import/mcp_pack_import_service.dart';
import '../../utils/file_utils.dart';
import '../../features/timeline/timeline_cubit.dart';
import '../../arcx/ui/arcx_import_progress_screen.dart';

/// MCP Import Screen - Restore from MCP Package (.zip) or Secure Archive (.arcx)
class McpImportScreen extends StatefulWidget {
  const McpImportScreen({super.key});

  @override
  State<McpImportScreen> createState() => _McpImportScreenState();
}

class _McpImportScreenState extends State<McpImportScreen> {
  bool _isImporting = false;
  String? _selectedPath;
  String? _detectedFormat;

  Future<void> _selectMcpFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'mcpkg', 'arcx'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String? format;
        if (file.path!.endsWith('.arcx')) {
          format = 'Secure Archive (.arcx)';
        } else if (FileUtils.isMcpPackage(file.path!)) {
          format = 'MCP Package (.zip)';
        } else {
          format = 'Unknown';
        }
        
        setState(() {
          _selectedPath = file.path;
          _detectedFormat = format;
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to select file: $e');
    }
  }


  Future<void> _importMcpData() async {
    if (_isImporting || _selectedPath == null) return;

    setState(() {
      _isImporting = true;
    });

    try {
      // Check file type
      if (_selectedPath!.endsWith('.arcx')) {
        // Secure .arcx import - navigate to progress screen
        final arcxFile = File(_selectedPath!);
        if (!await arcxFile.exists()) {
          _showErrorDialog('ARCX file not found');
          setState(() => _isImporting = false);
          return;
        }

        // Find manifest file (sibling to .arcx)
        final manifestPath = _selectedPath!.replaceAll('.arcx', '.manifest.json');
        final manifestFile = File(manifestPath);
        String? actualManifestPath;
        
        if (await manifestFile.exists()) {
          actualManifestPath = manifestPath;
        }

        // Navigate to ARCX import progress screen
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ARCXImportProgressScreen(
              arcxPath: _selectedPath!,
              manifestPath: actualManifestPath,
            ),
          ),
        ).then((_) {
          // Refresh timeline after import completes
          context.read<TimelineCubit>().reloadAllEntries();
          setState(() => _isImporting = false);
        });
      } else {
        // Legacy MCP (.zip) import
        final journalRepo = context.read<JournalRepository>();
        final importService = McpPackImportService(journalRepo: journalRepo);

        // Show progress dialog
        _showProgressDialog();

        // Import
        final importResult = await importService.importFromPath(_selectedPath!);

        // Hide progress dialog
        Navigator.of(context).pop();

        if (importResult.success) {
          // Refresh timeline to show imported entries
          context.read<TimelineCubit>().reloadAllEntries();
          _showSuccessDialog(importResult);
        } else {
          _showErrorDialog(importResult.error ?? 'Import failed');
        }
      }

    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Hide progress dialog
      }
      _showErrorDialog('Import failed: $e');
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  void _showProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Restoring from MCP Package...',
              style: heading3Style(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Validating package → Importing entries → Importing photos → Linking',
              style: bodyStyle(context),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(McpImportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text('Import Complete', style: heading2Style(context)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your data has been successfully restored!',
              style: bodyStyle(context),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Entries restored:', '${result.totalEntries}'),
            _buildSummaryRow('Photos restored:', '${result.totalPhotos}'),
            _buildSummaryRow('Missing/corrupted:', '0'),
            if (result.manifest != null) ...[
              const SizedBox(height: 8),
              Text(
                'Package info:',
                style: bodyStyle(context).copyWith(fontWeight: FontWeight.bold),
              ),
              _buildSummaryRow('Format:', result.manifest!.format),
              _buildSummaryRow('Version:', '${result.manifest!.version}'),
              _buildSummaryRow('Type:', result.manifest!.subtype),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to previous screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: bodyStyle(context)),
          Text(value, style: bodyStyle(context).copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text('Import Failed', style: heading2Style(context)),
          ],
        ),
        content: Text(message, style: bodyStyle(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: Text(
          'Restore from Package',
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
                    'Select an MCP package (.zip) or Secure Archive (.arcx) to restore your data.',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Legacy .zip files import directly, while encrypted .arcx archives are decrypted with AES-256-GCM and verified with Ed25519 signatures.',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // File selection
            Text(
              'Select MCP Package',
              style: heading2Style(context).copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Package file selection
            _buildSelectionTile(
              title: 'Select Package File',
              subtitle: 'Choose a .zip (MCP) or .arcx (Secure Archive) file to restore from',
              icon: Icons.file_present,
              onTap: _selectMcpFile,
            ),

            // Selected file info
            if (_selectedPath != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Selected: $_detectedFormat',
                          style: bodyStyle(context).copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      path.basename(_selectedPath!),
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Import button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isImporting || _selectedPath == null) ? null : _importMcpData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kcAccentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isImporting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Restoring Data...'),
                        ],
                      )
                    : Text(
                        _selectedPath == null 
                            ? 'Select MCP Package First'
                            : 'Restore from MCP Package',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Icon(icon, color: kcAccentColor),
        title: Text(title, style: heading3Style(context)),
        subtitle: Text(subtitle, style: bodyStyle(context)),
        trailing: const Icon(Icons.arrow_forward_ios, color: kcSecondaryTextColor, size: 16),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
