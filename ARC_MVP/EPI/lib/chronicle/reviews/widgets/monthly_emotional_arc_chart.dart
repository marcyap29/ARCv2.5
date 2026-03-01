import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:my_app/chronicle/reviews/models/yearly_review.dart';
import 'package:my_app/shared/app_colors.dart';

/// Line chart showing month-by-month emotional arc for the year.
class MonthlyEmotionalArcChart extends StatelessWidget {
  final List<MonthlyEmotionalSummary> monthlyArc;
  final int year;

  const MonthlyEmotionalArcChart({
    super.key,
    required this.monthlyArc,
    required this.year,
  });

  static const List<String> _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    if (monthlyArc.isEmpty) {
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
              'Month-by-Month Emotional Arc',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: kcPrimaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'No emotional data for this year.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: kcSecondaryTextColor,
                  ),
            ),
          ],
        ),
      );
    }

    final spots = monthlyArc
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.averageIntensity))
        .toList();
    final maxY = monthlyArc.map((m) => m.averageIntensity).reduce((a, b) => a > b ? a : b);
    final minY = monthlyArc.map((m) => m.averageIntensity).reduce((a, b) => a < b ? a : b);
    final range = (maxY - minY).clamp(0.1, 1.0);
    final chartMinY = (minY - 0.05).clamp(0.0, 1.0);
    final chartMaxY = (maxY + 0.05).clamp(0.0, 1.0);

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
            'Month-by-Month Emotional Arc',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (monthlyArc.length - 1).toDouble(),
                minY: chartMinY,
                maxY: chartMaxY,
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= monthlyArc.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _monthLabels[monthlyArc[i].month - 1],
                            style: const TextStyle(
                              fontSize: 10,
                              color: kcSecondaryTextColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: range / 2,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 10,
                            color: kcSecondaryTextColor,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: range / 2,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: kcBorderColor.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final i = spot.x.toInt();
                        if (i < 0 || i >= monthlyArc.length) return null;
                        final m = monthlyArc[i];
                        final ann = m.annotation != null && m.annotation!.isNotEmpty
                            ? '\n${m.annotation!.substring(0, m.annotation!.length > 40 ? 40 : m.annotation!.length)}...'
                            : '';
                        return LineTooltipItem(
                          '${_monthLabels[m.month - 1]}: ${m.averageIntensity.toStringAsFixed(2)}$ann',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: kcAccentColor,
                    barWidth: 2,
                    belowBarData: BarAreaData(
                      show: true,
                      color: kcAccentColor.withValues(alpha: 0.15),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: kcAccentColor,
                        strokeWidth: 1,
                        strokeColor: kcSurfaceColor,
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 250),
            ),
          ),
        ],
      ),
    );
  }
}
