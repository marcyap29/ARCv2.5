import 'package:flutter/material.dart';
import 'package:my_app/core/mira/mira_feature_flags.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/text_style.dart';

/// Card showing top themes (keywords) for the current time window
class ThemesCard extends StatelessWidget {
  const ThemesCard({super.key});

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
              const Icon(Icons.topic, color: kcPrimaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'This Week\'s Themes',
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
              const Icon(Icons.topic, color: kcPrimaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'This Week\'s Themes',
                style: heading3Style(context).copyWith(color: kcPrimaryColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.topic_outlined,
                  size: 32,
                  color: kcSecondaryTextColor,
                ),
                const SizedBox(height: 8),
                Text(
                  'No themes yet',
                  style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start journaling to see your themes emerge',
                  style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemesCard(BuildContext context, List<dynamic> themes) {
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
              const Icon(Icons.topic, color: kcPrimaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'This Week\'s Themes',
                style: heading3Style(context).copyWith(color: kcPrimaryColor),
              ),
              const Spacer(),
              Text(
                '${themes.length} themes',
                style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...themes.take(5).map((theme) => _buildThemeItem(context, theme)),
          if (themes.length > 5) ...[
            const SizedBox(height: 8),
            Text(
              '... and ${themes.length - 5} more',
              style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThemeItem(BuildContext context, dynamic theme) {
    // Handle both MiraKeywordStat and Map types for flexibility
    String keyword;
    double score;
    int count;
    
    if (theme is Map<String, dynamic>) {
      keyword = theme['keyword'] ?? theme['key'] ?? 'Unknown';
      score = (theme['score'] ?? theme['value'] ?? 0.0).toDouble();
      count = (theme['count'] ?? 0).toInt();
    } else {
      // Assume it's a MiraKeywordStat
      keyword = theme.keyword ?? 'Unknown';
      score = theme.score ?? 0.0;
      count = theme.count ?? 0;
    }

    // Normalize keyword display
    final displayKeyword = keyword.replaceAll('_', ' ').toLowerCase();
    final capitalizedKeyword = displayKeyword.isNotEmpty 
        ? '${displayKeyword[0].toUpperCase()}${displayKeyword.substring(1)}'
        : displayKeyword;

    // Calculate relative intensity (0-1)
    const maxScore = 10.0; // Adjust based on expected max score
    final intensity = (score / maxScore).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Intensity indicator
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: kcPrimaryColor.withOpacity(intensity),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          
          // Keyword and count
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
                  '$count mentions',
                  style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
                ),
              ],
            ),
          ),
          
          // Score indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kcPrimaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              score.toStringAsFixed(1),
              style: captionStyle(context).copyWith(
                color: kcPrimaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
