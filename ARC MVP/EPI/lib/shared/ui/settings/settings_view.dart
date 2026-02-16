import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/shared/ui/settings/privacy_settings_view.dart';
import 'package:my_app/shared/ui/settings/memory_mode_settings_view.dart';
import 'package:my_app/shared/ui/settings/memory_snapshot_management_view.dart';
import 'package:my_app/shared/ui/settings/conflict_management_view.dart';
import 'package:my_app/shared/ui/settings/favorites_management_view.dart';
import 'package:my_app/shared/ui/settings/advanced_settings_view.dart';
import 'package:my_app/shared/ui/settings/phase_analysis_settings_view.dart';
import 'package:my_app/shared/ui/settings/voiceover_preference_service.dart';
import 'package:my_app/shared/ui/settings/throttle_settings_view.dart';
import 'package:my_app/shared/ui/settings/health_readiness_view.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/chat/services/favorites_service.dart';
import 'package:my_app/arc/chat/services/lumara_reflection_settings_service.dart';
import 'package:my_app/arc/chat/ui/lumara_settings_screen.dart';
import 'package:my_app/models/engagement_discipline.dart';
import 'package:my_app/models/memory_focus_preset.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/ui/subscription/subscription_management_view.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/shared/ui/settings/verify_backup_screen.dart';
import 'package:my_app/shared/ui/settings/local_backup_settings_view.dart';
import 'package:my_app/shared/ui/settings/google_drive_settings_view.dart';
import 'package:my_app/shared/ui/settings/import_status_screen.dart';
import 'package:my_app/shared/ui/settings/temporal_notification_settings_view.dart';
import 'package:my_app/shared/ui/settings/chronicle_management_view.dart';
import 'package:my_app/shared/ui/chronicle/chronicle_layers_viewer.dart';
import 'package:my_app/arc/phase/share/phase_share_service.dart';
import 'package:my_app/arc/ui/health/health_view.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:my_app/mira/store/mcp/import/mcp_pack_import_service.dart';
import 'package:my_app/mira/store/arcx/services/arcx_import_service_v2.dart';
import 'package:my_app/mira/store/arcx/import_progress_cubit.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/utils/file_utils.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/shared/ui/home/home_view.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: Text(
          'Settings',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Subscription & Account Folder
            _buildFolderTile(
              context,
              title: 'Subscription & Account',
              subtitle: 'Manage your account and subscription',
              icon: Icons.account_circle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SubscriptionAccountFolderView()),
              ),
            ),

            // 2. Import & Export Folder
            _buildFolderTile(
              context,
              title: 'Import & Export',
              subtitle: 'Backup, restore, and sync your data',
              icon: Icons.sync_alt,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ImportExportFolderView()),
              ),
            ),

            // 3. LUMARA Folder (above Health & Readiness)
            _buildFolderTile(
              context,
              title: 'LUMARA',
              subtitle: 'Customize your AI companion experience',
              icon: Icons.auto_awesome,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LumaraFolderView()),
              ),
            ),

            // 4. CHRONICLE Folder (top-level, outside LUMARA)
            _buildFolderTile(
              context,
              title: 'CHRONICLE',
              subtitle: 'Temporal layers, synthesis, and export',
              icon: Icons.history,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChronicleFolderView()),
              ),
            ),

            // 5. Phase Analysis (Phase Analysis card + Phase Statistics card)
            _buildFolderTile(
              context,
              title: 'Phase Analysis',
              subtitle: 'Phase detection and statistics',
              icon: Icons.auto_awesome,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PhaseAnalysisSettingsView()),
              ),
            ),

            // 6. Advanced Settings (own card, below Phase Analysis)
            _buildAdvancedSettingsCard(context),

            // 7. Health & Readiness (Available to everyone by default)
            _buildFolderTile(
              context,
              title: 'Health & Readiness',
              subtitle: 'Operational readiness and health tracking',
              icon: Icons.assessment,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HealthReadinessFolderView()),
              ),
            ),

            // 8. Bug Reporting Folder
            _buildFolderTile(
              context,
              title: 'Bug Reporting',
              subtitle: 'Report issues and provide feedback',
              icon: Icons.bug_report,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BugReportingFolderView()),
              ),
            ),

            // 9. Privacy & Security Folder
            _buildFolderTile(
              context,
              title: 'Privacy & Security',
              subtitle: 'Control your data and privacy settings',
              icon: Icons.security,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacySecurityFolderView()),
              ),
            ),

            const SizedBox(height: 32),

            // About Section (always visible)
            _buildSection(
              context,
              title: 'About',
              children: [
                _buildSettingsTile(
                  context,
                  title: 'Version',
                  subtitle: '1.0.5',
                  icon: Icons.info,
                  onTap: null,
                ),
                _buildSettingsTile(
                  context,
                  title: 'Privacy Policy',
                  subtitle: 'Read our privacy policy',
                  icon: Icons.privacy_tip,
                  onTap: () {
                    // TODO: Implement privacy policy
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: kcAccentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: kcAccentColor,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: kcSecondaryTextColor,
          size: 16,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  /// Advanced Settings in its own card: below CHRONICLE, above Health & Readiness.
  Widget _buildAdvancedSettingsCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              'Analysis and memory',
              style: heading3Style(context).copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: kcAccentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.settings_applications,
                color: kcAccentColor,
                size: 24,
              ),
            ),
            title: Text(
              'Analysis, memory & response behavior',
              style: heading3Style(context).copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Memory lookback, response behavior, debug options',
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: kcSecondaryTextColor,
              size: 16,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdvancedSettingsView()),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: heading2Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: kcAccentColor,
          size: 24,
        ),
        title: Text(
          title,
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
          ),
        ),
        trailing: onTap != null
            ? const Icon(
                Icons.arrow_forward_ios,
                color: kcSecondaryTextColor,
                size: 16,
              )
            : null,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }
}

