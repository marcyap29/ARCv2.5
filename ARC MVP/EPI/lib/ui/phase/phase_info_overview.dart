// lib/ui/phase/phase_info_overview.dart
// Informational overview explaining what phases are and how they work

import 'package:flutter/material.dart';
import '../../models/phase_models.dart';

class PhaseInfoOverview extends StatelessWidget {
  const PhaseInfoOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme),
          const SizedBox(height: 24),
          _buildWhatArePhases(theme),
          const SizedBox(height: 24),
          _buildPhaseTypes(theme),
          const SizedBox(height: 24),
          _buildRivetSystem(theme),
          const SizedBox(height: 24),
          _buildSentinelSystem(theme),
          const SizedBox(height: 24),
          _buildPhaseQuizSection(theme),
          const SizedBox(height: 24),
          _buildHowItWorks(theme),
          const SizedBox(height: 24),
          _buildBenefits(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(
              Icons.auto_graph,
              size: 64,
              color: theme.primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Understanding Life Phases',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Discover the natural rhythms and patterns in your personal growth journey',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatArePhases(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: theme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  'What Are Life Phases?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Life phases are distinct periods in your personal development journey, each characterized by unique patterns of growth, challenges, and opportunities. Just as nature has seasons, your personal growth follows natural cycles.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Our system identifies six core phases that most people experience:',
            ),
            const SizedBox(height: 16),
            _buildPhaseList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseList() {
    return Column(
      children: PhaseLabel.values.map((phase) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getPhaseColor(phase),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phase.name.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _getPhaseDescription(phase),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPhaseTypes(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: theme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Timeline-Based Phases',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Unlike traditional phase systems that assign phases to individual entries, our timeline-based approach creates continuous phase regimes that span across time periods.',
            ),
            const SizedBox(height: 12),
            _buildFeatureList([
              'Phases are timeline segments, not entry labels',
              'Each phase regime has start and end times',
              'Entries are anchored to their corresponding phase',
              'Automatic phase detection using RIVET Sweep',
              'Visual timeline shows phase transitions',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildRivetSystem(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.blue),
                const SizedBox(width: 12),
                Text(
                  'RIVET System',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RIVET: Risk–Validation Evidence Tracker',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'RIVET determines when it is defensible to shift from one developmental phase to the next based on sustained evidence of model or behavioral coherence.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'How RIVET Works:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            _buildFeatureList([
              'Uses dual-signal, sustainment-gated logic',
              'Analyzes writing patterns and emotional coherence',
              'Detects when phase transitions are justified',
              'Provides confidence scores for each detection',
              'Automatically creates timeline-based phase regimes',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSentinelSystem(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield, color: Colors.red),
                const SizedBox(width: 12),
                Text(
                  'SENTINEL System',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SENTINEL: Severity Evaluation and Negative Trend Identification for Emotional Longitudinal tracking',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'SENTINEL is the conceptual inverse of RIVET, applied to emotional and behavioral domains within EPI. It uses the same dual-signal, sustainment-gated logic to detect when distress patterns warrant intervention rather than reduction.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'How SENTINEL Works:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            _buildFeatureList([
              'Detects concerning emotional patterns and trends',
              'Identifies clustering, persistence, and escalation patterns',
              'Monitors for isolation and hopelessness indicators',
              'Provides risk levels and actionable recommendations',
              'Uses same dual-signal logic as RIVET but for escalation',
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.amber[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SENTINEL analysis is not medical advice. If you have concerns about your mental health, please consult a qualified healthcare professional.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber[800],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorks(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: theme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  'How It Works',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStepCard(
              '1',
              'Data Collection',
              'Your journal entries, emotions, and patterns are analyzed to understand your current state.',
              Icons.collections_bookmark,
            ),
            const SizedBox(height: 12),
            _buildStepCard(
              '2',
              'Pattern Recognition',
              'RIVET Sweep algorithm detects changes in your writing patterns, emotions, and topics.',
              Icons.auto_awesome,
            ),
            const SizedBox(height: 12),
            _buildStepCard(
              '3',
              'Phase Detection',
              'The system identifies phase transitions and creates timeline segments for each phase.',
              Icons.timeline,
            ),
            const SizedBox(height: 12),
            _buildStepCard(
              '4',
              'Visual Timeline',
              'See your phase journey as a colorful timeline with easy-to-understand visualizations.',
              Icons.visibility,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(String number, String title, String description, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefits(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: theme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Benefits of Phase Analysis',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFeatureList([
              'Understand your natural growth patterns',
              'Identify when you\'re in transition periods',
              'Recognize recurring themes and cycles',
              'Make more informed decisions about timing',
              'Track progress across different life areas',
              'Gain insights into your personal development',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureList(List<String> features) {
    return Column(
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  feature,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
        return 'Exploring new ideas, learning, and asking questions';
      case PhaseLabel.expansion:
        return 'Growing, building momentum, and taking action';
      case PhaseLabel.transition:
        return 'Navigating change, making decisions, and adapting';
      case PhaseLabel.consolidation:
        return 'Refining, organizing, and strengthening foundations';
      case PhaseLabel.recovery:
        return 'Resting, healing, and regaining energy';
      case PhaseLabel.breakthrough:
        return 'Achieving clarity, making breakthroughs, and moving forward';
    }
  }

  Widget _buildPhaseQuizSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.quiz, color: Colors.purple),
                const SizedBox(width: 12),
                Text(
                  'Phase Self-Assessment',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Phase Assessment',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Take a quick self-assessment to help identify your current developmental phase. This provides an initial baseline while you build journaling data.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'How Phase Detection Works:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            _buildFeatureList([
              'Self-assessment quiz (this tab) - Quick initial phase identification',
              'Natural journaling patterns (RIVET analysis) - Most accurate over time',
              'Imported MCP bundle analysis - Historical data analysis',
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.amber[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The most accurate phase detection comes from analyzing your actual journaling patterns over time. The quiz is a helpful starting point!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber[800],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
