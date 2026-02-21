/// Import Options Sheet
///
/// Bottom sheet presented from the welcome screen for users who already have
/// journal data. For LUMARA/ARCX/zip backups, directly triggers the same
/// import logic that Settings → Import & Export → Import Data uses
/// (ARCXImportServiceV2 / McpPackImportService). For third-party formats
/// (Day One, Journey, text, CSV), uses UniversalImporterService.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:my_app/mira/store/arcx/services/arcx_import_service_v2.dart';
import 'package:my_app/mira/store/arcx/import_progress_cubit.dart';
import 'package:my_app/mira/store/mcp/import/mcp_pack_import_service.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/utils/file_utils.dart';
import 'package:my_app/arc/unified_feed/services/universal_importer_service.dart';

class ImportOptionsSheet extends StatefulWidget {
  const ImportOptionsSheet({super.key});

  @override
  State<ImportOptionsSheet> createState() => _ImportOptionsSheetState();
}

class _ImportOptionsSheetState extends State<ImportOptionsSheet> {
  bool _importing = false;
  double _progress = 0.0;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Import Your Data',
                    style: TextStyle(
                      color: kcPrimaryTextColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close,
                      color: kcSecondaryTextColor.withOpacity(0.6)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Divider(color: kcBorderColor.withOpacity(0.3)),

          if (_importing) ...[
            // Progress view
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            kcPrimaryColor),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _statusMessage ?? 'Importing...',
                      style: const TextStyle(
                        color: kcPrimaryTextColor,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_progress > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: TextStyle(
                          color: kcSecondaryTextColor.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...[
            // Import options list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Choose your import source:',
                    style: TextStyle(
                      color: kcSecondaryTextColor.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // LUMARA / ARCX backup — uses existing import infra directly
                  _buildImportOption(
                    icon: Icons.backup_outlined,
                    title: 'LUMARA Backup',
                    subtitle: 'Restore from .zip or .arcx backup files',
                    onTap: _importLumaraBackup,
                  ),
                  const SizedBox(height: 12),

                  // Day One
                  _buildImportOption(
                    icon: Icons.book_outlined,
                    title: 'Day One',
                    subtitle: 'Import from Day One JSON export',
                    onTap: () => _pickAndImportThirdParty(
                      extensions: ['json'],
                      importType: ImportType.dayOne,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Journey
                  _buildImportOption(
                    icon: Icons.explore_outlined,
                    title: 'Journey',
                    subtitle: 'Import from Journey backup',
                    onTap: () => _pickAndImportThirdParty(
                      extensions: ['json'],
                      importType: ImportType.journey,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Plain text / Markdown
                  _buildImportOption(
                    icon: Icons.text_snippet_outlined,
                    title: 'Text Files',
                    subtitle: 'Import from plain text or markdown files',
                    onTap: () => _pickAndImportThirdParty(
                      extensions: ['txt', 'md'],
                      importType: ImportType.plainText,
                      allowMultiple: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // CSV / Excel
                  _buildImportOption(
                    icon: Icons.table_chart_outlined,
                    title: 'CSV / Excel',
                    subtitle: 'Import from spreadsheet exports',
                    onTap: () => _pickAndImportThirdParty(
                      extensions: ['csv', 'xlsx', 'xls'],
                      importType: ImportType.spreadsheet,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withOpacity(0.25),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFF60A5FA),
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your entries will be imported and CHRONICLE will '
                            'automatically build your temporal intelligence from them.',
                            style: TextStyle(
                              color: Color(0xFF93C5FD),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kcSurfaceAltColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kcBorderColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kcPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: kcPrimaryColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: kcPrimaryTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: kcSecondaryTextColor.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: kcSecondaryTextColor.withOpacity(0.3),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ─── LUMARA Backup: same logic as Settings → Import & Export ─────────

  /// Directly runs the same import logic that Settings uses:
  /// file picker → detect .arcx or .zip → ARCXImportServiceV2 or
  /// McpPackImportService. No intermediate navigation screens.
  Future<void> _importLumaraBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'arcx'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      final files = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();

      if (files.isEmpty) return;

      final hasArcx = files.any((p) => p.endsWith('.arcx'));
      final hasZip = files.any((p) =>
          p.endsWith('.zip') || FileUtils.isMcpPackage(p));

      if (hasArcx) {
        await _runArcxImport(files.where((p) => p.endsWith('.arcx')).toList());
      } else if (hasZip) {
        await _runZipImport(
            files.where((p) => p.endsWith('.zip')).toList());
      } else {
        _showError('Unsupported file format');
      }
    } catch (e) {
      _showError('Failed to select file: $e');
    }
  }

  /// Run ARCX import via ARCXImportServiceV2 (same as settings_view.dart).
  Future<void> _runArcxImport(List<String> arcxFiles) async {
    if (arcxFiles.isEmpty) return;

    setState(() {
      _importing = true;
      _progress = 0.0;
      _statusMessage = 'Preparing ARCX import...';
    });

    try {
      final journalRepo = context.read<JournalRepository>();
      final progressCubit = context.read<ImportProgressCubit>();

      final chatRepo = ChatRepoImpl.instance;
      await chatRepo.initialize();

      PhaseRegimeService? phaseRegimeService;
      try {
        final analyticsService = AnalyticsService();
        final rivetSweepService = RivetSweepService(analyticsService);
        phaseRegimeService =
            PhaseRegimeService(analyticsService, rivetSweepService);
        await phaseRegimeService.initialize();
      } catch (_) {}

      final importService = ARCXImportServiceV2(
        journalRepo: journalRepo,
        chatRepo: chatRepo,
        phaseRegimeService: phaseRegimeService,
      );

      // Also update the global progress cubit so HomeView status bar shows
      progressCubit.start();

      for (var i = 0; i < arcxFiles.length; i++) {
        final arcxPath = arcxFiles[i];
        if (mounted) {
          setState(() {
            _statusMessage = arcxFiles.length > 1
                ? 'Importing file ${i + 1} of ${arcxFiles.length}...'
                : 'Importing ARCX backup...';
          });
        }

        final importResult = await importService.import(
          arcxPath: arcxPath,
          options: ARCXImportOptions(
            validateChecksums: true,
            dedupeMedia: true,
            skipExisting: true,
            resolveLinks: true,
          ),
          password: null,
          onProgress: (message, [fraction = 0.0]) {
            if (mounted) {
              final base = i / arcxFiles.length;
              final slice = 1.0 / arcxFiles.length;
              setState(() {
                _progress = base + (fraction * slice);
                _statusMessage = message;
              });
            }
            progressCubit.update(message, fraction);
          },
        );

        if (importResult.success) {
          progressCubit.complete(importResult);
        } else {
          progressCubit.fail(importResult.error);
          _showError(importResult.error ?? 'Import failed');
          return;
        }
      }

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _statusMessage = 'Import complete!';
        });
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _importing = false;
          _statusMessage = null;
        });
        _showError('ARCX import failed: $e');
      }
    }
  }

  /// Run ZIP/MCP import via McpPackImportService (same as settings_view.dart).
  Future<void> _runZipImport(List<String> zipFiles) async {
    if (zipFiles.isEmpty) return;

    setState(() {
      _importing = true;
      _progress = 0.0;
      _statusMessage = 'Preparing ZIP import...';
    });

    try {
      final journalRepo = context.read<JournalRepository>();

      final chatRepo = ChatRepoImpl.instance;
      await chatRepo.initialize();

      PhaseRegimeService? phaseRegimeService;
      try {
        final analyticsService = AnalyticsService();
        final rivetSweepService = RivetSweepService(analyticsService);
        phaseRegimeService =
            PhaseRegimeService(analyticsService, rivetSweepService);
        await phaseRegimeService.initialize();
      } catch (e) {
        debugPrint('Warning: Could not initialize PhaseRegimeService: $e');
      }

      final importService = McpPackImportService(
        journalRepo: journalRepo,
        phaseRegimeService: phaseRegimeService,
        chatRepo: chatRepo,
      );

      for (var i = 0; i < zipFiles.length; i++) {
        final zipPath = zipFiles[i];
        final zipFile = File(zipPath);

        if (!await zipFile.exists()) {
          _showError('File not found: ${zipPath.split('/').last}');
          return;
        }

        if (mounted) {
          setState(() {
            _statusMessage = zipFiles.length > 1
                ? 'Importing file ${i + 1} of ${zipFiles.length}...'
                : 'Importing ZIP backup...';
          });
        }

        final importResult = await importService.importFromPath(zipPath);

        if (importResult.success) {
          if (mounted) {
            setState(() {
              _progress = (i + 1) / zipFiles.length;
              _statusMessage =
                  'Imported ${importResult.totalEntries} entries and '
                  '${importResult.totalPhotos} media items.';
            });
          }
        } else {
          _showError(importResult.error ?? 'Import failed');
          return;
        }
      }

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _statusMessage = 'Import complete!';
        });
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _importing = false;
          _statusMessage = null;
        });
        _showError('ZIP import failed: $e');
      }
    }
  }

  // ─── Third-party formats: use UniversalImporterService ──────────────

  Future<void> _pickAndImportThirdParty({
    required List<String> extensions,
    required ImportType importType,
    bool allowMultiple = false,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: allowMultiple,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _importing = true;
      _progress = 0.0;
      _statusMessage = 'Reading file...';
    });

    try {
      final importer = UniversalImporterService();

      await importer.importFromFile(
        filePath: result.files.first.path!,
        importType: importType,
        onProgress: (progress, message) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _statusMessage = message;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _statusMessage = 'Import complete!';
        });
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _importing = false;
          _statusMessage = null;
        });
        _showError('Import failed: $e');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kcDangerColor,
      ),
    );
  }
}
