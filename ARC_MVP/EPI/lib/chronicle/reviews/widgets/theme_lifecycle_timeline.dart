import 'package:flutter/material.dart';
import 'package:my_app/chronicle/reviews/models/yearly_review.dart';
import 'package:my_app/shared/app_colors.dart';

/// Horizontal scrollable timeline showing theme lifecycles across 12 months.
class ThemeLifecycleTimeline extends StatelessWidget {
  final List<ThemeLifecycle> lifecycles;
  final int year;

  const ThemeLifecycleTimeline({
    super.key,
    required this.lifecycles,
    required this.year,
  });

  static const List<String> _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    if (lifecycles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kcSurfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kcBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme Lifecycle',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: kcPrimaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'No theme data for this year.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: kcSecondaryTextColor,
                  ),
            ),
          ],
        ),
      );
    }

    const barHeight = 24.0;
    const monthWidth = 28.0;
    final totalWidth = 12 * monthWidth + 120;

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
          Text(
            'Theme Lifecycle',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Months on x-axis; themes show when they appeared.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: kcSecondaryTextColor,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: (lifecycles.length * (barHeight + 4)).toDouble() + 32,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth.toDouble(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month labels
                    SizedBox(
                      height: 24,
                      child: Row(
                        children: List.generate(12, (i) {
                          return SizedBox(
                            width: monthWidth - 2,
                            child: Text(
                              _monthLabels[i],
                              style: const TextStyle(
                                fontSize: 10,
                                color: kcSecondaryTextColor,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Theme bars
                    ...lifecycles.take(8).map((lc) {
                      final months = lc.monthlyFrequency.keys.toList()..sort();
                      final first = months.isEmpty ? 0 : months.first - 1;
                      final last = months.isEmpty ? 0 : months.last - 1;
                      final span = last - first + 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                lc.theme,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: kcPrimaryTextColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(
                              width: 12 * monthWidth,
                              height: barHeight,
                              child: Stack(
                                children: [
                                  // Background grid
                                  ...List.generate(12, (i) {
                                    return Positioned(
                                      left: (i * monthWidth).toDouble(),
                                      top: 0,
                                      bottom: 0,
                                      width: 2,
                                      child: Container(
                                        color: kcBorderColor.withValues(alpha: 0.3),
                                      ),
                                    );
                                  }),
                                  // Theme bar
                                  if (months.isNotEmpty)
                                    Positioned(
                                      left: (first * monthWidth).toDouble(),
                                      top: 4,
                                      child: Container(
                                        width: (span * monthWidth - 4).toDouble(),
                                        height: barHeight - 8,
                                        decoration: BoxDecoration(
                                          color: _colorForStatus(lc.status),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForStatus(String status) {
    switch (status) {
      case 'persistent':
        return kcAccentColor;
      case 'peaked':
        return kcPrimaryColor;
      case 'resolved':
        return kcSuccessColor;
      case 'born':
        return kcWarningColor;
      default:
        return kcSecondaryTextColor;
    }
  }
}
