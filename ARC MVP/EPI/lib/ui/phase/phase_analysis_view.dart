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
import 'simplified_arcform_view_3d.dart';
import 'phase_arcform_3d_screen.dart';
import '../../shared/app_colors.dart';

class PhaseAnalysisView extends StatefulWidget {
  const PhaseAnalysisView({super.key});

  @override
  State<PhaseAnalysisView> createState() => _PhaseAnalysisViewState();
}

class _PhaseAnalysisViewState extends State<PhaseAnalysisView> {
  String _selectedView = 'arcforms'; // 'arcforms', 'timeline', or 'analysis' - flattened single-level navigation
  PhaseIndex? _phaseIndex;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPhaseData();
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
      
      // Backfill Discovery regime if needed (for entries before first detected regime)
      final journalRepo = JournalRepository();
      await _backfillDiscoveryRegime(phaseRegimeService, journalRepo);
      
      // Reload phaseIndex after backfill to ensure it's up to date
      await phaseRegimeService.initialize();
      _phaseIndex = phaseRegimeService.phaseIndex;
      
      print('DEBUG: _loadPhaseData - Total regimes after backfill: ${_phaseIndex?.allRegimes.length ?? 0}');
      for (final regime in _phaseIndex?.allRegimes ?? []) {
        print('DEBUG: _loadPhaseData - Regime: ${_getPhaseLabelName(regime.label)} from ${regime.start} to ${regime.end ?? 'ongoing'}');
      }
      
      final currentRegime = _phaseIndex?.currentRegime;
      final currentPhaseName = currentRegime != null ? _getPhaseLabelName(currentRegime.label) : 'none';
      print('DEBUG: _loadPhaseData - Current phase determined: $currentPhaseName (ID: ${currentRegime?.id})');

      setState(() {
        _isLoading = false;
      });
      
      // Refresh ARCForms to show updated phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshArcforms();
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
        
