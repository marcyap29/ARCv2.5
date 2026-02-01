// Google Drive settings for export/import backup via OAuth.
// Connect with Google (drive.file scope), then export backups to Drive or import from Drive.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/google_drive_service.dart';
import 'package:my_app/mira/store/arcx/services/arcx_export_service_v2.dart';
import 'package:my_app/mira/store/mcp/export/zip_utils.dart';
import 'package:my_app/mira/store/mcp/import/mcp_pack_import_service.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/shared/ui/home/home_view.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleDriveSettingsView extends StatefulWidget {
  final JournalRepository journalRepo;

  const GoogleDriveSettingsView({
    super.key,
    required this.journalRepo,
  });

  @override
  State<GoogleDriveSettingsView> createState() => _GoogleDriveSettingsViewState();
}

class _GoogleDriveSettingsViewState extends State<GoogleDriveSettingsView> {
  final GoogleDriveService _driveService = GoogleDriveService.instance;

  bool _loading = true;
  bool _connecting = false;
  String? _accountEmail;
  bool _exporting = false;
  String _exportProgress = '';
  bool _importing = false;
  List<drive.File> _driveFiles = [];
  bool _loadingFiles = false;

  @override
  void initState() {
    super.initState();
    _refreshConnection();
  }

  Future<void> _refreshConnection() async {
    setState(() => _loading = true);
    try {
      final restored = await _driveService.restoreSession();
      if (mounted) {
        setState(() {
          _accountEmail = _driveService.currentUserEmail;
          if (!restored && _driveService.isSignedIn) {
            _accountEmail = _driveService.currentUserEmail;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _accountEmail = null;
          _loading = false;
        });
      }
    }
  }

  Future<void> _connect() async {
    setState(() => _connecting = true);
    try {
      final email = await _driveService.signIn();
      if (mounted) {
        setState(() {
          _accountEmail = email;
          _connecting = false;
        });
        if (email != null) {
          await _ensureFolder();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Connected as $email'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _connecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not connect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    await _driveService.signOut();
    if (mounted) {
      setState(() {
        _accountEmail = null;
        _driveFiles = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disconnected from Google Drive'),
          backgroundColor: Colors.grey,
        ),
      );
    }
  }

  Future<void> _ensureFolder() async {
    try {
      await _driveService.getOrCreateAppFolder();
    } catch (e) {
      debugPrint('GoogleDriveSettingsView: ensure folder: $e');
    }
  }

  Future<void> _exportToDrive() async {
    if (!_driveService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect Google Drive first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      _exporting = true;
      _exportProgress = 'Preparing export...';
    });
    Directory? tempDir;
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

      final appDocDir = await getApplicationDocumentsDirectory();
      final outputDir = Directory(path.join(appDocDir.path, 'arcx_drive_export_${DateTime.now().millisecondsSinceEpoch}'));
      await outputDir.create(recursive: true);
      tempDir = outputDir;

      if (!mounted) return;
      setState(() => _exportProgress = 'Exporting backup...');

      final result = await exportService.exportFullBackupChunked(
        outputDir: outputDir,
        password: null,
        chunkSizeMB: 200,
        onProgress: (msg, [fraction]) {
          if (mounted) {
            setState(() => _exportProgress = msg);
          }
        },
      );

      if (!result.success) {
        if (mounted) {
          setState(() => _exporting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Export failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() => _exportProgress = 'Uploading arcx files (smallest first)...');

      final manifestTimestamp = DateTime.now().toUtc().toIso8601String();
      await _driveService.uploadChunkedBackup(
        arcxPaths: result.chunkPaths,
        manifestTimestamp: manifestTimestamp,
        onProgress: (current, total, phase) {
          if (mounted) setState(() => _exportProgress = phase);
        },
      );

      if (mounted) {
        setState(() {
          _exporting = false;
          _exportProgress = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup uploaded to Google Drive'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _exporting = false;
          _exportProgress = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (tempDir != null) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<void> _loadDriveFiles() async {
    if (!_driveService.isSignedIn) return;
    setState(() => _loadingFiles = true);
    try {
      final files = await _driveService.listFiles(pageSize: 50);
      if (mounted) {
        setState(() {
          _driveFiles = files.where((f) {
            final n = f.name;
            if (n == null) return false;
            return n.endsWith('.zip') ||
                n.endsWith('.arcx') ||
                (n.startsWith('arc_backup_manifest_') && n.endsWith('.json'));
          }).toList();
          _loadingFiles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingFiles = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not list files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importFromDrive(drive.File file) async {
    if (file.id == null) return;
    final fileId = file.id!;
    final isManifestBackup = file.name != null &&
        file.name!.startsWith('arc_backup_manifest_') &&
        file.name!.endsWith('.json');

    setState(() => _importing = true);
    try {
      String zipPath;
      Directory? tempDirToDelete;

      if (isManifestBackup) {
        final folderPath = await _driveService.downloadChunkedBackup(fileId);
        tempDirToDelete = Directory(folderPath);
        final zipFile = await ZipUtils.zipDirectory(
          tempDirToDelete,
          zipFileName: 'arc_restore_${DateTime.now().millisecondsSinceEpoch}.zip',
        );
        zipPath = zipFile.path;
      } else {
        zipPath = await _driveService.downloadToTempFile(fileId, suggestedName: file.name);
      }

      final fileObj = File(zipPath);
      if (!await fileObj.exists()) {
        throw Exception('Downloaded file not found');
      }

      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      PhaseRegimeService? phaseRegimeService;
      try {
        phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
        await phaseRegimeService.initialize();
      } catch (e) {
        debugPrint('PhaseRegimeService init: $e');
      }
      final chatRepo = ChatRepoImpl.instance;
      await chatRepo.initialize();

      final importService = McpPackImportService(
        journalRepo: widget.journalRepo,
        phaseRegimeService: phaseRegimeService,
        chatRepo: chatRepo,
      );
      final importResult = await importService.importFromPath(zipPath);

      if (tempDirToDelete != null) {
        try {
          await tempDirToDelete.delete(recursive: true);
        } catch (_) {}
      }
      try {
        if (isManifestBackup) await File(zipPath).delete();
      } catch (_) {}

      if (mounted) {
        setState(() => _importing = false);
        try {
          if (context.mounted) context.read<TimelineCubit>().reloadAllEntries();
        } catch (_) {}
        if (importResult.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported ${importResult.totalEntries} entries, ${importResult.totalPhotos} media'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeView(initialTab: 0)),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(importResult.error ?? 'Import failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
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
        title: const Text('Google Drive'),
        backgroundColor: kcSurfaceColor,
        foregroundColor: kcPrimaryTextColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kcAccentColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildConnectionCard(),
                  const SizedBox(height: 24),
                  if (_accountEmail != null) ...[
                    _buildExportCard(),
                    const SizedBox(height: 24),
                    _buildImportCard(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildConnectionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connection',
            style: heading3Style(context).copyWith(color: kcPrimaryTextColor),
          ),
          const SizedBox(height: 12),
          if (_accountEmail != null) ...[
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _accountEmail!,
                    style: bodyStyle(context).copyWith(color: kcPrimaryTextColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Backups will be saved in the "ARC Backups" folder in your Drive.',
              style: bodyStyle(context).copyWith(color: kcSecondaryTextColor, fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _connecting ? null : _disconnect,
              icon: _connecting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.link_off, size: 18),
              label: const Text('Disconnect'),
              style: OutlinedButton.styleFrom(foregroundColor: kcSecondaryTextColor),
            ),
          ] else ...[
            Text(
              'Connect with your Google account to export and import backups. We only request access to files this app creates (drive.file scope).',
              style: bodyStyle(context).copyWith(color: kcSecondaryTextColor, fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _connecting ? null : _connect,
              icon: _connecting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud, size: 20),
              label: Text(_connecting ? 'Connecting...' : 'Connect Google Drive'),
              style: FilledButton.styleFrom(backgroundColor: kcAccentColor, foregroundColor: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Export to Drive',
            style: heading3Style(context).copyWith(color: kcPrimaryTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a full backup and upload it to your ARC Backups folder.',
            style: bodyStyle(context).copyWith(color: kcSecondaryTextColor, fontSize: 12),
          ),
          if (_exportProgress.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_exportProgress, style: bodyStyle(context).copyWith(color: kcAccentColor, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _exporting ? null : _exportToDrive,
            icon: _exporting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.upload, size: 18),
            label: Text(_exporting ? 'Exporting...' : 'Export backup to Drive'),
            style: FilledButton.styleFrom(backgroundColor: kcAccentColor, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildImportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import from Drive',
            style: heading3Style(context).copyWith(color: kcPrimaryTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Download and restore a backup from your ARC Backups folder.',
            style: bodyStyle(context).copyWith(color: kcSecondaryTextColor, fontSize: 12),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: (_loadingFiles || _importing) ? null : _loadDriveFiles,
            icon: _loadingFiles ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh, size: 18),
            label: Text(_loadingFiles ? 'Loading...' : 'Refresh backup list'),
            style: OutlinedButton.styleFrom(foregroundColor: kcSecondaryTextColor),
          ),
          if (_driveFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._driveFiles.map((f) {
              final displayName = _displayNameForBackup(f);
              final modified = f.modifiedTime != null ? _formatModifiedTime(f.modifiedTime!) : '';
              final fid = f.id;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(displayName, style: bodyStyle(context).copyWith(color: kcPrimaryTextColor)),
                subtitle: modified.isNotEmpty ? Text(modified, style: bodyStyle(context).copyWith(color: kcSecondaryTextColor, fontSize: 12)) : null,
                trailing: _importing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: fid == null ? null : () => _importFromDrive(f),
                      ),
              );
            }),
          ] else if (!_loadingFiles && _driveFiles.isEmpty && _accountEmail != null) ...[
            const SizedBox(height: 8),
            Text(
              'Tap "Refresh backup list" to see backups, or export one first.',
              style: bodyStyle(context).copyWith(color: kcSecondaryTextColor, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  String _displayNameForBackup(drive.File f) {
    final n = f.name ?? 'Unknown';
    if (n.startsWith('arc_backup_manifest_') && n.endsWith('.json')) {
      return 'Backup (manifest)';
    }
    return n;
  }

  String _formatModifiedTime(dynamic modifiedTime) {
    if (modifiedTime is DateTime) {
      return '${modifiedTime.year}-${modifiedTime.month.toString().padLeft(2, '0')}-${modifiedTime.day.toString().padLeft(2, '0')}';
    }
    if (modifiedTime is String) return modifiedTime.length > 10 ? modifiedTime.substring(0, 10) : modifiedTime;
    return '';
  }
}
