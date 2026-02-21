// Google Drive settings for export/import backup via OAuth.
// Connect with Google (drive.file + drive.readonly), then export backups or browse/import from any folder.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:accessing_security_scoped_resource/accessing_security_scoped_resource.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/google_drive_service.dart';
import 'package:my_app/mira/store/arcx/services/arcx_export_service_v2.dart';
import 'package:my_app/mira/store/mcp/export/mcp_pack_export_service.dart';
import 'package:my_app/mira/store/mcp/export/zip_utils.dart';
import 'package:my_app/mira/store/mcp/import/mcp_pack_import_service.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/shared/ui/home/home_view.dart';
import 'package:my_app/shared/ui/settings/drive_folder_picker_screen.dart';
import 'package:my_app/shared/ui/settings/sync_folder_push_screen.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';

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

  // SharedPreferences key for persisting selected backup folder
  static const String _keyGoogleDriveSourceFolder = 'google_drive_source_folder';
  static const String _keyLastUploadFromFolderAt = 'google_drive_last_upload_from_folder_at';
  static const String _keyDriveBackupFormat = 'google_drive_backup_format';

  bool _loading = true;
  bool _connecting = false;
  String? _accountEmail;
  bool _exporting = false;
  String _exportProgress = '';
  int _exportPercentage = 0;
  bool _importing = false;
  List<drive.File> _driveFiles = [];
  bool _loadingFiles = false;

  /// Whether the Import from Drive backup list is expanded (true) or collapsed (false).
  bool _importListExpanded = false;

  /// Backup file format for Google Drive exports: 'arcx' (default) or 'zip'.
  /// ZIP keeps backups accessible even when the app's security key changes after reinstall.
  String _driveBackupFormat = 'arcx';
  
  // Upload from folder state
  String? _sourceFolder;
  List<FileSystemEntity> _sourceFiles = [];
  bool _uploadingFromFolder = false;
  String _uploadFolderProgress = '';
  DateTime? _lastUploadFromFolderAt;

  /// Path we're currently holding security-scoped access for (iOS/macOS only).
  /// Retained after folder pick so Upload works without re-picking.
  String? _securityScopedPath;

  /// Sync folder: chosen Drive folder for .txt import. Name shown in UI.
  String? _syncFolderName;
  bool _syncingTxt = false;

  @override
  void initState() {
    super.initState();
    _refreshConnection();
    _loadSourceFolder();
    _loadSyncFolderName();
    _loadDriveBackupFormat();
  }

  Future<void> _loadSyncFolderName() async {
    final name = await _driveService.getSyncFolderName();
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _syncFolderName = name);
    }
  }

  Future<void> _loadDriveBackupFormat() async {
    final prefs = await SharedPreferences.getInstance();
    final format = prefs.getString(_keyDriveBackupFormat) ?? 'arcx';
    if (mounted) setState(() => _driveBackupFormat = format);
  }

  Future<void> _setDriveBackupFormat(String format) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDriveBackupFormat, format);
    setState(() => _driveBackupFormat = format);
  }

  @override
  void dispose() {
    _releaseSecurityScopedAccess();
    super.dispose();
  }

  /// Release security-scoped access for the path we're holding (iOS/macOS).
  Future<void> _releaseSecurityScopedAccess() async {
    if (_securityScopedPath == null) return;
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        final plugin = AccessingSecurityScopedResource();
        await plugin.stopAccessingSecurityScopedResourceWithFilePath(_securityScopedPath!);
      } catch (_) {}
    }
    _securityScopedPath = null;
  }

  Future<void> _loadSourceFolder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString(_keyGoogleDriveSourceFolder);
      if (savedPath != null && savedPath.isNotEmpty) {
        final dir = Directory(savedPath);
        if (await dir.exists()) {
          await _scanSourceFolder(savedPath);
        }
      }
      final lastUploadMs = prefs.getString(_keyLastUploadFromFolderAt);
      if (lastUploadMs != null) {
        final ms = int.tryParse(lastUploadMs);
        if (ms != null && mounted) {
          setState(() => _lastUploadFromFolderAt = DateTime.fromMillisecondsSinceEpoch(ms));
        }
      }
    } catch (e) {
      debugPrint('GoogleDriveSettingsView: Error loading source folder: $e');
    }
  }

  Future<void> _selectSourceFolder() async {
    try {
      final selectedPath = await FilePicker.platform.getDirectoryPath();
      if (selectedPath != null) {
        // Persist the selected folder
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyGoogleDriveSourceFolder, selectedPath);
        // Retain security-scoped access so Upload works without re-picking (iOS/macOS)
        await _scanSourceFolder(selectedPath, retainAccessForUpload: true);
        
        if (mounted && _sourceFiles.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${_sourceFiles.length} backup file(s)'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'No .arcx or .zip files found here. If the folder has backup files, try selecting it again (the system may need to grant access).',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting folder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// True if [folderPath] is inside the app's sandbox (Documents, Support, Caches, Temp).
  /// For in-app paths we already have access and must not use security-scoped resource.
  Future<bool> _isPathInAppSandbox(String folderPath) async {
    try {
      final normalizedPath = path.normalize(folderPath);
      final appDoc = await getApplicationDocumentsDirectory();
      final appSupport = await getApplicationSupportDirectory();
      final temp = await getTemporaryDirectory();
      final dirs = [
        path.normalize(appDoc.path),
        path.normalize(appSupport.path),
        path.normalize(temp.path),
      ];
      for (final base in dirs) {
        if (normalizedPath == base ||
            normalizedPath.startsWith('$base${path.separator}')) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// [retainAccessForUpload] When true (e.g. after user picks folder), we keep
  /// security-scoped access so Upload works without re-picking (iOS/macOS).
  Future<void> _scanSourceFolder(String folderPath, {bool retainAccessForUpload = false}) async {
    // On iOS/macOS, only request security-scoped access for paths *outside* the app sandbox.
    // Paths inside app Documents/Support/Temp already have normal access.
    bool isAccessing = false;
    if (Platform.isIOS || Platform.isMacOS) {
      final inSandbox = await _isPathInAppSandbox(folderPath);
      if (!inSandbox) {
        // Release previous path if we're selecting a different folder
        if (_securityScopedPath != null && _securityScopedPath != folderPath) {
          await _releaseSecurityScopedAccess();
        }
        try {
          final plugin = AccessingSecurityScopedResource();
          isAccessing = await plugin.startAccessingSecurityScopedResourceWithFilePath(folderPath);
          if (!isAccessing) {
            debugPrint('GoogleDriveSettingsView: Could not get security-scoped access to $folderPath');
          } else if (retainAccessForUpload) {
            _securityScopedPath = folderPath;
          }
        } catch (e) {
          debugPrint('GoogleDriveSettingsView: startAccessingSecurityScopedResource error: $e');
        }
      }
    }

    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) {
        if (mounted) {
          setState(() {
            _sourceFolder = null;
            _sourceFiles = [];
          });
        }
        return;
      }

      // List files: use stream + path check so we catch .arcx/.zip whether reported as File or not
      final backupPaths = <String>[];
      await for (final entity in dir.list(followLinks: false)) {
        final p = entity.path;
        final nameLower = path.basename(p).toLowerCase();
        if (!nameLower.endsWith('.arcx') && !nameLower.endsWith('.zip')) continue;
        try {
          if (await FileSystemEntity.isFile(p)) {
            backupPaths.add(p);
          }
        } catch (_) {}
      }

      final backupFiles = backupPaths.map((p) => File(p)).toList();

      // Sort by modification time (newest first)
      backupFiles.sort((a, b) {
        try {
          final aStat = a.statSync();
          final bStat = b.statSync();
          return bStat.modified.compareTo(aStat.modified);
        } catch (_) {
          return 0;
        }
      });

      if (mounted) {
        setState(() {
          _sourceFolder = folderPath;
          _sourceFiles = backupFiles;
        });
      }
    } catch (e) {
      debugPrint('GoogleDriveSettingsView: Error scanning folder: $e');
      if (mounted) {
        setState(() {
          _sourceFolder = folderPath;
          _sourceFiles = [];
        });
      }
    } finally {
      // Only release access if we're not retaining it for upload (iOS/macOS).
      if ((Platform.isIOS || Platform.isMacOS) && isAccessing && !retainAccessForUpload) {
        try {
          final plugin = AccessingSecurityScopedResource();
          await plugin.stopAccessingSecurityScopedResourceWithFilePath(folderPath);
        } catch (_) {}
      }
    }
  }

  Future<void> _uploadFromFolder() async {
    if (!_driveService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect Google Drive first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_sourceFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No backup files to upload'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_sourceFolder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No source folder selected'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _uploadingFromFolder = true;
      _uploadFolderProgress = 'Preparing upload...';
    });

    // On iOS/macOS, use retained security-scoped access from folder pick, or request it if we don't have it (e.g. app restarted).
    bool isAccessing = false;
    bool releaseAccessAfterUpload = false; // Only release when we started access in this method
    if (Platform.isIOS || Platform.isMacOS) {
      final inSandbox = await _isPathInAppSandbox(_sourceFolder!);
      if (!inSandbox) {
        if (_securityScopedPath == _sourceFolder) {
          // We already have access from when the user picked the folder; no need to start again.
          isAccessing = true;
        } else {
          try {
            final plugin = AccessingSecurityScopedResource();
            isAccessing = await plugin.startAccessingSecurityScopedResourceWithFilePath(_sourceFolder!);
            if (isAccessing) {
              _securityScopedPath = _sourceFolder;
              releaseAccessAfterUpload = true; // We started here; release after upload
            }
            if (!isAccessing) {
              if (mounted) {
                setState(() {
                  _uploadingFromFolder = false;
                  _uploadFolderProgress = '';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'This folder needs permission to access. Tap "Browse" to select the folder again (this grants access), then tap Upload.',
                    ),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
              return;
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _uploadingFromFolder = false;
                _uploadFolderProgress = '';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Folder access was denied (system privacy). Tap "Browse" to select the folder again, then Upload.',
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            return;
          }
        }
      }
    }

    try {
      await _ensureFolder();

      final arcxPaths = _sourceFiles.map((f) => f.path).toList();
      final manifestTimestamp = DateTime.now().toUtc().toIso8601String();

      if (!mounted) return;
      setState(() => _uploadFolderProgress = 'Uploading ${arcxPaths.length} file(s)...');

      await _driveService.uploadChunkedBackup(
        arcxPaths: arcxPaths,
        manifestTimestamp: manifestTimestamp,
        onProgress: (current, total, phase) {
          if (mounted) {
            setState(() => _uploadFolderProgress = phase);
          }
        },
      );

      if (mounted) {
        final now = DateTime.now();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyLastUploadFromFolderAt, '${now.millisecondsSinceEpoch}');
        setState(() {
          _uploadingFromFolder = false;
          _uploadFolderProgress = '';
          _lastUploadFromFolderAt = now;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded ${arcxPaths.length} file(s) to Google Drive'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadingFromFolder = false;
          _uploadFolderProgress = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Only release when we started access in this method (e.g. after app restart). Keep access when we had it from folder pick so user can upload again without re-picking.
      if (releaseAccessAfterUpload) {
        await _releaseSecurityScopedAccess();
      }
    }
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
      _exportPercentage = 0;
    });
    Directory? tempDir;
    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      final chatRepo = ChatRepoImpl.instance;
      await chatRepo.initialize();

      final appDocDir = await getApplicationDocumentsDirectory();
      final outputDir = Directory(path.join(appDocDir.path, 'arcx_drive_export_${DateTime.now().millisecondsSinceEpoch}'));
      await outputDir.create(recursive: true);
      tempDir = outputDir;

      if (_driveBackupFormat == 'zip') {
        // ZIP format: single file, standard ZIP — survives app reinstall / device change
        if (mounted) setState(() => _exportProgress = 'Loading entries...');

        final entries = await widget.journalRepo.getAllJournalEntries();
        if (entries.isEmpty) {
          if (mounted) {
            setState(() { _exporting = false; _exportProgress = ''; _exportPercentage = 0; });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No entries to backup'), backgroundColor: Colors.orange),
            );
          }
          return;
        }

        final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
        final zipFileName = 'LUMARA_Full_$timestamp.zip';
        final zipPath = path.join(outputDir.path, zipFileName);

        final mcpService = McpPackExportService(
          bundleId: 'LUMARA_Full_$timestamp',
          outputPath: zipPath,
          chatRepo: chatRepo,
          phaseRegimeService: phaseRegimeService,
        );

        if (mounted) setState(() => _exportProgress = 'Creating ZIP backup...');

        final zipResult = await mcpService.exportJournal(
          entries: entries,
          includePhotos: true,
          reducePhotoSize: false,
          includeChats: true,
          includeArchivedChats: true,
          mediaPackTargetSizeMB: 200,
        );

        if (!zipResult.success) {
          if (mounted) {
            setState(() { _exporting = false; _exportProgress = ''; _exportPercentage = 0; });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(zipResult.error ?? 'ZIP export failed'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        if (mounted) setState(() => _exportProgress = 'Uploading ZIP to Drive...');

        await _ensureFolder();
        final datedFolderId = await _driveService.getOrCreateDatedSubfolder(DateTime.now());
        await _driveService.uploadFile(
          localFile: File(zipPath),
          folderId: datedFolderId,
          nameOverride: zipFileName,
        );

        if (mounted) {
          setState(() { _exporting = false; _exportProgress = ''; _exportPercentage = 0; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ZIP backup complete: ${zipResult.totalEntries} entries, ${zipResult.totalChatSessions} chats'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // ARCX format: chunked encrypted backup (default)
        final exportService = ARCXExportServiceV2(
          journalRepo: widget.journalRepo,
          chatRepo: chatRepo,
          phaseRegimeService: phaseRegimeService,
        );

        if (mounted) setState(() => _exportProgress = 'Exporting backup...');

        final result = await exportService.exportFullBackupChunked(
          outputDir: outputDir,
          password: null,
          chunkSizeMB: 200,
          onProgress: (msg, [fraction]) {
            if (mounted) {
              setState(() {
                _exportProgress = msg;
                if (fraction != null) _exportPercentage = (fraction * 100).round();
              });
            }
          },
        );

        if (!result.success) {
          if (mounted) {
            setState(() { _exporting = false; _exportProgress = ''; _exportPercentage = 0; });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.error ?? 'Export failed'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        if (mounted) setState(() => _exportProgress = 'Uploading arcx files (smallest first)...');

        final manifestTimestamp = DateTime.now().toUtc().toIso8601String();
        await _driveService.uploadChunkedBackup(
          arcxPaths: result.chunkPaths,
          manifestTimestamp: manifestTimestamp,
          onProgress: (current, total, phase) {
            if (mounted) setState(() => _exportProgress = phase);
          },
        );

        if (mounted) {
          setState(() { _exporting = false; _exportProgress = ''; _exportPercentage = 0; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup uploaded to Google Drive'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _exporting = false;
          _exportProgress = '';
          _exportPercentage = 0;
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
      final files = await _driveService.listAllBackupFiles(pageSize: 200);
      if (mounted) {
        setState(() {
          _driveFiles = files;
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

  /// Choose a single Drive folder as the sync folder (source for .txt import).
  Future<void> _chooseSyncFolder() async {
    if (!_driveService.isSignedIn) return;
    final result = await Navigator.of(context).push<DriveSyncFolderResult>(
      MaterialPageRoute(
        builder: (context) => const DriveFolderPickerScreen(useAsSyncFolder: true),
      ),
    );
    if (result == null || !mounted) return;
    await _driveService.setSyncFolder(result.folderId, result.folderName);
    setState(() => _syncFolderName = result.folderName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync folder set to "${result.folderName}"'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Import .txt files from the sync folder into the Timeline with #googledrive and #FolderName.
  Future<void> _syncTxtFromDrive() async {
    final folderId = await _driveService.getSyncFolderId();
    if (folderId == null || folderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a sync folder first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _syncingTxt = true);
    try {
      final created = await _driveService.syncTxtFromDriveToTimeline(widget.journalRepo);
      if (mounted) {
        setState(() => _syncingTxt = false);
        try {
          if (context.mounted) context.read<TimelineCubit>().reloadAllEntries();
        } catch (_) {}
        if (created > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported $created .txt/.md file(s) into Timeline with #googledrive and folder hashtag'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeView(initialTab: 0)),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No new .txt/.md files in sync folder'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _syncingTxt = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Opens the Drive folder picker; on confirm, imports backup and text files from selected folders.
  Future<void> _openDriveFolderPicker() async {
    if (!_driveService.isSignedIn) return;
    final result = await Navigator.of(context).push<DriveFolderPickerResult>(
      MaterialPageRoute(
        builder: (context) => const DriveFolderPickerScreen(),
      ),
    );
    if (result == null || (result.selectedFolderIds.isEmpty && result.selectedFileIds.isEmpty) || !mounted) return;

    setState(() => _importing = true);
    try {
      final allFiles = <drive.File>[];
      final seenIds = <String>{};
      for (final folderId in result.selectedFolderIds) {
        final files = await _driveService.listImportableFilesInFolder(folderId, maxFiles: 500);
        for (final f in files) {
          final id = f.id;
          if (id != null && !seenIds.contains(id)) {
            seenIds.add(id);
            allFiles.add(f);
          }
        }
      }
      for (final fileId in result.selectedFileIds) {
        if (seenIds.contains(fileId)) continue;
        final file = await _driveService.getFileMetadata(fileId);
        if (file != null) {
          seenIds.add(fileId);
          allFiles.add(file);
        }
      }

      // Prefer manifest backups (full restore); then .arcx/.zip; then .txt.
      final manifests = allFiles.where((f) {
        final n = f.name ?? '';
        return n.startsWith('arc_backup_manifest_') && n.endsWith('.json');
      }).toList();
      final backups = allFiles.where((f) {
        final n = f.name ?? '';
        return n.endsWith('.arcx') || n.endsWith('.zip');
      }).toList();
      final textFiles = allFiles.where((f) {
        final n = f.name ?? '';
        return n.endsWith('.txt') || n.endsWith('.md');
      }).toList();

      int importedBackups = 0;
      String? lastError;

      for (final file in manifests) {
        if (!mounted) break;
        try {
          final r = await _performImportFromDriveFile(file);
          if (r.success) importedBackups++;
          else lastError = r.error;
        } catch (e) {
          lastError = e.toString();
        }
      }
      for (final file in backups) {
        if (!mounted) break;
        if (manifests.any((m) => m.id == file.id)) continue;
        try {
          final r = await _performImportFromDriveFile(file);
          if (r.success) importedBackups++;
          else lastError = r.error;
        } catch (e) {
          lastError = e.toString();
        }
      }

      // Import .txt/.md files as LUMARA entries (same as sync folder, but one-time from selected folders).
      int importedText = 0;
      if (mounted && textFiles.isNotEmpty) {
        importedText = await _driveService.importTextFilesFromDrive(textFiles, widget.journalRepo);
      }

      if (mounted) {
        setState(() => _importing = false);
        final buf = StringBuffer();
        if (importedBackups > 0) buf.write('Imported $importedBackups backup(s). ');
        if (importedText > 0) buf.write('Imported $importedText text file(s) as LUMARA entries. ');
        if (importedText == 0 && textFiles.isNotEmpty) buf.write('${textFiles.length} text file(s) found but could not be imported. ');
        if (lastError != null && importedBackups == 0 && importedText == 0) buf.write(lastError);
        final totalImported = importedBackups + importedText;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(buf.isEmpty ? 'No importable files in your selection.' : buf.toString().trim()),
            backgroundColor: totalImported > 0 ? Colors.green : Colors.orange,
          ),
        );
        if (totalImported > 0) {
          try {
            if (context.mounted) context.read<TimelineCubit>().reloadAllEntries();
          } catch (_) {}
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeView(initialTab: 0)),
            (route) => false,
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

  /// Performs download and import for one Drive file. Does not update UI or navigate.
  /// Returns (success, error message, totalEntries, totalPhotos).
  Future<({bool success, String? error, int totalEntries, int totalPhotos})> _performImportFromDriveFile(drive.File file) async {
    if (file.id == null) return (success: false, error: 'No file id', totalEntries: 0, totalPhotos: 0);
    final fileId = file.id!;
    final isManifestBackup = file.name != null &&
        file.name!.startsWith('arc_backup_manifest_') &&
        file.name!.endsWith('.json');

    String zipPath;
    Directory? tempDirToDelete;

    try {
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
        return (success: false, error: 'Downloaded file not found', totalEntries: 0, totalPhotos: 0);
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

      return (
        success: importResult.success,
        error: importResult.error,
        totalEntries: importResult.totalEntries,
        totalPhotos: importResult.totalPhotos,
      );
    } catch (e) {
      return (success: false, error: e.toString(), totalEntries: 0, totalPhotos: 0);
    }
  }

  Future<void> _importFromDrive(drive.File file) async {
    setState(() => _importing = true);
    try {
      final result = await _performImportFromDriveFile(file);
      if (!mounted) return;
      setState(() => _importing = false);
      try {
        if (context.mounted) context.read<TimelineCubit>().reloadAllEntries();
      } catch (_) {}
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported ${result.totalEntries} entries, ${result.totalPhotos} media'),
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
            content: Text(result.error ?? 'Import failed'),
            backgroundColor: Colors.red,
          ),
        );
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
                    _buildUploadFromFolderCard(),
                    const SizedBox(height: 24),
                    _buildSyncFolderCard(),
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
              'Backups will be saved in the "LUMARA Backups" folder in your Drive.',
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
              'Connect with your Google account to export and import backups. We request access to save backups (drive.file) and to browse and import from folders you choose (drive.readonly).',
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
            'Create a full backup and upload it to your LUMARA Backups folder.',
            style: bodyStyle(context).copyWith(color: kcSecondaryTextColor, fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Backup format selector
          Text(
            'Backup Format',
            style: bodyStyle(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          RadioListTile<String>(
            title: const Text('ARCX Format', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text(
              'Encrypted LUMARA archive (tied to this app install)',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            value: 'arcx',
            groupValue: _driveBackupFormat,
            onChanged: _exporting ? null : (value) => _setDriveBackupFormat(value!),
            activeColor: kcAccentColor,
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          RadioListTile<String>(
            title: const Text('ZIP Format', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text(
              'Standard ZIP — survives app reinstall / device change',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            value: 'zip',
            groupValue: _driveBackupFormat,
            onChanged: _exporting ? null : (value) => _setDriveBackupFormat(value!),
            activeColor: kcAccentColor,
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),

          const SizedBox(height: 12),
          if (_exporting)
            Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: _exportPercentage > 0 ? _exportPercentage / 100 : null,
                        strokeWidth: 4,
                        backgroundColor: Colors.grey[800],
                        valueColor: const AlwaysStoppedAnimation<Color>(kcAccentColor),
                      ),
                    ),
                    Text(
                      '$_exportPercentage%',
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
                          _exportProgress.isNotEmpty
                              ? _exportProgress
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
            FilledButton.icon(
              onPressed: _exportToDrive,
              icon: const Icon(Icons.upload, size: 18),
              label: const Text('Export backup to Drive'),
              style: FilledButton.styleFrom(backgroundColor: kcAccentColor, foregroundColor: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadFromFolderCard() {
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
            'Upload from Folder',
            style: heading3Style(context).copyWith(color: kcPrimaryTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a local folder with existing backup files to upload to Google Drive.',
            style: bodyStyle(context).copyWith(color: kcSecondaryTextColor, fontSize: 12),
          ),
          if (_lastUploadFromFolderAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Last upload: ${DateFormat('MMM d, y • h:mm a').format(_lastUploadFromFolderAt!)}',
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.orange[300]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'For folders outside the app, access is kept after you pick the folder so Upload works. If you see an access message (e.g. after restarting the app), tap "Browse" to select the folder again, then Upload.',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Folder selection row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    _sourceFolder != null 
                        ? path.basename(_sourceFolder!)
                        : 'No folder selected',
                    style: bodyStyle(context).copyWith(
                      color: _sourceFolder != null ? kcPrimaryTextColor : kcSecondaryTextColor,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: (_uploadingFromFolder || _exporting) ? null : _selectSourceFolder,
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('Browse'),
                style: OutlinedButton.styleFrom(foregroundColor: kcAccentColor),
              ),
            ],
          ),
          
          // Show selected files
          if (_sourceFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_sourceFiles.length} backup file(s) found:',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._sourceFiles.take(5).map((file) {
                    final fileName = path.basename(file.path);
                    final stat = (file as File).statSync();
                    final sizeKb = (stat.size / 1024).round();
                    final sizeMb = (stat.size / (1024 * 1024)).toStringAsFixed(1);
                    final sizeStr = stat.size > 1024 * 1024 ? '${sizeMb}MB' : '${sizeKb}KB';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            fileName.endsWith('.arcx') ? Icons.archive : Icons.folder_zip,
                            size: 16,
                            color: kcSecondaryTextColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fileName,
                              style: bodyStyle(context).copyWith(
                                color: kcPrimaryTextColor,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            sizeStr,
                            style: bodyStyle(context).copyWith(
                              color: kcSecondaryTextColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_sourceFiles.length > 5)
                    Text(
                      '...and ${_sourceFiles.length - 5} more',
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
          
          // Upload progress
          if (_uploadFolderProgress.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _uploadFolderProgress,
              style: bodyStyle(context).copyWith(color: kcAccentColor, fontSize: 12),
            ),
          ],
          
          // Upload button
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (_uploadingFromFolder || _exporting || _sourceFiles.isEmpty) 
                ? null 
                : _uploadFromFolder,
            icon: _uploadingFromFolder 
                ? const SizedBox(
                    width: 18, 
                    height: 18, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ) 
                : const Icon(Icons.cloud_upload, size: 18),
            label: Text(_uploadingFromFolder 
                ? 'Uploading...' 
                : 'Upload ${_sourceFiles.length} file(s) to Drive'),
            style: FilledButton.styleFrom(
              backgroundColor: _sourceFiles.isEmpty ? kcSecondaryTextColor : kcAccentColor, 
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncFolderCard() {
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
            'Sync folder',
            style: heading3Style(context).copyWith(color: kcPrimaryTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a Google Drive folder. Add .txt or .md files there, then tap Sync to import them into the Timeline with #googledrive and a hashtag from the folder name (e.g. #BYOK). You can also push changes from the timeline back to the same folder.',
            style: bodyStyle(context).copyWith(color: kcSecondaryTextColor, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.folder, color: Colors.amber[700], size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _syncFolderName ?? 'Not set',
                  style: bodyStyle(context).copyWith(
                    color: _syncFolderName != null ? kcPrimaryTextColor : kcSecondaryTextColor,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _syncingTxt ? null : _chooseSyncFolder,
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('Choose folder'),
                style: OutlinedButton.styleFrom(foregroundColor: kcAccentColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_syncingTxt || _syncFolderName == null) ? null : _syncTxtFromDrive,
                  icon: _syncingTxt
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync, size: 18),
                  label: Text(_syncingTxt ? 'Syncing...' : 'Sync'),
                  style: FilledButton.styleFrom(backgroundColor: kcAccentColor, foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_syncingTxt || _syncFolderName == null) ? null : _openPushToDrive,
                  icon: const Icon(Icons.upload, size: 18),
                  label: const Text('Push to Drive'),
                  style: OutlinedButton.styleFrom(foregroundColor: kcAccentColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Open screen to select synced entries and push their content back to the Drive sync folder.
  Future<void> _openPushToDrive() async {
    final folderId = await _driveService.getSyncFolderId();
    if (folderId == null || folderId.isEmpty || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => SyncFolderPushScreen(
          journalRepo: widget.journalRepo,
          syncFolderId: folderId,
          syncFolderName: _syncFolderName ?? 'Sync folder',
        ),
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
            'Restore from LUMARA Backups, or browse Drive to pick folders and import backups (.arcx, .zip) or text files (.txt, .md) as LUMARA entries.',
            style: bodyStyle(context).copyWith(color: kcSecondaryTextColor, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_loadingFiles || _importing) ? null : _loadDriveFiles,
                  icon: _loadingFiles ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh, size: 18),
                  label: Text(_loadingFiles ? 'Loading...' : 'LUMARA Backups'),
                  style: OutlinedButton.styleFrom(foregroundColor: kcSecondaryTextColor),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_loadingFiles || _importing) ? null : _openDriveFolderPicker,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Browse Drive'),
                  style: FilledButton.styleFrom(backgroundColor: kcAccentColor, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
          if (_driveFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            // Collapsible header: folder row with caret and newest backup date
            InkWell(
              onTap: () => setState(() => _importListExpanded = !_importListExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _importListExpanded ? Icons.expand_more : Icons.chevron_right,
                      color: kcSecondaryTextColor,
                      size: 24,
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.folder, color: Colors.amber[700], size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Backups (${_driveFiles.length})',
                            style: bodyStyle(context).copyWith(
                              color: kcPrimaryTextColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _newestBackupDateString(),
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
            ),
            if (_importListExpanded) ...[
              const SizedBox(height: 4),
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
            ],
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

  /// Formatted date for the newest backup in the list (list is ordered by modifiedTime desc).
  String _newestBackupDateString() {
    if (_driveFiles.isEmpty) return '';
    final mt = _driveFiles.first.modifiedTime;
    if (mt == null) return '';
    final formatted = _formatModifiedTime(mt);
    if (formatted.isEmpty) return '';
    return 'Newest: $formatted';
  }
}
