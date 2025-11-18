// lib/ui/phase/phase_change_readiness_card.dart
// Phase Change Readiness Card - Enhanced with RIVET & ATLAS Phase-Approaching Insights

import 'package:flutter/material.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart';
import 'package:my_app/prism/atlas/rivet/rivet_provider.dart';
import 'package:my_app/prism/atlas/rivet/rivet_service.dart';
import 'package:my_app/prism/atlas/phase/rivet_gate_details_modal.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/arc/ui/arcforms/phase_recommender.dart';
import 'package:uuid/uuid.dart';

class PhaseChangeReadinessCard extends StatefulWidget {
  const PhaseChangeReadinessCard({super.key});

  @override
  State<PhaseChangeReadinessCard> createState() => _PhaseChangeReadinessCardState();
}

class _PhaseChangeReadinessCardState extends State<PhaseChangeReadinessCard> {
  RivetState? _rivetState;
  PhaseTransitionInsights? _rivetInsights;
  Map<String, dynamic>? _atlasInsights;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      const userId = 'default_user';

      // Rebuild RIVET state from all journal entries to ensure entries loaded from documents are included
      final rebuilt = await _rebuildRivetStateFromAllEntries(userId);
      
      if (!mounted) return;
      
      if (rebuilt != null) {
        final rivetProvider = RivetProvider();
        
        if (!rivetProvider.isAvailable) {
          await rivetProvider.initialize(userId);
        }

        // Update the service with the rebuilt state
        if (rivetProvider.service != null) {
          rivetProvider.service!.updateState(rebuilt.state);
        }
        
        // Calculate transition insights from rebuilt event history
        PhaseTransitionInsights? insights;
        if (rebuilt.events.isNotEmpty) {
          // Get the last event's phase
          final lastEvent = rebuilt.events.last;
          // Calculate insights using the service's internal method
          // Since it's private, we'll create a simplified version
          insights = _calculateTransitionInsights(
            currentPhase: lastEvent.refPhase,
            eventHistory: rebuilt.events,
            updatedState: rebuilt.state,
          );
        }
        
        if (mounted) {
        setState(() {
          _rivetState = rebuilt.state;
          _rivetInsights = insights;
        });
        }
      } else {
        // Fallback: try to get state from storage
        final rivetProvider = RivetProvider();
        
        if (!rivetProvider.isAvailable) {
          await rivetProvider.initialize(userId);
        }

        final state = await rivetProvider.safeGetState(userId);
        
        if (mounted) {
        setState(() {
          _rivetState = state ?? const RivetState(
            align: 0,
            trace: 0,
            sustainCount: 0,
            sawIndependentInWindow: false,
          );
        });
        }
      }