        // After wizard completion, refresh all phase components
        await _refreshAllPhaseComponents();
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
          // ARCForms will be refreshed by the calling function
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
      }).toList()
        ..sort((a, b) => a.start.compareTo(b.start)); // Sort chronologically

      // Create phase regimes from approved proposals (in chronological order)
      for (int i = 0; i < finalProposals.length; i++) {
        final proposal = finalProposals[i];
        final isLastProposal = i == finalProposals.length - 1;
        
        // If this is the last proposal and it ends today (or very recently), make it ongoing
        // This handles the case where Transition (or any phase) starts today
        DateTime? regimeEnd = proposal.end;
        if (isLastProposal) {
          final now = DateTime.now();
          final daysSinceEnd = now.difference(proposal.end).inDays;
          // If the proposal ends within the last 2 days, consider it ongoing
          if (daysSinceEnd <= 2) {
            regimeEnd = null; // Ongoing
            print('DEBUG: Making last proposal (${_getPhaseLabelName(proposal.proposedLabel)}) ongoing - ended ${daysSinceEnd} days ago');
          }
        }
        
        await phaseRegimeService.createRegime(
          label: proposal.proposedLabel,
          start: proposal.start,
          end: regimeEnd,
          source: PhaseSource.rivet,
          confidence: proposal.confidence,
          anchors: proposal.entryIds,
        );
        
        // Add phase hashtags to entries in this regime for future reconstruction
        await _addPhaseHashtagsToEntries(proposal.entryIds, proposal.proposedLabel);
      }

      // Backfill Discovery regime for any unphased entries before the first regime
      final journalRepo = JournalRepository();
      await _backfillDiscoveryRegime(phaseRegimeService, journalRepo);

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
      ),
      body: Column(
        children: [
          // Horizontally scrollable button bar - single row with all 4 options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: SizedBox(
              height: 36, // Reduced height for compact bar
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPhaseButton('arcforms', 'ARCForms', Icons.auto_awesome),
                    const SizedBox(width: 8),
                    _buildPhaseButton('timeline', 'Timeline', Icons.timeline),
                    const SizedBox(width: 8),
                    _buildPhaseButton('analysis', 'Analysis', Icons.analytics),
                  ],
                ),
              ),
            ),
          ),
          // Content based on selection
          Expanded(
            child: _buildContentForView(_selectedView),
          ),
        ],
      ),
    );
  }

  /// Build phase navigation button
  Widget _buildPhaseButton(String value, String label, IconData icon) {
    final isSelected = _selectedView == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedView = value;
          // Refresh ARCForms when switching to ARCForms view
          if (_selectedView == 'arcforms') {
            print('DEBUG: ARCForms view selected, refreshing...');
            _refreshArcforms();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.purple : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey), // Reduced icon size
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11, // Reduced font size
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build content based on selected view (flattened navigation)
  Widget _buildContentForView(String view) {
    switch (view) {
      case 'arcforms':
        return _buildArcformsTab();
      case 'timeline':
        return _buildTimelineContent();
      case 'analysis':
        return _buildAnalysisTab();
      default:
        return _buildArcformsTab();
    }
  }

  /// Build Timeline content
  Widget _buildTimelineContent() {
    return _phaseIndex != null
        ? PhaseTimelineView(
            key: ValueKey('phase_timeline_${_phaseIndex!.allRegimes.length}_${_phaseIndex!.allRegimes.isNotEmpty ? _phaseIndex!.allRegimes.first.id : 'empty'}'),
            phaseIndex: _phaseIndex!,
            onRegimeTap: _showRegimeDetails,
            onRegimeAction: _handleRegimeAction,
          )
        : Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No phase data available',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Run Phase Analysis to detect phases',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
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
                      const Expanded(
                        child: Text(
                          'Phase Analysis',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Refresh button
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                        ),
                        child: IconButton(
                          icon: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.blue,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.refresh,
                                  size: 20,
                                ),
                          onPressed: _isLoading ? null : () async {
                            await _runRivetSweep();
                          },
                          tooltip: 'Refresh Phase Analysis',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
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
          // Current Phase Detection Card
          _buildCurrentPhaseCard(),
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

  /// Build Current Phase Detection Card
  Widget _buildCurrentPhaseCard() {
    String? currentPhaseName;
    if (_phaseIndex?.currentRegime != null) {
      currentPhaseName = _getPhaseLabelName(_phaseIndex!.currentRegime!.label);
    } else if (_phaseIndex?.allRegimes.isNotEmpty == true) {
      // No current ongoing regime, use most recent one
      final sortedRegimes = List.from(_phaseIndex!.allRegimes)..sort((a, b) => b.start.compareTo(a.start));
      currentPhaseName = _getPhaseLabelName(sortedRegimes.first.label);
    } else {
      currentPhaseName = 'Discovery'; // Default
    }

    // Get phase color
    Color phaseColor;
    switch (currentPhaseName.toLowerCase()) {
      case 'discovery':
        phaseColor = Colors.blue;
        break;
      case 'expansion':
        phaseColor = Colors.green;
        break;
      case 'transition':
        phaseColor = Colors.orange;
        break;
      case 'consolidation':
        phaseColor = Colors.purple;
        break;
      case 'recovery':
        phaseColor = Colors.teal;
        break;
      case 'breakthrough':
        phaseColor = Colors.pink;
        break;
      default:
        phaseColor = Colors.blue;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: phaseColor),
                const SizedBox(width: 8),
                const Text(
                  'Phase Transition Detection',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: phaseColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: phaseColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Phase:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentPhaseName,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: phaseColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: phaseColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
            if (_phaseIndex?.currentRegime != null) ...[
              const SizedBox(height: 8),
              Text(
                'Started: ${_formatDateTime(_phaseIndex!.currentRegime!.start)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ] else if (_phaseIndex?.allRegimes.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                'Most recent phase (no current ongoing phase)',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
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

  /// Backfill Discovery regime for entries before the first detected regime
  Future<void> _backfillDiscoveryRegime(
    PhaseRegimeService phaseRegimeService,
    JournalRepository journalRepo,
  ) async {
    try {
      final allEntries = journalRepo.getAllJournalEntriesSync();
      if (allEntries.isEmpty) return;

      final regimes = phaseRegimeService.phaseIndex.allRegimes;
      if (regimes.isEmpty) {
        // No regimes at all - create Discovery regime from first entry to now
        final firstEntry = allEntries.reduce((a, b) => 
          a.createdAt.isBefore(b.createdAt) ? a : b);
        
        await phaseRegimeService.createRegime(
          label: PhaseLabel.discovery,
          start: firstEntry.createdAt,
          end: null, // Ongoing until another phase is detected
          source: PhaseSource.rivet,
          confidence: 0.5, // Lower confidence for backfilled Discovery
        );
        print('DEBUG: Created backfilled Discovery regime from ${firstEntry.createdAt}');
        return;
      }

      // Sort regimes by start date
      final sortedRegimes = List.from(regimes)..sort((a, b) => a.start.compareTo(b.start));
      final firstRegime = sortedRegimes.first;
      
      // Determine the cutoff date: use the first regime's END date if it has one,
      // otherwise use its START date (for ongoing regimes, we want Discovery before they started)
      // But if the regime has ended, we want Discovery for all entries before it ended
      final cutoffDate = firstRegime.end ?? firstRegime.start;
      
      // Find entries before the cutoff date (end of first regime, or start if ongoing)
      final entriesBeforeCutoff = allEntries
          .where((entry) => entry.createdAt.isBefore(cutoffDate))
          .toList();

      print('DEBUG: _backfillDiscoveryRegime - First regime: ${_getPhaseLabelName(firstRegime.label)} from ${firstRegime.start} to ${firstRegime.end ?? 'ongoing'}');
      print('DEBUG: _backfillDiscoveryRegime - Cutoff date: $cutoffDate');
      print('DEBUG: _backfillDiscoveryRegime - Found ${entriesBeforeCutoff.length} entries before cutoff date');
      print('DEBUG: _backfillDiscoveryRegime - Total entries: ${allEntries.length}, First entry date: ${allEntries.isNotEmpty ? allEntries.reduce((a, b) => a.createdAt.isBefore(b.createdAt) ? a : b).createdAt : 'none'}');

      if (entriesBeforeCutoff.isNotEmpty) {
        // Create Discovery regime for entries before cutoff date
        final discoveryStart = entriesBeforeCutoff
            .reduce((a, b) => a.createdAt.isBefore(b.createdAt) ? a : b)
            .createdAt;
        
        // Check if a Discovery regime already exists that covers this period
        final existingDiscovery = regimes.where((r) => 
          r.label == PhaseLabel.discovery && 
          r.start.isBefore(discoveryStart.add(const Duration(seconds: 1))) &&
          (r.end == null || r.end!.isAfter(discoveryStart.subtract(const Duration(seconds: 1)))) &&
          (r.end == null || r.end!.isAtSameMomentAs(cutoffDate) || (r.end!.isAfter(cutoffDate.subtract(const Duration(seconds: 1)))))
        ).isEmpty;
        
        print('DEBUG: _backfillDiscoveryRegime - Discovery start: $discoveryStart, Cutoff date: $cutoffDate');
        print('DEBUG: _backfillDiscoveryRegime - Existing Discovery regimes: ${regimes.where((r) => r.label == PhaseLabel.discovery).length}');
        
        if (existingDiscovery) {
          try {
            final discoveryEntryIds = entriesBeforeCutoff.map((e) => e.id).toList();
            await phaseRegimeService.createRegime(
              label: PhaseLabel.discovery,
              start: discoveryStart,
              end: cutoffDate,
              source: PhaseSource.rivet,
              confidence: 0.5, // Lower confidence for backfilled Discovery
              anchors: discoveryEntryIds,
            );
            print('✅ Created backfilled Discovery regime from $discoveryStart to $cutoffDate (${entriesBeforeCutoff.length} entries)');
            
            // Add phase hashtags to Discovery entries for future reconstruction
            await _addPhaseHashtagsToEntries(discoveryEntryIds, PhaseLabel.discovery);
            
            // Reload phaseIndex after creating Discovery regime
            await phaseRegimeService.initialize();
          } catch (e) {
            print('❌ ERROR creating Discovery regime: $e');
          }
        } else {
          print('DEBUG: Discovery regime already exists for this period, skipping');
        }
      } else {
        print('DEBUG: No entries found before cutoff date, skipping Discovery backfill');
      }
    } catch (e) {
      print('DEBUG: Error backfilling Discovery regime: $e');
    }
  }

  /// Helper to get PhaseLabel name (works with all Dart versions)
  String _getPhaseLabelName(PhaseLabel label) {
    // Use toString().split('.').last which works in all Dart versions
    // e.g., "PhaseLabel.discovery" -> "discovery"
    return label.toString().split('.').last;
  }

  /// Add phase hashtags to entries retroactively when phases are detected
  Future<void> _addPhaseHashtagsToEntries(List<String> entryIds, PhaseLabel phaseLabel) async {
    try {
      final journalRepo = JournalRepository();
      final phaseName = _getPhaseLabelName(phaseLabel).toLowerCase();
      final hashtag = '#$phaseName';
      
      print('DEBUG: Adding phase hashtag $hashtag to ${entryIds.length} entries');
      
      int updatedCount = 0;
      for (final entryId in entryIds) {
        try {
          final entry = journalRepo.getJournalEntryById(entryId);
          if (entry == null) {
            print('DEBUG: Entry $entryId not found, skipping');
            continue;
          }
          
          // Check if hashtag already exists (case-insensitive)
          final contentLower = entry.content.toLowerCase();
          if (contentLower.contains(hashtag)) {
            print('DEBUG: Entry $entryId already has hashtag $hashtag, skipping');
            continue;
          }
          
          // Add hashtag to content
          final updatedContent = '${entry.content} $hashtag';
          final updatedEntry = entry.copyWith(
            content: updatedContent,
            updatedAt: DateTime.now(),
          );
          
          await journalRepo.updateJournalEntry(updatedEntry);
          updatedCount++;
          print('DEBUG: Added hashtag $hashtag to entry $entryId');
        } catch (e) {
          print('DEBUG: Error updating entry $entryId: $e');
        }
      }
      
      print('DEBUG: Successfully added phase hashtags to $updatedCount/${entryIds.length} entries');
    } catch (e) {
      print('DEBUG: Error adding phase hashtags to entries: $e');
    }
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
                Expanded(
                  child: Text(
                    'Building Your Phase Timeline',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                    overflow: TextOverflow.ellipsis,
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
              // Refresh button with RIVET Sweep functionality
              IconButton(
                icon: const Icon(Icons.refresh),
                iconSize: 18,
                tooltip: 'Run Phase Analysis & Refresh',
                onPressed: () async {
                  // Run RIVET Sweep for phase analysis (includes comprehensive refresh)
                  await _runRivetSweep();
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
          child: Builder(
            builder: (context) {
              // Get current phase - prioritize currentRegime, fallback to most recent regime
              String? currentPhaseName;
              if (_phaseIndex?.currentRegime != null) {
                currentPhaseName = _getPhaseLabelName(_phaseIndex!.currentRegime!.label);
                print('DEBUG: phase_analysis_view - Using currentRegime: $currentPhaseName');
              } else if (_phaseIndex?.allRegimes.isNotEmpty == true) {
                // No current ongoing regime, use most recent one
                final sortedRegimes = List.from(_phaseIndex!.allRegimes)..sort((a, b) => b.start.compareTo(a.start));
                currentPhaseName = _getPhaseLabelName(sortedRegimes.first.label);
                print('DEBUG: phase_analysis_view - No current regime, using most recent: $currentPhaseName');
              } else {
                print('DEBUG: phase_analysis_view - No regimes found, passing null');
              }
              
              print('DEBUG: phase_analysis_view - Passing currentPhase to SimplifiedArcformView3D: $currentPhaseName');
              print('DEBUG: phase_analysis_view - currentRegime ID: ${_phaseIndex?.currentRegime?.id}');
              print('DEBUG: phase_analysis_view - Total regimes: ${_phaseIndex?.allRegimes.length ?? 0}');
              
              // Create a unique key that includes both the regime ID and phase name to force rebuild
              final regimeId = _phaseIndex?.currentRegime?.id ?? 'none';
              final phaseName = currentPhaseName ?? 'none';
              final uniqueKey = 'arcform_${regimeId}_$phaseName';
              
              return SimplifiedArcformView3D(
                key: ValueKey(uniqueKey),
                currentPhase: currentPhaseName,
              );
            },
          ),
        ),
      ],
    );
  }


  /// Refresh ARCForms when phase changes occur
  void _refreshArcforms() {
    // Force rebuild by updating state - the ValueKey will ensure widget rebuilds
    if (mounted) {
      setState(() {
        // Trigger rebuild - the ValueKey on SimplifiedArcformView3D will force recreation
      });
    }
  }

  /// Comprehensive refresh of all phase-related components after RIVET Sweep
  Future<void> _refreshAllPhaseComponents() async {
    try {
      // 1. Reload phase data (includes Phase Regimes and Phase Statistics)
      await _loadPhaseData();
      
      // 2. Refresh ARCForms
      _refreshArcforms();
      
      // 3. Trigger comprehensive rebuild of all analysis components
      setState(() {
        // This will trigger rebuild of:
        // - Phase Statistics card (_buildPhaseStats)
        // - Phase Change Readiness Card
        // - Themes analysis
        // - Tone analysis  
        // - Stable themes
        // - Patterns analysis
        // - All other analysis components in the Analysis tab
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All phase components refreshed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
