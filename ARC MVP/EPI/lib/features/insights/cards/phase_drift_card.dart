import 'package:flutter/material.dart';
import '../../../core/mira/mira_feature_flags.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/text_style.dart';

/// Card showing phase trajectory over time
class PhaseDriftCard extends StatelessWidget {
  const PhaseDriftCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!MiraFeatureFlags.enableInsightsCards) {
      return const SizedBox.shrink();
    }

    // For now, return a placeholder card
    return _buildEmptyCard(context);
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kcSurfaceAltColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kcSecondaryTextColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: kcPrimaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Phase Trajectory',
                style: heading3Style(context).copyWith(color: kcPrimaryColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Center(
            child: CircularProgressIndicator(
              color: kcPrimaryColor,
              strokeWidth: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kcSurfaceAltColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kcSecondaryTextColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: kcPrimaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Phase Trajectory',
                style: heading3Style(context).copyWith(color: kcPrimaryColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.timeline_outlined,
                  size: 32,
                  color: kcSecondaryTextColor,
                ),
                const SizedBox(height: 8),
                Text(
                  'No phase data yet',
                  style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Phase patterns will emerge as you journal',
                  style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseDriftCard(BuildContext context, List<dynamic> trajectory) {
    // Simplified placeholder to avoid type issues
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kcSurfaceAltColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kcSecondaryTextColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: kcPrimaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                "Phase Drift",
                style: heading1Style(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Total entries: ${trajectory.length}",
            style: bodyStyle(context),
          ),
          const SizedBox(height: 16),
          Text(
            "Phase drift visualization coming soon...",
            style: captionStyle(context),
          ),
        ],
      ),
    );
  }
  Widget _buildSummary(BuildContext context, int totalEntries, String dominantPhase, Map<String, int> phaseCounts) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: bodyStyle(context).copyWith(
              color: kcPrimaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  context,
                  'Total Entries',
                  totalEntries.toString(),
                  Icons.article,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  context,
                  'Dominant Phase',
                  _capitalizePhase(dominantPhase),
                  Icons.flag,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kcSecondaryTextColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
              ),
              Text(
                value,
                style: bodyStyle(context).copyWith(
                  color: kcPrimaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(BuildContext context, List<dynamic> trajectory) {
    // Take last 7 points for display
    final displayPoints = trajectory.length > 7 
        ? trajectory.sublist(trajectory.length - 7)
        : trajectory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: bodyStyle(context).copyWith(
            color: kcPrimaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ...displayPoints.map((point) => _buildTimelinePoint(context, point)),
      ],
    );
  }

  Widget _buildTimelinePoint(BuildContext context, dynamic point) {
    DateTime timestamp;
    Map<String, int> counts;
    
    if (point is Map<String, dynamic>) {
      timestamp = point['timestamp'] ?? DateTime.now();
      counts = point['countsByPhase'] as Map<String, int>? ?? {};
    } else {
      timestamp = point.timestamp ?? DateTime.now();
      counts = point.countsByPhase ?? {};
    }

    final totalCount = counts.values.fold<int>(0, (int a, int b) => a + b);
    final dateStr = _formatDate(timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Date
          SizedBox(
            width: 60,
            child: Text(
              dateStr,
              style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
            ),
          ),
          const SizedBox(width: 12),
          
          // Phase bars
          Expanded(
            child: Row(
              children: _buildPhaseBars(counts, totalCount),
            ),
          ),
          
          // Total count
          Text(
            totalCount.toString(),
            style: captionStyle(context).copyWith(
              color: kcPrimaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPhaseBars(Map<String, int> counts, int totalCount) {
    if (totalCount == 0) return [];

    final phaseColors = {
      'Discovery': kcPrimaryColor,
      'Breakthrough': kcSuccessColor,
      'Integration': kcSecondaryTextColor,
      'Reflection': kcDangerColor,
    };

    final sortedPhases = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedPhases.map((entry) {
      final phase = entry.key;
      final count = entry.value;
      final width = (count / totalCount) * 100;
      final color = phaseColors[phase] ?? kcSecondaryTextColor;

      return Container(
        width: width,
        height: 16,
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.7),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }).toList();
  }

  String _capitalizePhase(String phase) {
    if (phase.isEmpty) return 'Unknown';
    return '${phase[0].toUpperCase()}${phase.substring(1).toLowerCase()}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '${difference}d ago';
    
    return '${date.month}/${date.day}';
  }
}
