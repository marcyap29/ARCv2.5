// lib/ui/phase/phase_change_readiness_card.dart
// Phase Change Readiness Card - Shows when user is ready to transition to a new phase

import 'package:flutter/material.dart';
import '../../rivet/models/rivet_models.dart';
import '../../rivet/validation/rivet_provider.dart';

class PhaseChangeReadinessCard extends StatefulWidget {
  const PhaseChangeReadinessCard({super.key});

  @override
  State<PhaseChangeReadinessCard> createState() => _PhaseChangeReadinessCardState();
}

class _PhaseChangeReadinessCardState extends State<PhaseChangeReadinessCard> {
  RivetState? _rivetState;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRivetState();
  }

  Future<void> _loadRivetState() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final rivetProvider = RivetProvider();
      const userId = 'default_user';

      if (!rivetProvider.isAvailable) {
        await rivetProvider.initialize(userId);
      }

      final state = await rivetProvider.safeGetState(userId);

      if (state != null && rivetProvider.service != null) {
        rivetProvider.service!.updateState(state);

        setState(() {
          _rivetState = state;
          _isLoading = false;
        });
      } else {
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

  // Calculate how many qualifying entries the user has
  int _getQualifyingEntriesCount() {
    if (_rivetState == null) return 0;
    return _rivetState!.sustainCount;
  }

  // Check if user has independent evidence
  bool _hasIndependentEvidence() {
    if (_rivetState == null) return false;
    return _rivetState!.sawIndependentInWindow;
  }

  // Check if user is ready for phase change
  bool _isReadyForPhaseChange() {
    if (_rivetState == null) return false;
    return _rivetState!.sustainCount >= 2 &&
           _rivetState!.sawIndependentInWindow &&
           _rivetState!.align >= 0.6 &&
           _rivetState!.trace >= 0.6;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final qualifyingEntries = _getQualifyingEntriesCount();
    final hasIndependent = _hasIndependentEvidence();
    final isReady = _isReadyForPhaseChange();
    final entriesNeeded = (2 - qualifyingEntries).clamp(0, 2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isReady ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isReady ? Icons.check_circle : Icons.auto_graph,
                    color: isReady ? Colors.green : Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phase Change Readiness',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isReady
                            ? 'You\'re ready to explore a new phase!'
                            : 'Track your progress toward detecting a new phase',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadRivetState,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Main Progress Display
            _buildProgressDisplay(qualifyingEntries, hasIndependent, isReady),

            const SizedBox(height: 24),

            // Requirements Checklist
            _buildRequirementsChecklist(qualifyingEntries, hasIndependent),

            const SizedBox(height: 20),

            // Help Text
            _buildHelpText(entriesNeeded, hasIndependent, isReady),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressDisplay(int qualifyingEntries, bool hasIndependent, bool isReady) {
    final progress = isReady ? 1.0 : (qualifyingEntries / 2.0).clamp(0.0, 0.9);
    final color = isReady ? Colors.green : (qualifyingEntries >= 1 ? Colors.orange : Colors.blue);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 12,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isReady ? Icons.check_circle : Icons.auto_graph,
                size: 40,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                isReady
                    ? 'Ready!'
                    : qualifyingEntries >= 1
                        ? 'Almost There'
                        : 'Getting Started',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (!isReady)
                Text(
                  '${qualifyingEntries}/2 entries',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsChecklist(int qualifyingEntries, bool hasIndependent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Requirements',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          _buildRequirementItem(
            'Write 2 journal entries showing new patterns',
            qualifyingEntries >= 2,
            '$qualifyingEntries/2 entries',
          ),
          const SizedBox(height: 8),
          _buildRequirementItem(
            'Journal on different days',
            hasIndependent,
            hasIndependent ? 'Completed' : 'Pending',
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String title, bool isComplete, String status) {
    return Row(
      children: [
        Icon(
          isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isComplete ? Colors.green : Colors.grey[400],
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: isComplete ? Colors.black87 : Colors.grey[600],
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  color: isComplete ? Colors.green : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpText(int entriesNeeded, bool hasIndependent, bool isReady) {
    String helpText;
    Color bgColor;
    Color textColor;
    IconData icon;

    if (isReady) {
      helpText = 'Great! Your journal entries show consistent patterns suggesting you might be ready for a new phase. Run Phase Analysis to detect phase transitions automatically.';
      bgColor = Colors.green.withOpacity(0.1);
      textColor = Colors.green[800]!;
      icon = Icons.celebration;
    } else if (entriesNeeded == 0 && !hasIndependent) {
      helpText = 'You have enough entries, but they\'re all from the same day. Try journaling on a different day to confirm the pattern is consistent over time.';
      bgColor = Colors.orange.withOpacity(0.1);
      textColor = Colors.orange[800]!;
      icon = Icons.schedule;
    } else if (entriesNeeded == 1) {
      helpText = 'You\'re almost there! Write one more journal entry showing similar patterns to unlock phase change detection.';
      bgColor = Colors.blue.withOpacity(0.1);
      textColor = Colors.blue[800]!;
      icon = Icons.trending_up;
    } else {
      helpText = 'Write journal entries that describe your current experiences, thoughts, and feelings. Once you have enough entries showing new patterns, we\'ll help detect if you\'re transitioning to a new phase.';
      bgColor = Colors.blue.withOpacity(0.1);
      textColor = Colors.blue[800]!;
      icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              helpText,
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
