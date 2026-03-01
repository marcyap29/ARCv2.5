import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:my_app/chronicle/reviews/models/monthly_review.dart';
import 'package:my_app/shared/app_colors.dart';

/// Sparkline/line chart showing emotional intensity trajectory across the month.
class EmotionalTrajectoryChart extends StatelessWidget {
  final List<EmotionalDataPoint> dataPoints;
  final String descriptor;

  const EmotionalTrajectoryChart({
    super.key,
    required this.dataPoints,
    required this.descriptor,
  });

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
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
              'Emotional Trajectory',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: kcPrimaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'No emotional data this month.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: kcSecondaryTextColor,
                  ),
            ),
          ],
        ),
      );
    }

    final spots = dataPoints.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.intensity);
    }).toList();

    final maxY = dataPoints.map((p) => p.intensity).reduce((a, b) => a > b ? a : b);
    final minY = dataPoints.map((p) => p.intensity).reduce((a, b) => a < b ? a : b);
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
            'Emotional Trajectory',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            descriptor,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: kcSecondaryTextColor,
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (dataPoints.length - 1).toDouble(),
                minY: chartMinY,
                maxY: chartMaxY,
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: dataPoints.length <= 10,
                      reservedSize: 24,
                      interval: dataPoints.length > 1 ? (dataPoints.length - 1) / 4 : 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= dataPoints.length) return const SizedBox.shrink();
                        final d = dataPoints[i].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${d.month}/${d.day}',
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
                    color: kcBorderColor.withOpacity(0.3),
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
                        if (i < 0 || i >= dataPoints.length) return null;
                        final d = dataPoints[i];
                        return LineTooltipItem(
                          '${d.date.month}/${d.date.day}: ${d.intensity.toStringAsFixed(2)}',
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
                      color: kcAccentColor.withOpacity(0.15),
                    ),
                    dotData: FlDotData(
                      show: dataPoints.length <= 15,
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
