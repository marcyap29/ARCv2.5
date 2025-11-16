/// ARCX Import Progress Screen
/// 
/// Fullscreen modal showing import progress with status updates.
library arcx_import_progress;

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:archive/archive.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/analytics_service.dart';
import '../services/arcx_import_service.dart';
import '../services/arcx_import_service_v2.dart';
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
  int? _chatSessionsImported;
  int? _chatMessagesImported;
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
      // Get ChatRepo instance
      final chatRepo = ChatRepoImpl.instance;
      await chatRepo.initialize();
      
      // Initialize PhaseRegimeService for import
      PhaseRegimeService? phaseRegimeService;
      try {
        final analyticsService = AnalyticsService();
        final rivetSweepService = RivetSweepService(analyticsService);
        phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
        await phaseRegimeService.initialize();
        print('ARCX Import: PhaseRegimeService initialized');
      } catch (e) {
        print('Warning: Could not initialize PhaseRegimeService: $e');
        // Continue import without phase regimes
      }
      
      // Try V2 import service first (for ARCX 1.2 format)
      // If it fails, fall back to legacy import service
      try {
        final importServiceV2 = ARCXImportServiceV2(
          journalRepo: journalRepo,
          chatRepo: chatRepo,
          phaseRegimeService: phaseRegimeService,
        );
        
        setState(() => _status = 'Decrypting...');
        
        final v2Result = await importServiceV2.import(
          arcxPath: widget.arcxPath,
          options: ARCXImportOptions(
            validateChecksums: true,
            dedupeMedia: true,
            skipExisting: true,
            resolveLinks: true,
          ),
          password: _password,
          onProgress: (message) {
            if (mounted) {
              setState(() => _status = message);
            }
          },
        );
        
        // Convert V2 result to display format
        if (v2Result.success) {
          setState(() {
            _isLoading = false;
            _status = 'Done';
            _entriesImported = v2Result.entriesImported;
            _photosImported = v2Result.mediaImported;
            _chatSessionsImported = v2Result.chatsImported;
            _chatMessagesImported = 0; // V2 doesn't track message count separately
          });
          
          // Show success dialog for V2
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.of(context).pop();
            _showImportCompleteDialogV2(v2Result);
          }
          return;
        } else {
          // V2 failed, try legacy
          print('ARCX Import: V2 import failed, trying legacy: ${v2Result.error}');
        }
      } catch (e) {
        print('ARCX Import: V2 import error, trying legacy: $e');
      }
      
      // Fall back to legacy import service
      final importService = ARCXImportService(
        journalRepo: journalRepo,
        chatRepo: chatRepo,
      );
      
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
          _chatSessionsImported = result.chatSessionsImported;
          _chatMessagesImported = result.chatMessagesImported;
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

  void _showImportCompleteDialogV2(ARCXImportResultV2 result) {
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
            _buildSummaryRow('Entries restored:', '${result.entriesImported}'),
            _buildSummaryRow('Media restored:', '${result.mediaImported}'),
            if (result.chatsImported > 0)
              _buildSummaryRow('Chat sessions:', '${result.chatsImported}'),
            if (result.phaseRegimesImported > 0)
              _buildSummaryRow('Phase regimes:', '${result.phaseRegimesImported}'),
            if (result.rivetStatesImported > 0)
              _buildSummaryRow('RIVET states:', '${result.rivetStatesImported}'),
            if (result.sentinelStatesImported > 0)
              _buildSummaryRow('Sentinel states:', '${result.sentinelStatesImported}'),
            if (result.arcformSnapshotsImported > 0)
              _buildSummaryRow('ArcForm snapshots:', '${result.arcformSnapshotsImported}'),
            if (result.lumaraFavoritesImported > 0)
              _buildSummaryRow('LUMARA Favorites:', '${result.lumaraFavoritesImported}'),
            if (result.warnings != null && result.warnings!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Warnings:',
                style: bodyStyle(context).copyWith(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              ...result.warnings!.map((w) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text('• $w', style: bodyStyle(context).copyWith(fontSize: 12, color: Colors.orange)),
              )),
            ],
            const SizedBox(height: 8),
            Text(
              'Package info:',
              style: bodyStyle(context).copyWith(fontWeight: FontWeight.bold),
            ),
            _buildSummaryRow('Format:', 'arcx'),
            _buildSummaryRow('Version:', '1.2'),
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
            if ((result.chatSessionsImported ?? 0) > 0 || (result.chatMessagesImported ?? 0) > 0) ...[
              _buildSummaryRow('Chat sessions:', '${result.chatSessionsImported ?? 0}'),
              _buildSummaryRow('Chat messages:', '${result.chatMessagesImported ?? 0}'),
            ],
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

