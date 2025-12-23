// lib/services/backup_upload_service.dart
// Background backup upload service for Google Drive

import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:my_app/services/google_drive_service.dart';
import 'package:my_app/services/google_drive_backup_settings_service.dart';
import 'package:my_app/mira/store/arcx/services/arcx_export_service_v2.dart';
import 'package:my_app/mira/store/mcp/export/mcp_pack_export_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/chat/chat/chat_repo.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// Backup upload result
class BackupUploadResult {
  final bool success;
  final String? error;
  final String? fileId;
  final String? fileName;
  final DateTime? uploadedAt;

  BackupUploadResult({
    required this.success,
    this.error,
    this.fileId,
    this.fileName,
    this.uploadedAt,
  });

  factory BackupUploadResult.success({
    required String fileId,
    required String fileName,
  }) {
    return BackupUploadResult(
      success: true,
      fileId: fileId,
      fileName: fileName,
      uploadedAt: DateTime.now(),
    );
  }

  factory BackupUploadResult.failure(String error) {
    return BackupUploadResult(
      success: false,
      error: error,
    );
  }
}

/// Backup upload service
class BackupUploadService {
  static final BackupUploadService _instance = BackupUploadService._internal();
  factory BackupUploadService() => _instance;
  BackupUploadService._internal();

  static BackupUploadService get instance => _instance;

  final GoogleDriveService _driveService = GoogleDriveService.instance;
  final GoogleDriveBackupSettingsService _settingsService = GoogleDriveBackupSettingsService.instance;

  bool _isUploading = false;
  final StreamController<BackupUploadResult> _uploadController = StreamController<BackupUploadResult>.broadcast();
  final StreamController<String> _progressController = StreamController<String>.broadcast();

  /// Stream of upload results
  Stream<BackupUploadResult> get uploadStream => _uploadController.stream;

  /// Stream of upload progress messages
  Stream<String> get progressStream => _progressController.stream;

  /// Check if upload is in progress
  bool get isUploading => _isUploading;

  /// Create backup and upload to Google Drive
  /// 
  /// [format] - 'arcx' or 'mcp' (uses settings default if not provided)
  /// [journalRepo] - Journal repository for export
  /// [chatRepo] - Chat repository for export
  /// [phaseRegimeService] - Phase regime service for export
  Future<BackupUploadResult> createAndUploadBackup({
    String? format,
    required JournalRepository journalRepo,
    ChatRepo? chatRepo,
    PhaseRegimeService? phaseRegimeService,
  }) async {
    if (_isUploading) {
      return BackupUploadResult.failure('Upload already in progress');
    }

    const maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        _isUploading = true;
        _progressController.add('Checking Google Drive connection...');

        // Check if Google Drive is enabled and configured
        final isEnabled = await _settingsService.isEnabled();
        if (!isEnabled) {
          return BackupUploadResult.failure('Google Drive backup is not enabled');
        }

        // Check authentication
        if (!_driveService.isAuthenticated) {
          _progressController.add('Authenticating with Google Drive...');
          final authenticated = await _driveService.authenticate();
          if (!authenticated) {
            return BackupUploadResult.failure('Failed to authenticate with Google Drive');
          }
        }

        // Get folder ID
        final folderId = await _settingsService.getFolderId();
        if (folderId == null) {
          return BackupUploadResult.failure('No Google Drive folder selected');
        }

        // Get backup format
        final backupFormat = format ?? await _settingsService.getBackupFormat();
        _progressController.add('Creating $backupFormat backup...');

        // Create export file
        final exportFile = await _createExportFile(
          format: backupFormat,
          journalRepo: journalRepo,
          chatRepo: chatRepo,
          phaseRegimeService: phaseRegimeService,
        );

        if (exportFile == null) {
          return BackupUploadResult.failure('Failed to create backup file');
        }

        // Upload to Google Drive with retry logic
        _progressController.add('Uploading to Google Drive...');
        drive.File? driveFile;

        try {
          driveFile = await _driveService.uploadFile(
            exportFile,
            folderId: folderId,
          );
        } catch (e) {
          // Try to refresh token and retry
          if (retryCount < maxRetries - 1) {
            print('Backup Upload Service: Upload failed, attempting token refresh...');
            final refreshed = await _driveService.refreshToken();
            if (refreshed) {
              retryCount++;
              _progressController.add('Retrying upload (attempt ${retryCount + 1}/$maxRetries)...');
              await Future.delayed(Duration(seconds: retryCount)); // Exponential backoff
              continue; // Retry upload
            }
          }
          
          // If refresh failed or max retries reached, throw
          rethrow;
        }

        // Update last backup timestamp
        await _settingsService.setLastBackup(DateTime.now());

        // Clean up local file
        try {
          await exportFile.delete();
        } catch (e) {
          print('Backup Upload Service: Warning - could not delete temp file: $e');
        }

        final result = BackupUploadResult.success(
          fileId: driveFile.id ?? '',
          fileName: driveFile.name ?? path.basename(exportFile.path),
        );

        _uploadController.add(result);
        _progressController.add('Upload complete!');
        return result;
      } catch (e) {
        retryCount++;
        
        if (retryCount >= maxRetries) {
          final error = 'Upload failed after $maxRetries attempts: $e';
          _progressController.add(error);
          final result = BackupUploadResult.failure(error);
          _uploadController.add(result);
          return result;
        } else {
          // Wait before retry with exponential backoff
          final delay = Duration(seconds: retryCount * 2);
          _progressController.add('Upload failed, retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        }
      } finally {
        if (retryCount >= maxRetries) {
          _isUploading = false;
        }
      }
    }

    // Should never reach here, but just in case
    return BackupUploadResult.failure('Upload failed after all retries');
  }

