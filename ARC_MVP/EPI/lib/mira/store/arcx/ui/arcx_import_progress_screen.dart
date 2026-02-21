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
import '../services/arcx_import_set_index_service.dart';
import '../models/arcx_result.dart';
import 'package:my_app/shared/ui/home/home_view.dart';

class ARCXImportProgressScreen extends StatefulWidget {
  final String arcxPath;
  final String? manifestPath;
  final BuildContext? parentContext; // Context from calling screen for showing dialog
  
  const ARCXImportProgressScreen({
    super.key,
    required this.arcxPath,
    this.manifestPath,
    this.parentContext,
  });

  @override
  State<ARCXImportProgressScreen> createState() => _ARCXImportProgressScreenState();
}

class _ARCXImportProgressScreenState extends State<ARCXImportProgressScreen> {
  String _status = 'Verifying signature...';
  double _progress = 0.0;
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
          onProgress: (message, [fraction = 0.0]) {
            if (mounted) {
              setState(() {
                _status = message;
                _progress = fraction;
              });
            }
          },
        );
        
        // Convert V2 result to display format
        if (v2Result.success) {
          print('🎉 ARCX DEBUG: V2 Import succeeded');
          print('🎉 ARCX DEBUG: Entries: ${v2Result.entriesImported}');
          print('🎉 ARCX DEBUG: Media: ${v2Result.mediaImported}');
          print('🎉 ARCX DEBUG: Chats: ${v2Result.chatsImported}');

          // Record in import set index so "continue import from folder" can skip this file
          try {
            final arcxFile = File(widget.arcxPath);
            if (await arcxFile.exists()) {
              final stat = await arcxFile.stat();
              await ArcxImportSetIndexService.instance.recordImport(
                sourcePath: widget.arcxPath,
                lastModifiedMs: stat.modified.millisecondsSinceEpoch,
                importedEntryIds: v2Result.importedEntryIds ?? {},
                importedChatIds: v2Result.importedChatIds ?? {},
              );
            }
          } catch (_) {}

          setState(() {
            _isLoading = false;
            _status = 'Done';
            _entriesImported = v2Result.entriesImported;
            _photosImported = v2Result.mediaImported;
            _chatSessionsImported = v2Result.chatsImported;
            _chatMessagesImported = 0; // V2 doesn't track message count separately
          });

          print('🎉 ARCX DEBUG: State updated - _entriesImported: $_entriesImported, _photosImported: $_photosImported');
          print('🎉 ARCX DEBUG: UI condition check: ${_entriesImported != null || _photosImported != null}');

          // Show success state briefly, then pop with result
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted && Navigator.of(context).canPop()) {
            print('🎉 ARCX DEBUG: About to pop with result');
            // Pop the progress screen and return the result
            Navigator.of(context).pop(v2Result);
            print('🎉 ARCX DEBUG: Popped with result');
          } else if (mounted) {
            // If we can't pop, try using root navigator
            print('🎉 ARCX DEBUG: Cannot pop normally, trying root navigator');
            Navigator.of(context, rootNavigator: true).pop(v2Result);
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
        
        // Show success state briefly, then pop with result
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          // Pop the progress screen and return the result
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(result);
          } else {
            // Fallback to root navigator
            Navigator.of(context, rootNavigator: true).pop(result);
          }
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
      
      // Pop the progress screen on error
      if (mounted) {
        // Store error message before popping
        final errorMessage = e.toString();
        
        // Try to pop normally first
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          // Fallback to root navigator
          Navigator.of(context, rootNavigator: true).pop();
        }
        
        // Show error after navigation completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              // Try to get a valid context for showing the error
              final navigator = Navigator.of(context, rootNavigator: true);
              if (navigator.canPop() || navigator.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Import failed: $errorMessage'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            } catch (contextError) {
              // Context is invalid, log the error instead
              print('⚠️ Could not show error snackbar: $contextError');
              print('⚠️ Import error: $errorMessage');
            }
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔧 ARCX DEBUG: Building UI - _isLoading: $_isLoading, _error: $_error, _entriesImported: $_entriesImported, _photosImported: $_photosImported');

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
                SizedBox(
                  width: double.infinity,
                  child: LinearProgressIndicator(
                    value: _progress.clamp(0.0, 1.0),
                    backgroundColor: kcSurfaceAltColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(kcPrimaryColor),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _status,
                  style: heading3Style(context).copyWith(
                    color: kcPrimaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_progress * 100).round()}%',
                  style: bodyStyle(context).copyWith(
                    color: kcSecondaryTextColor,
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
                // Import complete - show success content
                // DEBUG: This block should show success UI
                ...[
                  () {
                    print('🎉 ARCX DEBUG: Showing success UI block');
                    print('🎉 ARCX DEBUG: _entriesImported: $_entriesImported');
                    print('🎉 ARCX DEBUG: _photosImported: $_photosImported');
                    print('🎉 ARCX DEBUG: _isLoading: $_isLoading');
                    return Container(); // Empty container just for the debug print
                  }(),
                ],
                const Icon(
                  Icons.check_circle,
                  size: 64,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                Text(
                  'Import Complete',
                  style: heading2Style(context).copyWith(
                    color: kcPrimaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_entriesImported ?? 0} entries imported\n${_photosImported ?? 0} photos imported${_chatSessionsImported != null && _chatSessionsImported! > 0 ? '\n${_chatSessionsImported} chat sessions imported' : ''}',
                  style: bodyStyle(context).copyWith(
                    color: kcSecondaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showImportCompleteDialogV2(ARCXImportResultV2 result) {
    _showImportCompleteDialogV2WithContext(result, context);
  }

  void _showImportCompleteDialogV2WithContext(ARCXImportResultV2 result, BuildContext dialogContext) {
    // Ensure any existing dialog is dismissed first
    Navigator.of(dialogContext, rootNavigator: true).popUntil((route) => !route.navigator!.canPop() || route.isFirst);
    
    showDialog(
      context: dialogContext,
      barrierDismissible: true,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Import Complete', style: heading2Style(context)),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Text(
                  'Your data has been successfully restored!',
                  style: bodyStyle(context),
                ),
                const SizedBox(height: 16),
                _buildSummaryRow(
                  'Entries restored:',
                  result.entriesTotalInArchive != null
                      ? '${result.entriesImported} of ${result.entriesTotalInArchive}'
                          + (result.entriesFailed != null && result.entriesFailed! > 0 ? ' (${result.entriesFailed} failed)' : '')
                      : '${result.entriesImported}',
                ),
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
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        // Navigate to main screen (HomeView)
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const HomeView()),
                          (route) => false, // Remove all previous routes
                        );
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImportCompleteDialog(ARCXImportResult result) {
    _showImportCompleteDialogWithContext(result, context);
  }

  void _showImportCompleteDialogWithContext(ARCXImportResult result, BuildContext dialogContext) {
    // Ensure any existing dialog is dismissed first
    Navigator.of(dialogContext, rootNavigator: true).popUntil((route) => !route.navigator!.canPop() || route.isFirst);
    
    showDialog(
      context: dialogContext,
      barrierDismissible: true,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Import Complete', style: heading2Style(context)),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
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
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        // Navigate to main screen (HomeView)
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const HomeView()),
                          (route) => false, // Remove all previous routes
                        );
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: bodyStyle(context),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: bodyStyle(context).copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