// ============================================================================
// FOLDER 1: Subscription & Account
// ============================================================================
class SubscriptionAccountFolderView extends StatelessWidget {
  const SubscriptionAccountFolderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: const BackButton(color: kcPrimaryTextColor),
        title: Text(
          'Subscription & Account',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AccountTile(),
            const SizedBox(height: 8),
            _SettingsTile(
              title: 'Subscription Management',
              subtitle: 'Manage your subscription tier and billing',
              icon: Icons.workspace_premium,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionManagementView(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FOLDER 2: Import & Export
// ============================================================================
class ImportExportFolderView extends StatelessWidget {
  const ImportExportFolderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: const BackButton(color: kcPrimaryTextColor),
        title: Text(
          'Import & Export',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'When you back up, files save to this device by default (App Documents). Choose a destination below to use a different folder or the cloud.',
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            _SettingsTile(
              title: 'Verify',
              subtitle: 'Obtain detailed info on backup files',
              icon: Icons.folder,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VerifyBackupScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                'On this device',
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            _SettingsTile(
              title: 'Local Backup',
              subtitle: 'Save to this device (App Documents or a folder). Use Files to copy to iCloud or a computer.',
              icon: Icons.folder,
              badge: 'Most private',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocalBackupSettingsView(
                      journalRepo: context.read<JournalRepository>(),
                    ),
                  ),
                );
              },
            ),
            if (Platform.isIOS)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 6, bottom: 4),
                child: Text(
                  'On iPhone: App Documents is included in iCloud Backup when enabled in Settings. You can also move exports to iCloud Drive via the Files app.',
                  style: bodyStyle(context).copyWith(
                    color: kcSecondaryTextColor,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                'In the cloud',
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            _SettingsTile(
              title: 'Google Drive',
              subtitle: 'Back up to your Google account. Restore on any device.',
              icon: Icons.cloud,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GoogleDriveSettingsView(
                      journalRepo: context.read<JournalRepository>(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _SettingsTile(
              title: 'Import Data',
              subtitle: 'Restore from .zip, .mcpkg, or .arcx backup files',
              icon: Icons.cloud_download,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImportStatusScreen(
                      onChooseFiles: () => _restoreDataFromSettings(context),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreDataFromSettings(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'mcpkg', 'arcx'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final files = result.files.where((f) => f.path != null).map((f) => f.path!).toList();
      
      if (files.isEmpty) {
        return;
      }

      final hasArcx = files.any((p) => p.endsWith('.arcx'));
      final hasZip = files.any((p) => p.endsWith('.zip') || p.endsWith('.mcpkg') || FileUtils.isMcpPackage(p));

      if (hasArcx) {
        final arcxFiles = files.where((p) => p.endsWith('.arcx')).toList();
        
        if (arcxFiles.length == 1) {
          final arcxFile = File(arcxFiles.first);
          if (!await arcxFile.exists()) {
            _showImportError(context, 'File not found');
            return;
          }

          if (!context.mounted) return;
          final progressCubit = context.read<ImportProgressCubit>();
          final journalRepo = context.read<JournalRepository>();
          final arcxPath = arcxFiles.first;
          progressCubit.start();
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          Future(() async {
            try {
              final chatRepo = ChatRepoImpl.instance;
              await chatRepo.initialize();
              PhaseRegimeService? phaseRegimeService;
              try {
                final analyticsService = AnalyticsService();
                final rivetSweepService = RivetSweepService(analyticsService);
                phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
                await phaseRegimeService.initialize();
              } catch (_) {}
              final importService = ARCXImportServiceV2(
                journalRepo: journalRepo,
                chatRepo: chatRepo,
                phaseRegimeService: phaseRegimeService,
              );
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
                  progressCubit.update(message, fraction);
                },
              );
              if (importResult.success) {
                progressCubit.complete(importResult);
              } else {
                progressCubit.fail(importResult.error);
              }
            } catch (e) {
              progressCubit.fail(e.toString());
            }
          });
        } else {
          if (!context.mounted) return;
          final progressCubit = context.read<ImportProgressCubit>();
          final journalRepo = context.read<JournalRepository>();
          progressCubit.startWithFiles(arcxFiles);
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          Future(() => _runMultipleArcImportInBackground(
            progressCubit: progressCubit,
            journalRepo: journalRepo,
            filePaths: arcxFiles,
          ));
        }
      } else if (hasZip) {
        final zipFiles = files.where((p) => p.endsWith('.zip') || p.endsWith('.mcpkg') || FileUtils.isMcpPackage(p)).toList();
        
        if (zipFiles.length == 1) {
          final zipFile = File(zipFiles.first);
          if (!await zipFile.exists()) {
            _showImportError(context, 'File not found');
            return;
          }

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );

          try {
            PhaseRegimeService? phaseRegimeService;
            try {
              final analyticsService = AnalyticsService();
              final rivetSweepService = RivetSweepService(analyticsService);
              phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
              await phaseRegimeService.initialize();
            } catch (e) {
              print('Warning: Could not initialize PhaseRegimeService: $e');
            }

            final chatRepo = ChatRepoImpl.instance;
            await chatRepo.initialize();
            
            final journalRepo = context.read<JournalRepository>();
            final importService = McpPackImportService(
              journalRepo: journalRepo,
              phaseRegimeService: phaseRegimeService,
              chatRepo: chatRepo,
            );

            final importResult = await importService.importFromPath(zipFiles.first);

            if (!context.mounted) return;
            Navigator.pop(context);

            if (importResult.success) {
              try {
                context.read<TimelineCubit>().reloadAllEntries();
              } catch (e) {
                print('Could not refresh timeline: $e');
              }
              
              _showImportSuccess(
                context,
                'Import Complete',
                'Imported ${importResult.totalEntries} entries and ${importResult.totalPhotos} media items.',
              );
              
              Future.delayed(const Duration(milliseconds: 500), () {
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const HomeView(initialTab: 0),
                    ),
                    (route) => false,
                  );
                }
              });
            } else {
              _showImportError(context, importResult.error ?? 'Import failed');
            }
          } catch (e) {
            if (!context.mounted) return;
            Navigator.pop(context);
            _showImportError(context, 'Import failed: $e');
          }
        }
      } else {
        _showImportError(context, 'Unsupported file format');
      }
    } catch (e) {
      _showImportError(context, 'Failed to select file: $e');
    }
  }

  static Future<void> _runMultipleArcImportInBackground({
    required ImportProgressCubit progressCubit,
    required JournalRepository journalRepo,
    required List<String> filePaths,
  }) async {
    final chatRepo = ChatRepoImpl.instance;
    await chatRepo.initialize();
    PhaseRegimeService? phaseRegimeService;
    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
    } catch (e) {
      print('Warning: Could not initialize PhaseRegimeService: $e');
    }
    final importService = ARCXImportServiceV2(
      journalRepo: journalRepo,
      chatRepo: chatRepo,
      phaseRegimeService: phaseRegimeService,
    );
    final sortedFiles = <String>[];
    final fileStats = <String, DateTime>{};
    for (final filePath in filePaths) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final stat = await file.stat();
          fileStats[filePath] = stat.modified;
          sortedFiles.add(filePath);
        }
      } catch (e) {
        sortedFiles.add(filePath);
        fileStats[filePath] = DateTime.now();
      }
    }
    sortedFiles.sort((a, b) => (fileStats[a] ?? DateTime.now()).compareTo(fileStats[b] ?? DateTime.now()));
    final total = sortedFiles.length;
    try {
      for (int i = 0; i < sortedFiles.length; i++) {
        final filePath = sortedFiles[i];
        progressCubit.updateFileStatus(i, ImportFileStatus.importing);
        progressCubit.update('Importing archive ${i + 1} of $total...', (i + 0.0) / total);
        if (!await File(filePath).exists()) {
          progressCubit.updateFileStatus(i, ImportFileStatus.failed);
          continue;
        }
        try {
          final result = await importService.import(
            arcxPath: filePath,
            options: ARCXImportOptions(
              validateChecksums: true,
              dedupeMedia: true,
              skipExisting: true,
              resolveLinks: true,
            ),
            password: null,
            onProgress: (message, [fraction = 0.0]) {
              progressCubit.update(message, (i + fraction.clamp(0.0, 1.0)) / total);
            },
          );
          if (result.success) {
            progressCubit.updateFileStatus(i, ImportFileStatus.completed);
          } else {
            progressCubit.updateFileStatus(i, ImportFileStatus.failed);
          }
        } catch (e) {
          progressCubit.updateFileStatus(i, ImportFileStatus.failed);
        }
      }
      progressCubit.update('Import complete', 1.0);
      progressCubit.complete();
    } catch (e) {
      progressCubit.fail('Import failed: $e');
    }
  }

  void _showImportError(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcBackgroundColor,
        title: const Text('Error', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showImportSuccess(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcBackgroundColor,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FOLDER: CHRONICLE (top-level, outside LUMARA)
// ============================================================================
class ChronicleFolderView extends StatelessWidget {
  const ChronicleFolderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: const BackButton(color: kcPrimaryTextColor),
        title: Text(
          'CHRONICLE',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingsTile(
              title: 'View CHRONICLE Layers',
              subtitle: 'Browse monthly, yearly, and multi-year temporal aggregations',
              icon: Icons.history,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChronicleLayersViewer(),
                  ),
                );
              },
            ),
            _SettingsTile(
              title: 'CHRONICLE Management',
              subtitle: 'Manual synthesis, export, and temporal aggregation controls',
              icon: Icons.settings,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChronicleManagementView(),
                  ),
                );
              },
            ),
            _SettingsTile(
              title: 'Privacy protection',
              subtitle: 'PII detection and masking for CHRONICLE and LUMARA',
              icon: Icons.security,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacySettingsView(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FOLDER 3a: Health & Readiness (Available to everyone)
// ============================================================================
class HealthReadinessFolderView extends StatelessWidget {
  const HealthReadinessFolderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: const BackButton(color: kcPrimaryTextColor),
        title: Text(
          'Health & Readiness',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingsTile(
              title: 'Health & Readiness',
              subtitle: 'Operational readiness and phase ratings',
              icon: Icons.assessment,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HealthReadinessView()),
                );
              },
            ),
            _SettingsTile(
              title: 'Medical',
              subtitle: 'Health data tracking and summary',
              icon: Icons.medical_services,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HealthView()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FOLDER 4: LUMARA
// ============================================================================
class LumaraFolderView extends StatefulWidget {
  const LumaraFolderView({super.key});

  @override
  State<LumaraFolderView> createState() => _LumaraFolderViewState();
}

class _LumaraFolderViewState extends State<LumaraFolderView> {
  int _favoritesCount = 0;
  int _savedChatsCount = 0;
  int _favoriteEntriesCount = 0;
  int _answersLimit = 25;
  int _chatsLimit = 25;
  int _entriesLimit = 25;
  bool _favoritesCountLoaded = false;
  bool _voiceoverEnabled = false;
  bool _voiceoverLoading = true;
  
  // LUMARA Persona state
  LumaraPersona _selectedPersona = LumaraPersona.auto;
  bool _personaLoading = true;
  
  // Therapeutic depth state
  int _therapeuticDepthLevel = 2;
  bool _webAccessEnabled = false;
  bool _lumaraSettingsLoading = true;

  // Engagement settings state
  EngagementSettings _engagementSettings = const EngagementSettings();
  bool _engagementSettingsLoading = true;

  // Memory Focus preset state
  MemoryFocusPreset _memoryFocusPreset = MemoryFocusPreset.balanced;
  bool _memoryFocusLoading = true;
  
  // Custom Memory Focus settings state
  bool _showCustomMemorySettings = false;
  int _customTimeWindowDays = 90;
  double _customSimilarityThreshold = 0.55;
  int _customMaxEntries = 20;
  bool _customMemorySettingsLoading = true;
  
  // Other LUMARA settings state
  bool _crossModalEnabled = true;
  bool _crossModalLoading = true;
  
  // Phase share settings
  bool _phaseSharePromptsEnabled = true;
  bool _phaseShareSettingsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavoritesCount();
    _loadVoiceoverPreference();
    _loadPersonaPreference();
    _loadLumaraSettings();
    _loadMemoryFocusPreset();
    _loadCrossModalSetting();
    _loadEngagementSettings();
    _loadPhaseShareSettings();
  }
  
  Future<void> _loadPhaseShareSettings() async {
    try {
      final shareService = PhaseShareService.instance;
      final enabled = await shareService.areSharePromptsEnabled();
      if (mounted) {
        setState(() {
          _phaseSharePromptsEnabled = enabled;
          _phaseShareSettingsLoading = false;
        });
      }
    } catch (e) {
      print('Error loading phase share settings: $e');
      if (mounted) {
        setState(() {
          _phaseShareSettingsLoading = false;
        });
      }
    }
  }
  
  Future<void> _togglePhaseSharePrompts(bool value) async {
    try {
      final shareService = PhaseShareService.instance;
      await shareService.setSharePromptsEnabled(value);
      if (mounted) {
        setState(() {
          _phaseSharePromptsEnabled = value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Phase share prompts enabled'
                  : 'Phase share prompts disabled',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: value ? Colors.green : Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating setting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _loadLumaraSettings() async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();
      final settings = await settingsService.loadAllSettings();
      if (mounted) {
        setState(() {
          _therapeuticDepthLevel = settings['therapeuticDepthLevel'] as int;
          _webAccessEnabled = settings['webAccessEnabled'] as bool;
          _lumaraSettingsLoading = false;
        });
      }
    } catch (e) {
      print('Error loading LUMARA settings: $e');
      if (mounted) {
        setState(() {
          _lumaraSettingsLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadMemoryFocusPreset() async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();
      final preset = await settingsService.getMemoryFocusPreset();
      
      if (preset == MemoryFocusPreset.custom) {
        final settings = await settingsService.loadAllSettings();
        if (mounted) {
          setState(() {
            _memoryFocusPreset = preset;
            _showCustomMemorySettings = true;
            _customTimeWindowDays = settings['timeWindowDays'] as int? ?? settings['lookbackYears'] as int? ?? 90;
            _customSimilarityThreshold = settings['similarityThreshold'] as double? ?? 0.55;
            _customMaxEntries = settings['maxMatches'] as int? ?? 20;
            _memoryFocusLoading = false;
            _customMemorySettingsLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _memoryFocusPreset = preset;
            _showCustomMemorySettings = false;
            _memoryFocusLoading = false;
            _customMemorySettingsLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading memory focus preset: $e');
      if (mounted) {
        setState(() {
          _memoryFocusLoading = false;
          _customMemorySettingsLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadCrossModalSetting() async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();
      final enabled = await settingsService.isCrossModalEnabled();
      if (mounted) {
        setState(() {
          _crossModalEnabled = enabled;
          _crossModalLoading = false;
        });
      }
    } catch (e) {
      print('Error loading cross-modal setting: $e');
      if (mounted) {
        setState(() {
          _crossModalLoading = false;
        });
      }
    }
  }

  Future<void> _loadEngagementSettings() async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();
      final engagement = await settingsService.getEngagementSettings();
      if (mounted) {
        setState(() {
          _engagementSettings = engagement;
          _engagementSettingsLoading = false;
        });
      }
    } catch (e) {
      print('Error loading engagement settings: $e');
      if (mounted) {
        setState(() {
          _engagementSettingsLoading = false;
        });
      }
    }
  }
  
  Future<void> _setTherapeuticDepthLevel(int level) async {
    setState(() {
      _therapeuticDepthLevel = level;
    });
    final settingsService = LumaraReflectionSettingsService.instance;
    await settingsService.setTherapeuticDepthLevel(level);
  }
  
  Future<void> _setWebAccessEnabled(bool enabled) async {
    setState(() {
      _webAccessEnabled = enabled;
    });
    final settingsService = LumaraReflectionSettingsService.instance;
    await settingsService.setWebAccessEnabled(enabled);
  }
  
  Future<void> _loadPersonaPreference() async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();
      final persona = await settingsService.getLumaraPersona();
      if (mounted) {
        setState(() {
          _selectedPersona = persona;
          _personaLoading = false;
        });
      }
    } catch (e) {
      print('Error loading persona preference: $e');
      if (mounted) {
        setState(() {
          _personaLoading = false;
        });
      }
    }
  }
  
  Future<void> _setPersona(LumaraPersona persona) async {
    setState(() {
      _personaLoading = true;
    });
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.setLumaraPersona(persona);
      if (mounted) {
        setState(() {
          _selectedPersona = persona;
          _personaLoading = false;
        });
      }
    } catch (e) {
      print('Error setting persona: $e');
      if (mounted) {
        setState(() {
          _personaLoading = false;
        });
      }
    }
  }

  Future<void> _loadFavoritesCount() async {
    try {
      await FavoritesService.instance.initialize();
      
      final answersLimit = await FavoritesService.instance.getCategoryLimit('answer');
      final chatsLimit = await FavoritesService.instance.getCategoryLimit('chat');
      final entriesLimit = await FavoritesService.instance.getCategoryLimit('journal_entry');
      
      final answersCount = await FavoritesService.instance.getCountByCategory('answer');
      final chatsCount = await FavoritesService.instance.getCountByCategory('chat');
      final entriesCount = await FavoritesService.instance.getCountByCategory('journal_entry');
      if (mounted) {
        setState(() {
          _answersLimit = answersLimit;
          _chatsLimit = chatsLimit;
          _entriesLimit = entriesLimit;
          _favoritesCount = answersCount;
          _savedChatsCount = chatsCount;
          _favoriteEntriesCount = entriesCount;
          _favoritesCountLoaded = true;
        });
      }
    } catch (e) {
      print('Error loading favorites count: $e');
      if (mounted) {
        setState(() {
          _favoritesCountLoaded = true;
        });
      }
    }
  }


  Future<void> _loadVoiceoverPreference() async {
    try {
      final enabled = await VoiceoverPreferenceService.instance.isVoiceoverEnabled();
      if (mounted) {
        setState(() {
          _voiceoverEnabled = enabled;
          _voiceoverLoading = false;
        });
      }
    } catch (e) {
      print('Error loading voiceover preference: $e');
      if (mounted) {
        setState(() {
          _voiceoverLoading = false;
        });
      }
    }
  }

  Future<void> _toggleVoiceover(bool value) async {
    try {
      await VoiceoverPreferenceService.instance.setVoiceoverEnabled(value);
      if (mounted) {
        setState(() {
          _voiceoverEnabled = value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Voiceover enabled - AI responses will be spoken aloud'
                  : 'Voiceover disabled - AI responses will be text only',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: value ? Colors.green : Colors.lightBlue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling Voiceover: $e'),
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
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: const BackButton(color: kcPrimaryTextColor),
        title: Text(
          'LUMARA',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Setup — API, reflection, voice (one place for technical config)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                'Setup',
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _SettingsTile(
              title: 'API',
              subtitle: 'API keys, provider selection, voice transcription',
              icon: Icons.settings_applications,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LumaraSettingsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Preferences — how LUMARA behaves
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                'Preferences',
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _SettingsTile(
              title: 'LUMARA Favorites',
              subtitle: _favoritesCountLoaded
                  ? 'Answers ($_favoritesCount/$_answersLimit), Chats ($_savedChatsCount/$_chatsLimit), Entries ($_favoriteEntriesCount/$_entriesLimit)'
                  : 'Manage your favorites',
              icon: Icons.star,
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FavoritesManagementView(),
                  ),
                );
                if (result == true || mounted) {
                  _loadFavoritesCount();
                }
              },
            ),
            // LUMARA Persona Card
            _buildPersonaCard(),
            // Memory Focus Preset Card
            _buildMemoryFocusCard(),
            // Engagement Mode Card
            _buildEngagementModeCard(),
            // Include Media Toggle
            _buildIncludeMediaToggle(),
            // Therapeutic Depth Slider
            _buildTherapeuticDepthCard(),
            // Web Search Toggle
            _buildWebSearchToggle(),
            // Voice Responses Toggle
            _buildVoiceResponsesToggle(),
            // Phase Share Settings
            _buildPhaseShareToggle(),
            // Temporal Notifications
            _SettingsTile(
              title: 'Temporal Notifications',
              subtitle: 'Daily prompts, monthly reviews, arc views, and summaries',
              icon: Icons.notifications_active,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TemporalNotificationSettingsView(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonaCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.theater_comedy,
                  color: kcAccentColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LUMARA Persona',
                        style: heading3Style(context).copyWith(
                          color: kcPrimaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choose how LUMARA responds to you',
                        style: bodyStyle(context).copyWith(
                          color: kcSecondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_personaLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          ...LumaraPersona.values.map((persona) => _buildPersonaOption(persona)),
        ],
      ),
    );
  }

  Widget _buildPersonaOption(LumaraPersona persona) {
    final isSelected = _selectedPersona == persona;
    return InkWell(
      onTap: _personaLoading ? null : () => _setPersona(persona),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? kcAccentColor : Colors.white38,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kcAccentColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              persona.icon,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    persona.displayName,
                    style: heading3Style(context).copyWith(
                      color: isSelected ? kcAccentColor : kcPrimaryTextColor,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    persona.description,
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryFocusCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.memory, color: kcAccentColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Memory Focus',
                        style: heading3Style(context).copyWith(
                          color: kcPrimaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'How much context LUMARA uses from your history',
                        style: bodyStyle(context).copyWith(
                          color: kcSecondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_memoryFocusLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          ...MemoryFocusPreset.values.map((preset) => _buildMemoryFocusOption(preset)),
          if (_showCustomMemorySettings) ..._buildCustomMemorySettings(),
        ],
      ),
    );
  }

  Widget _buildMemoryFocusOption(MemoryFocusPreset preset) {
    final isSelected = _memoryFocusPreset == preset;
    return InkWell(
      onTap: _memoryFocusLoading ? null : () => _setMemoryFocusPreset(preset),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? kcAccentColor : Colors.white38,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kcAccentColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.displayName,
                    style: bodyStyle(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? kcAccentColor : kcPrimaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preset.description,
                    style: bodyStyle(context).copyWith(
                      fontSize: 11,
                      color: kcSecondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setMemoryFocusPreset(MemoryFocusPreset preset) async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.setMemoryFocusPreset(preset);
      if (mounted) {
        setState(() {
          _memoryFocusPreset = preset;
          _showCustomMemorySettings = preset == MemoryFocusPreset.custom;
          
          if (preset == MemoryFocusPreset.custom) {
            _loadCustomMemorySettings();
          }
        });
      }
    } catch (e) {
      print('Error setting memory focus preset: $e');
    }
  }

  Future<void> _loadCustomMemorySettings() async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();
      final settings = await settingsService.loadAllSettings();
      if (mounted) {
        setState(() {
          _customTimeWindowDays = settings['timeWindowDays'] as int? ?? (settings['lookbackYears'] as int? ?? 5) * 365;
          _customSimilarityThreshold = settings['similarityThreshold'] as double? ?? 0.55;
          _customMaxEntries = settings['maxMatches'] as int? ?? 20;
          _customMemorySettingsLoading = false;
        });
      }
    } catch (e) {
      print('Error loading custom memory settings: $e');
      if (mounted) {
        setState(() {
          _customMemorySettingsLoading = false;
        });
      }
    }
  }

  List<Widget> _buildCustomMemorySettings() {
    return [
      const Divider(height: 1, color: Colors.white12),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          'Custom Settings',
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
      _buildCustomSliderCard(
        title: 'Time Window',
        subtitle: 'How far back LUMARA searches your history',
        icon: Icons.history,
        value: _customTimeWindowDays.toDouble(),
        min: 1,
        max: 365,
        divisions: 36,
        loading: _customMemorySettingsLoading,
        onChanged: (value) => _setCustomTimeWindowDays(value.round()),
        labels: const ['1 day', '30 days', '90 days', '180 days', '365 days'],
      ),
      _buildCustomSliderCard(
        title: 'Matching Precision',
        subtitle: 'How similar memories must be to include them',
        icon: Icons.tune,
        value: _customSimilarityThreshold,
        min: 0.3,
        max: 0.9,
        divisions: 12,
        loading: _customMemorySettingsLoading,
        onChanged: _setCustomSimilarityThreshold,
        labels: const ['Loose', 'Balanced', 'Strict'],
      ),
      _buildCustomSliderCard(
        title: 'Maximum Entries',
        subtitle: 'Maximum number of past entries to include',
        icon: Icons.format_list_numbered,
        value: _customMaxEntries.toDouble(),
        min: 1,
        max: 50,
        divisions: 49,
        loading: _customMemorySettingsLoading,
        onChanged: (value) => _setCustomMaxEntries(value.round()),
        labels: const ['1', '10', '20', '30', '50'],
      ),
    ];
  }

  Widget _buildCustomSliderCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required bool loading,
    required Function(double) onChanged,
    required List<String> labels,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: kcAccentColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: kcAccentColor,
            inactiveColor: Colors.grey.withValues(alpha: 0.3),
            onChanged: loading ? null : onChanged,
          ),
          if (labels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: labels.map((label) => Text(
                  label,
                  style: bodyStyle(context).copyWith(
                    color: kcSecondaryTextColor,
                    fontSize: 9,
                  ),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _setCustomTimeWindowDays(int days) async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.setTimeWindowDays(days);
      if (mounted) {
        setState(() {
          _customTimeWindowDays = days;
        });
      }
    } catch (e) {
      print('Error setting custom time window days: $e');
    }
  }

  Future<void> _setCustomSimilarityThreshold(double threshold) async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.setSimilarityThreshold(threshold);
      if (mounted) {
        setState(() {
          _customSimilarityThreshold = threshold;
        });
      }
    } catch (e) {
      print('Error setting custom similarity threshold: $e');
    }
  }

  Future<void> _setCustomMaxEntries(int entries) async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.setMaxMatches(entries);
      if (mounted) {
        setState(() {
          _customMaxEntries = entries;
        });
      }
    } catch (e) {
      print('Error setting custom max entries: $e');
    }
  }

  Widget _buildEngagementModeCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.tune, color: kcAccentColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Engagement Mode',
                        style: heading3Style(context).copyWith(
                          color: kcPrimaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'How deeply LUMARA engages with your reflections',
                        style: bodyStyle(context).copyWith(
                          color: kcSecondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_engagementSettingsLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          ...EngagementMode.values.map((mode) => _buildEngagementModeOption(mode)),
        ],
      ),
    );
  }

  Widget _buildEngagementModeOption(EngagementMode mode) {
    final isSelected = _engagementSettings.defaultMode == mode;
    return InkWell(
      onTap: _engagementSettingsLoading ? null : () => _setEngagementMode(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? kcAccentColor : Colors.white38,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kcAccentColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.displayName,
                    style: bodyStyle(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? kcAccentColor : kcPrimaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.description,
                    style: bodyStyle(context).copyWith(
                      fontSize: 11,
                      color: kcSecondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setEngagementMode(EngagementMode mode) async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      final updated = _engagementSettings.copyWith(defaultMode: mode);
      await settingsService.saveAllSettingsWithEngagement(
        engagementSettings: updated,
      );
      if (mounted) {
        setState(() {
          _engagementSettings = updated;
        });
      }
    } catch (e) {
      print('Error setting engagement mode: $e');
    }
  }

  Widget _buildIncludeMediaToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: SwitchListTile(
        title: Text(
          'Include Media',
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Analyze photos, audio, and video in reflections',
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
          ),
        ),
        value: _crossModalEnabled,
        onChanged: _crossModalLoading
            ? null
            : (value) => _setCrossModalEnabled(value),
        secondary: Icon(
          Icons.perm_media,
          color: kcAccentColor,
          size: 24,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Future<void> _setCrossModalEnabled(bool value) async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.setCrossModalEnabled(value);
      if (mounted) {
        setState(() {
          _crossModalEnabled = value;
        });
      }
    } catch (e) {
      print('Error setting cross-modal enabled: $e');
    }
  }

  Widget _buildTherapeuticDepthCard() {
    final depthLabels = ['Light', 'Moderate', 'Deep'];
    final depthDescriptions = [
      'Supportive and encouraging',
      'Reflective and insight-oriented',
      'Exploratory and emotionally resonant',
    ];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology,
                color: kcAccentColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Therapeutic Depth',
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      depthDescriptions[_therapeuticDepthLevel - 1],
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kcAccentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  depthLabels[_therapeuticDepthLevel - 1],
                  style: bodyStyle(context).copyWith(
                    color: kcAccentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: _therapeuticDepthLevel.toDouble(),
            min: 1,
            max: 3,
            divisions: 2,
            activeColor: kcAccentColor,
            inactiveColor: Colors.grey.withValues(alpha: 0.3),
            onChanged: _lumaraSettingsLoading
                ? null
                : (value) => _setTherapeuticDepthLevel(value.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: depthLabels.asMap().entries.map((entry) {
              final index = entry.key;
              final label = entry.value;
              final isSelected = _therapeuticDepthLevel == index + 1;
              return GestureDetector(
                onTap: _lumaraSettingsLoading
                    ? null
                    : () => _setTherapeuticDepthLevel(index + 1),
                child: Text(
                  label,
                  style: bodyStyle(context).copyWith(
                    color: isSelected ? kcAccentColor : kcSecondaryTextColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 11,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWebSearchToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: SwitchListTile(
        title: Text(
          'Web Search',
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Allow web lookups for external info',
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
          ),
        ),
        value: _webAccessEnabled,
        onChanged: _lumaraSettingsLoading
            ? null
            : (value) => _setWebAccessEnabled(value),
        secondary: Icon(
          Icons.language,
          color: kcAccentColor,
          size: 24,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }

  Widget _buildVoiceResponsesToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: SwitchListTile(
        title: Text(
          'Voice Responses',
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Speak LUMARA\'s responses aloud',
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
          ),
        ),
        value: _voiceoverEnabled,
        onChanged: _voiceoverLoading
            ? null
            : (value) => _toggleVoiceover(value),
        secondary: _voiceoverLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                Icons.volume_up,
                color: kcAccentColor,
                size: 24,
              ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }

  Widget _buildPhaseShareToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: SwitchListTile(
        title: Text(
          'Phase Share Prompts',
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Show prompts to share phase transitions',
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
            fontSize: 12,
          ),
        ),
        value: _phaseSharePromptsEnabled,
        onChanged: _phaseShareSettingsLoading
            ? null
            : (value) => _togglePhaseSharePrompts(value),
        secondary: _phaseShareSettingsLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                Icons.share,
                color: kcAccentColor,
                size: 24,
              ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }
}

// ============================================================================
// FOLDER 5: Bug Reporting
// ============================================================================
class BugReportingFolderView extends StatefulWidget {
  const BugReportingFolderView({super.key});

  @override
  State<BugReportingFolderView> createState() => _BugReportingFolderViewState();
}

class _BugReportingFolderViewState extends State<BugReportingFolderView> {
  bool _shakeToReportEnabled = true;
  bool _shakeToReportLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShakeToReportPreference();
  }

  Future<void> _loadShakeToReportPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('shake_to_report_enabled') ?? true;
      if (mounted) {
        setState(() {
          _shakeToReportEnabled = enabled;
          _shakeToReportLoading = false;
        });
      }
    } catch (e) {
      print('Error loading shake-to-report preference: $e');
      if (mounted) {
        setState(() {
          _shakeToReportLoading = false;
        });
      }
    }
  }

  Future<void> _toggleShakeToReport(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('shake_to_report_enabled', value);
      if (mounted) {
        setState(() {
          _shakeToReportEnabled = value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Shake to report enabled - shake your device to report bugs'
                  : 'Shake to report disabled',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: value ? Colors.green : Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling shake-to-report: $e'),
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
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: const BackButton(color: kcPrimaryTextColor),
        title: Text(
          'Bug Reporting',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shake to Report Toggle
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: SwitchListTile(
                title: Text(
                  'Shake to Report',
                  style: heading3Style(context).copyWith(
                    color: kcPrimaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Shake your device to quickly report a bug or issue',
                  style: bodyStyle(context).copyWith(
                    color: kcSecondaryTextColor,
                  ),
                ),
                value: _shakeToReportEnabled,
                onChanged: _shakeToReportLoading
                    ? null
                    : (value) => _toggleShakeToReport(value),
                secondary: _shakeToReportLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.vibration,
                        color: kcAccentColor,
                        size: 24,
                      ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Info card about bug reporting
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'How to Report Bugs',
                        style: heading3Style(context).copyWith(
                          color: kcPrimaryTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When Shake to Report is enabled, simply shake your device at any time to capture a bug report. This will include a screenshot and relevant diagnostic information to help us fix the issue faster.',
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
    );
  }
}

// ============================================================================
// FOLDER 6: Privacy & Security
// ============================================================================
class PrivacySecurityFolderView extends StatelessWidget {
  const PrivacySecurityFolderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: const BackButton(color: kcPrimaryTextColor),
        title: Text(
          'Privacy & Security',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingsTile(
              title: 'Throttle',
              subtitle: 'Manage rate limiting settings',
              icon: Icons.speed,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ThrottleSettingsView()),
                );
              },
            ),
            _SettingsTile(
              title: 'Privacy Protection',
              subtitle: 'Configure PII detection and masking settings',
              icon: Icons.security,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PrivacySettingsView()),
                );
              },
            ),
            _SettingsTile(
              title: 'Memory Modes',
              subtitle: 'Control how LUMARA uses your memories',
              icon: Icons.memory,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MemoryModeSettingsView()),
                );
              },
            ),
            _SettingsTile(
              title: 'Memory Snapshots',
              subtitle: 'Backup and restore your memories',
              icon: Icons.backup,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MemorySnapshotManagementView()),
                );
              },
            ),
            _SettingsTile(
              title: 'Memory Conflicts',
              subtitle: 'Resolve memory contradictions',
              icon: Icons.psychology,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ConflictManagementView()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SHARED WIDGETS
// ============================================================================

/// Account tile widget showing sign in/out status
class _AccountTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = FirebaseAuthService.instance;
    final isSignedIn = authService.isSignedIn;
    final isAnonymous = authService.isAnonymous;
    final userEmail = authService.userEmail;
    final displayName = authService.userDisplayName;

    String title;
    String subtitle;
    IconData icon;
    
    if (!isSignedIn || isAnonymous) {
      title = 'Sign In';
      subtitle = 'Sign in to sync your data across devices';
      icon = Icons.login;
    } else {
      title = displayName ?? userEmail ?? 'Signed In';
      subtitle = userEmail ?? 'Manage your account';
      icon = Icons.account_circle;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kcAccentColor.withValues(alpha: 0.2),
          backgroundImage: authService.userPhotoURL != null 
              ? NetworkImage(authService.userPhotoURL!) 
              : null,
          child: authService.userPhotoURL == null 
              ? Icon(icon, color: kcAccentColor, size: 24)
              : null,
        ),
        title: Text(
          title,
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: (!isSignedIn || isAnonymous)
            ? const Icon(
                Icons.arrow_forward_ios,
                color: kcSecondaryTextColor,
                size: 16,
              )
            : IconButton(
                icon: const Icon(Icons.logout, color: kcSecondaryTextColor),
                onPressed: () => _showSignOutDialog(context),
                tooltip: 'Sign Out',
              ),
        onTap: (!isSignedIn || isAnonymous)
            ? () => Navigator.of(context).pushNamed('/sign-in')
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }

  Future<void> _showSignOutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out', style: heading2Style(context)),
        content: Text(
          'Are you sure you want to sign out? Your local data will remain on this device.',
          style: bodyStyle(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: kcSecondaryTextColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kcDangerColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await FirebaseAuthService.instance.signOut();
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/sign-in',
            (route) => false,
          );

          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Signed out successfully'),
                  backgroundColor: kcSuccessColor,
                ),
              );
            }
          });
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign out failed: $e'),
              backgroundColor: kcDangerColor,
            ),
          );
        }
      }
    }
  }
}

/// Reusable settings tile widget
class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final String? badge;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: kcAccentColor,
          size: 24,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (badge != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Chip(
                  label: Text(
                    badge!,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
          ),
        ),
        trailing: onTap != null
            ? const Icon(
                Icons.arrow_forward_ios,
                color: kcSecondaryTextColor,
                size: 16,
              )
            : null,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }
}
