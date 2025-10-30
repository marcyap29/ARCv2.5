import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:my_app/core/mcp/validation/mcp_validator.dart';
import 'package:my_app/core/mcp/export/manifest_builder.dart';
import 'package:my_app/core/mcp/validation/mcp_bundle_repair_service.dart';
import 'package:my_app/core/mcp/export/zip_utils.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

/// MCP Bundle Health Checker - Focused on ZIP files
class McpBundleHealthView extends StatefulWidget {
  const McpBundleHealthView({Key? key}) : super(key: key);

  @override
  State<McpBundleHealthView> createState() => _McpBundleHealthViewState();
}

class _McpBundleHealthViewState extends State<McpBundleHealthView> {
  BundleHealthState _healthState = BundleHealthState.idle;
  List<BundleHealthReport> _healthReports = [];
  List<String> _selectedBundlePaths = [];
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
              onPressed: _isAnalyzing ? null : _analyzeBundles,
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
              _buildLoadingIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      color: kcSurfaceColor,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety, color: kcPrimaryColor, size: 28),
                const SizedBox(width: 12),
                Text(
                  'MCP Bundle Health Checker',
                  style: heading2Style(context).copyWith(color: kcPrimaryColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Analyze and repair MCP bundle ZIP files for integrity and compliance. '
              'Select one or more .zip files containing MCP bundles to begin batch analysis.',
              style: bodyStyle(context).copyWith(color: kcTextSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBundleSelector() {
    return Card(
      color: kcSurfaceColor,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select MCP Bundle ZIP Files',
              style: heading3Style(context).copyWith(color: kcPrimaryColor),
            ),
            const SizedBox(height: 12),
            if (_selectedBundlePaths.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kcBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kcBorderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.archive, color: kcSuccessColor),
                        const SizedBox(width: 12),
                        Text(
                          'Selected ZIP Files (${_selectedBundlePaths.length})',
                          style: captionStyle(context).copyWith(color: kcTextSecondary),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedBundlePaths.clear();
                              _healthState = BundleHealthState.idle;
                              _healthReports.clear();
                            });
                          },
                          icon: const Icon(Icons.clear_all),
                          tooltip: 'Clear All',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._selectedBundlePaths.asMap().entries.map((entry) {
                      final index = entry.key;
                      final path = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: kcSurfaceColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: kcBorderColor.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.insert_drive_file, size: 16, color: kcTextSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                path.split('/').last,
                                style: bodyStyle(context).copyWith(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedBundlePaths.removeAt(index);
                                  if (_selectedBundlePaths.isEmpty) {
                                    _healthState = BundleHealthState.idle;
                                    _healthReports.clear();
                                  }
                                });
                              },
                              icon: const Icon(Icons.close, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectBundles,
                    icon: const Icon(Icons.folder_open),
                    label: Text(_selectedBundlePaths.isEmpty ? 'Select ZIP Files' : 'Add More Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (_selectedBundlePaths.isNotEmpty)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _analyzeBundles,
                      icon: const Icon(Icons.search),
                      label: Text('Analyze ${_selectedBundlePaths.length} File${_selectedBundlePaths.length == 1 ? '' : 's'}'),
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
    if (_healthReports.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        // Summary Card
        Card(
          color: kcSurfaceColor,
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getOverallStatusIcon(),
                      color: _getOverallStatusColor(),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Batch Analysis Summary',
                      style: heading3Style(context).copyWith(color: kcPrimaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSummaryStats(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Individual Reports
        ..._healthReports.asMap().entries.map((entry) {
          final index = entry.key;
          final report = entry.value;
          final fileName = _selectedBundlePaths[index].split('/').last;
          
          return Card(
            color: kcSurfaceColor,
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getReportStatusIcon(report),
                        color: _getReportStatusColor(report),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          fileName,
                          style: heading4Style(context).copyWith(color: kcPrimaryColor),
                        ),
                      ),
                      Text(
                        '${report.errors.length} errors, ${report.warnings.length} warnings',
                        style: captionStyle(context).copyWith(color: kcTextSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Bundle Info
                  _buildInfoSection(report),
                  const SizedBox(height: 16),
                  
                  // File Status
                  _buildFileStatusSection(report),
                  const SizedBox(height: 16),
                  
                  // Validation Results
                  _buildValidationSection(report),
                  
                  // Errors and Warnings
                  if (report.errors.isNotEmpty || report.warnings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildIssuesSection(report),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSummaryStats() {
    final totalFiles = _healthReports.length;
    final validFiles = _healthReports.where((r) => r.errors.isEmpty).length;
    final totalErrors = _healthReports.fold(0, (sum, r) => sum + r.errors.length);
    final totalWarnings = _healthReports.fold(0, (sum, r) => sum + r.warnings.length);
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard('Total Files', totalFiles.toString(), Icons.folder),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard('Valid Files', '$validFiles/$totalFiles', Icons.check_circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard('Errors', totalErrors.toString(), Icons.error),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard('Warnings', totalWarnings.toString(), Icons.warning),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kcBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kcBorderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: kcPrimaryColor, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: heading4Style(context).copyWith(color: kcPrimaryColor),
          ),
          Text(
            label,
            style: captionStyle(context).copyWith(color: kcTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BundleHealthReport report) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kcBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kcBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bundle Information',
            style: bodyStyle(context).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Bundle ID', report.bundleId),
          _buildInfoRow('Version', report.version),
          _buildInfoRow('Created', report.createdAt),
          _buildInfoRow('Storage Profile', report.storageProfile),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: captionStyle(context).copyWith(color: kcTextSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: bodyStyle(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileStatusSection(BundleHealthReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'File Status',
          style: bodyStyle(context).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...report.fileStatus.entries.map((entry) {
          final status = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: status.exists ? kcSuccessColor.withOpacity(0.1) : kcDangerColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: status.exists ? kcSuccessColor : kcDangerColor,
                width: 1,
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
                        style: bodyStyle(context).copyWith(fontWeight: FontWeight.w500),
                      ),
                      if (status.exists)
                        Text(
                          'Size: ${_formatFileSize(status.sizeBytes)}',
                          style: captionStyle(context).copyWith(color: kcTextSecondary),
                        ),
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

  Widget _buildValidationSection(BundleHealthReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Validation Results',
          style: bodyStyle(context).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _buildValidationItem('Manifest', report.manifestValid),
        _buildValidationItem('Schema', report.schemaValid),
        _buildValidationItem('Checksums', report.checksumsValid),
        _buildValidationItem('Data Integrity', report.dataIntegrityValid),
      ],
    );
  }

  Widget _buildValidationItem(String label, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.error,
            color: isValid ? kcSuccessColor : kcDangerColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: bodyStyle(context),
          ),
          const Spacer(),
          Text(
            isValid ? 'Valid' : 'Invalid',
            style: captionStyle(context).copyWith(
              color: isValid ? kcSuccessColor : kcDangerColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesSection(BundleHealthReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (report.errors.isNotEmpty) ...[
          Text(
            'Errors',
            style: bodyStyle(context).copyWith(
              fontWeight: FontWeight.w600,
              color: kcDangerColor,
            ),
          ),
          const SizedBox(height: 8),
          ...report.errors.map((error) => _buildIssueItem(error, true)),
          const SizedBox(height: 16),
        ],
        if (report.warnings.isNotEmpty) ...[
          Text(
            'Warnings',
            style: bodyStyle(context).copyWith(
              fontWeight: FontWeight.w600,
              color: kcWarningColor,
            ),
          ),
          const SizedBox(height: 8),
          ...report.warnings.map((warning) => _buildIssueItem(warning, false)),
        ],
      ],
    );
  }

  Widget _buildIssueItem(HealthIssue issue, bool isError) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? kcDangerColor.withOpacity(0.1) : kcWarningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? kcDangerColor : kcWarningColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            issue.title,
            style: bodyStyle(context).copyWith(
              fontWeight: FontWeight.w600,
              color: isError ? kcDangerColor : kcWarningColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            issue.description,
            style: bodyStyle(context),
          ),
          if (issue.suggestion.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Suggestion: ${issue.suggestion}',
              style: captionStyle(context).copyWith(
                color: kcTextSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final canRepair = _healthReports.isNotEmpty && 
        _healthReports.any((r) => r.errors.isNotEmpty || r.warnings.isNotEmpty);

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isAnalyzing ? null : _analyzeBundles,
            icon: const Icon(Icons.refresh),
            label: Text('Re-analyze ${_selectedBundlePaths.length} File${_selectedBundlePaths.length == 1 ? '' : 's'}'),
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
              onPressed: _isRepairing ? null : _repairBundles,
              icon: const Icon(Icons.build),
              label: const Text('Auto-Repair All'),
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

  Widget _buildLoadingIndicator() {
    return Card(
      color: kcSurfaceColor,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(kcPrimaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              _isAnalyzing ? 'Analyzing bundle...' : 'Repairing bundle...',
              style: bodyStyle(context).copyWith(color: kcTextSecondary),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getOverallStatusIcon() {
    if (_healthReports.isEmpty) return Icons.help;
    final hasErrors = _healthReports.any((r) => r.errors.isNotEmpty);
    final hasWarnings = _healthReports.any((r) => r.warnings.isNotEmpty);
    if (hasErrors) return Icons.error;
    if (hasWarnings) return Icons.warning;
    return Icons.check_circle;
  }

  Color _getOverallStatusColor() {
    if (_healthReports.isEmpty) return kcTextSecondary;
    final hasErrors = _healthReports.any((r) => r.errors.isNotEmpty);
    final hasWarnings = _healthReports.any((r) => r.warnings.isNotEmpty);
    if (hasErrors) return kcDangerColor;
    if (hasWarnings) return kcWarningColor;
    return kcSuccessColor;
  }

  IconData _getReportStatusIcon(BundleHealthReport report) {
    if (report.errors.isNotEmpty) return Icons.error;
    if (report.warnings.isNotEmpty) return Icons.warning;
    return Icons.check_circle;
  }

  Color _getReportStatusColor(BundleHealthReport report) {
    if (report.errors.isNotEmpty) return kcDangerColor;
    if (report.warnings.isNotEmpty) return kcWarningColor;
    return kcSuccessColor;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Action methods
  Future<void> _selectBundles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      allowMultiple: true,
    );
    
    if (result != null && result.files.isNotEmpty) {
      final newPaths = result.files
          .where((file) => file.path != null)
          .map((file) => file.path!)
          .toList();
      
      setState(() {
        _selectedBundlePaths.addAll(newPaths);
        _healthState = BundleHealthState.idle;
        _healthReports.clear();
      });
    }
  }

  Future<void> _analyzeBundles() async {
    if (_selectedBundlePaths.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _healthState = BundleHealthState.analyzing;
    });

    try {
      final reports = <BundleHealthReport>[];
      
      for (int i = 0; i < _selectedBundlePaths.length; i++) {
        final zipFile = File(_selectedBundlePaths[i]);
        final report = await _performHealthCheck(zipFile);
        reports.add(report);
        
        // Update progress
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Analyzed ${i + 1}/${_selectedBundlePaths.length} files...'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
      
      setState(() {
        _healthReports = reports;
        _healthState = BundleHealthState.analyzed;
        _isAnalyzing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis complete: ${reports.length} files analyzed'),
            backgroundColor: kcSuccessColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _healthState = BundleHealthState.error;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            backgroundColor: kcDangerColor,
          ),
        );
      }
    }
  }

  Future<void> _repairBundles() async {
    if (_selectedBundlePaths.isEmpty) return;

    setState(() {
      _isRepairing = true;
    });

    try {
      final allRepairs = <BundleRepair>[];
      final allErrors = <String>[];
      int successCount = 0;
      
      for (int i = 0; i < _selectedBundlePaths.length; i++) {
        final zipFile = File(_selectedBundlePaths[i]);
        final repairResult = await McpBundleRepairService.repairZipBundle(zipFile);
        
        if (repairResult.success) {
          allRepairs.addAll(repairResult.repairs);
          successCount++;
        } else {
          allErrors.addAll(repairResult.errors);
        }
        
        // Update progress
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Repaired ${i + 1}/${_selectedBundlePaths.length} files...'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
      
      // Show repair summary
      if (allRepairs.isNotEmpty) {
        _showRepairSummary(allRepairs);
      }
      
      // Re-analyze after repair
      await _analyzeBundles();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batch repair completed: $successCount/${_selectedBundlePaths.length} files repaired, ${allRepairs.length} repairs applied'),
            backgroundColor: successCount > 0 ? kcSuccessColor : kcDangerColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Repair failed: $e'),
            backgroundColor: kcDangerColor,
          ),
        );
      }
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
        title: Text('Repair Summary', style: heading3Style(context)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: repairs.map((repair) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  _getRepairIcon(repair.severity),
                  color: _getRepairColor(repair.severity),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    repair.description,
                    style: bodyStyle(context),
                  ),
                ),
              ],
            ),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  IconData _getRepairIcon(RepairSeverity severity) {
    switch (severity) {
      case RepairSeverity.low:
        return Icons.info;
      case RepairSeverity.medium:
        return Icons.warning;
      case RepairSeverity.high:
        return Icons.error;
    }
  }

  Color _getRepairColor(RepairSeverity severity) {
    switch (severity) {
      case RepairSeverity.low:
        return kcPrimaryColor;
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

    try {
      // Check if zip file exists and is readable
      if (!await zipFile.exists()) {
        report.errors.add(HealthIssue(
          title: 'ZIP File Not Found',
          description: 'The selected ZIP file does not exist',
          suggestion: 'Please select a valid ZIP file',
        ));
        return report;
      }

      // Get zip file info
      final zipSize = await zipFile.length();
      report.fileStatus['bundle.zip'] = FileStatus(
        exists: true,
        sizeBytes: zipSize,
        checksumValid: null,
      );

      // Check if zip contains valid MCP bundle
      final isValidBundle = await ZipUtils.isValidMcpBundle(zipFile);
      if (!isValidBundle) {
        report.errors.add(HealthIssue(
          title: 'Invalid MCP Bundle',
          description: 'ZIP file does not contain a valid MCP bundle (missing required files)',
          suggestion: 'Ensure the ZIP contains manifest.json, nodes.jsonl, edges.jsonl, pointers.jsonl, and embeddings.jsonl',
        ));
        return report;
      }

      // Extract zip to temporary directory for validation
      final tempDir = await ZipUtils.extractZip(zipFile);
      
      try {
        // Check required files in extracted directory
        final requiredFiles = [
          'manifest.json',
          'nodes.jsonl',
          'edges.jsonl',
          'pointers.jsonl',
          'embeddings.jsonl',
        ];

        for (final filename in requiredFiles) {
          final file = File('${tempDir.path}/$filename');
          final exists = await file.exists();
          final sizeBytes = exists ? await file.length() : 0;
          
          report.fileStatus[filename] = FileStatus(
            exists: exists,
            sizeBytes: sizeBytes,
            checksumValid: null,
          );
        }

        // Validate manifest
        try {
          final manifestFile = File('${tempDir.path}/manifest.json');
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
            description: 'Failed to read or parse manifest.json: $e',
            suggestion: 'Check if manifest.json exists and contains valid JSON',
          ));
        }

        // Validate schema using zip validation
        try {
          final validationResult = await McpValidator.validateZipBundle(zipFile);
          report.schemaValid = validationResult.isValid;
          if (!validationResult.isValid) {
            for (final error in validationResult.errors) {
              report.errors.add(HealthIssue(
                title: 'Schema Validation Error',
                description: error,
                suggestion: 'Check the structure and content of your MCP bundle files',
              ));
            }
          }
        } catch (e) {
          report.errors.add(HealthIssue(
            title: 'Schema Validation Failed',
            description: 'Failed to validate bundle schema: $e',
            suggestion: 'Check if all required files are present and valid',
          ));
        }

        // Check checksums
        try {
          final manifestFile = File('${tempDir.path}/manifest.json');
          if (await manifestFile.exists()) {
            final manifest = await McpManifestBuilder.readManifest(manifestFile);
            final ndjsonFiles = {
              'nodes': File('${tempDir.path}/nodes.jsonl'),
              'edges': File('${tempDir.path}/edges.jsonl'),
              'pointers': File('${tempDir.path}/pointers.jsonl'),
              'embeddings': File('${tempDir.path}/embeddings.jsonl'),
            };
            
            final checksumsValid = await McpManifestBuilder.verifyChecksums(manifest, ndjsonFiles);
            report.checksumsValid = checksumsValid;
            
            if (!checksumsValid) {
              report.warnings.add(HealthIssue(
                title: 'Checksum Mismatch',
                description: 'One or more file checksums do not match the manifest',
                suggestion: 'The bundle may have been corrupted or modified',
              ));
            }
          }
        } catch (e) {
          report.warnings.add(HealthIssue(
            title: 'Checksum Verification Failed',
            description: 'Failed to verify file checksums: $e',
            suggestion: 'Check if the manifest contains valid checksum data',
          ));
        }

        // Check data integrity
        report.dataIntegrityValid = report.manifestValid && report.schemaValid;

      } finally {
        // Clean up temporary directory
        try {
          await tempDir.delete(recursive: true);
        } catch (e) {
          // Ignore cleanup errors
        }
      }

    } catch (e) {
      report.errors.add(HealthIssue(
        title: 'ZIP Processing Failed',
        description: 'Failed to process ZIP file: $e',
        suggestion: 'Check if the ZIP file is valid and not corrupted',
      ));
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
  Map<String, FileStatus> fileStatus;
  bool manifestValid;
  bool schemaValid;
  bool checksumsValid;
  bool dataIntegrityValid;
  List<HealthIssue> errors;
  List<HealthIssue> warnings;

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
  final String suggestion;

  HealthIssue({
    required this.title,
    required this.description,
    required this.suggestion,
  });
}
