import 'package:flutter/material.dart';
import '../../../core/mira/mira_cubit.dart';
import '../../../core/mira/mira_feature_flags.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/text_style.dart';

/// Card showing keywords that often precede breakthrough moments
class PrecursorsCard extends StatelessWidget {
  const PrecursorsCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!MiraFeatureFlags.enableInsightsCards) {
      return const SizedBox.shrink();
    }

    // For now, return a placeholder card
    return _buildEmptyCard();
  }

  Widget _buildLoadingCard() {
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
              Icon(Icons.psychology, color: kcSuccessColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Breakthrough Precursors',
                style: heading3Style(context).copyWith(color: kcSuccessColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Center(
            child: CircularProgressIndicator(
              color: kcSuccessColor,
              strokeWidth: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
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
              Icon(Icons.psychology, color: kcSuccessColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Breakthrough Precursors',
                style: heading3Style(context).copyWith(color: kcSuccessColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.psychology_outlined,
                  size: 32,
                  color: kcSecondaryTextColor,
                ),
                const SizedBox(height: 8),
                Text(
                  'No breakthrough patterns yet',
                  style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Breakthrough precursors will appear as you experience more insights',
                  style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrecursorsCard(List<dynamic> precursors) {
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
              Icon(Icons.psychology, color: kcSuccessColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Breakthrough Precursors',
                style: heading3Style(context).copyWith(color: kcSuccessColor),
              ),
              const Spacer(),
              Text(
                '${precursors.length} patterns',
                style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Keywords that often appear before breakthrough moments',
            style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
          ),
          const SizedBox(height: 16),
          ...precursors.take(5).map((precursor) => _buildPrecursorItem(precursor)).toList(),
          if (precursors.length > 5) ...[
            const SizedBox(height: 8),
            Text(
              '... and ${precursors.length - 5} more',
              style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrecursorItem(dynamic precursor) {
    // Handle both MiraKeywordStat and Map types for flexibility
    String keyword;
    double score;
    int count;
    
    if (precursor is Map<String, dynamic>) {
      keyword = precursor['keyword'] ?? precursor['key'] ?? 'Unknown';
      score = (precursor['score'] ?? precursor['value'] ?? 0.0).toDouble();
      count = (precursor['count'] ?? 0).toInt();
    } else {
      // Assume it's a MiraKeywordStat
      keyword = precursor.keyword ?? 'Unknown';
      score = precursor.score ?? 0.0;
      count = precursor.count ?? 0;
    }

    // Normalize keyword display
    final displayKeyword = keyword.replaceAll('_', ' ').toLowerCase();
    final capitalizedKeyword = displayKeyword.isNotEmpty 
        ? '${displayKeyword[0].toUpperCase()}${displayKeyword.substring(1)}'
        : displayKeyword;

    // Calculate precursor strength (0-1)
    final maxScore = 10.0; // Adjust based on expected max score
    final strength = (score / maxScore).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Precursor strength indicator
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: kcSuccessColor.withOpacity(strength),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          
          // Keyword and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  capitalizedKeyword,
                  style: bodyStyle(context).copyWith(
                    color: kcPrimaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Seen rising before Breakthrough',
                  style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
                ),
              ],
            ),
          ),
          
          // Score indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kcSuccessColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.trending_up,
                  size: 12,
                  color: kcSuccessColor,
                ),
                const SizedBox(width: 4),
                Text(
                  score.toStringAsFixed(1),
                  style: captionStyle(context).copyWith(
                    color: kcSuccessColor,
                    fontWeight: FontWeight.w500,
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
