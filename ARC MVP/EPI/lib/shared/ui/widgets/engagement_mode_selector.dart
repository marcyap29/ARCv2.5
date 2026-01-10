import 'package:flutter/material.dart';
import 'package:my_app/models/engagement_discipline.dart';

/// Widget for selecting engagement mode (Reflect, Explore, Integrate)
class EngagementModeSelector extends StatelessWidget {
  final EngagementMode selectedMode;
  final ValueChanged<EngagementMode> onModeChanged;
  final bool compact;

  const EngagementModeSelector({
    Key? key,
    required this.selectedMode,
    required this.onModeChanged,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactSelector(context);
    }
    return _buildFullSelector(context);
  }

  Widget _buildCompactSelector(BuildContext context) {
    return SegmentedButton<EngagementMode>(
      segments: [
        ButtonSegment(
          value: EngagementMode.reflect,
          label: Text('Reflect'),
          icon: Icon(Icons.auto_awesome, size: 16),
        ),
        ButtonSegment(
          value: EngagementMode.explore,
          label: Text('Explore'),
          icon: Icon(Icons.explore, size: 16),
        ),
        ButtonSegment(
          value: EngagementMode.integrate,
          label: Text('Integrate'),
          icon: Icon(Icons.integration_instructions, size: 16),
        ),
      ],
      selected: {selectedMode},
      onSelectionChanged: (Set<EngagementMode> newSelection) {
        onModeChanged(newSelection.first);
      },
    );
  }

  Widget _buildFullSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Engagement Mode',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<EngagementMode>(
          segments: [
            ButtonSegment(
              value: EngagementMode.reflect,
              label: Text('Reflect'),
              icon: Icon(Icons.auto_awesome),
            ),
            ButtonSegment(
              value: EngagementMode.explore,
              label: Text('Explore'),
              icon: Icon(Icons.explore),
            ),
            ButtonSegment(
              value: EngagementMode.integrate,
              label: Text('Integrate'),
              icon: Icon(Icons.integration_instructions),
            ),
          ],
          selected: {selectedMode},
          onSelectionChanged: (Set<EngagementMode> newSelection) {
            onModeChanged(newSelection.first);
          },
        ),
        const SizedBox(height: 8),
        Text(
          _getModeDescription(selectedMode),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _getModeDescription(EngagementMode mode) {
    switch (mode) {
      case EngagementMode.reflect:
        return 'Quick insights, no questions';
      case EngagementMode.explore:
        return 'Patterns + 1 connecting question';
      case EngagementMode.integrate:
        return 'Full synthesis across domains';
    }
  }
}

/// Mode indicator badge for LUMARA responses
class EngagementModeBadge extends StatelessWidget {
  final EngagementMode mode;

  const EngagementModeBadge({Key? key, required this.mode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getModeColor(mode).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getModeColor(mode).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getModeIcon(mode), size: 12, color: _getModeColor(mode)),
          const SizedBox(width: 4),
          Text(
            mode.displayName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _getModeColor(mode),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getModeIcon(EngagementMode mode) {
    switch (mode) {
      case EngagementMode.reflect:
        return Icons.auto_awesome;
      case EngagementMode.explore:
        return Icons.explore;
      case EngagementMode.integrate:
        return Icons.integration_instructions;
    }
  }

  Color _getModeColor(EngagementMode mode) {
    switch (mode) {
      case EngagementMode.reflect:
        return Colors.blue;
      case EngagementMode.explore:
        return Colors.orange;
      case EngagementMode.integrate:
        return Colors.purple;
    }
  }
}

