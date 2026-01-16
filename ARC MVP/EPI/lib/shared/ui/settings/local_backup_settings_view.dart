// lib/shared/ui/settings/local_backup_settings_view.dart
// Local backup settings UI

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/services/local_backup_settings_service.dart';
import 'package:my_app/services/local_backup_service.dart';
import 'package:my_app/services/scheduled_local_backup_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/mira/store/arcx/services/arcx_export_service_v2.dart';
import 'package:my_app/services/export_history_service.dart';
import 'package:intl/intl.dart';

class LocalBackupSettingsView extends StatefulWidget {
  final JournalRepository journalRepo;

  const LocalBackupSettingsView({
    super.key,
    required this.journalRepo,
  });

  @override
  State<LocalBackupSettingsView> createState() => _LocalBackupSettingsViewState();
}

class _LocalBackupSettingsViewState extends State<LocalBackupSettingsView> {
  final LocalBackupSettingsService _settingsService = LocalBackupSettingsService.instance;
  final LocalBackupService _backupService = LocalBackupService.instance;

  bool _isLoading = false;
  bool _isEnabled = false;
  String? _backupPath;
  String _backupFormat = 'arcx';
  bool _scheduleEnabled = false;
  String _scheduleFrequency = 'daily';
  String _scheduleTime = '02:00';
  DateTime? _lastBackup;
  bool _isBackingUp = false;
  String _backupProgress = '';
  int _backupPercentage = 0;
  
  // Incremental backup state
  bool _isLoadingPreview = false;
  Map<String, dynamic>? _incrementalPreview;
  Map<String, dynamic>? _historySummary;

  StreamSubscription<String>? _progressSubscription;
  StreamSubscription<int>? _percentageSubscription;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _setupBackupListeners();
    _loadBackupInfo();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _percentageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      await _settingsService.initialize();

      final isEnabled = await _settingsService.isEnabled();
      final backupPath = await _settingsService.getBackupPath();
      final backupFormat = await _settingsService.getBackupFormat();
      final scheduleEnabled = await _settingsService.isScheduleEnabled();
      final scheduleFrequency = await _settingsService.getScheduleFrequency();
      final scheduleTime = await _settingsService.getScheduleTime();
      final lastBackup = await _settingsService.getLastBackup();

