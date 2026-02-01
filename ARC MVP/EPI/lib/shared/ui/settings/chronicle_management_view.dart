import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/chronicle/services/chronicle_manual_service.dart';
import 'package:my_app/chronicle/services/chronicle_export_service.dart';
import 'package:my_app/chronicle/storage/aggregation_repository.dart';
import 'package:my_app/chronicle/storage/changelog_repository.dart';
import 'package:my_app/chronicle/synthesis/synthesis_engine.dart';
import 'package:my_app/chronicle/storage/layer0_repository.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';
import 'package:my_app/chronicle/scheduling/synthesis_scheduler.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/shared/ui/chronicle/chronicle_layers_viewer.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

/// CHRONICLE Management Settings View
/// 
/// Provides manual controls for CHRONICLE synthesis and export.
class ChronicleManagementView extends StatefulWidget {
  const ChronicleManagementView({super.key});

  @override
  State<ChronicleManagementView> createState() => _ChronicleManagementViewState();
}

class _ChronicleManagementViewState extends State<ChronicleManagementView> {
  bool _isLoading = false;
  String? _statusMessage;
  bool _statusIsError = false;
  
  // Aggregation counts
  int _monthlyCount = 0;
  int _yearlyCount = 0;
  int _multiyearCount = 0;
  bool _countsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAggregationCounts();
  }

  Future<void> _loadAggregationCounts() async {
    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final aggregationRepo = AggregationRepository();
      
      final monthly = await aggregationRepo.getAllForLayer(
        userId: userId,
        layer: ChronicleLayer.monthly,
      );
      final yearly = await aggregationRepo.getAllForLayer(
        userId: userId,
        layer: ChronicleLayer.yearly,
      );
      final multiyear = await aggregationRepo.getAllForLayer(
        userId: userId,
        layer: ChronicleLayer.multiyear,
      );
      
      if (mounted) {
        setState(() {
          _monthlyCount = monthly.length;
          _yearlyCount = yearly.length;
          _multiyearCount = multiyear.length;
          _countsLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading aggregation counts: $e');
    }
  }

  Future<void> _synthesizeCurrentMonth() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final service = await _createManualService();
      
      final aggregation = await service.synthesizeCurrentMonth(userId: userId);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = aggregation != null
              ? 'Successfully synthesized current month'
              : 'No entries found for current month';
          _statusIsError = false;
        });
        await _loadAggregationCounts();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error: $e';
          _statusIsError = true;
        });
      }
    }
  }

  Future<void> _synthesizeCurrentYear() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final service = await _createManualService();
      
      final aggregation = await service.synthesizeCurrentYear(userId: userId);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = aggregation != null
              ? 'Successfully synthesized current year'
              : 'No entries found for current year';
          _statusIsError = false;
        });
        await _loadAggregationCounts();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error: $e';
          _statusIsError = true;
        });
      }
    }
  }

  Future<void> _synthesizeAllPending() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final service = await _createManualService();
      
      // Default to premium tier for manual synthesis
      final results = await service.synthesizeAllPending(
        userId: userId,
        tier: SynthesisTier.premium,
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Synthesized ${results['monthly']} monthly, ${results['yearly']} yearly, ${results['multiyear']} multi-year aggregations';
          _statusIsError = false;
        });
        await _loadAggregationCounts();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error: $e';
          _statusIsError = true;
        });
      }
    }
  }

  Future<void> _exportAll() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      
      // Pick export directory
      final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _statusMessage = 'Export cancelled';
            _statusIsError = false;
          });
        }
        return;
      }

      final exportDir = Directory(selectedDirectory);
      final aggregationRepo = AggregationRepository();
      final changelogRepo = ChangelogRepository();
      
      final exportService = ChronicleExportService(
        aggregationRepo: aggregationRepo,
        changelogRepo: changelogRepo,
      );
      
      final result = await exportService.exportAll(
        userId: userId,
        exportDir: exportDir,
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result.success) {
            _statusMessage = result.toString();
            _statusIsError = false;
          } else {
            _statusMessage = 'Export failed: ${result.error}';
            _statusIsError = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error: $e';
          _statusIsError = true;
        });
      }
    }
  }

  Future<ChronicleManualService> _createManualService() async {
    final layer0Repo = Layer0Repository();
    await layer0Repo.initialize();
    
    final aggregationRepo = AggregationRepository();
    final changelogRepo = ChangelogRepository();
    
    final synthesisEngine = SynthesisEngine(
      layer0Repo: layer0Repo,
      aggregationRepo: aggregationRepo,
      changelogRepo: changelogRepo,
    );
    
    return ChronicleManualService(
      synthesisEngine: synthesisEngine,
      changelogRepo: changelogRepo,
    );
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
          'CHRONICLE Management',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status message
                  if (_statusMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: _statusIsError
                            ? Colors.red.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _statusIsError ? Colors.red : Colors.green,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _statusIsError ? Icons.error : Icons.check_circle,
                            color: _statusIsError ? Colors.red : Colors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _statusMessage!,
                              style: bodyStyle(context).copyWith(
                                color: _statusIsError ? Colors.red : Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Aggregation Status
                  _buildSection(
                    title: 'Aggregation Status',
                    children: [
                      _buildStatusTile(
                        'Monthly Aggregations',
                        _countsLoaded ? '$_monthlyCount files' : 'Loading...',
                        Icons.calendar_month,
                      ),
                      const SizedBox(height: 8),
                      _buildStatusTile(
                        'Yearly Aggregations',
                        _countsLoaded ? '$_yearlyCount files' : 'Loading...',
                        Icons.calendar_today,
                      ),
                      const SizedBox(height: 8),
                      _buildStatusTile(
                        'Multi-Year Aggregations',
                        _countsLoaded ? '$_multiyearCount files' : 'Loading...',
                        Icons.calendar_view_month,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Manual Synthesis
                  _buildSection(
                    title: 'Manual Synthesis',
                    children: [
                      _buildActionButton(
                        'Synthesize Current Month',
                        'Create monthly aggregation for current month',
                        Icons.auto_fix_high,
                        _synthesizeCurrentMonth,
                      ),
                      const SizedBox(height: 12),
                      _buildActionButton(
                        'Synthesize Current Year',
                        'Create yearly aggregation for current year',
                        Icons.auto_fix_high,
                        _synthesizeCurrentYear,
                      ),
                      const SizedBox(height: 12),
                      _buildActionButton(
                        'Synthesize All Pending',
                        'Synthesize all months/years with entries but no aggregations',
                        Icons.playlist_add_check,
                        _synthesizeAllPending,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Export
                  _buildSection(
                    title: 'Export',
                    children: [
                      _buildActionButton(
                        'Export All Aggregations',
                        'Export all CHRONICLE aggregations to a folder',
                        Icons.download,
                        _exportAll,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // View Layers
                  _buildSection(
                    title: 'View Layers',
                    children: [
                      _buildActionButton(
                        'View CHRONICLE Layers',
                        'Browse monthly, yearly, and multi-year aggregations',
                        Icons.visibility,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ChronicleLayersViewer(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
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
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildStatusTile(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kcBackgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kcPrimaryTextColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: kcPrimaryTextColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: bodyStyle(context).copyWith(
                    color: kcPrimaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: captionStyle(context).copyWith(
                    color: kcSecondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kcBackgroundColor.withOpacity(0.5),
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: kcPrimaryTextColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: bodyStyle(context).copyWith(
                      color: kcPrimaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: captionStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kcPrimaryTextColor),
          ],
        ),
      ),
    );
  }
}
