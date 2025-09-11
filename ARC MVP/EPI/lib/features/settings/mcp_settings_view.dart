import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import '../../mcp/models/mcp_schemas.dart';
import '../../mcp/import/mcp_import_service.dart';
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
      child: _McpSettingsViewContent(),
    );
  }
}

class _McpSettingsViewContent extends StatelessWidget {
  _McpSettingsViewContent();

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
          value: state.selectedProfile,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: kcSurfaceAltColor,
          ),
          dropdownColor: kcSurfaceAltColor,
          style: bodyStyle(context).copyWith(color: Colors.white),
          items: McpStorageProfile.values.map((profile) {
            return DropdownMenuItem(
              value: profile,
              child: Text(_getProfileDescription(profile)),
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
      final outputDir = Directory('${directory.path}/mcp_exports');
      
      await context.read<McpSettingsCubit>().exportToMcp(
        outputDir: outputDir,
        scope: McpExportScope.all,
      );
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
      // For now, show a dialog asking for directory path
      final TextEditingController controller = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import MCP Bundle'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Enter MCP bundle directory path',
              hintText: '/path/to/mcp/bundle',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      
      if (result != null && result.isNotEmpty) {
        final bundleDir = Directory(result);
        if (await bundleDir.exists()) {
          await context.read<McpSettingsCubit>().importFromMcp(
            bundleDir: bundleDir,
            options: const McpImportOptions(),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Directory does not exist'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