      setState(() {
        _isEnabled = isEnabled;
        _backupPath = backupPath;
        _backupFormat = backupFormat;
        _scheduleEnabled = scheduleEnabled;
        _scheduleFrequency = scheduleFrequency;
        _scheduleTime = scheduleTime;
        _lastBackup = lastBackup;
        _isLoading = false;
      });
    } catch (e) {
      print('Local Backup Settings: Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadBackupInfo() async {
    if (!_isEnabled || _backupPath == null) return;
    
    setState(() => _isLoadingPreview = true);
    
    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      final chatRepo = ChatRepoImpl.instance;
      await chatRepo.initialize();
      
      final exportService = ARCXExportServiceV2(
        journalRepo: widget.journalRepo,
        chatRepo: chatRepo,
        phaseRegimeService: phaseRegimeService,
      );
      
      final preview = await exportService.getIncrementalExportPreview();
      final history = await ExportHistoryService.instance.getSummary();
      
      if (mounted) {
        setState(() {
          _incrementalPreview = preview;
          _historySummary = history;
          _isLoadingPreview = false;
        });
      }
    } catch (e) {
      print('Local Backup Settings: Error loading backup info: $e');
      if (mounted) {
        setState(() => _isLoadingPreview = false);
      }
    }
  }

  void _setupBackupListeners() {
    _progressSubscription = _backupService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _backupProgress = progress;
        });
      }
    });

    _percentageSubscription = _backupService.percentageStream.listen((percentage) {
      if (mounted) {
        setState(() {
          _backupPercentage = percentage;
        });
      }
    });
  }

  Future<void> _selectBackupFolder() async {
    try {
      String? selectedPath = await FilePicker.platform.getDirectoryPath();
      
      if (selectedPath != null) {
        // Check if path is restricted
        if (_isRestrictedPath(selectedPath)) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: kcBackgroundColor,
              title: const Text('Restricted Location', style: TextStyle(color: Colors.white)),
              content: Text(
                'The selected folder may have write restrictions (like iCloud Drive). '
                'Backups may fail. Continue anyway?',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Continue Anyway'),
                ),
              ],
            ),
          );
          
          if (confirmed != true) {
            return; // User cancelled
          }
        }
        
        await _settingsService.setBackupPath(selectedPath);
        setState(() {
          _backupPath = selectedPath;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup folder selected: ${path.basename(selectedPath)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Reload backup info after folder selection
        await _loadBackupInfo();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting folder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _useAppDocumentsFolder() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(path.join(appDocDir.path, 'ARCX_Backups'));
      
      // Create directory if it doesn't exist
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      await _settingsService.setBackupPath(backupDir.path);
      setState(() {
        _backupPath = backupDir.path;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Using app documents folder (recommended)'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
      // Reload backup info
      await _loadBackupInfo();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error setting app documents folder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  bool _isRestrictedPath(String path) {
    // Check for iCloud Drive or other restricted paths
    final lowerPath = path.toLowerCase();
    return lowerPath.contains('icloud') || 
           lowerPath.contains('clouddocs') ||
           lowerPath.contains('mobile documents');
  }

  Future<void> _setBackupFormat(String format) async {
    await _settingsService.setBackupFormat(format);
    setState(() => _backupFormat = format);
  }

  Future<void> _setScheduleEnabled(bool enabled) async {
    await _settingsService.setScheduleEnabled(enabled);
    setState(() => _scheduleEnabled = enabled);

    if (enabled && _isEnabled && _backupPath != null) {
      await _startScheduledBackups();
    } else {
      ScheduledLocalBackupService.instance.stop();
    }
  }

  Future<void> _setScheduleFrequency(String frequency) async {
    await _settingsService.setScheduleFrequency(frequency);
    setState(() => _scheduleFrequency = frequency);
  }

  Future<void> _setScheduleTime(String time) async {
    await _settingsService.setScheduleTime(time);
    setState(() => _scheduleTime = time);
  }

  Future<void> _startScheduledBackups() async {
    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      final chatRepo = ChatRepoImpl.instance;
      await chatRepo.initialize();

      await ScheduledLocalBackupService.instance.start(
        journalRepo: widget.journalRepo,
        chatRepo: chatRepo,
        phaseRegimeService: phaseRegimeService,
      );
    } catch (e) {
      print('Local Backup Settings: Error starting scheduled backups: $e');
    }
  }

  Future<void> _triggerManualBackup() async {
    // Default to incremental backup
    await _performIncrementalBackup();
  }
  
  Future<void> _performIncrementalBackup({bool excludeMedia = false}) async {
    if (_backupPath == null || _backupPath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a backup folder first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isBackingUp = true;
      _backupProgress = 'Starting incremental backup...';
      _backupPercentage = 0;
    });

    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      final chatRepo = ChatRepoImpl.instance;
      await chatRepo.initialize();
      
      final exportService = ARCXExportServiceV2(
        journalRepo: widget.journalRepo,
        chatRepo: chatRepo,
        phaseRegimeService: phaseRegimeService,
      );
      
      // Clean and validate backup path
      final cleanBackupPath = _backupPath!.trim();
      final outputDir = Directory(cleanBackupPath);
      
      // Verify directory exists or can be created
      if (!await outputDir.exists()) {
        try {
          await outputDir.create(recursive: true);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cannot create backup folder: $e. Please select a different folder.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
      
      final result = await exportService.exportIncremental(
        outputDir: outputDir,
        password: null,
        excludeMedia: excludeMedia,
        onProgress: (msg) {
          if (mounted) {
            setState(() {
              _backupProgress = msg;
            });
          }
        },
      );

      if (result.success) {
        await _loadSettings();
        await _loadBackupInfo();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Incremental backup complete: ${result.entriesExported} entries, ${result.chatsExported} chats'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Show error in a dialog for better readability (especially for disk space errors)
        if (mounted) {
          _showBackupErrorDialog(result.error ?? 'Unknown error');
        }
      }
    } catch (e) {
      if (mounted) {
        _showBackupErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _backupProgress = '';
          _backupPercentage = 0;
        });
      }
    }
  }
  
  Future<void> _performFullBackup() async {
    if (_backupPath == null || _backupPath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a backup folder first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isBackingUp = true;
      _backupProgress = 'Starting full backup...';
      _backupPercentage = 0;
    });

    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      final chatRepo = ChatRepoImpl.instance;
      await chatRepo.initialize();
      
      final exportService = ARCXExportServiceV2(
        journalRepo: widget.journalRepo,
        chatRepo: chatRepo,
        phaseRegimeService: phaseRegimeService,
      );
      
      // Clean and validate backup path
      final cleanBackupPath = _backupPath!.trim();
      final outputDir = Directory(cleanBackupPath);
      
      // Verify directory exists or can be created
      if (!await outputDir.exists()) {
        try {
          await outputDir.create(recursive: true);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cannot create backup folder: $e. Please select a different folder.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
      
      // Use chunked backup (splits into ~200MB files)
      final result = await exportService.exportFullBackupChunked(
        outputDir: outputDir,
        password: null,
        chunkSizeMB: 200, // Split at 200MB per chunk
        onProgress: (msg) {
          if (mounted) {
            setState(() {
              _backupProgress = msg;
            });
          }
        },
      );

      if (result.success) {
        await _loadSettings();
        await _loadBackupInfo();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Full backup complete: ${result.totalChunks} file(s), '
              '${result.totalEntries} entries, ${result.totalChats} chats'
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        
        // Show additional info dialog if multiple chunks were created
        if (result.totalChunks > 1 && mounted) {
          _showChunkedBackupInfoDialog(result);
        }
      } else {
        // Show error in a dialog for better readability (especially for disk space errors)
        if (mounted) {
          _showBackupErrorDialog(result.error ?? 'Unknown error');
        }
      }
    } catch (e) {
      if (mounted) {
        _showBackupErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _backupProgress = '';
          _backupPercentage = 0;
        });
      }
    }
  }
  
  Future<void> _showChunkedBackupInfoDialog(ChunkedBackupResult result) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcBackgroundColor,
        title: Row(
          children: [
            Icon(Icons.folder, color: Colors.green[300], size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Backup Complete',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your data has been split into ${result.totalChunks} files (~200MB each):',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Folder: ${path.basename(result.folderPath)}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    ...result.chunkPaths.map((chunkPath) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.file_present, size: 16, color: Colors.white54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              path.basename(chunkPath),
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Files are numbered sequentially (001, 002, etc.) from oldest to newest entries.',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showBackupErrorDialog(String error) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcBackgroundColor,
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[300], size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Backup Failed',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            error,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showClearHistoryDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcBackgroundColor,
        title: const Text('Clear Backup History?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will reset the backup tracker. Your next backup will include '
          'all entries (full backup). Existing backup files are not affected.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: kcDangerColor),
            child: const Text('Clear History'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await ExportHistoryService.instance.clearHistory();
      await _loadBackupInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup history cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Today at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  Future<void> _toggleEnabled(bool enabled) async {
    await _settingsService.setEnabled(enabled);
    setState(() => _isEnabled = enabled);

    if (enabled && _backupPath != null) {
      if (_scheduleEnabled) {
        await _startScheduledBackups();
      }
    } else {
      ScheduledLocalBackupService.instance.stop();
    }
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: heading2Style(context).copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: const Text(
          'Local Backup',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enable/Disable Toggle
                  _buildSection(
                    title: 'Backup Settings',
                    children: [
                      SwitchListTile(
                        title: const Text(
                          'Enable Local Backup',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          _isEnabled ? 'Backups will be saved to selected folder' : 'Backups disabled',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        value: _isEnabled,
                        onChanged: _toggleEnabled,
                        activeColor: kcAccentColor,
                      ),
                    ],
                  ),

                  if (_isEnabled) ...[
                    // Instructions Card
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[300], size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Where to Save Backups',
                                  style: heading3Style(context).copyWith(
                                    color: Colors.blue[200],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Recommended: Use "On My iPhone" → "ARC" or "Documents" folder.\n\n'
                            'Avoid: iCloud Drive folders (they have restricted write permissions).\n\n'
                            'Tip: Create a new folder in Files app first, then select it here.',
                            style: bodyStyle(context).copyWith(
                              color: Colors.blue[100],
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _useAppDocumentsFolder,
                            icon: const Icon(Icons.phone_iphone, size: 18),
                            label: const Text('Use App Documents (Recommended)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Backup Folder Selection
                    _buildSection(
                      title: 'Backup Folder',
                      children: [
                        ListTile(
                          title: const Text(
                            'Selected Folder',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _backupPath ?? 'No folder selected',
                                style: TextStyle(color: Colors.grey[400]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_backupPath != null && _isRestrictedPath(_backupPath!))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning, color: Colors.orange[300], size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        'This location may have write restrictions',
                                        style: TextStyle(
                                          color: Colors.orange[300],
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: _selectBackupFolder,
                            child: const Text('Select Folder'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kcAccentColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Backup Format
                    _buildSection(
                      title: 'Backup Format',
                      children: [
                        RadioListTile<String>(
                          title: const Text(
                            'ARCX Format',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Encrypted ARC archive format',
                            style: TextStyle(color: Colors.grey),
                          ),
                          value: 'arcx',
                          groupValue: _backupFormat,
                          onChanged: (value) => _setBackupFormat(value!),
                          activeColor: kcAccentColor,
                        ),
                        RadioListTile<String>(
                          title: const Text(
                            'ZIP Format',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Standard ZIP format with MCP structure',
                            style: TextStyle(color: Colors.grey),
                          ),
                          value: 'zip',
                          groupValue: _backupFormat,
                          onChanged: (value) => _setBackupFormat(value!),
                          activeColor: kcAccentColor,
                        ),
                      ],
                    ),

                    if (_backupPath != null) const SizedBox(height: 24),

                    // Scheduled Backups
                    if (_backupPath != null)
                      _buildSection(
                        title: 'Scheduled Backups',
                        children: [
                          SwitchListTile(
                            title: const Text(
                              'Automatic Backups',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: const Text(
                              'Automatically backup on a schedule',
                              style: TextStyle(color: Colors.grey),
                            ),
                            value: _scheduleEnabled,
                            onChanged: _setScheduleEnabled,
                            activeColor: kcAccentColor,
                          ),
                          if (_scheduleEnabled) ...[
                            const SizedBox(height: 16),
                            ListTile(
                              title: const Text(
                                'Frequency',
                                style: TextStyle(color: Colors.white),
                              ),
                              trailing: DropdownButton<String>(
                                value: _scheduleFrequency,
                                items: const [
                                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                                ],
                                onChanged: (value) {
                                  if (value != null) _setScheduleFrequency(value);
                                },
                                dropdownColor: kcSurfaceColor,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            ListTile(
                              title: const Text(
                                'Time',
                                style: TextStyle(color: Colors.white),
                              ),
                              trailing: TextButton(
                                onPressed: () async {
                                  final timeParts = _scheduleTime.split(':');
                                  final initialTime = TimeOfDay(
                                    hour: int.parse(timeParts[0]),
                                    minute: int.parse(timeParts[1]),
                                  );
                                  final selectedTime = await showTimePicker(
                                    context: context,
                                    initialTime: initialTime,
                                  );
                                  if (selectedTime != null) {
                                    final timeString = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                                    _setScheduleTime(timeString);
                                  }
                                },
                                child: Text(
                                  _scheduleTime,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                    if (_backupPath != null) ...[
                      const SizedBox(height: 24),
                      
                      // Incremental Backup Card
                      _buildIncrementalBackupCard(),
                      
                      const SizedBox(height: 16),
                      
                      // Full Backup Card
                      _buildFullBackupCard(),
                      
                      const SizedBox(height: 16),
                      
                      // Backup History Card
                      _buildBackupHistoryCard(),
                      
                      const SizedBox(height: 24),
                    ],

                    // Manual Backup (Legacy - kept for compatibility)
                    if (_backupPath != null)
                      _buildSection(
                        title: 'Manual Backup',
                        children: [
                          if (_isBackingUp)
                            Column(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: CircularProgressIndicator(
                                        value: _backupPercentage > 0 ? _backupPercentage / 100 : null,
                                        strokeWidth: 4,
                                        backgroundColor: Colors.grey[800],
                                        valueColor: AlwaysStoppedAnimation<Color>(kcAccentColor),
                                      ),
                                    ),
                                    Text(
                                      '$_backupPercentage%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[900],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[700]!),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.save_alt,
                                        color: kcAccentColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _backupProgress.isNotEmpty
                                              ? _backupProgress
                                              : 'Preparing backup...',
                                          style: TextStyle(
                                            color: Colors.grey[300],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: _triggerManualBackup,
                              icon: const Icon(Icons.backup),
                              label: const Text('Backup Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                minimumSize: const Size(double.infinity, 50),
                              ),
                            ),
                        ],
                      ),

                    // Last Backup
                    if (_lastBackup != null)
                      _buildSection(
                        title: 'Last Backup',
                        children: [
                          ListTile(
                            title: const Text(
                              'Last Backup Time',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              DateFormat('MMM dd, yyyy • hh:mm a').format(_lastBackup!),
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                            leading: const Icon(Icons.check_circle, color: Colors.green),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
    );
  }
  
  Widget _buildIncrementalBackupCard() {
    final preview = _incrementalPreview;
    final hasChanges = preview?['hasChanges'] ?? false;
    final newEntries = preview?['newEntries'] ?? 0;
    final newChats = preview?['newChats'] ?? 0;
    final newMedia = preview?['newMedia'] ?? 0;
    final lastExport = preview?['lastExportDate'] as DateTime?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kcAccentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: kcAccentColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Backup',
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Export only new entries since last backup',
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
          const SizedBox(height: 16),
          
          // Preview info
          if (_isLoadingPreview)
            const Center(child: CircularProgressIndicator())
          else if (preview != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  if (lastExport != null)
                    _buildPreviewRow(
                      'Last backup',
                      _formatDate(lastExport),
                      Icons.history,
                    ),
                  _buildPreviewRow(
                    'New entries',
                    '$newEntries',
                    Icons.article_outlined,
                  ),
                  _buildPreviewRow(
                    'New chats',
                    '$newChats',
                    Icons.chat_bubble_outline,
                  ),
                  _buildPreviewRow(
                    'New media',
                    '$newMedia',
                    Icons.photo_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Backup options
          if (hasChanges && newMedia > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[300], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$newMedia new media items will be included. This may create a large backup.',
                      style: TextStyle(
                        color: Colors.orange[200],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Action buttons
          Row(
            children: [
              // Text-only incremental backup (smaller, faster)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasChanges && !_isBackingUp 
                      ? () => _performIncrementalBackup(excludeMedia: true)
                      : null,
                  icon: const Icon(Icons.text_fields, size: 18),
                  label: const Text('Text Only'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kcSecondaryTextColor,
                    side: BorderSide(color: kcSecondaryTextColor.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Full incremental backup (includes media)
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: hasChanges && !_isBackingUp 
                      ? () => _performIncrementalBackup(excludeMedia: false)
                      : null,
                  icon: const Icon(Icons.backup, size: 18),
                  label: Text(hasChanges ? 'Backup All' : 'No New Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kcAccentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          if (hasChanges && newMedia > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Tip: Use "Text Only" for frequent backups. Media can be backed up separately.',
              style: TextStyle(
                color: kcSecondaryTextColor.withOpacity(0.7),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildFullBackupCard() {
    final totalEntries = _incrementalPreview?['totalEntries'] ?? 0;
    final totalChats = _incrementalPreview?['totalChats'] ?? 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_download, color: kcSecondaryTextColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Full Backup',
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Export ALL files: $totalEntries entries, $totalChats chats, and ALL media files',
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
          const SizedBox(height: 12),
          // Chunked backup info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.blue[300], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Automatically splits into ~200MB files for easier management',
                    style: TextStyle(
                      color: Colors.blue[200],
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: !_isBackingUp ? _performFullBackup : null,
              icon: const Icon(Icons.backup),
              label: const Text('Create Full Backup'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kcSecondaryTextColor,
                side: BorderSide(color: kcSecondaryTextColor.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBackupHistoryCard() {
    final history = _historySummary;
    if (history == null) return const SizedBox.shrink();
    
    final totalExports = history['totalExports'] ?? 0;
    final entriesExported = history['entriesExported'] ?? 0;
    final lastFullBackup = history['lastFullBackupDate'] as DateTime?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backup History',
            style: heading3Style(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _buildHistoryRow('Total backups', '$totalExports'),
          _buildHistoryRow('Entries backed up', '$entriesExported'),
          if (lastFullBackup != null)
            _buildHistoryRow('Last full backup', _formatDate(lastFullBackup)),
          
          const SizedBox(height: 12),
          TextButton(
            onPressed: _showClearHistoryDialog,
            child: Text(
              'Clear History (Force Full Backup)',
              style: TextStyle(color: kcDangerColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPreviewRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: kcSecondaryTextColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: bodyStyle(context).copyWith(
              color: kcPrimaryTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHistoryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: bodyStyle(context).copyWith(
              color: kcPrimaryTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

