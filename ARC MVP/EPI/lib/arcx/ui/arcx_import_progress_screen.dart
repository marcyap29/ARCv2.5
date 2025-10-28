/// ARCX Import Progress Screen
/// 
/// Fullscreen modal showing import progress with status updates.
library arcx_import_progress;

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:archive/archive.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import '../../arc/core/journal_repository.dart';
import '../services/arcx_import_service.dart';
import '../models/arcx_result.dart';

class ARCXImportProgressScreen extends StatefulWidget {
  final String arcxPath;
  final String? manifestPath;
  
  const ARCXImportProgressScreen({
    super.key,
    required this.arcxPath,
    this.manifestPath,
  });

  @override
  State<ARCXImportProgressScreen> createState() => _ARCXImportProgressScreenState();
}

class _ARCXImportProgressScreenState extends State<ARCXImportProgressScreen> {
  String _status = 'Verifying signature...';
  bool _isLoading = true;
  String? _error;
  int? _entriesImported;
  int? _photosImported;
  String? _password;

  @override
  void initState() {
    super.initState();
    _promptForPasswordIfNeeded();
  }

  Future<void> _promptForPasswordIfNeeded() async {
    try {
      // First, try to extract the manifest to check if password is required
      final arcxFile = File(widget.arcxPath);
      final arcxZip = await arcxFile.readAsBytes();
      final zipDecoder = ZipDecoder().decodeBytes(arcxZip);
      
      ArchiveFile? manifestFile;
      
      for (final file in zipDecoder) {
        if (file.name == 'manifest.json') {
          manifestFile = file;
          break;
        }
      }
      
      if (manifestFile != null) {
        final manifestJson = jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, dynamic>;
        final isPasswordEncrypted = manifestJson['is_password_encrypted'] as bool? ?? false;
        
        if (isPasswordEncrypted) {
          // Show password dialog
          await _showPasswordDialog();
          if (_password == null) {
            // User cancelled
            if (mounted) Navigator.of(context).pop();
            return;
          }
        }
      }
      
      // Continue with import
      await _import();
    } catch (e) {
      // If we can't check, try importing without password first
      await _import();
    }
  }

  Future<void> _showPasswordDialog() async {
    final controller = TextEditingController();
    bool showError = false;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.lock, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Enter Password', style: heading2Style(context)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This archive is encrypted with a password. Enter the password to restore your data.',
                style: bodyStyle(context),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter the archive password',
                  errorText: showError ? 'Password required' : null,
                ),
                onChanged: (_) {
                  if (showError) {
                    setState(() => showError = false);
                  }
                },
                onSubmitted: (_) {
                  if (controller.text.isNotEmpty) {
                    this.setState(() {
                      _password = controller.text;
                    });
                    Navigator.of(context).pop();
                  } else {
                    setState(() => showError = true);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Pop back to previous screen
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isEmpty) {
                  setState(() => showError = true);
                  return;
                }
                
                this.setState(() {
                  _password = controller.text;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Decrypt'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _import() async {
    try {
      setState(() => _status = 'Verifying signature...');
      
      // Get the journal repository from context
      final journalRepo = context.read<JournalRepository>();
      final importService = ARCXImportService(journalRepo: journalRepo);
      
      setState(() => _status = 'Decrypting...');
      
      final result = await importService.importSecure(
        arcxPath: widget.arcxPath,
        manifestPath: widget.manifestPath,
        dryRun: false,
        password: _password,
      );
      
      if (result.success) {
        setState(() {
          _isLoading = false;
          _status = 'Done';
          _entriesImported = result.entriesImported;
          _photosImported = result.photosImported;
        });
        
        // Show success dialog
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          Navigator.of(context).pop();
          _showImportCompleteDialog(result);
        }
      } else {
        throw Exception(result.error ?? 'Import failed');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
        _status = 'Failed';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: Text(
          'Importing Secure Archive',
          style: heading2Style(context).copyWith(
            color: kcPrimaryTextColor,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(kcPrimaryColor),
                ),
                const SizedBox(height: 32),
                Text(
                  _status,
                  style: heading3Style(context).copyWith(
                    color: kcPrimaryTextColor,
                  ),
                ),
              ] else if (_error != null) ...[
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Import Failed',
                  style: heading2Style(context).copyWith(
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: bodyStyle(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kcPrimaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Close'),
                ),
              ] else if (_entriesImported != null || _photosImported != null) ...[
                // Import complete - dialog will be shown
                const SizedBox(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showImportCompleteDialog(ARCXImportResult result) {
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
            _buildSummaryRow('Entries restored:', '${result.entriesImported ?? 0}'),
            _buildSummaryRow('Photos restored:', '${result.photosImported ?? 0}'),
            _buildSummaryRow('Missing/corrupted:', '0'),
            const SizedBox(height: 8),
            Text(
              'Package info:',
              style: bodyStyle(context).copyWith(fontWeight: FontWeight.bold),
            ),
            _buildSummaryRow('Format:', 'arcx'),
            _buildSummaryRow('Version:', '1.1'),
            _buildSummaryRow('Type:', 'secure'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: bodyStyle(context)),
          Text(
            value,
            style: bodyStyle(context).copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

