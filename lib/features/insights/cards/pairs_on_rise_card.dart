import 'package:flutter/material.dart';
import '../../../core/mira/mira_cubit.dart';
import '../../../core/mira/mira_feature_flags.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/text_style.dart';

/// Card showing keyword pairs that are co-occurring more frequently
class PairsOnRiseCard extends StatelessWidget {
  const PairsOnRiseCard({Key? key}) : super(key: key);

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
              Icon(Icons.trending_up, color: kcSuccessColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pairs on the Rise',
                style: AppTextStyle.heading4.copyWith(color: kcSuccessColor),
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
              Icon(Icons.trending_up, color: kcSuccessColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pairs on the Rise',
                style: AppTextStyle.heading4.copyWith(color: kcSuccessColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.trending_flat,
                  size: 32,
                  color: kcSecondaryTextColor,
                ),
                const SizedBox(height: 8),
                Text(
                  'No rising pairs yet',
                  style: AppTextStyle.body.copyWith(color: kcSecondaryTextColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keyword combinations will appear as you journal',
                  style: AppTextStyle.caption.copyWith(color: kcSecondaryTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairsCard(List<dynamic> pairs) {
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
              Icon(Icons.trending_up, color: kcSuccessColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pairs on the Rise',
                style: AppTextStyle.heading4.copyWith(color: kcSuccessColor),
              ),
              const Spacer(),
              Text(
                '${pairs.length} pairs',
                style: AppTextStyle.caption.copyWith(color: kcSecondaryTextColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...pairs.take(5).map((pair) => _buildPairItem(pair)).toList(),
          if (pairs.length > 5) ...[
            const SizedBox(height: 8),
            Text(
              '... and ${pairs.length - 5} more',
              style: AppTextStyle.caption.copyWith(color: kcSecondaryTextColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPairItem(dynamic pair) {
    // Handle both MiraPairStat and Map types for flexibility
    String k1, k2;
    double lift;
    int count;
    
    if (pair is Map<String, dynamic>) {
      k1 = pair['k1'] ?? pair['keyword1'] ?? 'Unknown';
      k2 = pair['k2'] ?? pair['keyword2'] ?? 'Unknown';
      lift = (pair['lift'] ?? pair['value'] ?? 1.0).toDouble();
      count = (pair['count'] ?? 0).toInt();
    } else {
      // Assume it's a MiraPairStat
      k1 = pair.k1 ?? 'Unknown';
      k2 = pair.k2 ?? 'Unknown';
      lift = pair.lift ?? 1.0;
      count = pair.count ?? 0;
    }

    // Normalize keyword display
    final displayK1 = _normalizeKeyword(k1);
    final displayK2 = _normalizeKeyword(k2);

    // Calculate lift intensity (1.0 = no change, >1.0 = rising)
    final liftIntensity = (lift - 1.0).clamp(0.0, 2.0) / 2.0; // Normalize to 0-1

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Lift indicator
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: kcSuccessColor.withOpacity(liftIntensity),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          
          // Keyword pair
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      displayK1,
                      style: AppTextStyle.body.copyWith(
                        color: kcPrimaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.add,
                      size: 12,
                      color: kcSecondaryTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      displayK2,
                      style: AppTextStyle.body.copyWith(
                        color: kcPrimaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$count co-occurrences',
                  style: AppTextStyle.caption.copyWith(color: kcSecondaryTextColor),
                ),
              ],
            ),
          ),
          
          // Lift value
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
                  '${lift.toStringAsFixed(1)}x',
                  style: AppTextStyle.caption.copyWith(
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

  String _normalizeKeyword(String keyword) {
    return keyword
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : word)
        .join(' ');
  }
}
