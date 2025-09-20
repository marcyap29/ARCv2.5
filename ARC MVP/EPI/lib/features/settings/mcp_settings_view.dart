import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import '../../mcp/models/mcp_schemas.dart';
import '../../mcp/import/mcp_import_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive_io.dart';
import '../../mcp/export/zip_utils.dart';
import '../../repositories/journal_repository.dart';
import 'mcp_settings_cubit.dart';

class McpSettingsView extends StatelessWidget {
  const McpSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => McpSettingsCubit(
        journalRepository: context.read<JournalRepository>(),
      ),
      child: const _McpSettingsViewContent(),
    );
  }
}

class _McpSettingsViewContent extends StatelessWidget {
  const _McpSettingsViewContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: Text(
          'MCP Export & Import',
          style: heading2Style(context).copyWith(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<McpSettingsCubit, McpSettingsState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red,
              ),
            );
          }
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // MCP Export Section
                _buildSection(
                  context: context,
                  title: 'Export to MCP Format',
                  subtitle: 'Export your journal data to MCP Memory Bundle format for AI ecosystem interoperability',
                  children: [
                    _buildStorageProfileSelector(context, state),
                    const SizedBox(height: 16),
                    _buildExportButton(context, state),
                    if (state.isExporting) ...[
                      const SizedBox(height: 16),
                      _buildProgressIndicator(context, state),
                    ],
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // MCP Import Section
                _buildSection(
                  context: context,
                  title: 'Import from MCP Format',
                  subtitle: 'Import journal data from MCP Memory Bundle format',
                  children: [
                    _buildImportButton(context, state),
                    if (state.isImporting) ...[
                      const SizedBox(height: 16),
                      _buildProgressIndicator(context, state),
                    ],
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Information Section
                _buildInfoSection(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Card(
      color: kcSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: heading3Style(context).copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: bodyStyle(context).copyWith(color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStorageProfileSelector(BuildContext context, McpSettingsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Storage Profile',
          style: bodyStyle(context).copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<McpStorageProfile>(
          initialValue: state.selectedProfile,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: kcSurfaceAltColor,
          ),
          isExpanded: true,
          dropdownColor: kcSurfaceAltColor,
          style: bodyStyle(context).copyWith(color: Colors.white),
          items: McpStorageProfile.values.map((profile) {
            return DropdownMenuItem(
              value: profile,
              child: Text(
                _getProfileDescription(profile),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                softWrap: false,
              ),
            );
          }).toList(),
          onChanged: (profile) {
            if (profile != null) {
              context.read<McpSettingsCubit>().setStorageProfile(profile);
            }
          },
        ),
      ],
    );
  }

  Widget _buildExportButton(BuildContext context, McpSettingsState state) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: state.isLoading ? null : () => _exportToMcp(context),
        icon: const Icon(Icons.cloud_upload),
        label: Text(
          state.isExporting ? 'Exporting...' : 'Export to MCP',
          style: bodyStyle(context).copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: kcPrimaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildImportButton(BuildContext context, McpSettingsState state) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: state.isLoading ? null : () => _importFromMcp(context),
        icon: const Icon(Icons.cloud_download),
        label: Text(
          state.isImporting ? 'Importing...' : 'Import from MCP',
          style: bodyStyle(context).copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: kcAccentColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context, McpSettingsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.currentOperation != null) ...[
          Text(
            state.currentOperation!,
            style: bodyStyle(context).copyWith(color: Colors.grey[400]),
          ),
          const SizedBox(height: 8),
        ],
        LinearProgressIndicator(
          value: state.progress,
          backgroundColor: Colors.grey[800],
          valueColor: AlwaysStoppedAnimation<Color>(
            state.isExporting ? kcPrimaryColor : kcAccentColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(state.progress * 100).toInt()}%',
          style: bodyStyle(context).copyWith(color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Card(
      color: kcSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About MCP Format',
              style: heading3Style(context).copyWith(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'MCP (Memory Bundle) is a standardized format for exporting and importing memory data across AI systems. It enables:',
              style: bodyStyle(context).copyWith(color: Colors.grey[400]),
            ),
            const SizedBox(height: 12),
            _buildInfoItem(context, '• Interoperability with other AI memory systems'),
            _buildInfoItem(context, '• Structured data with semantic relationships'),
            _buildInfoItem(context, '• Privacy protection and data portability'),
            _buildInfoItem(context, '• Content-addressable storage for efficiency'),
            _buildInfoItem(context, '• Deterministic exports with validation'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: bodyStyle(context).copyWith(color: Colors.grey[400]),
      ),
    );
  }

  String _getProfileDescription(McpStorageProfile profile) {
    switch (profile) {
      case McpStorageProfile.minimal:
        return 'Minimal - Basic data only (fastest)';
      case McpStorageProfile.spaceSaver:
        return 'Space Saver - Compressed data (smaller size)';
      case McpStorageProfile.balanced:
        return 'Balanced - Good balance of size and detail';
      case McpStorageProfile.hiFidelity:
        return 'High Fidelity - Complete data with all details';
    }
  }

  Future<void> _exportToMcp(BuildContext context) async {
    try {
      // Get downloads directory
      final directory = await getApplicationDocumentsDirectory();
      final rootDir = Directory('${directory.path}/mcp_exports');
      if (!await rootDir.exists()) {
        await rootDir.create(recursive: true);
      }
      // Unique folder per export so each bundle is isolated
      final runDir = Directory('${rootDir.path}/${DateTime.now().millisecondsSinceEpoch}');
      await runDir.create(recursive: true);
      
      final result = await context.read<McpSettingsCubit>().exportToMcp(
        outputDir: runDir,
        scope: McpExportScope.all,
        emitSuccessMessage: false,
      );

      // On success: zip the folder and open share sheet so user chooses destination in Files
      if (result != null && result.success) {
        final bundleDir = result.outputDir;
        // Create ZIP of the export directory
        final zipFile = await ZipUtils.zipDirectory(
          bundleDir,
          zipFileName: 'mcp_${result.bundleId}.zip',
        );
        // Open iOS share sheet so user can save to Files
        await Share.shareXFiles([
          XFile(
            zipFile.path,
            mimeType: 'application/zip',
            name: 'mcp_${result.bundleId}.zip',
          ),
        ]);

        // After share sheet returns, show one concise success notice
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export saved: mcp_${result.bundleId}.zip'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importFromMcp(BuildContext context) async {
    try {
      // Let the user pick a .zip or a folder containing an MCP bundle
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        allowMultiple: false,
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedPath = result.files.single.path;
      if (pickedPath == null) return;

      final pickedFile = File(pickedPath);
      if (!await pickedFile.exists()) return;

      // Copy picked ZIP into app sandbox first to avoid security-scope issues
      final docs = await getApplicationDocumentsDirectory();
      final importRoot = Directory('${docs.path}/mcp_imports');
      if (!await importRoot.exists()) await importRoot.create(recursive: true);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final localZip = File('${importRoot.path}/incoming_$ts.zip');
      await localZip.writeAsBytes(await pickedFile.readAsBytes(), flush: true);

      // Unzip into app documents under mcp_imports/<timestamp>
      final dest = Directory('${importRoot.path}/extracted_$ts');
      await dest.create(recursive: true);

      // Extract ZIP with two strategies for robustness
      try {
        final bytes = await localZip.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes, verify: true);
        extractArchiveToDisk(archive, dest.path);
      } catch (_) {
        try {
          final inputStream = InputFileStream(localZip.path);
          final archive = ZipDecoder().decodeBuffer(inputStream);
          extractArchiveToDisk(archive, dest.path);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Import failed: Unable to extract ZIP ($e)'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Locate bundle root (some zips contain a top-level folder)
      final bundleRoot = await _locateBundleRoot(dest);

      // Kick off import from detected bundle root directory
      await context.read<McpSettingsCubit>().importFromMcp(
        bundleDir: bundleRoot,
        options: const McpImportOptions(),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Find the directory that actually contains manifest.json
  Future<Directory> _locateBundleRoot(Directory extractedDir) async {
    final manifestAtRoot = File('${extractedDir.path}/manifest.json');
    if (await manifestAtRoot.exists()) {
      return extractedDir;
    }

    // Check first-level subdirectories
    final entries = await extractedDir.list(followLinks: false).toList();
    final dirs = entries.whereType<Directory>().toList();
    for (final d in dirs) {
      final mf = File('${d.path}/manifest.json');
      if (await mf.exists()) {
        return d;
      }
    }

    // As a fallback, search depth=2
    for (final d in dirs) {
      final subEntries = await d.list(followLinks: false).toList();
      for (final se in subEntries.whereType<Directory>()) {
        final mf = File('${se.path}/manifest.json');
        if (await mf.exists()) {
          return se;
        }
      }
    }

    // If not found, return the original dir (import will surface an error)
    return extractedDir;
  }
}
