import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import '../../arc/core/journal_repository.dart';
import '../../models/journal_entry_model.dart';
import '../../data/models/media_item.dart';
import '../../mcp/export/mcp_pack_export_service.dart';
import '../../utils/file_utils.dart';

/// MCP Export Screen - Create MCP Package (.mcpkg)
class McpExportScreen extends StatefulWidget {
  const McpExportScreen({super.key});

  @override
  State<McpExportScreen> createState() => _McpExportScreenState();
}

class _McpExportScreenState extends State<McpExportScreen> {
  bool _includePhotos = true;
  bool _reducePhotoSize = false;
  bool _isExporting = false;
  String? _exportPath;
  int _entryCount = 0;
  int _photoCount = 0;
  String _estimatedSize = 'Calculating...';

  @override
  void initState() {
    super.initState();
    _loadJournalStats();
  }

  Future<void> _loadJournalStats() async {
    try {
      final journalRepo = context.read<JournalRepository>();
      final entries = await journalRepo.getAllJournalEntries();
      
      int photoCount = 0;
      for (final entry in entries) {
        photoCount += entry.media.where((m) => m.type == MediaType.image).length;
      }

      setState(() {
        _entryCount = entries.length;
        _photoCount = photoCount;
        _estimatedSize = _calculateEstimatedSize(entries);
      });
    } catch (e) {
      print('Error loading journal stats: $e');
    }
  }

  String _calculateEstimatedSize(List<JournalEntry> entries) {
    // Rough estimation: 1KB per entry + 500KB per photo
    final estimatedBytes = (_entryCount * 1024) + (_photoCount * 500 * 1024);
    return FileUtils.formatFileSize(estimatedBytes);
  }

  Future<void> _exportMcpPackage() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      // Get journal entries
      final journalRepo = context.read<JournalRepository>();
      final entries = await journalRepo.getAllJournalEntries();

      if (entries.isEmpty) {
        _showErrorDialog('No entries to export');
        return;
      }

      // Create temporary file path
      final tempDir = await getTemporaryDirectory();
      final fileName = FileUtils.generateMcpPackageName('journal_export');
      final tempFilePath = path.join(tempDir.path, fileName);

      // Create export service
      final exportService = McpPackExportService(
        bundleId: 'export_${DateTime.now().millisecondsSinceEpoch}',
        outputPath: tempFilePath,
        isDebugMode: false,
      );

      // Show progress dialog
      _showProgressDialog();

      // Export
      final exportResult = await exportService.exportJournal(
        entries: entries,
        includePhotos: _includePhotos,
        reducePhotoSize: _reducePhotoSize,
      );

      // Hide progress dialog
      Navigator.of(context).pop();

      if (exportResult.success) {
        setState(() {
          _exportPath = exportResult.outputPath;
        });
        _showSuccessDialog(exportResult);
      } else {
        _showErrorDialog(exportResult.error ?? 'Export failed');
      }

    } catch (e) {
      Navigator.of(context).pop(); // Hide progress dialog
      _showErrorDialog('Export failed: $e');
    } finally {
      setState(() {
        _isExporting = false;
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
              'Creating MCP Package...',
              style: heading3Style(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Processing $_entryCount entries and $_photoCount photos',
              style: bodyStyle(context),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(McpExportResult result) async {
    // First show the success dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text('Export Complete', style: heading2Style(context)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your MCP Package was created successfully!',
              style: bodyStyle(context),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Entries exported:', '$_entryCount'),
            _buildSummaryRow('Photos exported:', '$_photoCount'),
            const SizedBox(height: 16),
            Text(
              'Tap "Share" to save the file to your device.',
              style: bodyStyle(context).copyWith(
                fontStyle: FontStyle.italic,
                color: kcSecondaryTextColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog first
              await _shareMcpPackage(result.outputPath!);
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareMcpPackage(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _showErrorDialog('Export file not found');
        return;
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'MCP Package - $_entryCount entries, $_photoCount photos',
        subject: 'Journal Export - ${path.basename(filePath)}',
      );
    } catch (e) {
      _showErrorDialog('Failed to share file: $e');
    }
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
            Text('Export Failed', style: heading2Style(context)),
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
          'Create MCP Package',
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
                    'Save all your journal entries and photos in a single portable .zip file.',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can re-import this package at any time to restore your data.',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Options
            Text(
              'Export Options',
              style: heading2Style(context).copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Include photos option
            _buildOptionTile(
              title: 'Include photos',
              subtitle: 'Export all photos with your entries',
              value: _includePhotos,
              onChanged: (value) {
                setState(() {
                  _includePhotos = value;
                });
                _loadJournalStats(); // Recalculate size
              },
            ),

            // Reduce photo size option
            if (_includePhotos) ...[
              const SizedBox(height: 8),
              _buildOptionTile(
                title: 'Reduce photo size',
                subtitle: 'Compress photos to save space (recommended)',
                value: _reducePhotoSize,
                onChanged: (value) {
                  setState(() {
                    _reducePhotoSize = value;
                  });
                  _loadJournalStats(); // Recalculate size
                },
              ),
            ],

            const SizedBox(height: 24),

            // Summary
            Text(
              'Export Summary',
              style: heading2Style(context).copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Entries:', '$_entryCount'),
                  _buildSummaryRow('Photos:', '$_photoCount'),
                  _buildSummaryRow('Estimated size:', _estimatedSize),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Export button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isExporting ? null : _exportMcpPackage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kcAccentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isExporting
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
                          Text('Creating Package...'),
                        ],
                      )
                    : const Text(
                        'Create MCP Package (.zip)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        title: Text(title, style: heading3Style(context)),
        subtitle: Text(subtitle, style: bodyStyle(context)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: kcAccentColor,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
