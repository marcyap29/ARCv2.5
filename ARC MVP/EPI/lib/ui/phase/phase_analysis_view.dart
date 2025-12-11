// lib/ui/phase/phase_analysis_view.dart
// Main Phase Analysis View - integrates timeline, wizard, and phase management

import 'package:flutter/material.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/services/phase_index.dart';
import '../../services/phase_regime_service.dart';
import '../../services/rivet_sweep_service.dart';
import '../../services/analytics_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/ui/journal/journal_screen.dart';
import 'rivet_sweep_wizard.dart';
import 'phase_help_screen.dart';
import 'phase_change_readiness_card.dart';
import 'phase_timeline_view.dart';
import 'simplified_arcform_view_3d.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:my_app/models/user_profile_model.dart';
import 'package:my_app/shared/ui/settings/settings_view.dart';
import 'package:my_app/ui/phase/advanced_analytics_view.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart';
import 'package:my_app/prism/atlas/rivet/rivet_service.dart';
import 'package:my_app/arc/ui/arcforms/phase_recommender.dart';

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
  RivetSweepResult? _lastSweepResult;
  bool _hasUnapprovedAnalysis = false;
  bool _isLoadingPhaseData = false; // Guard to prevent loop
  
  // Trend data - calculated during load, displayed in card
  String? _approachingPhase;
  int _trendPercent = 0;

  @override
  void initState() {
    super.initState();
    _loadPhaseData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Don't reload in didChangeDependencies - it causes loops
    // Phase data is loaded in initState and can be refreshed manually if needed
  }

  Future<void> _loadPhaseData() async {
    // Prevent multiple simultaneous loads
    if (_isLoadingPhaseData) {
      return;
    }
    
    try {
      _isLoadingPhaseData = true;
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

      // Check if there's a pending analysis result from ARCX import
      await _checkPendingAnalysis();
      
      // Calculate trend toward next phase (synchronous calculation from entries)
      await _calculatePhaseTrend(journalRepo);

      setState(() {
        _isLoading = false;
      });
      
      // Refresh ARCForms to show updated phase
      // Removed post-frame callback to prevent rendering loops
      // The ValueKey on SimplifiedArcformView3D will handle updates automatically
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    } finally {
      // Always reset loading flag to allow future loads
      _isLoadingPhaseData = false;
    }
  }

  /// Calculate phase trend from recent entries using RIVET-based analysis
  /// This uses the same methodology as PhaseChangeReadinessCard for consistency
  Future<void> _calculatePhaseTrend(JournalRepository journalRepo) async {
    try {
      final currentRegime = _phaseIndex?.currentRegime;
      String currentPhaseName;
      
      if (currentRegime != null) {
        currentPhaseName = _getPhaseLabelName(currentRegime.label);
      } else if (_phaseIndex?.allRegimes.isNotEmpty == true) {
        final sortedRegimes = List.from(_phaseIndex!.allRegimes)
          ..sort((a, b) => b.start.compareTo(a.start));
        currentPhaseName = _getPhaseLabelName(sortedRegimes.first.label);
      } else {
        _approachingPhase = null;
        _trendPercent = 0;
        return;
      }

      // Rebuild RIVET state from journal entries (same as PhaseChangeReadinessCard)
      final allEntries = journalRepo.getAllJournalEntriesSync();
      if (allEntries.isEmpty) {
        _approachingPhase = null;
        _trendPercent = 0;
        return;
      }

      // Sort entries chronologically
      final sortedEntries = List<JournalEntry>.from(allEntries)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Build RIVET events from entries (same approach as PhaseChangeReadinessCard)
      final rivetService = RivetService();
      final events = <RivetEvent>[];
      RivetEvent? lastEvent;

      for (final entry in sortedEntries) {
        // Use PhaseRecommender to predict phase from content (same as PhaseChangeReadinessCard)
        final recommendedPhase = PhaseRecommender.recommend(
          emotion: entry.emotion ?? '',
          reason: entry.emotionReason ?? '',
          text: entry.content,
          selectedKeywords: entry.keywords,
        );

        // Use userPhaseOverride as refPhase if set (chisel), otherwise use regime baseline
        final entryRefPhase = entry.userPhaseOverride ?? currentPhaseName;
        
        final event = RivetEvent(
          eventId: entry.id,
          date: entry.createdAt,
          source: EvidenceSource.text,
          keywords: entry.keywords.toSet(),
          predPhase: recommendedPhase,
          refPhase: entryRefPhase,  // User corrections feed into RIVET
          tolerance: const {},
        );

        events.add(event);
        rivetService.ingest(event, lastEvent: lastEvent);
        lastEvent = event;
      }

      if (events.length < 3) {
        _approachingPhase = null;
        _trendPercent = 0;
        return;
      }

      // Calculate transition insights (same algorithm as PhaseChangeReadinessCard)
      final recentEvents = events.length > 10 
          ? events.sublist(events.length - 10) 
          : events;
      
      final phaseCounts = <String, int>{};
      for (final event in recentEvents) {
        phaseCounts[event.predPhase] = (phaseCounts[event.predPhase] ?? 0) + 1;
      }

      String? approachingPhase;
      double maxCount = 0;
      for (final entry in phaseCounts.entries) {
        if (entry.key.toLowerCase() != currentPhaseName.toLowerCase() && entry.value > maxCount) {
          maxCount = entry.value.toDouble();
          approachingPhase = entry.key;
        }
      }

      if (approachingPhase == null) {
        _approachingPhase = null;
        _trendPercent = 0;
        print('DEBUG: Phase trend - stable in $currentPhaseName (no approaching phase)');
        return;
      }

      // Calculate shift percentage by comparing early vs recent predictions
      final midPoint = recentEvents.length ~/ 2;
      final earlyPhases = recentEvents.sublist(0, midPoint).map((e) => e.predPhase).toList();
      final recentPhases = recentEvents.sublist(midPoint).map((e) => e.predPhase).toList();
      
      final earlyApproachCount = earlyPhases.where((p) => p.toLowerCase() == approachingPhase!.toLowerCase()).length;
      final recentApproachCount = recentPhases.where((p) => p.toLowerCase() == approachingPhase!.toLowerCase()).length;
      
      final earlyPercent = earlyPhases.isEmpty ? 0.0 : (earlyApproachCount / earlyPhases.length) * 100;
      final recentPercent = recentPhases.isEmpty ? 0.0 : (recentApproachCount / recentPhases.length) * 100;
      
      final shiftPercentage = (recentPercent - earlyPercent).abs();
      final isToward = recentPercent > earlyPercent;

      // Only show trend if it's meaningful (> 5% shift and trending toward)
      if (shiftPercentage > 5.0 && isToward) {
        _approachingPhase = approachingPhase[0].toUpperCase() + approachingPhase.substring(1).toLowerCase();
        _trendPercent = shiftPercentage.round();
      } else {
        _approachingPhase = null;
        _trendPercent = 0;
      }
      
      print('DEBUG: Phase trend (RIVET-based) - approaching: $_approachingPhase, percent: $_trendPercent%, '
            'early: ${earlyPercent.toStringAsFixed(1)}%, recent: ${recentPercent.toStringAsFixed(1)}%');
    } catch (e) {
      print('DEBUG: Error calculating phase trend: $e');
      _approachingPhase = null;
      _trendPercent = 0;
    }
  }

  /// Check if there's a pending analysis result from ARCX import
  Future<void> _checkPendingAnalysis() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPendingAnalysis = prefs.getBool('phase_analysis_pending') ?? false;
      
      if (hasPendingAnalysis) {
        // Set flag to show placard and gray out button
        // The actual analysis will be re-run when Review is clicked
        setState(() {
          _hasUnapprovedAnalysis = true;
        });
      }
    } catch (e) {
      print('Error checking pending analysis: $e');
    }
  }

  /// Get segment count from preferences (for display in placard)
  Future<int> _getSegmentCountFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('phase_analysis_segments') ?? 0;
    } catch (e) {
      return 0;
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
        // Store result and show unapproved analysis state
        setState(() {
          _lastSweepResult = result;
          _hasUnapprovedAnalysis = true;
        });
        
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
          // Clear unapproved analysis state
          if (mounted) {
            setState(() {
              _hasUnapprovedAnalysis = false;
              _lastSweepResult = null;
            });
          }
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
          title: const Text('Phase'),
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
          title: const Text('Phase'),
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
        leading: IconButton(
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
        title: const Text('Phase'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'arcforms':
                  setState(() {
                    _selectedView = 'arcforms';
                    _refreshArcforms();
                  });
                  break;
                case 'timeline':
                  setState(() {
                    _selectedView = 'timeline';
                  });
                  break;
                case 'analysis':
                  setState(() {
                    _selectedView = 'analysis';
                  });
                  break;
                case 'advanced_analytics':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdvancedAnalyticsView(),
                    ),
                  );
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsView(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'arcforms',
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: _selectedView == 'arcforms' ? Colors.purple : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Phase Visualizations',
                      style: TextStyle(
                        fontWeight: _selectedView == 'arcforms' ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'timeline',
                child: Row(
                  children: [
                    Icon(
                      Icons.timeline,
                      size: 20,
                      color: _selectedView == 'timeline' ? Colors.purple : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Timeline',
                      style: TextStyle(
                        fontWeight: _selectedView == 'timeline' ? FontWeight.w600 : FontWeight.normal,
                      ),
          ),
        ],
      ),
              ),
              PopupMenuItem<String>(
                value: 'analysis',
        child: Row(
          children: [
                    Icon(
                      Icons.analytics,
                      size: 20,
                      color: _selectedView == 'analysis' ? Colors.purple : null,
                    ),
                    const SizedBox(width: 12),
            Text(
                      'Analysis',
              style: TextStyle(
                        fontWeight: _selectedView == 'analysis' ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
              ),
              PopupMenuItem<String>(
                value: 'advanced_analytics',
                child: Row(
                  children: [
                    const Icon(Icons.analytics, size: 20),
                    const SizedBox(width: 12),
                    const Text('Advanced Analytics'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.settings, size: 20),
                    const SizedBox(width: 12),
                    const Text('Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Content based on selection
          Expanded(
            child: _buildContentForView(_selectedView),
          ),
        ],
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
                  // Show Phase Analysis Complete placard if analysis is pending approval
                  if (_hasUnapprovedAnalysis && _lastSweepResult != null)
                    _buildAnalysisCompletePlacard(),
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

  /// Build Timeline content (function kept for potential future use)
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
            // Gray out button if analysis is already pending/complete
            final isDisabled = _hasUnapprovedAnalysis;
            
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: ElevatedButton.icon(
                onPressed: isDisabled ? null : _runRivetSweep,
                icon: const Icon(Icons.play_arrow, size: 24),
                label: const Text(
                  'Run Phase Analysis',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDisabled ? Colors.grey : Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  elevation: isDisabled ? 2 : 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            );
          }
        }
        
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.play_arrow, size: 24),
            label: const Text(
              'Run Phase Analysis',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build Phase Analysis Complete placard
  Widget _buildAnalysisCompletePlacard() {
    if (!_hasUnapprovedAnalysis) return const SizedBox.shrink();
    
    // Get segment count from stored result or preferences
    int totalSegments = 0;
    if (_lastSweepResult != null) {
      totalSegments = _lastSweepResult!.autoAssign.length + 
                     _lastSweepResult!.review.length + 
                     _lastSweepResult!.lowConfidence.length;
    }
    
    return FutureBuilder<int>(
      future: totalSegments > 0 ? Future.value(totalSegments) : _getSegmentCountFromPrefs(),
      builder: (context, snapshot) {
        final segmentCount = snapshot.data ?? totalSegments;
        
        return Container(
          margin: const EdgeInsets.only(top: 12.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.blue[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phase Analysis Complete',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          segmentCount > 0
                              ? 'Rivet found $segmentCount segments in your journal timeline. '
                                'Review and approve them below.'
                              : 'Phase analysis has been completed. Review the results below.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Review button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openReviewWizard,
                  icon: const Icon(Icons.reviews, size: 20),
                  label: const Text(
                    'Review',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    side: BorderSide(color: Colors.blue[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Open review wizard (re-run analysis and show wizard)
  Future<void> _openReviewWizard() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get journal entries for analysis
      final journalRepo = JournalRepository();
      final journalEntries = journalRepo.getAllJournalEntriesSync();

      // Check if there are enough entries for analysis
      if (journalEntries.length < 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Need at least 5 journal entries to run phase analysis'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final result = await rivetSweepService.analyzeEntries(journalEntries);

      if (mounted) {
        // Store result and show unapproved analysis state
        setState(() {
          _lastSweepResult = result;
          _hasUnapprovedAnalysis = true;
        });
        
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
          final entry = await journalRepo.getJournalEntryById(entryId);
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
        // Simplified view below
        Expanded(
          child: _buildArcformContent(),
        ),
      ],
    );
  }


  /// Build arcform content widget
  Widget _buildArcformContent() {
    // Get current phase - prioritize currentRegime, fallback to most recent regime
    String? currentPhaseName;
    if (_phaseIndex?.currentRegime != null) {
      currentPhaseName = _getPhaseLabelName(_phaseIndex!.currentRegime!.label);
    } else if (_phaseIndex?.allRegimes.isNotEmpty == true) {
      // No current ongoing regime, use most recent one
      final sortedRegimes = List.from(_phaseIndex!.allRegimes)..sort((a, b) => b.start.compareTo(a.start));
      currentPhaseName = _getPhaseLabelName(sortedRegimes.first.label);
    }
    
    // Create a unique key that includes both the regime ID and phase name
    final regimeId = _phaseIndex?.currentRegime?.id ?? 'none';
    final phaseName = currentPhaseName ?? 'none';
    final uniqueKey = 'arcform_${regimeId}_$phaseName';
    
    return SimplifiedArcformView3D(
      key: ValueKey(uniqueKey),
      currentPhase: currentPhaseName,
      footerWidgets: [
        // Phase Transition Readiness card
        _buildPhaseTransitionReadinessCard(currentPhaseName),
        // Simpler Most Aligned Phase card - no async, no CustomPaint
        _buildSimpleMostAlignedCard(currentPhaseName),
      ],
    );
  }

  /// Phase Transition Readiness card - shows trend toward next phase
  Widget _buildPhaseTransitionReadinessCard(String? currentPhaseName) {
    final hasTrend = _approachingPhase != null && _trendPercent > 0;
    final phaseColor = hasTrend 
        ? _getPhaseColor(_approachingPhase!) 
        : Colors.grey;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: phaseColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and info button
          Row(
            children: [
              Icon(
                hasTrend ? Icons.trending_up : Icons.trending_flat,
                color: phaseColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Phase Transition Readiness',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showTransitionReadinessInfo(),
                child: Icon(
                  Icons.info_outline,
                  color: Colors.grey[400],
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Trend text
          Text(
            hasTrend
                ? 'Your reflection patterns have shifted $_trendPercent% toward $_approachingPhase'
                : 'Your reflection patterns are stable in ${currentPhaseName ?? "your current phase"}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                // Background bar (100%)
                Container(
                  height: 8,
                  width: double.infinity,
                  color: phaseColor.withOpacity(0.2),
                ),
                // Filled bar (trend percent) - show 0% if no trend
                if (_trendPercent > 0)
                  FractionallySizedBox(
                    widthFactor: _trendPercent / 100,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: phaseColor.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Percentage label
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$_trendPercent%',
              style: TextStyle(
                color: phaseColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTransitionReadinessInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              'Phase Transition Readiness',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This indicator shows how your recent journal entries align with different phases.',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              'Based on your last 10 days of entries, your reflection patterns suggest a trend toward a new phase.',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 12),
            Text(
              'A higher percentage indicates stronger alignment with the approaching phase.',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Got it', style: TextStyle(color: Theme.of(context).primaryColor)),
          ),
        ],
      ),
    );
  }

  /// Simple Most Aligned Phase card - uses only synchronous data from _phaseIndex
  /// No FutureBuilder, no CustomPaint, no async calls during build
  Widget _buildSimpleMostAlignedCard(String? currentPhaseName) {
    final phase = currentPhaseName ?? 'Discovery';
    final capitalizedPhase = phase[0].toUpperCase() + phase.substring(1);
    final phaseColor = _getPhaseColor(phase);
    
    // Calculate days in current/most recent phase
    int daysInPhase = 0;
    bool isOngoing = false;
    
    if (_phaseIndex?.currentRegime != null) {
      // Ongoing regime exists
      daysInPhase = DateTime.now().difference(_phaseIndex!.currentRegime!.start).inDays;
      isOngoing = true;
    } else if (_phaseIndex?.allRegimes.isNotEmpty == true) {
      // No ongoing regime - use most recent one
      final sortedRegimes = List.from(_phaseIndex!.allRegimes)
        ..sort((a, b) => b.start.compareTo(a.start));
      final mostRecent = sortedRegimes.first;
      final regimeEnd = mostRecent.end ?? DateTime.now();
      daysInPhase = regimeEnd.difference(mostRecent.start).inDays;
      isOngoing = false;
    }
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: phaseColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_fix_high,
                  color: phaseColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Phase',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey[400],
                            letterSpacing: 0.4,
                          ),
                    ),
                    Text(
                      capitalizedPhase,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$daysInPhase',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (isOngoing)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    isOngoing 
                        ? (daysInPhase == 1 ? 'day' : 'days')
                        : (daysInPhase == 1 ? 'day duration' : 'days duration'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isOngoing ? Colors.grey[400] : Colors.grey[500],
                          fontSize: 10,
                        ),
                  ),
                ],
              ),
            ],
          ),
          
          // Simple timeline using Row of Containers (not CustomPaint)
          if (_phaseIndex != null && _phaseIndex!.allRegimes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Phase Timeline',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            _buildSimpleTimeline(),
          ],
          
          // Trend toward next phase (calculated during load, not build)
          if (_approachingPhase != null && _trendPercent > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getPhaseColor(_approachingPhase!).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getPhaseColor(_approachingPhase!).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.trending_up,
                    color: _getPhaseColor(_approachingPhase!),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_trendPercent% of recent entries suggest $_approachingPhase',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[300],
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build an interactive timeline using Row of colored Containers
  /// Tappable segments show details, with legend below
  /// Scrollable horizontally when there are many phases
  Widget _buildSimpleTimeline() {
    if (_phaseIndex == null || _phaseIndex!.allRegimes.isEmpty) {
      return const SizedBox.shrink();
    }

    final regimes = List.from(_phaseIndex!.allRegimes)
      ..sort((a, b) => a.start.compareTo(b.start));

    // Calculate total time span
    final earliestStart = regimes.first.start;
    final latestEnd = regimes.last.end ?? DateTime.now();
    final totalDuration = latestEnd.difference(earliestStart).inMilliseconds;
    final totalDays = latestEnd.difference(earliestStart).inDays;
    
    if (totalDuration == 0) {
      return const SizedBox.shrink();
    }

    // Determine if scrolling is needed (more than 5 phases or timeline > 180 days)
    final needsScroll = regimes.length > 5 || totalDays > 180;
    final minSegmentWidth = needsScroll ? 70.0 : 40.0; // Minimum width per segment

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline bar with interaction hint
        Stack(
          children: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: needsScroll
                    ? _buildScrollableTimeline(regimes, totalDuration, minSegmentWidth)
                    : _buildFixedTimeline(regimes, totalDuration),
              ),
            ),
            // Tap hint indicator (small touch icon)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  needsScroll ? Icons.swipe : Icons.touch_app,
                  size: 12,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
        
        // Hint text
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 10,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                needsScroll 
                    ? 'Swipe to scroll • Tap any phase for details'
                    : 'Tap any phase to see details',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Date range and total duration
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatShortDate(earliestStart),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey[500],
                    fontSize: 10,
                  ),
            ),
            Text(
              '$totalDays days total • ${regimes.length} phases',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey[500],
                    fontSize: 10,
                  ),
            ),
            Text(
              _formatShortDate(latestEnd),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey[500],
                    fontSize: 10,
                  ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Legend (only show if more than one phase type)
        _buildPhaseLegend(regimes),
      ],
    );
  }

  /// Build scrollable timeline for many phases
  Widget _buildScrollableTimeline(List<dynamic> regimes, int totalDuration, double minWidth) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: regimes.map((regime) {
          final regimeStart = regime.start as DateTime;
          final regimeEnd = (regime.end ?? DateTime.now()) as DateTime;
          final regimeDuration = regimeEnd.difference(regimeStart).inMilliseconds;
          final regimeDays = regimeEnd.difference(regimeStart).inDays;
          
          // Calculate width proportional to duration, with minimum
          final proportionalWidth = (regimeDuration / totalDuration) * 300; // Base width of 300
          final segmentWidth = proportionalWidth.clamp(minWidth, 150.0);
          
          final phaseName = _getPhaseLabelName(regime.label);
          final phaseColor = _getPhaseColor(phaseName);
          final capitalizedName = phaseName[0].toUpperCase() + phaseName.substring(1);
          
          return SizedBox(
            width: segmentWidth,
            height: 44,
            child: Material(
              color: phaseColor.withOpacity(0.85),
              child: InkWell(
                onTap: () => _showRegimeDetailPopup(regime, regimeDays),
                splashColor: Colors.white.withOpacity(0.3),
                highlightColor: Colors.white.withOpacity(0.1),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.transparent,
                        Colors.black.withOpacity(0.1),
                      ],
                    ),
                    border: Border(
                      right: BorderSide(
                        color: Colors.black.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        capitalizedName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${regimeDays}d',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 9,
                          shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Build fixed (non-scrollable) timeline for fewer phases
  Widget _buildFixedTimeline(List<dynamic> regimes, int totalDuration) {
    return Row(
      children: regimes.map((regime) {
        final regimeStart = regime.start as DateTime;
        final regimeEnd = (regime.end ?? DateTime.now()) as DateTime;
        final regimeDuration = regimeEnd.difference(regimeStart).inMilliseconds;
        final regimeDays = regimeEnd.difference(regimeStart).inDays;
        
        // Calculate flex weight (proportional to duration)
        final flexWeight = (regimeDuration / totalDuration * 100).round().clamp(1, 100);
        
        final phaseName = _getPhaseLabelName(regime.label);
        final phaseColor = _getPhaseColor(phaseName);
        final capitalizedName = phaseName[0].toUpperCase() + phaseName.substring(1);
        
        return Expanded(
          flex: flexWeight,
          child: Material(
            color: phaseColor.withOpacity(0.85),
            child: InkWell(
              onTap: () => _showRegimeDetailPopup(regime, regimeDays),
              splashColor: Colors.white.withOpacity(0.3),
              highlightColor: Colors.white.withOpacity(0.1),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.transparent,
                      Colors.black.withOpacity(0.1),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (flexWeight > 20)
                      Text(
                        capitalizedName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    else if (flexWeight > 8)
                      Text(
                        phaseName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
                        ),
                      ),
                    if (flexWeight > 15)
                      Text(
                        '${regimeDays}d',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 9,
                          shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Show popup with regime details when tapped
  void _showRegimeDetailPopup(dynamic regime, int days) {
    final phaseName = _getPhaseLabelName(regime.label);
    final capitalizedName = phaseName[0].toUpperCase() + phaseName.substring(1);
    final phaseColor = _getPhaseColor(phaseName);
    final regimeStart = regime.start as DateTime;
    final regimeEnd = (regime.end ?? DateTime.now()) as DateTime;
    final isOngoing = regime.end == null;
    
    // Count entries in this phase
    final journalRepo = JournalRepository();
    final allEntries = journalRepo.getAllJournalEntriesSync();
    final phaseEntries = allEntries.where((entry) {
      return entry.createdAt.isAfter(regimeStart.subtract(const Duration(days: 1))) &&
             entry.createdAt.isBefore(regimeEnd.add(const Duration(days: 1)));
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: phaseColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                capitalizedName,
                style: TextStyle(color: phaseColor, fontWeight: FontWeight.bold),
              ),
            ),
            if (isOngoing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Current',
                  style: TextStyle(fontSize: 10, color: Colors.green),
                ),
              ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(Icons.calendar_today, 'Started', _formatFullDate(regimeStart)),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.event,
              isOngoing ? 'Ongoing' : 'Ended',
              isOngoing ? 'Present' : _formatFullDate(regimeEnd),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.timelapse, 'Duration', '$days days'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.article, 'Entries', '${phaseEntries.length}'),
            const SizedBox(height: 16),
            Text(
              _getPhaseDescription(phaseName),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic,
                  ),
            ),
            
            // View entries button
            if (phaseEntries.isNotEmpty) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showPhaseEntriesSheet(capitalizedName, phaseColor, phaseEntries, regimeStart, regimeEnd);
                  },
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: Text('View ${phaseEntries.length} Entries'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: phaseColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
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

  /// Show bottom sheet with entries from a specific phase
  void _showPhaseEntriesSheet(
    String phaseName,
    Color phaseColor,
    List<JournalEntry> entries,
    DateTime startDate,
    DateTime endDate,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 40,
                      decoration: BoxDecoration(
                        color: phaseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$phaseName Phase',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            '${_formatShortDate(startDate)} – ${_formatShortDate(endDate)} • ${entries.length} entries',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[500],
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Entries list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _buildEntryCard(entry, phaseColor);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a card for an entry in the phase entries list
  Widget _buildEntryCard(JournalEntry entry, Color phaseColor) {
    final preview = entry.content.length > 100 
        ? '${entry.content.substring(0, 100)}...' 
        : entry.content;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          // Navigate to the entry
          Navigator.of(context).pop(); // Close the bottom sheet
          // Navigate to journal entry using MaterialPageRoute
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => JournalScreen(
                initialContent: entry.content,
                selectedEmotion: entry.emotion,
                selectedReason: entry.emotionReason,
                existingEntry: entry,
                isViewOnly: true, // Open in view mode first
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: phaseColor.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title.isNotEmpty ? entry.title : 'Untitled',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatFullDate(entry.createdAt),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.grey[500],
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                ],
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  preview,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[400],
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (entry.media.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.photo, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.media.length} media',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        ),
      ],
    );
  }

  String _getPhaseDescription(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return 'A time of exploration, curiosity, and learning new things about yourself.';
      case 'expansion':
        return 'A period of growth, taking on challenges, and expanding your horizons.';
      case 'transition':
        return 'A time of change, adapting to new circumstances, and finding balance.';
      case 'consolidation':
        return 'A period of integration, solidifying gains, and building on progress.';
      case 'recovery':
        return 'A time of rest, healing, and gentle self-care.';
      case 'breakthrough':
        return 'A moment of clarity, revelation, and transformative insight.';
      default:
        return 'A unique period in your journey.';
    }
  }

  /// Build legend showing phase colors
  Widget _buildPhaseLegend(List<dynamic> regimes) {
    // Get unique phases from regimes
    final uniquePhases = regimes.map((r) => _getPhaseLabelName(r.label)).toSet().toList();
    
    if (uniquePhases.length <= 1) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: uniquePhases.map((phase) {
        final phaseColor = _getPhaseColor(phase);
        final capitalizedName = phase[0].toUpperCase() + phase.substring(1);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: phaseColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              capitalizedName,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey[400],
                    fontSize: 10,
                  ),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _formatShortDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year.toString().substring(2)}';
  }

  String _formatFullDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Get color for phase name
  Color _getPhaseColor(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return Colors.blue;
      case 'expansion':
        return Colors.green;
      case 'transition':
        return Colors.orange;
      case 'consolidation':
        return Colors.purple;
      case 'recovery':
        return Colors.red;
      case 'breakthrough':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  /// Refresh ARCForms when phase changes occur
  void _refreshArcforms() {
    // Don't call setState here - it causes rendering loops
    // The ValueKey on SimplifiedArcformView3D will handle updates when phase changes
  }

  /// Comprehensive refresh of all phase-related components after RIVET Sweep
  Future<void> _refreshAllPhaseComponents() async {
    try {
      // 1. Reload phase data (includes Phase Regimes and Phase Statistics)
      await _loadPhaseData();
      
      // 2. Update user profile with current phase from phase regimes
      await _updateUserPhaseFromRegimes();
      
      // 3. Refresh ARCForms
      _refreshArcforms();
      
      // 4. Trigger comprehensive rebuild of all analysis components
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

  /// Update user profile with current phase from phase regimes
  Future<void> _updateUserPhaseFromRegimes() async {
    try {
      if (_phaseIndex == null) {
        print('Phase Analysis: No phase index available, skipping phase update');
        return;
      }

      // Determine current phase from phase index
      String? currentPhaseName;
      final currentRegime = _phaseIndex!.currentRegime;
      
      if (currentRegime != null) {
        // Use current ongoing regime
        currentPhaseName = _getPhaseLabelName(currentRegime.label);
        // Capitalize first letter
        currentPhaseName = currentPhaseName.substring(0, 1).toUpperCase() + currentPhaseName.substring(1);
      } else {
        // No current ongoing regime, use most recent one
        final allRegimes = _phaseIndex!.allRegimes;
        if (allRegimes.isNotEmpty) {
          final sortedRegimes = List.from(allRegimes)..sort((a, b) => b.start.compareTo(a.start));
          final mostRecent = sortedRegimes.first;
          currentPhaseName = _getPhaseLabelName(mostRecent.label);
          // Capitalize first letter
          currentPhaseName = currentPhaseName.substring(0, 1).toUpperCase() + currentPhaseName.substring(1);
        } else {
          // No regimes at all, use default
          currentPhaseName = 'Discovery';
        }
      }

      // Update user profile
      final userBox = await Hive.openBox<UserProfile>('user_profile');
      final userProfile = userBox.get('profile');
      
      if (userProfile != null) {
        final oldPhase = userProfile.onboardingCurrentSeason ?? userProfile.currentPhase;
        
        // Only update if phase actually changed
        if (oldPhase != currentPhaseName) {
          final updatedProfile = userProfile.copyWith(
            onboardingCurrentSeason: currentPhaseName,
            currentPhase: currentPhaseName,
            lastPhaseChangeAt: DateTime.now(),
          );
          await userBox.put('profile', updatedProfile);
          print('Phase Analysis: ✓ Updated user profile phase from $oldPhase to $currentPhaseName');
        } else {
          print('Phase Analysis: Phase unchanged ($currentPhaseName), skipping profile update');
        }
      } else {
        print('Phase Analysis: ⚠️ No user profile found, cannot update phase');
      }
    } catch (e) {
      print('Phase Analysis: ⚠️ Error updating user phase from regimes: $e');
      // Don't throw - phase update failure shouldn't break refresh
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

  // Most Aligned Phase card temporarily disabled to fix rendering loop
  // TODO: Re-implement with proper state isolation
}

// Most Aligned Phase card and Gantt timeline painter removed temporarily
// to fix rendering loop issue. Will re-implement with proper state isolation.
