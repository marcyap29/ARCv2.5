import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:my_app/mcp/mcp_fs.dart';

class HealthDetailScreen extends StatefulWidget {
  final String? monthKey; // e.g., "2025-10" - optional, if not provided loads last 30 days
  final int daysBack; // 7..90
  const HealthDetailScreen({super.key, this.monthKey, this.daysBack = 30});

  @override
  State<HealthDetailScreen> createState() => _HealthDetailScreenState();
}

class _HealthDetailScreenState extends State<HealthDetailScreen> {
  List<Map<String, dynamic>> _days = [];
  bool _loading = true;
  String _log = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _monthKeyUtc(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _log = '';
    });

    try {
      final now = DateTime.now().toUtc();
      final start = DateTime.utc(now.year, now.month, now.day)
          .subtract(Duration(days: widget.daysBack - 1));

      // If monthKey is provided, only load that month. Otherwise load months needed for daysBack
      final months = widget.monthKey != null
          ? <String>{widget.monthKey!}
          : <String>{_monthKeyUtc(start), _monthKeyUtc(now)};

      final loaded = <Map<String, dynamic>>[];
      final logLines = <String>[];

      for (final m in months) {
        final file = await McpFs.healthMonth(m);
        logLines.add('Looking for ${file.path}');
        if (!await file.exists()) {
          logLines.add('  (missing)');
          continue;
        }

        final stream = file
            .openRead()
            .transform(utf8.decoder)
            .transform(const LineSplitter());
        
        int lineCount = 0;
        await for (final line in stream) {
          if (line.trim().isEmpty) continue;
          try {
            final obj = jsonDecode(line) as Map<String, dynamic>;
            if (obj['type'] != 'health.timeslice.daily') continue;
            
            final startIso = (obj['timeslice']?['start'] as String?) ?? '';
            if (startIso.isEmpty) continue;
            
            final day = DateTime.parse(startIso);
            if (widget.monthKey == null && (day.isBefore(start) || day.isAfter(now))) {
              continue;
            }
            
            loaded.add(obj);
            lineCount++;
          } catch (_) {
            // ignore malformed lines
          }
        }
        logLines.add('  loaded $lineCount lines from this file');
      }

      loaded.sort((a, b) {
        final aStart = (a['timeslice']?['start'] as String?) ?? '';
        final bStart = (b['timeslice']?['start'] as String?) ?? '';
        return aStart.compareTo(bStart);
      });

      setState(() {
        _days = loaded.take(90).toList(); // cap for safety
        _loading = false;
        _log = logLines.join('\n');
      });
    } catch (e) {
      debugPrint('Error loading health data: $e');
      setState(() {
        _days = [];
        _loading = false;
        _log = 'Error: $e';
      });
    }
  }

  /// Safely extract a metric that could be:
  /// - number
  /// - {"value": number, "unit": "..."}
  num? _m(Map<String, dynamic> day, String key) {
    final m = day['metrics'];
    if (m is! Map) return null;

    final v = m[key];
    if (v is num) return v;
    if (v is Map && v['value'] is num) return v['value'] as num;
    
    // sleep fallback: the older "sleep": {"total_minutes_asleep": N}
    if (key == 'sleep_total_minutes' && m['sleep'] is Map) {
      final alt = (m['sleep'] as Map)['total_minutes_asleep'];
      if (alt is num) return alt;
    }
    
    return null;
  }

  List<FlSpot> _spots(List<num?> values) {
    final out = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      out.add(FlSpot(i.toDouble(), (values[i] ?? 0).toDouble()));
    }
    return out;
  }

  Widget _chart(String title, List<num?> vals, {double? maxY, String unit = '', String aggregationType = 'avg'}) {
    final validValues = vals.where((v) => v != null && v > 0).cast<num>().map((v) => v.toDouble()).toList();
    final calculatedMaxY = maxY ?? (validValues.isEmpty ? 100.0 : validValues.reduce((a, b) => a > b ? a : b) * 1.1);
    final maxX = vals.isEmpty ? 1.0 : (vals.length - 1).toDouble();

    // Calculate statistics
    final total = validValues.fold<double>(0, (sum, val) => sum + val);
    final average = validValues.isEmpty ? 0.0 : total / validValues.length;
    final maxValue = validValues.isEmpty ? 0.0 : validValues.reduce((a, b) => a > b ? a : b);

    // Format statistics based on aggregation type
    String statsText;
    if (aggregationType == 'total') {
      statsText = 'Total: ${total.toStringAsFixed(0)}$unit';
    } else {
      statsText = 'Avg: ${average.toStringAsFixed(0)}$unit • Max: ${maxValue.toStringAsFixed(0)}$unit';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            statsText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            height: 170,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: vals.isEmpty || validValues.isEmpty
                  ? Center(
                      child: Text(
                        'No data available',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    )
                  : LineChart(LineChartData(
                      minX: 0,
                      maxX: maxX,
                      minY: 0,
                      maxY: calculatedMaxY,
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: vals.length > 15 ? vals.length / 5 : 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= _days.length) return const SizedBox.shrink();

                              // Extract date from day object
                              final day = _days[index];
                              final timeslice = day['timeslice'] as Map<String, dynamic>?;
                              final startStr = timeslice?['start'] as String?;

                              if (startStr == null) return const SizedBox.shrink();

                              try {
                                final date = DateTime.parse(startStr);
                                final dayLabel = '${date.month}/${date.day}';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    dayLabel,
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                );
                              } catch (_) {
                                return const SizedBox.shrink();
                              }
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 35,
                            interval: calculatedMaxY > 100 ? calculatedMaxY / 4 : null,
                            getTitlesWidget: (value, meta) {
                              // Format large numbers more readably
                              String formatted;
                              if (value >= 1000) {
                                formatted = '${(value / 1000).toStringAsFixed(1)}k';
                              } else {
                                formatted = value.toInt().toString();
                              }

                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  formatted,
                                  style: const TextStyle(fontSize: 9),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: calculatedMaxY > 100 ? calculatedMaxY / 4 : null,
                      ),
                      borderData: FlBorderData(show: true),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final index = spot.x.toInt();
                              if (index < 0 || index >= _days.length) return null;

                              // Extract date from day object
                              final day = _days[index];
                              final timeslice = day['timeslice'] as Map<String, dynamic>?;
                              final startStr = timeslice?['start'] as String?;

                              String dateLabel = '';
                              if (startStr != null) {
                                try {
                                  final date = DateTime.parse(startStr);
                                  dateLabel = '${date.month}/${date.day}/${date.year.toString().substring(2)}';
                                } catch (_) {}
                              }

                              return LineTooltipItem(
                                '${spot.y.toStringAsFixed(0)}$unit\n$dateLabel',
                                const TextStyle(color: Colors.white, fontSize: 12),
                              );
                            }).toList();
                          },
                        ),
                        handleBuiltInTouches: true,
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _spots(vals),
                          isCurved: true,
                          color: Colors.blue,
                          barWidth: 2,
                          dotData: FlDotData(
                            show: vals.length <= 10,
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(radius: 3, color: Colors.blue),
                          ),
                        )
                      ],
                    )),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Health Detail')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final n = _days.length;

    List<num?> listOf(String key) => List.generate(n, (i) => _m(_days[i], key));

    final steps = listOf('steps');
    final active = listOf('active_energy');
    final basal = listOf('resting_energy');
    final sleep = List.generate(n, (i) => _m(_days[i], 'sleep_total_minutes'));
    final rhr = listOf('resting_hr');
    final avghr = listOf('avg_hr');
    final hrv = listOf('hrv_sdnn');

    return Scaffold(
      appBar: AppBar(title: const Text('Health Detail')),
      body: n == 0
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('No data available'),
                const SizedBox(height: 8),
                Text(
                  _log.isEmpty ? 'No health data files found.' : _log,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text('Loaded $n day(s)', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                _chart('Steps', steps, unit: ' steps', aggregationType: 'total'),
                _chart('Active Energy', active, unit: ' kcal'),
                _chart('Basal Energy', basal, unit: ' kcal'),
                _chart('Sleep', sleep, unit: ' min'),
                _chart('Resting Heart Rate', rhr, unit: ' bpm'),
                _chart('Average Heart Rate', avghr, unit: ' bpm'),
                _chart('Heart Rate Variability', hrv, unit: ' ms'),
                const SizedBox(height: 12),
                ExpansionTile(
                  title: Text('Debug log'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        _log.isEmpty ? 'No debug info' : _log,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                    )
                  ],
                ),
              ],
            ),
    );
  }
}