      // Get ATLAS insights (simplified - would need health data in real implementation)
      final atlasInsights = _getAtlasInsights();
      if (mounted) {
      setState(() {
        _atlasInsights = atlasInsights;
        _isLoading = false;
      });
      }
    } catch (e, stackTrace) {
      print('ERROR: Failed to load readiness data: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
      setState(() {
        _rivetState = const RivetState(
          align: 0,
          trace: 0,
          sustainCount: 0,
          sawIndependentInWindow: false,
        );
        _isLoading = false;
      });
      }
    }
  }

  /// Get current phase from PhaseRegimeService (helper method)
  Future<String> _getPhaseFromPhaseRegimeService() async {
    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      
      final currentRegime = phaseRegimeService.phaseIndex.currentRegime;
      if (currentRegime != null) {
        String phase = currentRegime.label.toString().split('.').last;
        // Capitalize first letter
        phase = phase[0].toUpperCase() + phase.substring(1);
        print('PhaseChangeReadinessCard: Using current phase from PhaseRegimeService: $phase');
        return phase;
      } else {
        // Fallback to most recent regime if no current ongoing regime
        final allRegimes = phaseRegimeService.phaseIndex.allRegimes;
        if (allRegimes.isNotEmpty) {
          final sortedRegimes = List.from(allRegimes)..sort((a, b) => b.start.compareTo(a.start));
          final mostRecentRegime = sortedRegimes.first;
          String phase = mostRecentRegime.label.toString().split('.').last;
          phase = phase[0].toUpperCase() + phase.substring(1);
          print('PhaseChangeReadinessCard: No current ongoing regime, using most recent: $phase');
          return phase;
        } else {
          // No regimes found, throw to trigger fallback
          throw Exception('No phase regimes found');
        }
      }
    } catch (e) {
      print('PhaseChangeReadinessCard: Error in _getPhaseFromPhaseRegimeService: $e');
      rethrow;
    }
  }

  /// Rebuild RIVET state from all journal entries to ensure all entries are counted
  /// Returns both the state and event history for insights calculation
  Future<({RivetState state, List<RivetEvent> events})?> _rebuildRivetStateFromAllEntries(String userId) async {
    try {
      final journalRepository = JournalRepository();
      final allEntries = journalRepository.getAllJournalEntriesSync();

      if (allEntries.isEmpty) {
        // No entries = return initial state
        return (
          state: const RivetState(
            align: 0,
            trace: 0,
            sustainCount: 0,
            sawIndependentInWindow: false,
          ),
          events: <RivetEvent>[],
        );
      }

      // Create fresh RIVET service and process all entries
      final rivetService = RivetService();
      final events = <RivetEvent>[];
      RivetEvent? lastEvent;

      // Sort entries chronologically
      final sortedEntries = allEntries.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Get current phase - try PhaseRegimeService first, fallback to UserPhaseService
      // Use a timeout to prevent hanging, and ensure we always get a phase
      String currentPhase = 'Discovery';
      try {
        // Try to get phase with a timeout to prevent blocking
        currentPhase = await _getPhaseFromPhaseRegimeService()
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                print('PhaseChangeReadinessCard: PhaseRegimeService timeout, using UserPhaseService');
                return UserPhaseService.getCurrentPhase();
              },
            )
            .catchError((e) {
              print('PhaseChangeReadinessCard: Error in PhaseRegimeService: $e, using UserPhaseService');
              return UserPhaseService.getCurrentPhase();
            });
        print('PhaseChangeReadinessCard: Successfully got phase: $currentPhase');
      } catch (e, stackTrace) {
        print('PhaseChangeReadinessCard: Error getting phase: $e');
        print('Stack trace: $stackTrace');
        try {
          currentPhase = await UserPhaseService.getCurrentPhase();
          print('PhaseChangeReadinessCard: Using phase from UserPhaseService: $currentPhase');
        } catch (e2) {
          print('PhaseChangeReadinessCard: Error with UserPhaseService: $e2, defaulting to Discovery');
          currentPhase = 'Discovery';
        }
      }

      for (final entry in sortedEntries) {
        final recommendedPhase = PhaseRecommender.recommend(
          emotion: entry.emotion ?? '',
          reason: entry.emotionReason ?? '',
          text: entry.content,
          selectedKeywords: entry.keywords,
        );

        // Create RIVET event
        final rivetEvent = RivetEvent(
          eventId: const Uuid().v4(),
          date: entry.createdAt,
          source: EvidenceSource.text,
          keywords: entry.keywords.toSet(),
          predPhase: recommendedPhase,
          refPhase: currentPhase,
          tolerance: const {},
        );

        // Process through RIVET service
        rivetService.ingest(rivetEvent, lastEvent: lastEvent);
        events.add(rivetEvent);
        lastEvent = rivetEvent;
      }

      print('DEBUG: Rebuilt RIVET state from ${sortedEntries.length} entries - '
            'ALIGN: ${(rivetService.state.align * 100).toInt()}%, '
            'TRACE: ${(rivetService.state.trace * 100).toInt()}%, '
            'Sustain: ${rivetService.state.sustainCount}');

      return (state: rivetService.state, events: events);
    } catch (e) {
      print('ERROR: Failed to rebuild RIVET state: $e');
      return null;
    }
  }

  // Simplified transition insights calculation
  PhaseTransitionInsights? _calculateTransitionInsights({
    required String currentPhase,
    required List<RivetEvent> eventHistory,
    required RivetState updatedState,
  }) {
    if (eventHistory.length < 3) {
      return null;
    }

    final recentEvents = eventHistory.length > 10 
        ? eventHistory.sublist(eventHistory.length - 10) 
        : eventHistory;
    
    final phaseCounts = <String, int>{};
    for (final event in recentEvents) {
      phaseCounts[event.predPhase] = (phaseCounts[event.predPhase] ?? 0) + 1;
    }

    String? approachingPhase;
    double maxCount = 0;
    for (final entry in phaseCounts.entries) {
      if (entry.key != currentPhase && entry.value > maxCount) {
        maxCount = entry.value.toDouble();
        approachingPhase = entry.key;
      }
    }

    if (approachingPhase == null) return null;

    // Calculate shift percentage
    final midPoint = recentEvents.length ~/ 2;
    final earlyPhases = recentEvents.sublist(0, midPoint).map((e) => e.predPhase).toList();
    final recentPhases = recentEvents.sublist(midPoint).map((e) => e.predPhase).toList();
    
    final earlyApproachCount = earlyPhases.where((p) => p == approachingPhase).length;
    final recentApproachCount = recentPhases.where((p) => p == approachingPhase).length;
    
    final earlyPercent = earlyPhases.isEmpty ? 0.0 : (earlyApproachCount / earlyPhases.length) * 100;
    final recentPercent = recentPhases.isEmpty ? 0.0 : (recentApproachCount / recentPhases.length) * 100;
    
    final shiftPercentage = (recentPercent - earlyPercent).abs();
    final direction = recentPercent > earlyPercent 
        ? TransitionDirection.toward 
        : (recentPercent < earlyPercent ? TransitionDirection.away : TransitionDirection.stable);

    final measurableSigns = <String>[];
    if (shiftPercentage > 5.0) {
      // Use direction-aware message to match getPrimaryInsight()
      if (direction == TransitionDirection.toward) {
      measurableSigns.add('Your reflection patterns have shifted ${shiftPercentage.toStringAsFixed(0)}% toward $approachingPhase.');
      } else if (direction == TransitionDirection.away) {
        measurableSigns.add('Your reflection patterns have shifted ${shiftPercentage.toStringAsFixed(0)}% away from $approachingPhase.');
      } else {
        measurableSigns.add('Your reflection patterns are stable in $currentPhase.');
      }
    }
    if (updatedState.align > 0.7) {
      measurableSigns.add('Phase predictions align ${(updatedState.align * 100).toStringAsFixed(0)}% with your confirmed experiences.');
    }
    if (updatedState.trace > 0.6) {
      measurableSigns.add('Evidence accumulation is ${(updatedState.trace * 100).toStringAsFixed(0)}% complete for phase validation.');
    }

    return PhaseTransitionInsights(
      currentPhase: currentPhase,
      approachingPhase: approachingPhase,
      shiftPercentage: shiftPercentage,
      measurableSigns: measurableSigns,
      transitionConfidence: (updatedState.align * 0.4 + updatedState.trace * 0.3 + 0.3).clamp(0.0, 1.0),
      direction: direction,
      contributingMetrics: {
        'align_score': updatedState.align,
        'trace_score': updatedState.trace,
      },
    );
  }

  // Get ATLAS insights (simplified - would use actual health data)
  Map<String, dynamic>? _getAtlasInsights() {
    // In a real implementation, this would fetch health/activity data
    // For now, return a placeholder structure
    return {
      'current_phase': _rivetState != null ? 'Consolidation' : 'Discovery',
      'approaching_phase': null,
      'measurable_signs': <String>[],
    };
  }

  bool _isReadyForPhaseChange() {
    if (_rivetState == null) return false;
    return _rivetState!.sustainCount >= 2 &&
           _rivetState!.sawIndependentInWindow &&
           _rivetState!.align >= 0.6 &&
           _rivetState!.trace >= 0.6;
  }

  void _showRivetDetails() {
    if (_rivetState == null) return;
    
    showDialog(
      context: context,
      builder: (context) => RivetGateDetailsModal(
        rivetState: _rivetState!,
        transitionInsights: _rivetInsights,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Always ensure widget renders, even if there's an error
    try {
    if (_isLoading) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(32.0),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final isReady = _isReadyForPhaseChange();
    final qualifyingEntries = _rivetState?.sustainCount ?? 0;
    final hasIndependent = _rivetState?.sawIndependentInWindow ?? false;
    final alignPercent = ((_rivetState?.align ?? 0) * 100).toInt();
    final tracePercent = ((_rivetState?.trace ?? 0) * 100).toInt();

    final readinessCard = Card(
      elevation: 4,
      color: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.black87,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isReady ? Colors.green.shade100 : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (isReady ? Colors.green : Colors.blue).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isReady ? Icons.auto_awesome : Icons.trending_up,
                      color: isReady ? Colors.green.shade700 : Colors.blue.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phase Transition Readiness',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isReady
                              ? 'Ready for phase transition'
                              : 'Tracking transition patterns',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[300],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  // Refresh button
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blue.shade600,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.refresh,
                              color: Colors.blue.shade600,
                              size: 20,
                            ),
                      onPressed: _isLoading ? null : _loadAllData,
                      tooltip: 'Refresh readiness data',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.info_outline, color: Colors.blue.shade600),
                    onPressed: _showRivetDetails,
                    tooltip: 'View detailed RIVET analysis',
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Key Metrics Row (with explicit guidance on phase change distance)
              _buildMetricsRow(
                alignPercent,
                tracePercent,
                qualifyingEntries,
                hasIndependent,
                approachingPhase: _rivetInsights?.approachingPhase,
              ),
              
              const SizedBox(height: 20),

              // RIVET Phase Transition Insights or gap guidance
              if (_rivetInsights != null && _rivetInsights!.approachingPhase != null)
                _buildRivetInsightsSection(_rivetInsights!)
              else
                _buildPhaseGuidanceBanner(alignPercent, tracePercent, qualifyingEntries, hasIndependent),

              // ATLAS Phase Insights (if available)
              if (_atlasInsights != null && 
                  _atlasInsights!['approaching_phase'] != null &&
                  _atlasInsights!['measurable_signs'] is List &&
                  (_atlasInsights!['measurable_signs'] as List).isNotEmpty)
                ...[
                  if (_rivetInsights != null) const SizedBox(height: 20),
                  _buildAtlasInsightsSection(_atlasInsights!),
                ],

              const SizedBox(height: 24),

              // Progress Indicator
              _buildEnhancedProgressDisplay(isReady, qualifyingEntries, hasIndependent),

              const SizedBox(height: 24),

              // Requirements Section
              _buildEnhancedRequirementsSection(qualifyingEntries, hasIndependent, isReady),
            ],
          ),
        ),
      ),
    );

    final alignmentPhaseName = _rivetInsights?.currentPhase ??
        (_atlasInsights?['current_phase'] as String? ?? 'Discovery');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhaseAlignmentCard(
          phaseName: alignmentPhaseName,
          alignmentPercent: alignPercent.clamp(0, 100),
          tracePercent: tracePercent.clamp(0, 100),
          approachingPhase: _rivetInsights?.approachingPhase,
          shiftPercent: _rivetInsights?.shiftPercentage,
          independentEvidence: hasIndependent,
          sustainCount: qualifyingEntries,
        ),
        const SizedBox(height: 16),
        readinessCard,
      ],
    );
    } catch (e, stackTrace) {
      print('ERROR: PhaseChangeReadinessCard build error: $e');
      print('Stack trace: $stackTrace');
      // Return a minimal card so widget is always visible
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phase Transition Detection',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Error loading data. Please try refreshing.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loadAllData,
                child: const Text('Retry'),
              ),
            ],
        ),
      ),
    );
    }
  }

  Widget _buildMetricsRow(
    int align,
    int trace,
    int entries,
    bool hasIndependent, {
    String? approachingPhase,
  }) {
    return GridView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.8,
      ),
      children: [
        _buildMetricCard(
          title: 'Alignment strength',
          subtitle: approachingPhase != null
              ? 'Trending toward ${approachingPhase[0].toUpperCase()}${approachingPhase.substring(1)}'
              : 'Stability vs current phase',
          value: '$align%',
          percent: align,
          icon: Icons.verified,
          color: Colors.deepPurple,
        ),
        _buildMetricCard(
          title: 'Evidence quality',
          subtitle: 'Confidence from recent entries',
          value: '$trace%',
          percent: trace,
          icon: Icons.assessment,
          color: Colors.orange,
        ),
        _buildMetricCard(
          title: 'Qualifying entries',
          subtitle: entries >= 2 ? 'Requirement met' : '${(2 - entries).clamp(0, 2)} more needed',
          value: '$entries / 2',
          percent: (entries / 2 * 100).clamp(0, 100).toInt(),
          icon: Icons.menu_book,
          color: Colors.teal,
        ),
        _buildMetricCard(
          title: 'Independent signals',
          subtitle: hasIndependent ? 'Multiple days confirmed' : 'Log another session',
          value: hasIndependent ? 'Verified' : 'Pending',
          percent: hasIndependent ? 100 : 50,
          icon: Icons.timeline,
          color: hasIndependent ? Colors.green : Colors.blueGrey,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String subtitle,
    required String value,
    required int percent,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 100) / 100.0,
              minHeight: 6,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRivetInsightsSection(PhaseTransitionInsights insights) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade50,
            Colors.indigo.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insights,
                  color: Colors.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Phase Transition Detection',
                style: TextStyle(
                    fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: Colors.purple.shade600,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    insights.getPrimaryInsight(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (insights.measurableSigns.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...insights.measurableSigns.take(2).map((sign) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.purple.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      sign,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  String _getGuidanceBannerMessage(int align, int trace, int entries, bool hasIndependent, String? targetPhase) {
    // Calculate how close they are
    final alignClose = align >= 59 && align < 60;
    final traceClose = trace >= 59 && trace < 60;
    final veryClose = (alignClose || traceClose) && entries >= 1 && hasIndependent;
    
    if (veryClose) {
      // When very close (99% range), be specific
      if (alignClose && traceClose) {
        return 'You\'re at 99%! Just need a tiny bit more alignment and evidence quality.';
      } else if (alignClose) {
        return 'You\'re at 99%! Just need ${60 - align}% more alignment in your entries.';
      } else if (traceClose) {
        return 'You\'re at 99%! Just need ${60 - trace}% more evidence quality.';
      }
    }
    
    // Default message
    final phaseName = targetPhase != null && targetPhase.isNotEmpty
        ? targetPhase[0].toUpperCase() + targetPhase.substring(1)
        : 'next phase';
    return 'You\'re close to $phaseName. Remaining checklist:';
  }

  Widget _buildPhaseGuidanceBanner(
    int align,
    int trace,
    int entries,
    bool hasIndependent, {
    String? approachingPhase,
  }) {
    final entriesNeeded = (2 - entries).clamp(0, 2);
    final alignmentNeeded = (60 - align).clamp(0, 60);
    final traceNeeded = (60 - trace).clamp(0, 60);
    final needsIndependent = !hasIndependent;

    final remaining = <String>[];
    if (entriesNeeded > 0) {
      remaining.add('${entriesNeeded} more qualifying ${entriesNeeded == 1 ? 'entry' : 'entries'}');
    }
    if (needsIndependent) {
      remaining.add('Evidence from a different day');
    }
    if (alignmentNeeded > 0) {
      remaining.add('${alignmentNeeded}% alignment evidence');
    }
    if (traceNeeded > 0) {
      remaining.add('${traceNeeded}% supporting data');
    }

    final isReady = remaining.isEmpty;
    final targetPhase = approachingPhase != null && approachingPhase.isNotEmpty
        ? approachingPhase[0].toUpperCase() + approachingPhase.substring(1)
        : 'next phase';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isReady ? Icons.check_circle : Icons.hourglass_top,
                color: isReady ? Colors.greenAccent : Colors.orangeAccent,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isReady
                      ? 'All requirements met. Keep journaling to confirm $targetPhase.'
                      : _getGuidanceBannerMessage(align, trace, entries, hasIndependent, targetPhase),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (!isReady) ...[
            const SizedBox(height: 12),
            ...remaining.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Row(
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAtlasInsightsSection(Map<String, dynamic> insights) {
    final measurableSigns = insights['measurable_signs'] as List<dynamic>? ?? [];
    if (measurableSigns.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.shade50,
            Colors.orange.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.explore,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'ATLAS: Activity-Based Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...measurableSigns.take(2).map((sign) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sign.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildEnhancedProgressDisplay(bool isReady, int qualifyingEntries, bool hasIndependent) {
    // Calculate progress based on multiple factors, not just consecutive qualifying entries
    double progress = 0.0;
    if (isReady) {
      progress = 1.0;
    } else if (_rivetState != null) {
      // Progress is based on:
      // 1. ALIGN progress (40% weight) - how close to 0.6 threshold
      // 2. TRACE progress (40% weight) - how close to 0.6 threshold  
      // 3. Sustainment progress (20% weight) - consecutive qualifying entries / 2
      final alignProgress = (_rivetState!.align / 0.6).clamp(0.0, 1.0);
      final traceProgress = (_rivetState!.trace / 0.6).clamp(0.0, 1.0);
      final sustainProgress = (qualifyingEntries / 2.0).clamp(0.0, 1.0);
      
      progress = (alignProgress * 0.4 + traceProgress * 0.4 + sustainProgress * 0.2).clamp(0.0, 0.95);
      
      print('DEBUG: Readiness Progress - ALIGN: ${(_rivetState!.align * 100).toInt()}% (progress: ${(alignProgress * 100).toInt()}%), '
            'TRACE: ${(_rivetState!.trace * 100).toInt()}% (progress: ${(traceProgress * 100).toInt()}%), '
            'Sustain: $qualifyingEntries/2 (progress: ${(sustainProgress * 100).toInt()}%), '
            'Overall: ${(progress * 100).toInt()}%');
    } else {
      // Fallback: use qualifying entries if no RIVET state
      progress = (qualifyingEntries / 2.0).clamp(0.0, 0.95);
      print('DEBUG: Readiness Progress - No RIVET state, using sustain count: $qualifyingEntries/2 = ${(progress * 100).toInt()}%');
    }
    
    final color = isReady 
        ? Colors.green 
        : (progress >= 0.5 
            ? Colors.orange 
            : (progress >= 0.25 ? Colors.blue : Colors.grey));

    // Determine what phase they're ready to transition to (if ready)
    String? targetPhase;
    String readinessMessage;
    List<String> nextSteps = [];
    
    if (isReady) {
      // If ready, check if we have transition insights to show target phase
      if (_rivetInsights != null && 
          _rivetInsights!.approachingPhase != null && 
          _rivetInsights!.direction == TransitionDirection.toward) {
        targetPhase = _rivetInsights!.approachingPhase;
        readinessMessage = '✨ Ready to transition to $targetPhase phase!';
        nextSteps.add('Continue journaling to confirm the transition to $targetPhase.');
        nextSteps.add('Look for patterns that align with $targetPhase characteristics.');
      } else {
        readinessMessage = '✨ Ready to explore a new phase!';
        nextSteps.add('Continue journaling to identify which phase you\'re moving toward.');
        nextSteps.add('Review your recent entries for emerging patterns.');
      }
    } else {
      // Not ready - show what's needed with specific, user-friendly explanations
      final isVeryClose = progress >= 0.95; // 95% or higher
      
      if (isVeryClose) {
        // When very close (95%+), be more specific about what's missing
        readinessMessage = '🎯 You\'re almost there! Just one more thing needed:';
      } else if (qualifyingEntries >= 1) {
        readinessMessage = '📈 Almost there - keep journaling to validate phase transition!';
      } else {
        readinessMessage = '📝 Building your phase profile...';
      }
      
      // Build list of what's still needed with more specific, user-friendly language
      if (_rivetState != null) {
        // Check each requirement and explain what's missing in plain language
        final allRequirements = <String>[];
        
        if (qualifyingEntries < 2) {
          final needed = 2 - qualifyingEntries;
          if (isVeryClose) {
            allRequirements.add('Write $needed more journal ${needed == 1 ? 'entry' : 'entries'} that clearly shows you\'re moving toward a new phase.');
          } else {
            allRequirements.add('Write $needed more journal ${needed == 1 ? 'entry' : 'entries'} that reflect phase transition patterns.');
          }
        }
        
        if (!hasIndependent) {
          if (isVeryClose) {
            allRequirements.add('Create at least one entry on a different day - this shows the pattern is consistent, not just a one-time thing.');
          } else {
            allRequirements.add('Create entries on different days to show independent validation.');
          }
        }
        
        if (_rivetState!.align < 0.6) {
          final gap = ((0.6 - _rivetState!.align) * 100).toInt();
          final currentAlign = (_rivetState!.align * 100).toInt();
          if (isVeryClose && gap <= 1) {
            allRequirements.add('Your entries are ${currentAlign}% aligned with the new phase - just need ${gap}% more alignment. Try writing about themes that match the new phase more closely.');
          } else if (isVeryClose) {
            allRequirements.add('Your entries are ${currentAlign}% aligned - need ${gap}% more. Focus on writing about experiences that match the new phase\'s characteristics.');
          } else {
            allRequirements.add('Increase alignment by $gap% - ensure your entries match predicted phase patterns.');
          }
        }
        
        if (_rivetState!.trace < 0.6) {
          final gap = ((0.6 - _rivetState!.trace) * 100).toInt();
          final currentTrace = (_rivetState!.trace * 100).toInt();
          if (isVeryClose && gap <= 1) {
            allRequirements.add('Evidence quality is at ${currentTrace}% - just ${gap}% more needed. Keep journaling to build a stronger pattern.');
          } else if (isVeryClose) {
            allRequirements.add('Evidence quality is at ${currentTrace}% - need ${gap}% more. Continue journaling regularly to strengthen the pattern.');
          } else {
            allRequirements.add('Build evidence trace by $gap% - continue journaling to accumulate validation data.');
          }
        }
        
        // If very close and all requirements are met except one, be extra specific
        if (isVeryClose && allRequirements.length == 1) {
          nextSteps.add(allRequirements[0]);
          // Add a helpful tip
          if (qualifyingEntries >= 2 && hasIndependent && _rivetState!.align >= 0.59 && _rivetState!.trace >= 0.59) {
            nextSteps.add('You\'re literally one entry away! Write about how you\'re feeling or what\'s changing in your life right now.');
          }
        } else {
          nextSteps.addAll(allRequirements);
        }
      } else {
        nextSteps.add('Keep journaling regularly to build your phase profile.');
        nextSteps.add('Reflect on patterns and themes in your entries.');
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
              'Readiness Progress',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 8),
          Text(
          readinessMessage,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[300],
              fontStyle: FontStyle.italic,
            ),
          ),
        // Add clarification for 100% ready state
        if (isReady && targetPhase != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green.shade400),
                    const SizedBox(width: 6),
                    Text(
                      'All validation requirements met',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade300,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Your patterns suggest entering $targetPhase phase.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[300],
                  ),
                ),
                if (nextSteps.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...nextSteps.map((step) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        Expanded(
                          child: Text(
                            step,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[400],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ] else if (isReady) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green.shade400),
                    const SizedBox(width: 6),
                    Text(
                      'All validation requirements met',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade300,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Continue journaling to confirm phase transition.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[300],
                  ),
                ),
                if (nextSteps.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...nextSteps.map((step) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        Expanded(
                          child: Text(
                            step,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[400],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ] else if (nextSteps.isNotEmpty) ...[
          // Show what's needed if not ready - with more specific guidance when close
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: progress >= 0.95 
                  ? Colors.amber.withOpacity(0.15) 
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: progress >= 0.95 
                    ? Colors.amber.withOpacity(0.4) 
                    : Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      progress >= 0.95 ? Icons.near_me : Icons.info_outline, 
                      size: 16, 
                      color: progress >= 0.95 ? Colors.amber.shade400 : Colors.orange.shade400,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        progress >= 0.95 
                            ? 'Almost there! Here\'s what\'s left:'
                            : 'To move to a new phase:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: progress >= 0.95 
                              ? Colors.amber.shade300 
                              : Colors.orange.shade300,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...nextSteps.take(3).map((step) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        progress >= 0.95 ? '→ ' : '• ', 
                        style: TextStyle(
                          color: progress >= 0.95 
                              ? Colors.amber.shade300 
                              : Colors.grey[400], 
                          fontSize: 12,
                          fontWeight: progress >= 0.95 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          step,
                          style: TextStyle(
                            fontSize: progress >= 0.95 ? 12 : 11,
                            color: progress >= 0.95 
                                ? Colors.grey[200] 
                                : Colors.grey[300],
                            height: 1.4,
                            fontWeight: progress >= 0.95 ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                // Add encouraging note when very close
                if (progress >= 0.95) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.celebration, size: 14, color: Colors.amber.shade300),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'You\'re so close! Just a bit more journaling and you\'ll be ready.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade200,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEnhancedRequirementsSection(int qualifyingEntries, bool hasIndependent, bool isReady) {
    final int remainingEntries = (2 - qualifyingEntries).clamp(0, 2);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[700]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist, color: Colors.blue.shade600, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                'Validation Requirements',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRequirementRow(
            qualifyingEntries >= 2
                ? 'Qualifying journal entries complete'
                : 'Write ${2 - qualifyingEntries} more qualifying journal ${2 - qualifyingEntries == 1 ? 'entry' : 'entries'}',
            qualifyingEntries >= 2,
            '$qualifyingEntries/2',
            Icons.description,
            customStatus: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                children: [
                  TextSpan(
                    text: '$qualifyingEntries ',
                    style: TextStyle(
                      color: qualifyingEntries >= 2 ? Colors.green.shade300 : Colors.white,
                    ),
                  ),
                  const TextSpan(text: 'of '),
                  TextSpan(
                    text: '2',
                    style: TextStyle(
                      color: Colors.blue.shade300,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (remainingEntries > 0) ...[
                    const TextSpan(text: '  ('),
                    TextSpan(
                      text: '$remainingEntries remaining',
                      style: TextStyle(
                        color: Colors.orange.shade300,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(text: ')'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildRequirementRow(
            'Independent validation (different days)',
            hasIndependent,
            hasIndependent ? '✓ Verified' : 'Pending',
            Icons.calendar_today,
          ),
          const SizedBox(height: 12),
          _buildRequirementRow(
            'Alignment score ≥ 60%',
            (_rivetState?.align ?? 0) >= 0.6,
            '${((_rivetState?.align ?? 0) * 100).toInt()}%',
            Icons.verified,
          ),
          const SizedBox(height: 12),
          _buildRequirementRow(
            'Evidence trace ≥ 60%',
            (_rivetState?.trace ?? 0) >= 0.6,
            '${((_rivetState?.trace ?? 0) * 100).toInt()}%',
            Icons.analytics,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(
    String title,
    bool isComplete,
    String status,
    IconData icon, {
    Widget? customStatus,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isComplete ? Colors.green.withOpacity(0.2) : Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isComplete ? Colors.green.shade400 : Colors.grey[400],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: isComplete ? Colors.white : Colors.grey[300],
              fontWeight: isComplete ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isComplete ? Colors.green.withOpacity(0.2) : Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          child: customStatus ??
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isComplete ? Colors.green.shade400 : Colors.grey[300],
                ),
              ),
        ),
      ],
    );
  }
}

class _AlignedPhaseBadge extends StatelessWidget {
  final String phaseName;
  final int alignmentPercent;

  const _AlignedPhaseBadge({
    required this.phaseName,
    required this.alignmentPercent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_fix_high,
              color: Colors.blueAccent.shade100,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Most aligned phase',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey[400],
                        letterSpacing: 0.4,
                      ),
                ),
                Text(
                  phaseName,
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
              Text(
                '$alignmentPercent%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                'alignment',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey[400],
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhaseAlignmentCard extends StatelessWidget {
  final String phaseName;
  final int alignmentPercent;
  final int tracePercent;
  final String? approachingPhase;
  final double? shiftPercent;
  final bool independentEvidence;
  final int sustainCount;

  const _PhaseAlignmentCard({
    required this.phaseName,
    required this.alignmentPercent,
    required this.tracePercent,
    required this.approachingPhase,
    required this.shiftPercent,
    required this.independentEvidence,
    required this.sustainCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bubble_chart, color: Colors.blueAccent.shade200),
                const SizedBox(width: 8),
                Text(
                  'Phase Alignment Snapshot',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _AlignedPhaseBadge(
              phaseName: phaseName,
              alignmentPercent: alignmentPercent,
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                _AlignmentMetric(
                  icon: Icons.timeline,
                  color: independentEvidence ? Colors.teal : Colors.blueGrey,
                  label: 'Independent signals',
                  value: independentEvidence ? 'Verified' : 'Pending',
                  description: independentEvidence
                      ? 'Entries span multiple days'
                      : 'Log a reflection on a different day to confirm.',
                ),
                const SizedBox(height: 10),
                _AlignmentMetric(
                  icon: Icons.trending_up,
                  color: Colors.deepPurple,
                  label: 'Transition trend',
                  value: approachingPhase == null
                      ? 'Stable in $phaseName'
                      : (shiftPercent != null
                          ? 'Toward ${_titleCase(approachingPhase!)} (+${shiftPercent!.toStringAsFixed(0)}%)'
                          : 'Toward ${_titleCase(approachingPhase!)}'),
                  description: approachingPhase == null
                      ? 'Building consistency before recommending a move.'
                      : 'Signals increasingly resemble ${_titleCase(approachingPhase!)}.',
                ),
                const SizedBox(height: 10),
                _AlignmentMetric(
                  icon: Icons.assessment,
                  color: Colors.orange,
                  label: 'Evidence confidence',
                  value: '$tracePercent%',
                  description: 'Quality of supporting entries powering this call.',
                ),
                const SizedBox(height: 10),
                _AlignmentMetric(
                  icon: Icons.menu_book,
                  color: Colors.indigo,
                  label: 'Sustained entries',
                  value: '$sustainCount',
                  description: 'Distinct reflections bolstering this phase.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _titleCase(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}

class _AlignmentMetric extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String description;

  const _AlignmentMetric({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.7),
                        letterSpacing: 0.4,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
