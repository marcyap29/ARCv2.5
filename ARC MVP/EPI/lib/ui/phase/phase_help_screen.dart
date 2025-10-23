// lib/ui/phase/phase_help_screen.dart
// Comprehensive help screen for phase analysis concepts

import 'package:flutter/material.dart';
import '../../models/phase_models.dart';

class PhaseHelpScreen extends StatefulWidget {
  const PhaseHelpScreen({super.key});

  @override
  State<PhaseHelpScreen> createState() => _PhaseHelpScreenState();
}

class _PhaseHelpScreenState extends State<PhaseHelpScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phase Analysis Help'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Getting Started'),
            Tab(text: 'Phase Types'),
            Tab(text: 'RIVET Sweep'),
            Tab(text: 'Timeline View'),
            Tab(text: 'RIVET System'),
            Tab(text: 'SENTINEL System'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGettingStarted(theme),
          _buildPhaseTypes(theme),
          _buildRivetSweep(theme),
          _buildTimelineView(theme),
          _buildRivetSystem(theme),
          _buildSentinelSystem(theme),
        ],
      ),
    );
  }

  Widget _buildGettingStarted(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            theme,
            'Welcome to Phase Analysis',
            'Phase analysis helps you understand the natural rhythms and patterns in your personal growth journey. By identifying distinct phases in your life, you can make more informed decisions and better understand your development.',
            Icons.waving_hand,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'How to Use This Feature',
            'Start by running a RIVET Sweep to automatically detect phases in your journal entries. Then explore the timeline view to see your phase journey visually.',
            Icons.play_circle_outline,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'Key Concepts',
            '• Phases are timeline segments, not individual entry labels\n'
            '• Each phase has a start and end time\n'
            '• Phases are detected automatically using pattern recognition\n'
            '• You can manually adjust phases if needed',
            Icons.lightbulb_outline,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'Getting the Most Out of Phases',
            '• Write regularly to improve phase detection accuracy\n'
            '• Review detected phases and make adjustments\n'
            '• Use phase insights to plan your activities\n'
            '• Track how different phases affect your mood and productivity',
            Icons.trending_up,
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseTypes(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            theme,
            'The Six Core Phases',
            'Our system identifies six fundamental phases that most people experience in their personal development journey.',
            Icons.auto_graph,
          ),
          const SizedBox(height: 16),
          ...PhaseLabel.values.map((phase) => _buildPhaseCard(phase)),
        ],
      ),
    );
  }

  Widget _buildPhaseCard(PhaseLabel phase) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _getPhaseColor(phase),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  phase.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getPhaseDescription(phase),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              _getPhaseCharacteristics(phase),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRivetSweep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            theme,
            'What is RIVET Sweep?',
            'RIVET Sweep is our automated phase detection algorithm that analyzes your journal entries to identify natural phase transitions in your personal development journey.',
            Icons.auto_awesome,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'How RIVET Sweep Works',
            'The algorithm uses advanced pattern recognition to detect changes in your writing patterns, emotional tone, and topic focus. It identifies "change points" where your phase likely shifted.',
            Icons.psychology,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'What It Analyzes',
            '• Writing patterns and style changes\n'
            '• Emotional tone and sentiment shifts\n'
            '• Topic focus and theme changes\n'
            '• Frequency and consistency of entries\n'
            '• Temporal patterns and cycles',
            Icons.analytics,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'Confidence Scores',
            'Each detected phase comes with a confidence score (0-100%). Higher scores indicate more reliable phase detection. You can review and adjust phases with lower confidence scores.',
            Icons.speed,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'Best Practices',
            '• Run RIVET Sweep regularly as you add more entries\n'
            '• Review detected phases and make manual adjustments\n'
            '• Focus on phases with lower confidence scores\n'
            '• Consider your external life events when reviewing phases',
            Icons.tips_and_updates,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            theme,
            'Timeline Visualization',
            'The timeline view shows your phase journey as a colorful, interactive timeline. Each phase is represented by a colored band with its duration and characteristics.',
            Icons.timeline,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'Timeline Features',
            '• Zoom in/out to see different time periods\n'
            '• Tap on phases to see detailed information\n'
            '• Drag to navigate through time\n'
            '• See phase transitions and overlaps\n'
            '• View anchored journal entries for each phase',
            Icons.visibility,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'Phase Colors',
            'Each phase type has its own color for easy identification:\n'
            '• Discovery: Blue\n'
            '• Expansion: Green\n'
            '• Transition: Orange\n'
            '• Consolidation: Purple\n'
            '• Recovery: Red\n'
            '• Breakthrough: Yellow',
            Icons.palette,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'Interactive Controls',
            '• Use pinch gestures to zoom in/out\n'
            '• Swipe left/right to navigate time\n'
            '• Tap and hold on phases for options\n'
            '• Use the zoom controls for precise navigation',
            Icons.touch_app,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'Phase Actions',
            '• View phase details and statistics\n'
            '• Edit phase boundaries and labels\n'
            '• Split or merge phases\n'
            '• Delete phases you don\'t agree with\n'
            '• Export phase data for analysis',
            Icons.settings,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    ThemeData theme,
    String title,
    String content,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Color _getPhaseColor(PhaseLabel phase) {
    switch (phase) {
      case PhaseLabel.discovery:
        return Colors.blue;
      case PhaseLabel.expansion:
        return Colors.green;
      case PhaseLabel.transition:
        return Colors.orange;
      case PhaseLabel.consolidation:
        return Colors.purple;
      case PhaseLabel.recovery:
        return Colors.red;
      case PhaseLabel.breakthrough:
        return Colors.yellow[700]!;
    }
  }

  String _getPhaseDescription(PhaseLabel phase) {
    switch (phase) {
      case PhaseLabel.discovery:
        return 'A period of exploration, learning, and asking questions about yourself and your goals.';
      case PhaseLabel.expansion:
        return 'A time of growth, building momentum, and taking action on your discoveries.';
      case PhaseLabel.transition:
        return 'A phase of change, decision-making, and adapting to new circumstances.';
      case PhaseLabel.consolidation:
        return 'A period of refining, organizing, and strengthening your foundations.';
      case PhaseLabel.recovery:
        return 'A time of rest, healing, and regaining energy after intense periods.';
      case PhaseLabel.breakthrough:
        return 'A phase of clarity, major insights, and significant forward movement.';
    }
  }

  String _getPhaseCharacteristics(PhaseLabel phase) {
    switch (phase) {
      case PhaseLabel.discovery:
        return 'Characteristics: Curiosity, questioning, research, exploration, uncertainty';
      case PhaseLabel.expansion:
        return 'Characteristics: Growth, action, momentum, confidence, building';
      case PhaseLabel.transition:
        return 'Characteristics: Change, adaptation, decision-making, uncertainty, flexibility';
      case PhaseLabel.consolidation:
        return 'Characteristics: Organization, refinement, stability, structure, mastery';
      case PhaseLabel.recovery:
        return 'Characteristics: Rest, healing, reflection, self-care, regrouping';
      case PhaseLabel.breakthrough:
        return 'Characteristics: Clarity, insight, momentum, achievement, transformation';
    }
  }

  Widget _buildRivetSystem(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            theme,
            'What is RIVET?',
            'RIVET stands for Risk–Validation Evidence Tracker. It\'s an automated system that determines when it is defensible to shift from one developmental phase to the next based on sustained evidence of model or behavioral coherence.',
            Icons.auto_awesome,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'How RIVET Works',
            'RIVET uses dual-signal, sustainment-gated logic to analyze your journal entries. It looks for patterns in your writing style, emotional tone, and topic focus to identify when you\'re ready to transition between phases.',
            Icons.psychology,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'The Two Signals',
            'RIVET uses two independent signals that both must be present for a phase transition:\n'
            '• Base Alignment Score: Measures how well your entries align with your current phase\n'
            '• Evidence Accumulation: Tracks sustained patterns over time\n'
            'Both signals must exceed thresholds through a sustainment window.',
            Icons.analytics,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'Confidence Scoring',
            'Each RIVET detection comes with a confidence score (0-100%). Higher scores indicate more reliable phase detection. You can review and adjust phases with lower confidence scores.',
            Icons.speed,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'When to Trust RIVET',
            '• High confidence scores (80%+) are usually reliable\n'
            '• Review medium confidence (50-80%) suggestions carefully\n'
            '• Low confidence (<50%) suggestions may need manual review\n'
            '• Consider your external life events when reviewing suggestions',
            Icons.verified,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'RIVET vs Manual Phases',
            'RIVET provides suggestions, but you always have the final say. You can:\n'
            '• Accept RIVET\'s suggestions automatically\n'
            '• Review and modify suggestions before applying\n'
            '• Override RIVET with your own phase assignments\n'
            '• Use a combination of both approaches',
            Icons.settings,
          ),
        ],
      ),
    );
  }

  Widget _buildSentinelSystem(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            theme,
            'What is SENTINEL?',
            'SENTINEL stands for Severity Evaluation and Negative Trend Identification for Emotional Longitudinal tracking. It\'s the conceptual inverse of RIVET, designed to detect when distress patterns warrant intervention rather than phase reduction.',
            Icons.shield,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'The Reverse RIVET Concept',
            'While RIVET decides when to reduce testing (gate DOWN), SENTINEL decides when to escalate concern (gate UP). It uses the same dual-signal, sustainment-gated logic but for detecting risk rather than validation.',
            Icons.compare_arrows,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'Pattern Types Detected',
            'SENTINEL monitors for several concerning patterns:\n'
            '• Clustering: Similar emotional patterns occurring in clusters\n'
            '• Persistent Distress: Sustained negative emotional states\n'
            '• Escalating: Increasing intensity of negative patterns\n'
            '• Isolation: Signs of social withdrawal\n'
            '• Hopelessness: Indicators of hopelessness or lack of future orientation',
            Icons.psychology,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'Risk Levels',
            'SENTINEL provides five risk levels:\n'
            '• Minimal (0-20%): Patterns appear stable and healthy\n'
            '• Low (20-40%): Minor fluctuations detected\n'
            '• Moderate (40-60%): Some concerning patterns detected\n'
            '• High (60-80%): Significant concerning patterns\n'
            '• Critical (80-100%): Critical patterns requiring attention',
            Icons.warning,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'When to Take Action',
            '• Moderate risk: Review recommendations and consider self-care\n'
            '• High risk: Take recommendations seriously and consider support\n'
            '• Critical risk: Consider seeking professional help\n'
            '• Always trust your instincts over the system',
            Icons.lightbulb,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme,
            'Privacy and Data Handling',
            'SENTINEL analysis happens entirely on your device. Your journal entries are never sent to external servers. The analysis uses the same privacy-first approach as the rest of EPI.',
            Icons.privacy_tip,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Important Medical Disclaimer',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'SENTINEL analysis is not medical advice and should not replace professional mental health care. If you are experiencing significant distress or have concerns about your mental health, please consult with a qualified healthcare professional.',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 14,
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
