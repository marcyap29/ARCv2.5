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
    _tabController = TabController(length: 4, vsync: this);
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
}
