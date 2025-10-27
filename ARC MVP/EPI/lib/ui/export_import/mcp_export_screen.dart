import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import '../../arcx/services/arcx_export_service.dart';
import '../../arcx/models/arcx_result.dart';

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
  
  // Export format selection
  String _exportFormat = 'legacy'; // 'legacy' or 'secure'
  
  // ARCX redaction settings (only visible when secure format is selected)
  bool _includePhotoLabels = false;
  bool _dateOnlyTimestamps = false;

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

      // Show progress dialog
      _showProgressDialog();

      if (_exportFormat == 'secure') {
        // Secure .arcx export
        final outputDir = await getApplicationDocumentsDirectory();
        final exportsDir = Directory(path.join(outputDir.path, 'Exports'));
        if (!await exportsDir.exists()) {
          await exportsDir.create(recursive: true);
        }

        // Collect photo media items from journal entries
        final photoMedia = <MediaItem>[];
        if (_includePhotos) {
          for (final entry in entries) {
            photoMedia.addAll(entry.media.where((m) => m.type == MediaType.image));
          }
        }

        // Call ARCX export service
        final arcxExport = ARCXExportService();
        final result = await arcxExport.exportSecure(
          outputDir: exportsDir,
          journalEntries: entries,
          mediaFiles: _includePhotos ? photoMedia : null,
          includePhotoLabels: _includePhotoLabels,
          dateOnlyTimestamps: _dateOnlyTimestamps,
        );

        // Hide progress dialog
        Navigator.of(context).pop();

        if (result.success) {
          setState(() {
            _exportPath = result.arcxPath;
          });
          _showArcSuccessDialog(result);
        } else {
          _showErrorDialog(result.error ?? 'ARCX export failed');
        }
      } else {
        // Legacy MCP export
        final tempDir = await getTemporaryDirectory();
        final fileName = FileUtils.generateMcpPackageName('journal_export');
        final tempFilePath = path.join(tempDir.path, fileName);

        // Create export service
        final exportService = McpPackExportService(
          bundleId: 'export_${DateTime.now().millisecondsSinceEpoch}',
          outputPath: tempFilePath,
          isDebugMode: false,
        );

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
      }

    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Hide progress dialog
      }
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

  void _showArcSuccessDialog(ARCXExportResult result) async {
    // First show the success dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text('Secure Archive Created', style: heading2Style(context)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your encrypted .arcx archive was created successfully!',
              style: bodyStyle(context),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Entries exported:', '$_entryCount'),
            _buildSummaryRow('Photos exported:', '$_photoCount'),
            if (result.manifestPath != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Files created:',
                      style: bodyStyle(context).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    _buildFilePath('📦 Archive', result.arcxPath!),
                    _buildFilePath('📄 Manifest', result.manifestPath!),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Encrypted with AES-256-GCM • Signed with Ed25519',
              style: bodyStyle(context).copyWith(
                fontStyle: FontStyle.italic,
                color: kcSecondaryTextColor,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
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
              
              // Share both files
              if (result.manifestPath != null) {
                await Share.shareXFiles(
                  [XFile(result.arcxPath!), XFile(result.manifestPath!)],
                  text: 'Secure Archive - $_entryCount entries, $_photoCount photos',
                  subject: 'Encrypted Journal Export',
                );
              }
            },
            child: const Text('Share Files'),
          ),
        ],
      ),
    );
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

  Widget _buildFilePath(String label, String path) {
    // Extract just the filename for display
    final filename = path.split('/').last;
    final truncatedFilename = filename.length > 40 ? '...${filename.substring(filename.length - 40)}' : filename;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: bodyStyle(context).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              truncatedFilename,
              style: bodyStyle(context).copyWith(
                fontFamily: 'monospace',
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
                    'Choose your export format: Legacy MCP (.zip) for compatibility, or Secure Archive (.arcx) with AES-256 encryption.',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can re-import either format at any time to restore your data.',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Export format selection
            Text(
              'Export Format',
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
                  _buildFormatOption(
                    value: 'legacy',
                    groupValue: _exportFormat,
                    title: 'Legacy MCP (.zip)',
                    subtitle: 'Unencrypted package for compatibility',
                    icon: Icons.archive,
                    color: Colors.blue,
                    onChanged: (value) {
                      setState(() {
                        _exportFormat = value!;
                      });
                    },
                  ),
                  const Divider(height: 24),
                  _buildFormatOption(
                    value: 'secure',
                    groupValue: _exportFormat,
                    title: 'Secure Archive (.arcx)',
                    subtitle: 'Encrypted with AES-256-GCM and Ed25519 signing',
                    icon: Icons.lock,
                    color: Colors.green,
                    onChanged: (value) {
                      setState(() {
                        _exportFormat = value!;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Redaction settings (only for secure format)
            if (_exportFormat == 'secure') ...[
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
                        const Icon(Icons.security, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Security & Privacy Settings',
                          style: heading3Style(context).copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildOptionTile(
                      title: 'Include photo labels',
                      subtitle: 'Include AI-generated photo descriptions (may contain sensitive info)',
                      value: _includePhotoLabels,
                      onChanged: (value) {
                        setState(() {
                          _includePhotoLabels = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildOptionTile(
                      title: 'Date-only timestamps',
                      subtitle: 'Reduce timestamp precision to date only (e.g., 2024-01-15 instead of full datetime)',
                      value: _dateOnlyTimestamps,
                      onChanged: (value) {
                        setState(() {
                          _dateOnlyTimestamps = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

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
                    : Text(
                        _exportFormat == 'secure' 
                          ? 'Create Secure Archive (.arcx)'
                          : 'Create MCP Package (.zip)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildFormatOption({
    required String value,
    required String? groupValue,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = groupValue == value;
    
    return InkWell(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: color,
            ),
            const SizedBox(width: 12),
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: heading3Style(context).copyWith(
                      color: isSelected ? color : kcPrimaryTextColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
