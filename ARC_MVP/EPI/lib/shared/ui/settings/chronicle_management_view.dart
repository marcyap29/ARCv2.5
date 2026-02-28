import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/shared/ui/settings/settings_common.dart';
import 'package:my_app/chronicle/core/chronicle_repos.dart';
import 'package:my_app/chronicle/services/chronicle_export_service.dart';
import 'package:my_app/chronicle/services/chronicle_import_service.dart';
import 'package:my_app/chronicle/services/chronicle_onboarding_service.dart';
import 'package:my_app/chronicle/synthesis/synthesis_engine.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';
import 'package:my_app/chronicle/scheduling/synthesis_scheduler.dart';
import 'package:my_app/chronicle/scheduling/chronicle_schedule_preferences.dart';
import 'package:my_app/chronicle/storage/pattern_index_last_updated.dart';
import 'package:my_app/chronicle/embeddings/create_embedding_service.dart';
import 'package:my_app/chronicle/embeddings/embedding_service.dart';
import 'package:my_app/chronicle/storage/chronicle_index_storage.dart';
import 'package:my_app/chronicle/index/chronicle_index_builder.dart';
import 'package:my_app/chronicle/index/monthly_aggregation_adapter.dart';
import 'package:my_app/app/app_repos.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/shared/ui/chronicle/chronicle_layers_viewer.dart';
import 'package:my_app/shared/ui/chronicle/pattern_index_viewer.dart';
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

  // Automatic synthesis cadence (daily / weekly / monthly)
  ChronicleScheduleCadence _scheduleCadence = ChronicleScheduleCadence.daily;
  bool _cadenceLoaded = false;

  // Pattern index (vectorizer)
  DateTime? _patternIndexLastUpdated;
  bool _patternIndexLoaded = false;
  bool _patternIndexUpdating = false;
  String? _patternIndexError;

  /// When true, back arrow returns to this screen's menu instead of popping the route.
  bool get _showProgressView => _isLoading;

  @override
  void initState() {
    super.initState();
    _loadAggregationCounts();
    _loadScheduleCadence();
    _loadPatternIndexLastUpdated();
  }

  Future<void> _loadPatternIndexLastUpdated() async {
    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final when = await PatternIndexLastUpdatedStorage.getLastUpdated(userId);
      if (mounted) {
        setState(() {
          _patternIndexLastUpdated = when;
          _patternIndexLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _patternIndexLoaded = true;
          _patternIndexError = e.toString();
        });
      }
    }
  }

  /// Rebuild pattern index from existing monthly aggregations (vectorizer).
  Future<void> _updatePatternIndexNow() async {
    final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
    setState(() {
      _patternIndexUpdating = true;
      _patternIndexError = null;
      _isLoading = true;
      _progressStage = 'Loading embeddings...';
      _progressCurrent = 0;
      _progressTotal = 100;
    });
    try {
      EmbeddingService? embedder;
      try {
        embedder = await createEmbeddingService();
        await embedder.initialize();
      } catch (e) {
        final msg = e.toString();
        final isTflite = msg.contains('TfLite') ||
            msg.contains('symbol not found') ||
            msg.contains('dlsym') ||
            msg.contains('Interpreter');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _patternIndexUpdating = false;
            _patternIndexError = isTflite
                ? 'On-device embeddings are not available on this device (TensorFlow Lite not supported). Use a physical device or a build with TFLite support.'
                : msg;
            _statusMessage = isTflite
                ? 'Pattern index skipped: embeddings not available on this device.'
                : 'Pattern index update failed: $e';
            _statusIsError = true;
          });
          await _loadPatternIndexLastUpdated();
        }
        return;
      }
      final storage = ChronicleIndexStorage();
      final indexBuilder = ChronicleIndexBuilder(
        embedder: embedder,
        storage: storage,
      );
      final aggregationRepo = ChronicleRepos.aggregation;
      if (mounted) {
        setState(() {
          _progressStage = 'Loading monthly aggregations...';
          _progressCurrent = 0;
          _progressTotal = 100;
        });
      }
      final monthlyAggs = await aggregationRepo.getAllForLayer(
        userId: userId,
        layer: ChronicleLayer.monthly,
      );
      final total = monthlyAggs.isEmpty ? 1 : monthlyAggs.length;
      if (mounted) {
        setState(() {
          _progressTotal = total;
          _progressStage = 'Building pattern index...';
        });
      }
      for (int i = 0; i < monthlyAggs.length; i++) {
        final agg = monthlyAggs[i];
        final synthesis = MonthlyAggregation.fromChronicleAggregation(agg);
        await indexBuilder.updateIndexAfterSynthesis(
          userId: userId,
          synthesis: synthesis,
        );
        if (mounted) {
          setState(() {
            _progressCurrent = i + 1;
            _progressStage = 'Building pattern index... (${i + 1} / $total)';
          });
        }
        await Future.microtask(() {});
      }
      await PatternIndexLastUpdatedStorage.setLastUpdated(userId, DateTime.now());
      if (mounted) {
        setState(() {
          _patternIndexLastUpdated = DateTime.now();
          _patternIndexUpdating = false;
          _isLoading = false;
          _progressCurrent = total;
          _statusMessage = 'Pattern index updated (${monthlyAggs.length} months).';
          _statusIsError = false;
        });
        await _loadPatternIndexLastUpdated();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _patternIndexUpdating = false;
          _isLoading = false;
          _patternIndexError = e.toString();
          _statusMessage = 'Pattern index update failed: $e';
          _statusIsError = true;
        });
      }
    }
  }

  Future<void> _loadScheduleCadence() async {
    try {
      final cadence = await ChronicleSchedulePreferences.getCadence();
      if (mounted) {
        setState(() {
          _scheduleCadence = cadence;
          _cadenceLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading schedule cadence: $e');
      if (mounted) setState(() => _cadenceLoaded = true);
    }
  }

  Future<void> _setScheduleCadence(ChronicleScheduleCadence cadence) async {
    await ChronicleSchedulePreferences.setCadence(cadence);
    if (mounted) setState(() => _scheduleCadence = cadence);
  }

  Future<void> _loadAggregationCounts() async {
    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final aggregationRepo = ChronicleRepos.aggregation;
      
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
      _progressTotal = 2;
      _progressStage = 'Backfilling Layer 0...';
    });
    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final service = await _createOnboardingService();
      final result = await service.backfillAndSynthesizeCurrentMonth(
        userId: userId,
        onProgress: (processed, total) {
          if (mounted) {
            setState(() {
            _progressCurrent = processed;
            _progressTotal = total;
            _progressStage = processed < total ? 'Backfilling Layer 0...' : 'Synthesizing current month...';
          });
          }
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
      _progressTotal = 2;
      _progressStage = 'Backfilling Layer 0...';
    });
    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final service = await _createOnboardingService();
      final result = await service.backfillAndSynthesizeCurrentYear(
        userId: userId,
        onProgress: (processed, total) {
          if (mounted) {
            setState(() {
            _progressCurrent = processed;
            _progressTotal = total;
            _progressStage = processed < total ? 'Backfilling Layer 0...' : 'Synthesizing current year...';
          });
          }
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
      _progressTotal = 2;
      _progressStage = 'Backfilling Layer 0...';
    });
    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final service = await _createOnboardingService();
      final result = await service.backfillAndSynthesizeMultiYear(
        userId: userId,
        onProgress: (processed, total) {
          if (mounted) {
            setState(() {
            _progressCurrent = processed;
            _progressTotal = total;
            _progressStage = processed < total ? 'Backfilling Layer 0...' : 'Synthesizing multi-year...';
          });
          }
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

  Future<void> _importAggregations() async {
    final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null || !mounted) return;

    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _progressCurrent = 0;
      _progressTotal = 0;
      _progressStage = 'Scanning folder...';
    });

    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final aggregationRepo = ChronicleRepos.aggregation;
      final importService = ChronicleImportService(aggregationRepo: aggregationRepo);
      final exportDir = Directory(selectedDirectory);

      final result = await importService.importFromDirectory(
        userId: userId,
        exportDir: exportDir,
        onProgress: (processed, total) {
          if (mounted) {
            setState(() {
              _progressCurrent = processed;
              _progressTotal = total;
              _progressStage = 'Importing aggregations... ($processed / $total)';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = result.success ? result.toString() : 'Import failed: ${result.error}';
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
      final aggregationRepo = ChronicleRepos.aggregation;
      final changelogRepo = ChronicleRepos.changelog;

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

  Future<ChronicleOnboardingService> _createOnboardingService() async {
    final journalRepo = AppRepos.journal;
    final chatRepo = AppRepos.chat;
    final (layer0Repo, aggregationRepo, changelogRepo) = await AppRepos.initializedChronicleRepos;
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
      chatRepo: chatRepo,
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
      _progressTotal = 100;
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
              _progressTotal = total > 0 ? total : 100;
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
        if (result.success) {
          await _loadAggregationCounts();
          // Update pattern index from the newly synthesized monthly aggregations
          await _updatePatternIndexNow();
        }
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
      appBar: settingsAppBar(
        context,
        title: 'CHRONICLE Management',
        leading: _showProgressView
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: kcPrimaryTextColor),
                onPressed: () {
                  setState(() => _isLoading = false);
                },
                tooltip: 'Back to menu',
              )
            : null,
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
                  SettingsSection(
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

                  // Pattern index (vectorizer) — on-device embeddings for cross-temporal themes
                  SettingsSection(
                    title: 'Pattern index (vectorizer)',
                    children: [
                      Text(
                        'On-device embeddings power cross-temporal pattern search. Updated after each monthly synthesis or manually below.',
                        style: captionStyle(context).copyWith(
                          color: kcSecondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!_patternIndexLoaded)
                        const SizedBox(
                          height: 48,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        _buildStatusTile(
                          'Last updated',
                          _patternIndexLastUpdated != null
                              ? _patternIndexLastUpdated!.toIso8601String().split('.').first
                              : 'Never',
                          Icons.psychology,
                        ),
                        if (_patternIndexError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _patternIndexError!,
                            style: captionStyle(context).copyWith(
                              color: Colors.red,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SettingsActionButton(
                          title: _patternIndexUpdating
                              ? 'Updating pattern index...'
                              : 'Update pattern index now',
                          subtitle: 'Rebuild index from existing monthly aggregations (embeddings)',
                          icon: Icons.auto_awesome,
                          onPressed: _patternIndexUpdating ? () {} : _updatePatternIndexNow,
                          enabled: !_patternIndexUpdating,
                        ),
                        const SizedBox(height: 12),
                        SettingsActionButton(
                          title: 'View vectorized patterns',
                          subtitle: 'See which themes have been embedded and clustered across time',
                          icon: Icons.visibility,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PatternIndexViewer(),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Automatic synthesis schedule (Daily / Weekly / Monthly)
                  SettingsSection(
                    title: 'Automatic synthesis',
                    children: [
                      Text(
                        'How often to check and run CHRONICLE synthesis (and pattern index). Next run uses this setting.',
                        style: captionStyle(context).copyWith(
                          color: kcSecondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!_cadenceLoaded)
                        const SizedBox(
                          height: 48,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        Row(
                          children: [
                            _buildCadenceChip(ChronicleScheduleCadence.daily),
                            const SizedBox(width: 8),
                            _buildCadenceChip(ChronicleScheduleCadence.weekly),
                            const SizedBox(width: 8),
                            _buildCadenceChip(ChronicleScheduleCadence.monthly),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Backfill and Synthesize (single section with 4 options)
                  SettingsSection(
                    title: 'Backfill and Synthesize',
                    children: [
                      SettingsActionButton(
                        title: 'Backfill and Synthesize Current Month',
                        subtitle: 'Update Layer 0 and create monthly aggregation for this month',
                        icon: Icons.calendar_month,
                        onPressed: _backfillAndSynthesizeCurrentMonth,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 12),
                      SettingsActionButton(
                        title: 'Backfill and Synthesize Current Year',
                        subtitle: 'Update Layer 0 and create yearly aggregation for this year',
                        icon: Icons.calendar_today,
                        onPressed: _backfillAndSynthesizeCurrentYear,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 12),
                      SettingsActionButton(
                        title: 'Backfill and Synthesize Multi-Year',
                        subtitle: 'Update Layer 0 and create multi-year aggregation for current 5-year block',
                        icon: Icons.calendar_view_month,
                        onPressed: _backfillAndSynthesizeMultiYear,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 12),
                      SettingsActionButton(
                        title: 'Backfill and Synthesize All',
                        subtitle: 'Update Layer 0 and synthesize all months/years with entries',
                        icon: Icons.sync_alt,
                        onPressed: _backfillAndSynthesizeAll,
                        enabled: !_isLoading,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Import / Export
                  SettingsSection(
                    title: 'Import & Export',
                    children: [
                      SettingsActionButton(
                        title: 'Import Aggregations',
                        subtitle: 'Import aggregations from a previously exported folder',
                        icon: Icons.upload,
                        onPressed: _importAggregations,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 12),
                      SettingsActionButton(
                        title: 'Export All Aggregations',
                        subtitle: 'Export all CHRONICLE aggregations to a folder',
                        icon: Icons.download,
                        onPressed: _exportAll,
                        enabled: !_isLoading,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // View Layers
                  SettingsSection(
                    title: 'View Layers',
                    children: [
                      SettingsActionButton(
                        title: 'View CHRONICLE Layers',
                        subtitle: 'Browse monthly, yearly, and multi-year aggregations',
                        icon: Icons.visibility,
                        onPressed: () {
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
                  SettingsSection(
                    title: 'Privacy',
                    children: [
                      SettingsActionButton(
                        title: 'Privacy Protection',
                        subtitle: 'Configure PII detection and masking for CHRONICLE and LUMARA',
                        icon: Icons.security,
                        onPressed: () {
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
    final hasTotal = _progressTotal > 0;
    final fraction = hasTotal
        ? (_progressCurrent / _progressTotal).clamp(0.0, 1.0)
        : null; // null = indeterminate (animated)
    final percent = fraction != null ? (fraction * 100).round() : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular progress: indeterminate when no fraction so it visibly animates
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
                    )
                  else
                    Text(
                      '…',
                      style: heading1Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Stage label (always show something so it doesn't look static)
            Text(
              _progressStage ?? 'Working...',
              style: heading3Style(context).copyWith(color: kcPrimaryTextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Sub progress text
            if (hasTotal)
              Text(
                _progressTotal <= 10
                    ? '$_progressCurrent / $_progressTotal'
                    : '$_progressCurrent of $_progressTotal',
                style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
              )
            else
              Text(
                'Please wait',
                style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
              ),
            const SizedBox(height: 24),
            // Linear progress bar: indeterminate when no fraction so it animates
            SizedBox(
              width: double.infinity,
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: kcSurfaceAltColor,
                valueColor: const AlwaysStoppedAnimation<Color>(kcPrimaryColor),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCadenceChip(ChronicleScheduleCadence cadence) {
    final isSelected = _scheduleCadence == cadence;
    return FilterChip(
      label: Text(cadence.label),
      selected: isSelected,
      onSelected: (_) => _setScheduleCadence(cadence),
      selectedColor: kcPrimaryColor.withOpacity(0.3),
      checkmarkColor: kcPrimaryColor,
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
            const Icon(Icons.chevron_right, color: kcSecondaryTextColor),
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
}