  /// Create export file based on format
  Future<File?> _createExportFile({
    required String format,
    required JournalRepository journalRepo,
    ChatRepo? chatRepo,
    PhaseRegimeService? phaseRegimeService,
  }) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final tempDir = Directory(path.join(appDocDir.path, 'backup_temp_${DateTime.now().millisecondsSinceEpoch}'));
      await tempDir.create(recursive: true);

      if (format == 'arcx') {
        return await _createARCXExport(
          outputDir: tempDir,
          journalRepo: journalRepo,
          chatRepo: chatRepo,
          phaseRegimeService: phaseRegimeService,
        );
      } else {
        return await _createMCPExport(
          outputDir: tempDir,
          journalRepo: journalRepo,
          chatRepo: chatRepo,
          phaseRegimeService: phaseRegimeService,
        );
      }
    } catch (e) {
      print('Backup Upload Service: Error creating export file: $e');
      return null;
    }
  }

  /// Create ARCX export file
  Future<File?> _createARCXExport({
    required Directory outputDir,
    required JournalRepository journalRepo,
    ChatRepo? chatRepo,
    PhaseRegimeService? phaseRegimeService,
  }) async {
    try {
      _progressController.add('Exporting to ARCX format...');

      // Get all entries
      final entries = await journalRepo.getAllJournalEntries();
      if (entries.isEmpty) {
        _progressController.add('No entries to export');
        return null;
      }

      // Initialize services if needed
      if (phaseRegimeService == null) {
        final analyticsService = AnalyticsService();
        final rivetSweepService = RivetSweepService(analyticsService);
        phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
        await phaseRegimeService.initialize();
      }

      if (chatRepo == null) {
        chatRepo = ChatRepoImpl.instance;
        await chatRepo.initialize();
      }

      // Create ARCX export service
      final arcxService = ARCXExportServiceV2(
        journalRepo: journalRepo,
        chatRepo: chatRepo,
        phaseRegimeService: phaseRegimeService,
      );

      // Get all chat thread IDs
      final chatThreadIds = <String>[];
      try {
        final allChats = await chatRepo.listAll(includeArchived: true);
        chatThreadIds.addAll(allChats.map((c) => c.id));
      } catch (e) {
        print('Backup Upload Service: Warning - could not load chats: $e');
      }

      final options = ARCXExportOptions(
        strategy: ARCXExportStrategy.together,
        encrypt: true,
      );

      _progressController.add('Creating ARCX archive...');
      final result = await arcxService.export(
        selection: ARCXExportSelection(
          entryIds: entries.map((e) => e.id).toList(),
          chatThreadIds: chatThreadIds,
        ),
        options: options,
        outputDir: outputDir,
        onProgress: (message) {
          _progressController.add(message);
        },
      );

      if (!result.success || result.arcxPath == null) {
        _progressController.add('ARCX export failed: ${result.error ?? "Unknown error"}');
        return null;
      }

      final arcxFile = File(result.arcxPath!);
      if (!await arcxFile.exists()) {
        _progressController.add('ARCX file not found after export');
        return null;
      }

      // Move file to a predictable location for upload
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final finalPath = path.join(outputDir.path, 'arc_backup_$timestamp.arcx');
      final finalFile = await arcxFile.copy(finalPath);
      await arcxFile.delete(); // Delete original

      _progressController.add('ARCX export complete: ${path.basename(finalPath)}');
      return finalFile;
    } catch (e) {
      print('Backup Upload Service: ARCX export error: $e');
      _progressController.add('ARCX export error: $e');
      return null;
    }
  }

  /// Create MCP export file
  Future<File?> _createMCPExport({
    required Directory outputDir,
    required JournalRepository journalRepo,
    ChatRepo? chatRepo,
    PhaseRegimeService? phaseRegimeService,
  }) async {
    try {
      _progressController.add('Exporting to MCP format...');

      // Get all entries
      final entries = await journalRepo.getAllJournalEntries();
      if (entries.isEmpty) {
        _progressController.add('No entries to export');
        return null;
      }

      // Create output file path
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final outputPath = path.join(outputDir.path, 'arc_backup_$timestamp.mcpkg');

      // Create MCP export service
      final mcpService = McpPackExportService(
        bundleId: 'backup_${DateTime.now().millisecondsSinceEpoch}',
        outputPath: outputPath,
        chatRepo: chatRepo,
        phaseRegimeService: phaseRegimeService,
      );

      _progressController.add('Creating MCP package...');
      final result = await mcpService.exportJournal(
        entries: entries,
        includePhotos: true,
        includeChats: true,
        includeArchivedChats: true,
      );

      if (!result.success || result.outputPath == null) {
        _progressController.add('MCP export failed: ${result.error ?? "Unknown error"}');
        return null;
      }

      final mcpFile = File(result.outputPath!);
      if (!await mcpFile.exists()) {
        _progressController.add('MCP file not found after export');
        return null;
      }

      _progressController.add('MCP export complete: ${path.basename(result.outputPath!)}');
      return mcpFile;
    } catch (e) {
      print('Backup Upload Service: MCP export error: $e');
      _progressController.add('MCP export error: $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _uploadController.close();
    _progressController.close();
  }
}

