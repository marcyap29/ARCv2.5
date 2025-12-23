// lib/shared/ui/settings/google_drive_backup_settings_view.dart
// Google Drive backup settings UI

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/services/google_drive_service.dart';
import 'package:my_app/services/google_drive_backup_settings_service.dart';
import 'package:my_app/services/backup_upload_service.dart';
import 'package:my_app/services/scheduled_backup_service.dart' hide TimeOfDay;
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:intl/intl.dart';

class GoogleDriveBackupSettingsView extends StatefulWidget {
  final JournalRepository journalRepo;

  const GoogleDriveBackupSettingsView({
    super.key,
    required this.journalRepo,
  });

  @override
  State<GoogleDriveBackupSettingsView> createState() => _GoogleDriveBackupSettingsViewState();
}

class _GoogleDriveBackupSettingsViewState extends State<GoogleDriveBackupSettingsView> {
  final GoogleDriveService _driveService = GoogleDriveService.instance;
  final GoogleDriveBackupSettingsService _settingsService = GoogleDriveBackupSettingsService.instance;
  final BackupUploadService _uploadService = BackupUploadService.instance;

  bool _isLoading = false;
  bool _isEnabled = false;
  bool _isAuthenticated = false;
  String? _connectedEmail;
  String? _selectedFolderId;
  String? _selectedFolderName;
  String _backupFormat = 'arcx';
  bool _scheduleEnabled = false;
  String _scheduleFrequency = 'daily';
  String _scheduleTime = '02:00';
  DateTime? _lastBackup;
  bool _isUploading = false;
  String _uploadProgress = '';

