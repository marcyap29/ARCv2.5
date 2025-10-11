import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import '../../prism/mcp/models/mcp_schemas.dart';
import '../../prism/mcp/import/mcp_import_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive_io.dart';
import '../../prism/mcp/export/zip_utils.dart';
import '../../arc/core/journal_repository.dart';
import 'mcp_settings_cubit.dart';
import '../timeline/timeline_cubit.dart';
import 'mcp_bundle_health_view.dart';

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
            // Refresh timeline after successful MCP import
            if (state.successMessage!.contains('MCP import completed successfully')) {
              try {
                final timelineCubit = context.read<TimelineCubit>();
                timelineCubit.refreshEntries();
                print('DEBUG: Timeline refreshed after MCP import');
              } catch (e) {
                print('DEBUG: Could not refresh timeline: $e');
              }
            }
            
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
                
                // MCP Bundle Health Section
                _buildSection(
                  context: context,
                  title: 'Bundle Health Checker',
                  subtitle: 'Validate and repair MCP bundles for integrity and compliance',
                  children: [
                    _buildHealthCheckerButton(context),
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
      if (result != null) {
        final bundleDir = result;
        // Generate a simple bundle ID based on timestamp
        final bundleId = 'mcp_${DateTime.now().millisecondsSinceEpoch}';

        // Create ZIP of the export directory
        final zipFile = await ZipUtils.zipDirectory(
          bundleDir,
          zipFileName: '$bundleId.zip',
        );
        // Open iOS share sheet so user can save to Files
        await Share.shareXFiles([
          XFile(
            zipFile.path,
            mimeType: 'application/zip',
            name: '$bundleId.zip',
          ),
        ]);

        // After share sheet returns, show one concise success notice
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export saved: $bundleId.zip'),
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

      // Extract ZIP with robust handling of zero-byte files
      try {
        final bytes = await localZip.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes, verify: true);

        print('📦 ZIP contains ${archive.files.length} files:');
        for (final file in archive.files) {
          print('  ${file.name} (${file.size} bytes, isFile: ${file.isFile})');
        }

        // Custom extraction to handle zero-byte files properly
        await _extractArchiveRobustly(archive, dest);
      } catch (e) {
        print('❌ Primary extraction failed: $e');
        try {
          final inputStream = InputFileStream(localZip.path);
          final archive = ZipDecoder().decodeBuffer(inputStream);
          await _extractArchiveRobustly(archive, dest);
        } catch (e2) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Import failed: Unable to extract ZIP ($e2)'),
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
    print('🔍 DEBUG: Looking for manifest.json in: ${extractedDir.path}');

    // First, list what we have in the extraction directory
    print('🔍 DEBUG: Contents of extraction directory:');
    try {
      final entries = await extractedDir.list(followLinks: false).toList();
      for (final entry in entries) {
        if (entry is File) {
          final size = await entry.length();
          print('  📄 FILE: ${entry.path} ($size bytes)');
        } else if (entry is Directory) {
          print('  📁 DIR:  ${entry.path}');
        }
      }
    } catch (e) {
      print('❌ DEBUG: Error listing extraction directory: $e');
    }

    final manifestAtRoot = File('${extractedDir.path}/manifest.json');
    if (await manifestAtRoot.exists()) {
      print('✅ DEBUG: Found manifest.json at root: ${manifestAtRoot.path}');

      // Verify the bundle structure at root level
      final nodesFile = File('${extractedDir.path}/nodes.jsonl');
      final edgesFile = File('${extractedDir.path}/edges.jsonl');
      print('🔍 DEBUG: Root bundle structure check:');
      print('  manifest.json: EXISTS');
      print('  nodes.jsonl: ${await nodesFile.exists() ? "EXISTS" : "MISSING"}');
      print('  edges.jsonl: ${await edgesFile.exists() ? "EXISTS" : "MISSING"}');

      return extractedDir;
    }

    // Check first-level subdirectories
    final entries = await extractedDir.list(followLinks: false).toList();
    final dirs = entries.whereType<Directory>().toList();

    print('📂 DEBUG: Searching in ${dirs.length} subdirectories...');
    for (final d in dirs) {
      final mf = File('${d.path}/manifest.json');
      if (await mf.exists()) {
        print('✅ DEBUG: Found manifest.json in: ${d.path}');

        // Verify the bundle structure in subdirectory
        final nodesFile = File('${d.path}/nodes.jsonl');
        final edgesFile = File('${d.path}/edges.jsonl');
        print('🔍 DEBUG: Subdirectory bundle structure check:');
        print('  manifest.json: EXISTS');
        print('  nodes.jsonl: ${await nodesFile.exists() ? "EXISTS" : "MISSING"}');
        print('  edges.jsonl: ${await edgesFile.exists() ? "EXISTS" : "MISSING"}');

        // Also check the file sizes
        if (await nodesFile.exists()) {
          final size = await nodesFile.length();
          print('  nodes.jsonl size: $size bytes');
        }

        return d;
      }
    }

    // As a fallback, search depth=2
    print('🔍 Deep search in subdirectories...');
    for (final d in dirs) {
      try {
        final subEntries = await d.list(followLinks: false).toList();
        for (final se in subEntries.whereType<Directory>()) {
          final mf = File('${se.path}/manifest.json');
          if (await mf.exists()) {
            print('✅ Found manifest.json in: ${se.path}');
            return se;
          }
        }
      } catch (e) {
        print('⚠️ Error searching ${d.path}: $e');
      }
    }

    // List all files for debugging
    print('❌ manifest.json not found. Contents of ${extractedDir.path}:');
    try {
      await for (final entity in extractedDir.list(recursive: true, followLinks: false)) {
        print('  ${entity.path}');
      }
    } catch (e) {
      print('  Error listing files: $e');
    }

    // Throw instead of returning invalid directory
    throw Exception('manifest.json not found in extracted ZIP. Expected files: manifest.json, nodes.jsonl, edges.jsonl');
  }

  /// Custom archive extraction that handles zero-byte files properly
  Future<void> _extractArchiveRobustly(Archive archive, Directory destDir) async {
    print('🔧 Starting robust extraction to: ${destDir.path}');

    for (final file in archive.files) {
      if (!file.isFile) {
        print('📁 Skipping directory: ${file.name}');
        continue;
      }

      final filePath = '${destDir.path}/${file.name}';
      final outputFile = File(filePath);

      // Ensure parent directory exists
      final parentDir = outputFile.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
        print('📁 Created directory: ${parentDir.path}');
      }

      try {
        if (file.size == 0) {
          // Handle zero-byte files explicitly
          await outputFile.writeAsBytes(<int>[], flush: true);
          print('📄 Created zero-byte file: ${file.name}');
        } else {
          // Extract non-zero files normally
          final content = file.content as List<int>;
          await outputFile.writeAsBytes(content, flush: true);
          print('📄 Extracted file: ${file.name} (${content.length} bytes)');
        }
      } catch (e) {
        print('❌ Failed to extract ${file.name}: $e');
        // Try to create an empty file as fallback
        try {
          await outputFile.writeAsBytes(<int>[], flush: true);
          print('🔄 Created empty fallback file: ${file.name}');
        } catch (e2) {
          print('❌ Fallback also failed for ${file.name}: $e2');
        }
      }
    }

    print('✅ Extraction completed');
  }

  Widget _buildHealthCheckerButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const McpBundleHealthView(),
            ),
          );
        },
        icon: const Icon(Icons.health_and_safety),
        label: const Text('Open Bundle Health Checker'),
        style: ElevatedButton.styleFrom(
          backgroundColor: kcPrimaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
