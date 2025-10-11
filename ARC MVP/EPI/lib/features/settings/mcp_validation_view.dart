import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import 'mcp_validation_cubit.dart';

class McpValidationView extends StatelessWidget {
  const McpValidationView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => McpValidationCubit(),
      child: const _McpValidationViewContent(),
    );
  }
}

class _McpValidationViewContent extends StatefulWidget {
  const _McpValidationViewContent();

  @override
  State<_McpValidationViewContent> createState() => _McpValidationViewContentState();
}

class _McpValidationViewContentState extends State<_McpValidationViewContent> {
  bool _autoRepair = true;
  String? _selectedBundlePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: Text(
          'Validate MCP Bundle',
          style: heading2Style(context).copyWith(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<McpValidationCubit, McpValidationState>(
        listener: (context, state) {
          if (state is McpValidationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
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
                // Bundle Selection Section
                _buildSelectionSection(context, state),

                const SizedBox(height: 24),

                // Options Section
                _buildOptionsSection(context, state),

                const SizedBox(height: 24),

                // Validate Button
                _buildValidateButton(context, state),

                const SizedBox(height: 32),

                // Results Section
                if (state is McpValidationLoading)
                  _buildLoadingSection(context, state)
                else if (state is McpValidationSuccess)
                  _buildResultsSection(context, state),

                const SizedBox(height: 32),

                // Info Section
                _buildInfoSection(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectionSection(BuildContext context, McpValidationState state) {
    return Card(
      color: kcSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Bundle',
              style: heading3Style(context).copyWith(color: Colors.white),
            ),
            const SizedBox(height: 16),
            if (_selectedBundlePath != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kcSurfaceAltColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_zip,
                      color: kcAccentColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getFileName(_selectedBundlePath!),
                            style: bodyStyle(context).copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedBundlePath!,
                            style: bodyStyle(context).copyWith(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _selectedBundlePath = null;
                        });
                        context.read<McpValidationCubit>().reset();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state is McpValidationLoading ? null : _pickBundle,
                icon: const Icon(Icons.folder_open),
                label: Text(
                  _selectedBundlePath == null ? 'Choose Bundle File' : 'Choose Different Bundle',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsSection(BuildContext context, McpValidationState state) {
    return Card(
      color: kcSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Validation Options',
              style: heading3Style(context).copyWith(color: Colors.white),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(
                'Auto-repair Issues',
                style: bodyStyle(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Automatically fix common issues like missing IDs and timestamps',
                style: bodyStyle(context).copyWith(color: Colors.grey[400]),
              ),
              value: _autoRepair,
              onChanged: state is McpValidationLoading
                  ? null
                  : (value) {
                      setState(() {
                        _autoRepair = value;
                      });
                    },
              activeTrackColor: kcAccentColor,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidateButton(BuildContext context, McpValidationState state) {
    final isEnabled = _selectedBundlePath != null && state is! McpValidationLoading;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? () => _validateBundle(context) : null,
        icon: const Icon(Icons.health_and_safety),
        label: Text(
          state is McpValidationLoading ? 'Validating...' : 'Validate Bundle',
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

  Widget _buildLoadingSection(BuildContext context, McpValidationLoading state) {
    return Card(
      color: kcSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(kcAccentColor),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    state.message,
                    style: bodyStyle(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection(BuildContext context, McpValidationSuccess state) {
    final result = state.result;
    final isValid = result.isValid;

    return Card(
      color: kcSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Row(
              children: [
                Icon(
                  isValid ? Icons.check_circle : Icons.error,
                  color: isValid ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isValid ? 'Bundle is Valid' : 'Validation Failed',
                        style: heading3Style(context).copyWith(
                          color: isValid ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (state.autoRepaired)
                        Text(
                          'Auto-repaired ${result.repairLog.length} issues',
                          style: bodyStyle(context).copyWith(
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Errors Section
            if (result.errors.isNotEmpty) ...[
              _buildResultCategory(
                context,
                icon: Icons.error_outline,
                iconColor: Colors.red,
                title: 'Errors (${result.errors.length})',
                items: result.errors,
              ),
              const SizedBox(height: 16),
            ],

            // Warnings Section
            if (result.warnings.isNotEmpty) ...[
              _buildResultCategory(
                context,
                icon: Icons.warning_amber,
                iconColor: Colors.orange,
                title: 'Warnings (${result.warnings.length})',
                items: result.warnings,
              ),
              const SizedBox(height: 16),
            ],

            // Repair Log Section
            if (result.repairLog.isNotEmpty) ...[
              _buildResultCategory(
                context,
                icon: Icons.build,
                iconColor: Colors.blue,
                title: 'Repairs Made (${result.repairLog.length})',
                items: result.repairLog,
              ),
              const SizedBox(height: 16),
            ],

            // Summary
            if (isValid && result.errors.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bundle structure is valid and ready for import',
                        style: bodyStyle(context).copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildResultCategory(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: bodyStyle(context).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kcSurfaceAltColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: bodyStyle(context).copyWith(
                        color: Colors.grey[400],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: bodyStyle(context).copyWith(
                          color: Colors.grey[300],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
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
              'About Bundle Validation',
              style: heading3Style(context).copyWith(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'The MCP Bundle Doctor validates bundle structure and ensures data integrity. It checks:',
              style: bodyStyle(context).copyWith(color: Colors.grey[400]),
            ),
            const SizedBox(height: 12),
            _buildInfoItem(context, '• Schema version format'),
            _buildInfoItem(context, '• Bundle and node ID uniqueness'),
            _buildInfoItem(context, '• Timestamp validity'),
            _buildInfoItem(context, '• Edge reference integrity'),
            _buildInfoItem(context, '• Required field presence'),
            const SizedBox(height: 16),
            Text(
              'Auto-repair can fix common issues like missing IDs, timestamps, and invalid references without data loss.',
              style: bodyStyle(context).copyWith(
                color: Colors.grey[400],
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
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

  String _getFileName(String path) {
    return path.split('/').last;
  }

  Future<void> _pickBundle() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) return;

      setState(() {
        _selectedBundlePath = path;
      });

      // Reset validation state
      if (mounted) {
        context.read<McpValidationCubit>().reset();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _validateBundle(BuildContext context) async {
    if (_selectedBundlePath == null) return;

    await context.read<McpValidationCubit>().validateBundle(
          path: _selectedBundlePath!,
          autoRepair: _autoRepair,
        );
  }
}