  StreamSubscription<BackupUploadResult>? _uploadSubscription;
  StreamSubscription<String>? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _setupUploadListeners();
  }

  @override
  void dispose() {
    _uploadSubscription?.cancel();
    _progressSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      await _settingsService.initialize();
      await _driveService.initialize();

      final isEnabled = await _settingsService.isEnabled();
      final isAuthenticated = _driveService.isAuthenticated;
      final connectedEmail = _driveService.connectedAccountEmail;
      final folderId = await _settingsService.getFolderId();
      final backupFormat = await _settingsService.getBackupFormat();
      final scheduleEnabled = await _settingsService.isScheduleEnabled();
      final scheduleFrequency = await _settingsService.getScheduleFrequency();
      final scheduleTime = await _settingsService.getScheduleTime();
      final lastBackup = await _settingsService.getLastBackup();

      String? folderName;
      if (folderId != null) {
        folderName = await _driveService.getFolderName(folderId);
      }

      setState(() {
        _isEnabled = isEnabled;
        _isAuthenticated = isAuthenticated;
        _connectedEmail = connectedEmail;
        _selectedFolderId = folderId;
        _selectedFolderName = folderName;
        _backupFormat = backupFormat;
        _scheduleEnabled = scheduleEnabled;
        _scheduleFrequency = scheduleFrequency;
        _scheduleTime = scheduleTime;
        _lastBackup = lastBackup;
        _isLoading = false;
      });
    } catch (e) {
      print('Google Drive Backup Settings: Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  void _setupUploadListeners() {
    _uploadSubscription = _uploadService.uploadStream.listen((result) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = '';
        });

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup uploaded successfully to Google Drive'),
              backgroundColor: Colors.green,
            ),
          );
          _loadSettings(); // Refresh to update last backup time
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });

    _progressSubscription = _uploadService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _uploadProgress = progress;
        });
      }
    });
  }

  Future<void> _connectGoogleAccount() async {
    setState(() => _isLoading = true);

    try {
      // Ensure service is initialized
      await _driveService.initialize();
      
      final authenticated = await _driveService.authenticate();
      if (authenticated) {
        await _loadSettings();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to Google Drive'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to Google Drive. Please check your Google account settings.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Google Drive Backup Settings: Connection error: $e');
      print('Stack trace: $stackTrace');
      
      String errorMessage = 'Failed to connect to Google Drive';
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('client id') || 
          errorString.contains('clientid') ||
          errorString.contains('configuration') ||
          errorString.contains('missing')) {
        errorMessage = 'Google Sign-In is not configured. Please configure OAuth in Firebase Console.';
      } else if (errorString.contains('network') || errorString.contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _disconnectGoogleAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google Drive?'),
        content: const Text('This will disable automatic backups to Google Drive. Your existing backups will remain in Google Drive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _driveService.disconnect();
        await _settingsService.setEnabled(false);
        await _loadSettings();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disconnected from Google Drive'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _selectFolder() async {
    if (!_isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect your Google account first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final folders = await _driveService.listFolders();
      
      if (folders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No folders found in Google Drive'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final selectedFolder = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Folder'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return ListTile(
                  title: Text(folder.name ?? 'Unnamed Folder'),
                  onTap: () => Navigator.pop(context, {
                    'id': folder.id ?? '',
                    'name': folder.name ?? 'Unnamed Folder',
                  }),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedFolder != null) {
        final success = await _driveService.selectFolder(selectedFolder['id']!);
        if (success) {
          await _settingsService.setFolderId(selectedFolder['id']);
          setState(() {
            _selectedFolderId = selectedFolder['id'];
            _selectedFolderName = selectedFolder['name'];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Folder selected'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting folder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _setBackupFormat(String format) async {
    await _settingsService.setBackupFormat(format);
    setState(() => _backupFormat = format);
  }

  Future<void> _setScheduleEnabled(bool enabled) async {
    await _settingsService.setScheduleEnabled(enabled);
    setState(() => _scheduleEnabled = enabled);

    // Start or stop scheduled backup service
    if (enabled && _isEnabled && _isAuthenticated) {
      await _startScheduledBackups();
    } else {
      ScheduledBackupService.instance.stop();
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

      await ScheduledBackupService.instance.start(
        journalRepo: widget.journalRepo,
        chatRepo: chatRepo,
        phaseRegimeService: phaseRegimeService,
      );
    } catch (e) {
      print('Google Drive Backup Settings: Error starting scheduled backups: $e');
    }
  }

  Future<void> _triggerManualBackup() async {
    if (!_isAuthenticated || _selectedFolderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect Google Drive and select a folder first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 'Starting backup...';
    });

    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      final chatRepo = ChatRepoImpl.instance;
      await chatRepo.initialize();

      await _uploadService.createAndUploadBackup(
        format: _backupFormat,
        journalRepo: widget.journalRepo,
        chatRepo: chatRepo,
        phaseRegimeService: phaseRegimeService,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleEnabled(bool enabled) async {
    await _settingsService.setEnabled(enabled);
    setState(() => _isEnabled = enabled);

    if (enabled && _isAuthenticated && _selectedFolderId != null) {
      if (_scheduleEnabled) {
        await _startScheduledBackups();
      }
    } else {
      ScheduledBackupService.instance.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: const Text(
          'Google Drive Backup',
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
                  Card(
                    color: kcSurfaceColor,
                    child: SwitchListTile(
                      title: const Text(
                        'Google Drive Backup',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        _isEnabled ? 'Backups will be uploaded to Google Drive' : 'Backups disabled',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      value: _isEnabled,
                      onChanged: _toggleEnabled,
                      activeColor: kcAccentColor,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Connection Status
                  _buildSection(
                    context,
                    title: 'Connection',
                    children: [
                      if (!_isAuthenticated)
                        ElevatedButton.icon(
                          onPressed: _connectGoogleAccount,
                          icon: const Icon(Icons.cloud),
                          label: const Text('Connect Google Account'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Connected: $_connectedEmail',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _disconnectGoogleAccount,
                                  child: const Text('Disconnect'),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Folder Selection
                  if (_isAuthenticated)
                    _buildSection(
                      context,
                      title: 'Backup Folder',
                      children: [
                        ListTile(
                          title: const Text(
                            'Selected Folder',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            _selectedFolderName ?? 'No folder selected',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          trailing: ElevatedButton(
                            onPressed: _selectFolder,
                            child: const Text('Select Folder'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kcAccentColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                  if (_isAuthenticated) const SizedBox(height: 24),

                  // Backup Format
                  if (_isAuthenticated && _selectedFolderId != null)
                    _buildSection(
                      context,
                      title: 'Backup Format',
                      children: [
                        RadioListTile<String>(
                          title: const Text(
                            'ARCX (Encrypted)',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Secure encrypted archive format',
                            style: TextStyle(color: Colors.grey),
                          ),
                          value: 'arcx',
                          groupValue: _backupFormat,
                          onChanged: (value) => _setBackupFormat(value!),
                          activeColor: kcAccentColor,
                        ),
                        RadioListTile<String>(
                          title: const Text(
                            'MCP/ZIP',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Standard ZIP format with MCP structure',
                            style: TextStyle(color: Colors.grey),
                          ),
                          value: 'mcp',
                          groupValue: _backupFormat,
                          onChanged: (value) => _setBackupFormat(value!),
                          activeColor: kcAccentColor,
                        ),
                      ],
                    ),

                  if (_isAuthenticated && _selectedFolderId != null) const SizedBox(height: 24),

                  // Scheduled Backups
                  if (_isAuthenticated && _selectedFolderId != null)
                    _buildSection(
                      context,
                      title: 'Scheduled Backups',
                      children: [
                        SwitchListTile(
                          title: const Text(
                            'Automatic Backups',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Automatically backup to Google Drive on a schedule',
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

                  if (_isAuthenticated && _selectedFolderId != null) const SizedBox(height: 24),

                  // Manual Backup
                  if (_isAuthenticated && _selectedFolderId != null)
                    _buildSection(
                      context,
                      title: 'Manual Backup',
                      children: [
                        if (_isUploading)
                          Column(
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                _uploadProgress,
                                style: TextStyle(color: Colors.grey[400]),
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

                  if (_isAuthenticated && _selectedFolderId != null) const SizedBox(height: 24),

                  // Last Backup
                  if (_lastBackup != null)
                    _buildSection(
                      context,
                      title: 'Last Backup',
                      children: [
                        ListTile(
                          title: const Text(
                            'Last Successful Backup',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            DateFormat('MMM d, y • h:mm a').format(_lastBackup!),
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          leading: const Icon(Icons.check_circle, color: Colors.green),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: kcSurfaceColor,
          child: Column(children: children),
        ),
      ],
    );
  }
}

