// lib/ui/phase/phase_change_readiness_card.dart
// Phase Change Readiness Card - Enhanced with RIVET & ATLAS Phase-Approaching Insights

import 'package:flutter/material.dart';
import 'package:my_app/atlas/rivet/rivet_models.dart';
import 'package:my_app/atlas/rivet/rivet_provider.dart';
import 'package:my_app/atlas/phase_detection/rivet_gate_details_modal.dart';

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
    setState(() {
      _isLoading = true;
    });

    try {
      final rivetProvider = RivetProvider();
      const userId = 'default_user';

      if (!rivetProvider.isAvailable) {
        await rivetProvider.initialize(userId);
      }

      // Get RIVET state
      final state = await rivetProvider.safeGetState(userId);
      
      if (state != null && rivetProvider.service != null) {
        rivetProvider.service!.updateState(state);
        
        // Calculate transition insights from event history
        final service = rivetProvider.service!;
        final eventHistory = service.eventHistory;
        
        PhaseTransitionInsights? insights;
        if (eventHistory.isNotEmpty) {
          // Get the last event's phase
          final lastEvent = eventHistory.last;
          // Calculate insights using the service's internal method
          // Since it's private, we'll create a simplified version
          insights = _calculateTransitionInsights(
            currentPhase: lastEvent.refPhase,
            eventHistory: eventHistory,
            updatedState: state,
          );
        }
        
        setState(() {
          _rivetState = state;
          _rivetInsights = insights;
        });
      } else {
        setState(() {
          _rivetState = const RivetState(
            align: 0,
            trace: 0,
            sustainCount: 0,
            sawIndependentInWindow: false,
          );
        });
      }

      // Get ATLAS insights (simplified - would need health data in real implementation)
      final atlasInsights = _getAtlasInsights();
      setState(() {
        _atlasInsights = atlasInsights;
        _isLoading = false;
      });
    } catch (e) {
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
      measurableSigns.add('Your reflection patterns have shifted ${shiftPercentage.toStringAsFixed(0)}% toward $approachingPhase.');
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

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isReady
                ? [Colors.green.shade50, Colors.teal.shade50]
                : [Colors.blue.shade50, Colors.indigo.shade50],
          ),
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
                            color: Colors.grey[800],
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isReady
                              ? 'Ready for phase transition'
                              : 'Tracking transition patterns',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.info_outline, color: Colors.blue.shade600),
                    onPressed: _showRivetDetails,
                    tooltip: 'View detailed RIVET analysis',
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Key Metrics Row
              _buildMetricsRow(alignPercent, tracePercent, qualifyingEntries, hasIndependent),
              
              const SizedBox(height: 28),

              // RIVET Phase Transition Insights
              if (_rivetInsights != null && _rivetInsights!.approachingPhase != null)
                _buildRivetInsightsSection(_rivetInsights!),

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
              _buildEnhancedProgressDisplay(isReady, qualifyingEntries),

              const SizedBox(height: 24),

              // Requirements Section
              _buildEnhancedRequirementsSection(qualifyingEntries, hasIndependent, isReady),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsRow(int align, int trace, int entries, bool hasIndependent) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Alignment',
            '$align%',
            align,
            Icons.verified,
            Colors.purple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Evidence',
            '$trace%',
            trace,
            Icons.assessment,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Entries',
            '$entries/2',
            (entries / 2 * 100).toInt(),
            Icons.book,
            Colors.teal,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, int percent, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100.0,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
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

  Widget _buildEnhancedProgressDisplay(bool isReady, int qualifyingEntries) {
    final progress = isReady ? 1.0 : (qualifyingEntries / 2.0).clamp(0.0, 0.95);
    final color = isReady ? Colors.green : (qualifyingEntries >= 1 ? Colors.orange : Colors.blue);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Readiness Progress',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
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
          isReady
              ? '✨ Ready to explore a new phase!'
              : qualifyingEntries >= 1
                  ? '📈 Almost there - keep journaling!'
                  : '📝 Building your phase profile...',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedRequirementsSection(int qualifyingEntries, bool hasIndependent, bool isReady) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
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
              Text(
                'Validation Requirements',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRequirementRow(
            '2 qualifying journal entries',
            qualifyingEntries >= 2,
            '$qualifyingEntries/2',
            Icons.description,
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

  Widget _buildRequirementRow(String title, bool isComplete, String status, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isComplete ? Colors.green.shade50 : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isComplete ? Colors.green.shade700 : Colors.grey[400],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: isComplete ? Colors.grey[800] : Colors.grey[600],
              fontWeight: isComplete ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isComplete ? Colors.green.shade50 : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isComplete ? Colors.green.shade700 : Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }
}
