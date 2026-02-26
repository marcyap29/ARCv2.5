import 'package:flutter/material.dart';
import 'package:my_app/models/engagement_discipline.dart';

/// Widget for selecting engagement mode (Default, Deeper)
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
          label: Text('Default'),
          icon: Icon(Icons.auto_awesome, size: 16),
        ),
        ButtonSegment(
          value: EngagementMode.deeper,
          label: Text('Deeper'),
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
              label: Text('Default'),
              icon: Icon(Icons.auto_awesome),
            ),
            ButtonSegment(
              value: EngagementMode.deeper,
              label: Text('Deeper'),
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
        return 'Quick insights, up to one reference';
      case EngagementMode.deeper:
      case EngagementMode.explore:
      case EngagementMode.integrate:
        return 'Patterns, connections, and synthesis across your history';
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
      case EngagementMode.deeper:
      case EngagementMode.explore:
      case EngagementMode.integrate:
        return Icons.integration_instructions;
    }
  }

  Color _getModeColor(EngagementMode mode) {
    switch (mode) {
      case EngagementMode.reflect:
        return Colors.blue;
      case EngagementMode.deeper:
      case EngagementMode.explore:
      case EngagementMode.integrate:
        return Colors.purple;
    }
  }
}

