import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import '../chat_category_models.dart';
import '../enhanced_chat_repo.dart';

/// Screen for exporting and importing chat data
class ChatExportImportScreen extends StatefulWidget {
  final EnhancedChatRepo chatRepo;

  const ChatExportImportScreen({
    super.key,
    required this.chatRepo,
  });

  @override
  State<ChatExportImportScreen> createState() => _ChatExportImportScreenState();
}

class _ChatExportImportScreenState extends State<ChatExportImportScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  String? _exportStatus;
  String? _importStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Export & Import',
          style: heading1Style(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Export Section
            _buildExportSection(),
            const SizedBox(height: 32),
            
            // Import Section
            _buildImportSection(),
            const SizedBox(height: 32),
            
            // Status Messages
            if (_exportStatus != null || _importStatus != null)
              _buildStatusSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildExportSection() {
    return Card(
      color: kcSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.file_download, color: kcPrimaryColor),
                const SizedBox(width: 8),
                Text(
                  'Export Chats',
                  style: heading2Style(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Export your chat history, categories, and settings to a file that can be imported later or shared with others.',
              style: bodyStyle(context).copyWith(color: kcTextSecondaryColor),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _exportAllChats,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: Text(_isExporting ? 'Exporting...' : 'Export All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isExporting ? null : _exportSelectedChats,
                    icon: const Icon(Icons.checklist),
                    label: const Text('Export Selected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kcPrimaryColor,
                      side: BorderSide(color: kcPrimaryColor),
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

  Widget _buildImportSection() {
    return Card(
      color: kcSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.file_upload, color: kcPrimaryColor),
                const SizedBox(width: 8),
                Text(
                  'Import Chats',
                  style: heading2Style(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Import chat data from a previously exported file. You can choose to merge with existing data or replace it.',
              style: bodyStyle(context).copyWith(color: kcTextSecondaryColor),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isImporting ? null : _importChats,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload),
                    label: Text(_isImporting ? 'Importing...' : 'Import File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _isImporting ? null : _showImportOptions,
                  icon: const Icon(Icons.settings),
                  label: const Text('Options'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kcPrimaryColor,
                    side: BorderSide(color: kcPrimaryColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      color: kcSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status',
              style: heading3Style(context),
            ),
            const SizedBox(height: 8),
            if (_exportStatus != null)
              Text(
                _exportStatus!,
                style: bodyStyle(context),
              ),
            if (_importStatus != null)
              Text(
                _importStatus!,
                style: bodyStyle(context),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAllChats() async {
    setState(() {
      _isExporting = true;
      _exportStatus = 'Preparing export...';
    });

    try {
      final exportData = await widget.chatRepo.exportAllData();
      final jsonString = jsonEncode(exportData.toJson());
      
      setState(() {
        _exportStatus = 'Export completed. Sharing file...';
      });

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final fileName = 'lumara_chats_export_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'LUMARA Chat Export - ${exportData.sessions.length} sessions, ${exportData.categories.length} categories',
      );

      setState(() {
        _isExporting = false;
        _exportStatus = 'Export completed and shared successfully!';
      });

      // Clear status after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _exportStatus = null;
          });
        }
      });

    } catch (e) {
      setState(() {
        _isExporting = false;
        _exportStatus = 'Export failed: $e';
      });
    }
  }

  Future<void> _exportSelectedChats() async {
    // This would open a dialog to select specific chats
    // For now, we'll show a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Select chats feature coming soon!'),
      ),
    );
  }

  Future<void> _importChats() async {
    setState(() {
      _isImporting = true;
      _importStatus = 'Selecting file...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final jsonString = await file.readAsString();
        final jsonData = jsonDecode(jsonString);
        
        setState(() {
          _importStatus = 'Parsing import data...';
        });

        final exportData = ChatExportData.fromJson(jsonData);
        
        setState(() {
          _importStatus = 'Importing data...';
        });

        await widget.chatRepo.importData(exportData, merge: true);
        
        setState(() {
          _isImporting = false;
          _importStatus = 'Import completed successfully! ${exportData.sessions.length} sessions imported.';
        });

        // Clear status after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _importStatus = null;
            });
          }
        });

      } else {
        setState(() {
          _isImporting = false;
          _importStatus = 'No file selected';
        });
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _importStatus = 'Import failed: $e';
      });
    }
  }

  void _showImportOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Options'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Merge Mode:'),
            Text('• Merge with existing data (recommended)'),
            Text('• Replace all existing data'),
            SizedBox(height: 16),
            Text('Categories:'),
            Text('• Import new categories'),
            Text('• Map to existing categories'),
            SizedBox(height: 16),
            Text('Sessions:'),
            Text('• Import all sessions'),
            Text('• Skip duplicate sessions'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
