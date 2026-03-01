import 'package:flutter/material.dart';
import 'package:word_cloud/word_cloud.dart';
import 'package:my_app/shared/app_colors.dart';

/// Word cloud widget for Monthly/Yearly Review.
/// Uses word_cloud package with dark theme styling.
class ReviewWordCloud extends StatelessWidget {
  final Map<String, int> wordCloudData;
  final String title;
  final double height;
  final bool showTitle;

  const ReviewWordCloud({
    super.key,
    required this.wordCloudData,
    this.title = 'Word Cloud',
    this.height = 200,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    if (wordCloudData.isEmpty) {
      return Container(
        height: height,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kcSurfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kcBorderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: kcPrimaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'No keywords this month.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: kcSecondaryTextColor,
                  ),
            ),
          ],
        ),
      );
    }

    // Sort by value descending (word_cloud expects highest value first)
    final dataList = wordCloudData.entries
        .map((e) => {'word': e.key, 'value': e.value.toDouble()})
        .toList()
      ..sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));
    final cloudData = WordCloudData(data: dataList);

    final chartHeight = height - 50;
    final chartSize = chartHeight > 0 ? chartHeight : 150.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kcBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle && title.isNotEmpty) ...[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: kcPrimaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: chartSize,
            child: WordCloudView(
              data: cloudData,
              mapwidth: 350,
              mapheight: chartSize,
              mapcolor: kcSurfaceColor,
              colorlist: const [
                kcAccentColor,
                kcPrimaryColor,
                kcSuccessColor,
                kcWarningColor,
                Color(0xFF7C3AED),
              ],
              mintextsize: 12,
              maxtextsize: 36,
              shape: WordCloudEllipse(majoraxis: 160, minoraxis: 120),
            ),
          ),
        ],
      ),
    );
  }
}
