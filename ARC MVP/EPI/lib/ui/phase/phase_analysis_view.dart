// lib/ui/phase/phase_analysis_view.dart
// Main Phase Analysis View - integrates timeline, wizard, and phase management

import 'package:flutter/material.dart';
import '../../models/phase_models.dart';
import '../../models/journal_entry_model.dart';
import '../../services/phase_index.dart';
import '../../services/phase_regime_service.dart';
import '../../services/rivet_sweep_service.dart';
import '../../services/analytics_service.dart';
import '../../arc/core/journal_repository.dart';
import 'phase_timeline_view.dart';
import 'rivet_sweep_wizard.dart';
import 'phase_info_overview.dart';
import 'phase_help_screen.dart';

class PhaseAnalysisView extends StatefulWidget {
  const PhaseAnalysisView({super.key});

  @override
  State<PhaseAnalysisView> createState() => _PhaseAnalysisViewState();
}

class _PhaseAnalysisViewState extends State<PhaseAnalysisView>
    with TickerProviderStateMixin {
  late TabController _tabController;
  PhaseIndex? _phaseIndex;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPhaseData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPhaseData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load existing phase regimes
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      
      _phaseIndex = phaseRegimeService.phaseIndex;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _runRivetSweep() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get journal entries for analysis
      final journalRepo = JournalRepository();
      final journalEntries = journalRepo.getAllJournalEntries();

      // Check if there are enough entries for analysis
      if (journalEntries.length < 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Need at least 5 journal entries for phase analysis. You have ${journalEntries.length}.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final result = await rivetSweepService.analyzeEntries(journalEntries);

      if (mounted) {
        // Show RIVET Sweep wizard
        await _showRivetSweepWizard(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Phase Analysis failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showRivetSweepWizard(RivetSweepResult result) async {
    await showDialog(
      context: context,
      builder: (context) => RivetSweepWizard(
        sweepResult: result,
        onApprove: (approvedProposals, overrides) async {
          Navigator.of(context).pop();
          await _createPhaseRegimes(approvedProposals, overrides);
        },
        onSkip: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _createPhaseRegimes(
    List<PhaseSegmentProposal> proposals,
    Map<String, PhaseLabel> overrides,
  ) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      // Apply manual overrides to proposals
      final finalProposals = proposals.map((proposal) {
        final segmentId = '${proposal.start.millisecondsSinceEpoch}';
        if (overrides.containsKey(segmentId)) {
          return PhaseSegmentProposal(
            start: proposal.start,
            end: proposal.end,
            proposedLabel: overrides[segmentId]!,
            confidence: proposal.confidence,
            signals: proposal.signals,
            entryIds: proposal.entryIds,
            summary: proposal.summary,
            topKeywords: proposal.topKeywords,
          );
        }
        return proposal;
      }).toList();

      // Create phase regimes from approved proposals
      for (final proposal in finalProposals) {
        await phaseRegimeService.createRegime(
          label: proposal.proposedLabel,
          start: proposal.start,
          end: proposal.end,
          source: PhaseSource.rivet,
          confidence: proposal.confidence,
          anchors: proposal.entryIds,
        );
      }

      // Reload phase data to show new regimes
      await _loadPhaseData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created ${finalProposals.length} phase regimes'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create phase regimes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Phase Analysis'),
          centerTitle: true,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading phase data...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Phase Analysis'),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading phase data: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPhaseData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phase Analysis'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PhaseHelpScreen(),
                ),
              );
            },
            tooltip: 'Phase Help',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _runRivetSweep,
            tooltip: 'Run RIVET Sweep',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.timeline), text: 'Timeline'),
            Tab(icon: Icon(Icons.analytics), text: 'Analysis'),
            Tab(icon: Icon(Icons.info), text: 'Overview'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Timeline Tab
          _phaseIndex != null
              ? PhaseTimelineView(
                  phaseIndex: _phaseIndex!,
                  onRegimeTap: (regime) {
                    _showRegimeDetails(regime);
                  },
                  onRegimeAction: (regime, action) {
                    _handleRegimeAction(regime, action);
                  },
                )
              : const Center(
                  child: Text('No phase data available'),
                ),

          // Analysis Tab
          _buildAnalysisTab(),

          // Overview Tab
          const PhaseInfoOverview(),
        ],
      ),
    );
  }

  Widget _buildAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Phase Analysis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Automatically detect phase transitions in your journal entries using advanced pattern recognition.',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _runRivetSweep,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Run Phase Analysis'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timeline, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        'Phase Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPhaseStats(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseStats() {
    if (_phaseIndex == null) {
      return const Text('No phase data available');
    }

    final regimes = _phaseIndex!.allRegimes;
    final phaseCounts = <PhaseLabel, int>{};

    for (final regime in regimes) {
      phaseCounts[regime.label] = (phaseCounts[regime.label] ?? 0) + 1;
    }

    return Column(
      children: [
        Text('Total Phase Regimes: ${regimes.length}'),
        const SizedBox(height: 8),
        ...phaseCounts.entries.map((entry) {
          final phase = entry.key;
          final count = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${phase.name.toUpperCase()}:'),
                Text('$count regimes'),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showRegimeDetails(PhaseRegime regime) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Phase: ${regime.label.name.toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start: ${regime.start.toLocal().toString()}'),
            if (regime.end != null)
              Text('End: ${regime.end!.toLocal().toString()}')
            else
              const Text('Status: Ongoing'),
            Text('Source: ${regime.source.name}'),
            if (regime.confidence != null)
              Text('Confidence: ${(regime.confidence! * 100).toStringAsFixed(1)}%'),
            Text('Anchored Entries: ${regime.anchors.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleRegimeAction(PhaseRegime regime, String action) {
    switch (action) {
      case 'edit':
        // TODO: Implement regime editing
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edit functionality coming soon')),
        );
        break;
      case 'delete':
        _confirmDeleteRegime(regime);
        break;
      default:
        break;
    }
  }

  void _confirmDeleteRegime(PhaseRegime regime) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Phase Regime'),
        content: Text(
          'Are you sure you want to delete this ${regime.label.name} phase regime?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // TODO: Implement regime deletion
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete functionality coming soon')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
