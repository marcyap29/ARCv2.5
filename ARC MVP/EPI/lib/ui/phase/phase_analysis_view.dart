// lib/ui/phase/phase_analysis_view.dart
// Main Phase Analysis View - integrates timeline, wizard, and phase management

import 'package:flutter/material.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/services/phase_index.dart';
import '../../services/phase_regime_service.dart';
import '../../services/rivet_sweep_service.dart';
import '../../services/analytics_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'phase_timeline_view.dart';
import 'rivet_sweep_wizard.dart';
import 'phase_help_screen.dart';
import 'phase_change_readiness_card.dart';
import 'sentinel_analysis_view.dart';
import 'simplified_arcform_view_3d.dart';
import 'phase_arcform_3d_screen.dart';
import '../../shared/app_colors.dart';

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
  final GlobalKey<State<SimplifiedArcformView3D>> _arcformsKey = GlobalKey<State<SimplifiedArcformView3D>>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPhaseData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload phase data when navigating to this view to show latest changes
    if (ModalRoute.of(context)?.isCurrent == true) {
      _loadPhaseData();
    }
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
      final journalEntries = journalRepo.getAllJournalEntriesSync();

      // Check if there are enough entries for analysis
      if (journalEntries.length < 5) {
        // Progress card is already shown in the UI, no need for snackbar
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
          // Phase Analysis completed - refresh ARCForms
          _refreshArcforms();
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

      // Save the analysis date
      await phaseRegimeService.setLastAnalysisDate(DateTime.now());

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

  Future<void> _cleanupDuplicates() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      final removedCount = await phaseRegimeService.removeDuplicates();

      // Reload phase data to show cleaned up regimes
      await _loadPhaseData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleaned up $removedCount duplicate phase regimes'),
            backgroundColor: removedCount > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cleanup duplicates: $e'),
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
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelStyle: const TextStyle(fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome, size: 20), text: 'ARCForms'),
            Tab(icon: Icon(Icons.timeline, size: 20), text: 'Timeline'),
            Tab(icon: Icon(Icons.analytics, size: 20), text: 'Analysis'),
            Tab(icon: Icon(Icons.shield, size: 20), text: 'SENTINEL'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ARCForms Tab (moved to first position)
          _buildArcformsTab(),

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

          // SENTINEL Tab
          const SentinelAnalysisView(),
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
          // Phase Analysis Card - restored
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
                  const SizedBox(height: 12),
                  FutureBuilder<DateTime?>(
                    future: _getLastAnalysisDate(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text(
                                'Last analysis: ${_formatDateTime(snapshot.data!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  _buildRivetActionSection(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Phase Statistics Card
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
          const SizedBox(height: 16),
          const PhaseChangeReadinessCard(),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.quiz, color: Colors.purple),
                      const SizedBox(width: 8),
                      const Text(
                        'Phase Self-Assessment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Take a quick self-assessment to help identify your current developmental phase. This can provide an initial baseline while you build journaling data.',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startPhaseQuiz,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Self-Assessment'),
                    ),
                  ),
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
              children: [
                Expanded(
                  child: Text(
                    '${phase.name.toUpperCase()}:',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  '$count regimes',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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


  /// Get last analysis date from phase regime service
  Future<DateTime?> _getLastAnalysisDate() async {
    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      return await phaseRegimeService.getLastAnalysisDate();
    } catch (e) {
      return null;
    }
  }

  /// Format date/time for display
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }

  /// Build RIVET action section with Run Phase Analysis button
  Widget _buildRivetActionSection() {
    return FutureBuilder<int>(
      future: _getJournalEntryCount(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final entryCount = snapshot.data!;
          
          if (entryCount < 5) {
            return _buildInsufficientEntriesCard(entryCount);
          } else {
            return SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _runRivetSweep,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run Phase Analysis'),
              ),
            );
          }
        }
        
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Run Phase Analysis'),
          ),
        );
      },
    );
  }

  /// Get journal entry count
  Future<int> _getJournalEntryCount() async {
    try {
      final journalRepo = JournalRepository();
      final entries = journalRepo.getAllJournalEntriesSync();
      return entries.length;
    } catch (e) {
      return 0;
    }
  }

  /// Build insufficient entries card
  Widget _buildInsufficientEntriesCard(int entryCount) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Building Your Phase Timeline',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'RIVET needs at least 5 entries to detect phase patterns',
              style: TextStyle(color: Colors.blue[600]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: entryCount / 5.0,
                    backgroundColor: Colors.blue[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$entryCount/5 entries',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Keep journaling and your phase timeline will emerge naturally',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Or import an MCP bundle to analyze past entries',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArcformsTab() {
    return Column(
      children: [
        // Header with refresh and 3D view buttons
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'ARCForm Visualizations',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Small refresh button for phase updates
              IconButton(
                icon: const Icon(Icons.refresh),
                iconSize: 18,
                tooltip: 'Refresh phase data',
                onPressed: () async {
                  // Reload phase data from UserProfile and regimes
                  await _loadPhaseData();
                  // Refresh ARCForms
                  _refreshArcforms();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Phase data refreshed'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PhaseArcform3DScreen(
                        phase: _phaseIndex?.currentRegime?.label.name,
                        title: '3D Constellation View',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('3D View'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kcPrimaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Simplified view below
        Expanded(
          child: SimplifiedArcformView3D(
            key: _arcformsKey,
            currentPhase: _phaseIndex?.currentRegime?.label.name,
          ),
        ),
      ],
    );
  }


  /// Refresh ARCForms when phase changes occur
  void _refreshArcforms() {
    // Call refresh method on the ARCForms view
    final state = _arcformsKey.currentState;
    if (state != null && state.mounted) {
      (state as dynamic).refreshSnapshots();
      // Also update the phase if it has changed
      (state as dynamic).updatePhase(_phaseIndex?.currentRegime?.label.name);
    }
  }


  void _startPhaseQuiz() {
    // For now, show a simple dialog with phase options
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Your Phase'),
        content: const Text(
          'Based on your current state, which phase best describes you?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _setPhaseFromQuiz('Discovery');
            },
            child: const Text('Discovery'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _setPhaseFromQuiz('Exploration');
            },
            child: const Text('Exploration'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _setPhaseFromQuiz('Integration');
            },
            child: const Text('Integration'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _setPhaseFromQuiz('Mastery');
            },
            child: const Text('Mastery'),
          ),
        ],
      ),
    );
  }

  void _setPhaseFromQuiz(String phase) {
    // Set the phase and refresh the data
    // This is a simplified implementation - in practice you'd want to save this properly
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Phase set to $phase. This will be refined as you journal.'),
        backgroundColor: Colors.green,
      ),
    );
    _loadPhaseData(); // Refresh the phase data
  }
}
