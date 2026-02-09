import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/chronicle/services/chronicle_manual_service.dart';
import 'package:my_app/chronicle/services/chronicle_export_service.dart';
import 'package:my_app/chronicle/services/chronicle_onboarding_service.dart';
import 'package:my_app/chronicle/storage/aggregation_repository.dart';
import 'package:my_app/chronicle/storage/changelog_repository.dart';
import 'package:my_app/chronicle/synthesis/synthesis_engine.dart';
import 'package:my_app/chronicle/storage/layer0_repository.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';
import 'package:my_app/chronicle/scheduling/synthesis_scheduler.dart';
import 'package:my_app/arc/internal/mira/journal_repository.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/shared/ui/chronicle/chronicle_layers_viewer.dart';
import 'package:my_app/shared/ui/settings/privacy_settings_view.dart';
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
  
  // Progress tracking
  int _progressCurrent = 0;
  int _progressTotal = 0;
  String? _progressStage;
  
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

  Future<void> _backfillAndSynthesizeCurrentMonth() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _progressCurrent = 0;
      _progressTotal = 0;
      _progressStage = 'Backfilling Layer 0...';
    });
    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final service = await _createOnboardingService();
      final result = await service.backfillAndSynthesizeCurrentMonth(
        userId: userId,
        onProgress: (processed, total) {
          if (mounted) setState(() {
            _progressCurrent = processed;
            _progressTotal = total;
            _progressStage = 'Backfilling Layer 0...';
          });
        },
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = result.success ? (result.message ?? 'Done') : 'Failed: ${result.error}';
          _statusIsError = !result.success;
        });
        if (result.success) await _loadAggregationCounts();
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

  Future<void> _backfillAndSynthesizeCurrentYear() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _progressCurrent = 0;
      _progressTotal = 0;
      _progressStage = 'Backfilling Layer 0...';
    });
    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final service = await _createOnboardingService();
      final result = await service.backfillAndSynthesizeCurrentYear(
        userId: userId,
        onProgress: (processed, total) {
          if (mounted) setState(() {
            _progressCurrent = processed;
            _progressTotal = total;
            _progressStage = 'Backfilling Layer 0...';
          });
        },
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = result.success ? (result.message ?? 'Done') : 'Failed: ${result.error}';
          _statusIsError = !result.success;
        });
        if (result.success) await _loadAggregationCounts();
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

  Future<void> _backfillAndSynthesizeMultiYear() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _progressCurrent = 0;
      _progressTotal = 0;
      _progressStage = 'Backfilling Layer 0...';
    });
    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final service = await _createOnboardingService();
      final result = await service.backfillAndSynthesizeMultiYear(
        userId: userId,
        onProgress: (processed, total) {
          if (mounted) setState(() {
            _progressCurrent = processed;
            _progressTotal = total;
            _progressStage = 'Backfilling Layer 0...';
          });
        },
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = result.success ? (result.message ?? 'Done') : 'Failed: ${result.error}';
          _statusIsError = !result.success;
        });
        if (result.success) await _loadAggregationCounts();
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

  Future<ChronicleOnboardingService> _createOnboardingService() async {
    final journalRepo = JournalRepository();
    final layer0Repo = Layer0Repository();
    await layer0Repo.initialize();
    final aggregationRepo = AggregationRepository();
    final changelogRepo = ChangelogRepository();
    final synthesisEngine = SynthesisEngine(
      layer0Repo: layer0Repo,
      aggregationRepo: aggregationRepo,
      changelogRepo: changelogRepo,
    );
    return ChronicleOnboardingService(
      journalRepo: journalRepo,
      layer0Repo: layer0Repo,
      aggregationRepo: aggregationRepo,
      synthesisEngine: synthesisEngine,
    );
  }

  void _openLayersViewer({required int initialTabIndex}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChronicleLayersViewer(initialTabIndex: initialTabIndex),
      ),
    );
  }

  Future<void> _backfillAndSynthesizeAll() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _progressCurrent = 0;
      _progressTotal = 0;
      _progressStage = 'Initializing...';
    });

    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final service = await _createOnboardingService();

      final result = await service.fullOnboarding(
        userId: userId,
        tier: SynthesisTier.premium,
        onProgress: (stage, progress, total) {
          if (mounted) {
            setState(() {
              _progressStage = stage;
              _progressCurrent = progress;
              _progressTotal = total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = result.success
              ? (result.message ?? 'Backfill and synthesis complete')
              : 'Failed: ${result.error}';
          _statusIsError = !result.success;
        });
        if (result.success) await _loadAggregationCounts();
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
          ? _buildProgressView()
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

                  // Aggregation Status (tiles open CHRONICLE Layers at the corresponding tab)
                  _buildSection(
                    title: 'Aggregation Status',
                    children: [
                      _buildStatusTile(
                        'Monthly Aggregations',
                        _countsLoaded ? '$_monthlyCount files' : 'Loading...',
                        Icons.calendar_month,
                        onTap: () => _openLayersViewer(initialTabIndex: 0),
                      ),
                      const SizedBox(height: 8),
                      _buildStatusTile(
                        'Yearly Aggregations',
                        _countsLoaded ? '$_yearlyCount files' : 'Loading...',
                        Icons.calendar_today,
                        onTap: () => _openLayersViewer(initialTabIndex: 1),
                      ),
                      const SizedBox(height: 8),
                      _buildStatusTile(
                        'Multi-Year Aggregations',
                        _countsLoaded ? '$_multiyearCount files' : 'Loading...',
                        Icons.calendar_view_month,
                        onTap: () => _openLayersViewer(initialTabIndex: 2),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Backfill and Synthesize (single section with 4 options)
                  _buildSection(
                    title: 'Backfill and Synthesize',
                    children: [
                      _buildActionButton(
                        'Backfill and Synthesize Current Month',
                        'Update Layer 0 and create monthly aggregation for this month',
                        Icons.calendar_month,
                        _backfillAndSynthesizeCurrentMonth,
                      ),
                      const SizedBox(height: 12),
                      _buildActionButton(
                        'Backfill and Synthesize Current Year',
                        'Update Layer 0 and create yearly aggregation for this year',
                        Icons.calendar_today,
                        _backfillAndSynthesizeCurrentYear,
                      ),
                      const SizedBox(height: 12),
                      _buildActionButton(
                        'Backfill and Synthesize Multi-Year',
                        'Update Layer 0 and create multi-year aggregation for current 5-year block',
                        Icons.calendar_view_month,
                        _backfillAndSynthesizeMultiYear,
                      ),
                      const SizedBox(height: 12),
                      _buildActionButton(
                        'Backfill and Synthesize All',
                        'Update Layer 0 and synthesize all months/years with entries',
                        Icons.sync_alt,
                        _backfillAndSynthesizeAll,
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

                  const SizedBox(height: 32),

                  // Privacy Protection (links to same screen as Settings → Privacy & Security)
                  _buildSection(
                    title: 'Privacy',
                    children: [
                      _buildActionButton(
                        'Privacy Protection',
                        'Configure PII detection and masking for CHRONICLE and LUMARA',
                        Icons.security,
                        () {
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
                ],
              ),
            ),
    );
  }

  Widget _buildProgressView() {
    final fraction = _progressTotal > 0
        ? (_progressCurrent / _progressTotal).clamp(0.0, 1.0)
        : null; // null = indeterminate
    final percent = fraction != null ? (fraction * 100).round() : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular progress with percentage in the center
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: fraction,
                      strokeWidth: 6,
                      backgroundColor: kcSurfaceAltColor,
                      valueColor: const AlwaysStoppedAnimation<Color>(kcPrimaryColor),
                    ),
                  ),
                  if (percent != null)
                    Text(
                      '$percent%',
                      style: heading1Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Stage label
            if (_progressStage != null)
              Text(
                _progressStage!,
                style: heading3Style(context).copyWith(color: kcPrimaryTextColor),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            // x / y entries
            if (_progressTotal > 0)
              Text(
                '$_progressCurrent / $_progressTotal entries',
                style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
              ),
            const SizedBox(height: 24),
            // Linear progress bar
            SizedBox(
              width: double.infinity,
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 4,
                backgroundColor: kcSurfaceAltColor,
                valueColor: const AlwaysStoppedAnimation<Color>(kcPrimaryColor),
                borderRadius: BorderRadius.circular(2),
              ),
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

  Widget _buildStatusTile(
    String title,
    String subtitle,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    final content = Container(
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
          if (onTap != null)
            Icon(Icons.chevron_right, color: kcSecondaryTextColor),
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      );
    }
    return content;
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
