import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:my_app/core/mcp/validation/mcp_validator.dart';
import 'package:my_app/core/mcp/export/manifest_builder.dart';
import 'package:my_app/core/mcp/validation/mcp_bundle_repair_service.dart';
import 'package:my_app/core/mcp/export/zip_utils.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

/// MCP Bundle Health Checker - Comprehensive validation and repair interface
class McpBundleHealthView extends StatefulWidget {
  const McpBundleHealthView({Key? key}) : super(key: key);

  @override
  State<McpBundleHealthView> createState() => _McpBundleHealthViewState();
}

class _McpBundleHealthViewState extends State<McpBundleHealthView> {
  BundleHealthState _healthState = BundleHealthState.idle;
  BundleHealthReport? _healthReport;
  String? _selectedBundlePath;
  bool _isAnalyzing = false;
  bool _isRepairing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcSurfaceColor,
      appBar: AppBar(
        title: Text(
          'MCP Bundle Health',
          style: heading2Style(context).copyWith(color: kcPrimaryColor),
        ),
        backgroundColor: kcSurfaceColor,
        elevation: 0,
        actions: [
          if (_healthState != BundleHealthState.idle)
            IconButton(
              icon: const Icon(Icons.refresh, color: kcPrimaryColor),
              onPressed: _isAnalyzing ? null : _analyzeBundle,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            
            if (_healthState == BundleHealthState.idle) ...[
              _buildBundleSelector(),
            ] else ...[
              _buildHealthReport(),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
            
            if (_isAnalyzing || _isRepairing) ...[
              const SizedBox(height: 24),
              _buildProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      color: kcSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.health_and_safety,
                  color: kcPrimaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Bundle Health Checker',
                  style: heading3Style(context).copyWith(color: kcPrimaryColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Comprehensive validation and repair for MCP Memory Bundles. Check bundle integrity, validate schemas, and automatically fix common issues.',
              style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBundleSelector() {
    return Card(
      color: kcSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Bundle to Analyze',
              style: heading3Style(context).copyWith(color: kcTextColor),
            ),
            const SizedBox(height: 16),
            
            if (_selectedBundlePath != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kcSurfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kcBorderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder, color: kcPrimaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedBundlePath!,
                        style: bodyStyle(context).copyWith(color: kcTextColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: kcDangerColor),
                      onPressed: () {
                        setState(() {
                          _selectedBundlePath = null;
                          _healthState = BundleHealthState.idle;
                          _healthReport = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectBundle,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Select Bundle Folder'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (_selectedBundlePath != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _analyzeBundle,
                      icon: const Icon(Icons.search),
                      label: const Text('Analyze'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kcSuccessColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildHealthReport() {
    if (_healthReport == null) return const SizedBox.shrink();

    return Card(
      color: kcSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getHealthStatusIcon(),
                  color: _getHealthStatusColor(),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Health Report',
                  style: heading3Style(context).copyWith(color: kcTextColor),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getHealthStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _getHealthStatusColor()),
                  ),
                  child: Text(
                    _getHealthStatusText(),
                    style: captionStyle(context).copyWith(
                      color: _getHealthStatusColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Bundle Info
            _buildInfoSection('Bundle Information', [
              _buildInfoRow('Path', _selectedBundlePath ?? 'Unknown'),
              _buildInfoRow('Bundle ID', _healthReport!.bundleId),
              _buildInfoRow('Version', _healthReport!.version),
              _buildInfoRow('Created', _healthReport!.createdAt),
              _buildInfoRow('Storage Profile', _healthReport!.storageProfile),
            ]),
            
            const SizedBox(height: 20),
            
            // File Status
            _buildFileStatusSection(),
            
            const SizedBox(height: 20),
            
            // Validation Results
            _buildValidationSection(),
            
            if (_healthReport!.errors.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildErrorsSection(),
            ],
            
            if (_healthReport!.warnings.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildWarningsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'File Status',
          style: heading3Style(context).copyWith(color: kcTextColor),
        ),
        const SizedBox(height: 12),
        ..._healthReport!.fileStatus.entries.map((entry) {
          final status = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kcSurfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: status.exists ? kcSuccessColor : kcDangerColor,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  status.exists ? Icons.check_circle : Icons.error,
                  color: status.exists ? kcSuccessColor : kcDangerColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: bodyStyle(context).copyWith(
                          color: kcTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (status.exists) ...[
                        Text(
                          'Size: ${_formatBytes(status.sizeBytes)}',
                          style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
                        ),
                        if (status.checksumValid != null)
                          Text(
                            'Checksum: ${status.checksumValid! ? "Valid" : "Invalid"}',
                            style: captionStyle(context).copyWith(
                              color: status.checksumValid! ? kcSuccessColor : kcDangerColor,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildValidationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Validation Results',
          style: heading3Style(context).copyWith(color: kcTextColor),
        ),
        const SizedBox(height: 12),
        
        _buildValidationItem(
          'Manifest Validation',
          _healthReport!.manifestValid,
          'Bundle manifest is properly formatted and valid',
        ),
        
        _buildValidationItem(
          'Schema Validation',
          _healthReport!.schemaValid,
          'All NDJSON files conform to MCP schema',
        ),
        
        _buildValidationItem(
          'Checksum Verification',
          _healthReport!.checksumsValid,
          'File checksums match manifest values',
        ),
        
        _buildValidationItem(
          'Data Integrity',
          _healthReport!.dataIntegrityValid,
          'All data relationships and references are valid',
        ),
      ],
    );
  }

  Widget _buildValidationItem(String title, bool isValid, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isValid ? kcSuccessColor : kcDangerColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.error,
            color: isValid ? kcSuccessColor : kcDangerColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: bodyStyle(context).copyWith(
                    color: kcTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Errors (${_healthReport!.errors.length})',
          style: heading3Style(context).copyWith(color: kcDangerColor),
        ),
        const SizedBox(height: 12),
        ..._healthReport!.errors.map((error) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kcDangerColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kcDangerColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error, color: kcDangerColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      error.title,
                      style: bodyStyle(context).copyWith(
                        color: kcDangerColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      error.description,
                      style: captionStyle(context).copyWith(color: kcTextColor),
                    ),
                    if (error.suggestion != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Suggestion: ${error.suggestion}',
                        style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildWarningsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Warnings (${_healthReport!.warnings.length})',
          style: heading3Style(context).copyWith(color: kcWarningColor),
        ),
        const SizedBox(height: 12),
        ..._healthReport!.warnings.map((warning) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kcWarningColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kcWarningColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning, color: kcWarningColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      warning.title,
                      style: bodyStyle(context).copyWith(
                        color: kcWarningColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      warning.description,
                      style: captionStyle(context).copyWith(color: kcTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildActionButtons() {
    final hasErrors = _healthReport?.errors.isNotEmpty == true;
    final hasWarnings = _healthReport?.warnings.isNotEmpty == true;
    final canRepair = hasErrors || hasWarnings;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isAnalyzing ? null : _analyzeBundle,
            icon: const Icon(Icons.refresh),
            label: const Text('Re-analyze'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kcPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (canRepair)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isRepairing ? null : _repairBundle,
              icon: const Icon(Icons.build),
              label: const Text('Auto-Repair'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kcWarningColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Card(
      color: kcSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircularProgressIndicator(color: kcPrimaryColor),
            const SizedBox(height: 16),
            Text(
              _isAnalyzing ? 'Analyzing bundle...' : 'Repairing bundle...',
              style: bodyStyle(context).copyWith(color: kcTextColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: heading3Style(context).copyWith(color: kcTextColor),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: bodyStyle(context).copyWith(color: kcTextColor),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  IconData _getHealthStatusIcon() {
    if (_healthReport == null) return Icons.help;
    if (_healthReport!.errors.isNotEmpty) return Icons.error;
    if (_healthReport!.warnings.isNotEmpty) return Icons.warning;
    return Icons.check_circle;
  }

  Color _getHealthStatusColor() {
    if (_healthReport == null) return kcSecondaryTextColor;
    if (_healthReport!.errors.isNotEmpty) return kcDangerColor;
    if (_healthReport!.warnings.isNotEmpty) return kcWarningColor;
    return kcSuccessColor;
  }

  String _getHealthStatusText() {
    if (_healthReport == null) return 'Unknown';
    if (_healthReport!.errors.isNotEmpty) return 'Issues Found';
    if (_healthReport!.warnings.isNotEmpty) return 'Warnings';
    return 'Healthy';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Action methods
  Future<void> _selectBundle() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      allowMultiple: false,
    );
    
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.path != null) {
        setState(() {
          _selectedBundlePath = file.path!;
          _healthState = BundleHealthState.idle;
          _healthReport = null;
        });
      }
    }
  }

  Future<void> _analyzeBundle() async {
    if (_selectedBundlePath == null) return;

    setState(() {
      _isAnalyzing = true;
      _healthState = BundleHealthState.analyzing;
    });

    try {
      final zipFile = File(_selectedBundlePath!);
      final report = await _performHealthCheck(zipFile);
      
      setState(() {
        _healthReport = report;
        _healthState = BundleHealthState.analyzed;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _healthState = BundleHealthState.error;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Analysis failed: $e'),
          backgroundColor: kcDangerColor,
        ),
      );
    }
  }

  Future<void> _repairBundle() async {
    if (_healthReport == null || _selectedBundlePath == null) return;

    setState(() {
      _isRepairing = true;
    });

    try {
      final bundleDir = Directory(_selectedBundlePath!);
      final repairService = McpBundleRepairService(bundleDir);
      final repairResult = await repairService.repairBundle();
      
      if (repairResult.success) {
        // Show repair summary
        _showRepairSummary(repairResult.repairs);
        
        // Re-analyze after repair
        await _analyzeBundle();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bundle repair completed: ${repairResult.repairs.length} repairs applied'),
            backgroundColor: kcSuccessColor,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Repair failed: ${repairResult.errors.join(', ')}'),
            backgroundColor: kcDangerColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Repair failed: $e'),
          backgroundColor: kcDangerColor,
        ),
      );
    } finally {
      setState(() {
        _isRepairing = false;
      });
    }
  }

  void _showRepairSummary(List<BundleRepair> repairs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repair Summary'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: repairs.length,
            itemBuilder: (context, index) {
              final repair = repairs[index];
              return ListTile(
                leading: Icon(
                  _getRepairIcon(repair.type),
                  color: _getRepairColor(repair.severity),
                ),
                title: Text(repair.description),
                subtitle: Text('Severity: ${repair.severity.name}'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  IconData _getRepairIcon(RepairType type) {
    switch (type) {
      case RepairType.missingFile:
        return Icons.add_circle;
      case RepairType.emptyFile:
        return Icons.edit;
      case RepairType.invalidStructure:
        return Icons.build;
      case RepairType.invalidRecord:
        return Icons.cleaning_services;
      case RepairType.checksumMismatch:
        return Icons.verified;
      case RepairType.dataIntegrity:
        return Icons.link;
      case RepairType.chatJournalSeparation:
        return Icons.article;
    }
  }

  Color _getRepairColor(RepairSeverity severity) {
    switch (severity) {
      case RepairSeverity.low:
        return kcSuccessColor;
      case RepairSeverity.medium:
        return kcWarningColor;
      case RepairSeverity.high:
        return kcDangerColor;
    }
  }

  Future<BundleHealthReport> _performHealthCheck(File zipFile) async {
    final report = BundleHealthReport(
      bundleId: 'unknown',
      version: 'unknown',
      createdAt: 'unknown',
      storageProfile: 'unknown',
      fileStatus: {},
      manifestValid: false,
      schemaValid: false,
      checksumsValid: false,
      dataIntegrityValid: false,
      errors: [],
      warnings: [],
    );

    // Extract zip to temporary directory for validation
    Directory? bundleDir;
    try {
      bundleDir = await ZipUtils.extractZip(zipFile);
    } catch (e) {
      report.errors.add(HealthIssue(
        title: 'ZIP Extraction Failed',
        description: 'Could not extract ZIP file: $e',
        suggestion: 'Check if ZIP file is valid and not corrupted',
      ));
      return report;
    }

    try {
      // Check required files
      final requiredFiles = [
        'manifest.json',
        'nodes.jsonl',
        'edges.jsonl',
        'pointers.jsonl',
        'embeddings.jsonl',
      ];

      for (final filename in requiredFiles) {
        final file = File('${bundleDir.path}/$filename');
        final exists = await file.exists();
        final sizeBytes = exists ? await file.length() : 0;
        
        report.fileStatus[filename] = FileStatus(
          exists: exists,
          sizeBytes: sizeBytes,
          checksumValid: null, // Will be set later
        );
      }

      // Validate manifest
      try {
        final manifestFile = File('${bundleDir.path}/manifest.json');
      if (await manifestFile.exists()) {
        final manifest = await McpManifestBuilder.readManifest(manifestFile);
        report.bundleId = manifest.bundleId;
        report.version = manifest.version;
        report.createdAt = manifest.createdAt.toIso8601String();
        report.storageProfile = manifest.storageProfile;
        report.manifestValid = true;
      }
    } catch (e) {
      report.errors.add(HealthIssue(
        title: 'Manifest Validation Failed',
        description: 'Could not read or parse manifest.json: $e',
        suggestion: 'Check if manifest.json is valid JSON and follows MCP schema',
      ));
    }

    // Validate NDJSON files using bundle validation
    try {
      final validationResult = await McpValidator.validateBundle(bundleDir);
      report.schemaValid = validationResult.isValid;
      
      if (!validationResult.isValid) {
        for (final error in validationResult.errors) {
          report.errors.add(HealthIssue(
            title: 'Schema Validation Failed',
            description: error,
            suggestion: 'Check NDJSON format and field validation',
          ));
        }
      }
    } catch (e) {
      report.errors.add(HealthIssue(
        title: 'Schema Validation Error',
        description: 'Could not validate NDJSON files: $e',
        suggestion: 'Check file permissions and format',
      ));
    }

    // Check checksums
    try {
      if (report.manifestValid) {
        final manifestFile = File('${bundleDir.path}/manifest.json');
        final manifest = await McpManifestBuilder.readManifest(manifestFile);
        
        final ndjsonFiles = {
          'nodes': File('${bundleDir.path}/nodes.jsonl'),
          'edges': File('${bundleDir.path}/edges.jsonl'),
          'pointers': File('${bundleDir.path}/pointers.jsonl'),
          'embeddings': File('${bundleDir.path}/embeddings.jsonl'),
        };
        
        final checksumsValid = await McpManifestBuilder.verifyChecksums(manifest, ndjsonFiles);
        report.checksumsValid = checksumsValid;
        
        if (!checksumsValid) {
          report.warnings.add(HealthIssue(
            title: 'Checksum Mismatch',
            description: 'File checksums do not match manifest values',
            suggestion: 'Files may have been corrupted or modified',
          ));
        }
      }
    } catch (e) {
      report.warnings.add(HealthIssue(
        title: 'Checksum Verification Failed',
        description: 'Could not verify file checksums: $e',
        suggestion: 'Check file integrity manually',
      ));
    }

    // Check data integrity
    report.dataIntegrityValid = report.manifestValid && report.schemaValid;
    } finally {
      // Clean up temporary directory
      if (bundleDir != null) {
        try {
          await bundleDir.delete(recursive: true);
        } catch (e) {
          // Ignore cleanup errors
        }
      }
    }

    return report;
  }
}

// Data models
enum BundleHealthState {
  idle,
  analyzing,
  analyzed,
  error,
}

class BundleHealthReport {
  String bundleId;
  String version;
  String createdAt;
  String storageProfile;
  final Map<String, FileStatus> fileStatus;
  bool manifestValid;
  bool schemaValid;
  bool checksumsValid;
  bool dataIntegrityValid;
  final List<HealthIssue> errors;
  final List<HealthIssue> warnings;

  BundleHealthReport({
    required this.bundleId,
    required this.version,
    required this.createdAt,
    required this.storageProfile,
    required this.fileStatus,
    required this.manifestValid,
    required this.schemaValid,
    required this.checksumsValid,
    required this.dataIntegrityValid,
    required this.errors,
    required this.warnings,
  });
}

class FileStatus {
  final bool exists;
  final int sizeBytes;
  final bool? checksumValid;

  FileStatus({
    required this.exists,
    required this.sizeBytes,
    this.checksumValid,
  });
}

class HealthIssue {
  final String title;
  final String description;
  final String? suggestion;

  HealthIssue({
    required this.title,
    required this.description,
    this.suggestion,
  });
}
