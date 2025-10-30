import 'dart:convert';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class HealthDetailScreen extends StatefulWidget {
  final String monthKey; // e.g., "2025-10"
  const HealthDetailScreen({super.key, required this.monthKey});

  @override
  State<HealthDetailScreen> createState() => _HealthDetailScreenState();
}

class _HealthDetailScreenState extends State<HealthDetailScreen> {
  List<Map<String, dynamic>> _days = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/mcp/streams/health/${widget.monthKey}.jsonl');
      if (!await file.exists()) {
        setState(() {
          _days = [];
          _loading = false;
        });
        return;
      }
    final lines = await file.readAsLines();
    final items = <Map<String, dynamic>>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final obj = jsonDecode(line);
      if (obj['type'] == 'health.timeslice.daily') items.add(obj);
    }
      items.sort((a, b) =>
          (a['timeslice']['start'] as String).compareTo(b['timeslice']['start'] as String));
      setState(() {
        _days = items.take(30).toList().reversed.toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _days = [];
        _loading = false;
      });
    }
  }

  List<FlSpot> _spots(List<num?> values) {
    final list = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      list.add(FlSpot(i.toDouble(), (v ?? 0).toDouble()));
    }
    return list;
  }

  Widget _chart(String title, List<num?> values, {double? maxY}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 180,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LineChart(LineChartData(
            minX: 0,
            maxX: (values.length - 1).toDouble(),
            minY: 0,
            maxY: maxY,
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) => Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            gridData: const FlGridData(show: true),
            lineBarsData: [
              LineChartBarData(
                spots: _spots(values),
                isCurved: true,
                dotData: const FlDotData(show: false),
                barWidth: 2,
              )
            ],
          )),
        ),
      ),
    );
  }

  num? _metric(int i, String key) {
    final m = _days[i]['metrics'][key];
    if (m is Map && m['value'] != null) return m['value'] as num;
    if (m is num) return m;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_days.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Health Detail')),
        body: const Center(child: Text('No health data yet. Import data first from the Health Summary.')),
      );
    }
    final n = _days.length;
    List<num?> listOf(String k) => List.generate(n, (i) => _metric(i, k));

    final steps   = listOf('steps');
    final active  = listOf('active_energy');
    final basal   = listOf('resting_energy');
    final sleep   = List.generate(n, (i) => _days[i]['metrics']['sleep_total_minutes'] as num?);
    final rhr     = listOf('resting_hr');
    final avghr   = listOf('avg_hr');
    final hrv     = listOf('hrv_sdnn');
    final vo2     = listOf('vo2max');
    final stand   = listOf('stand_minutes');

    return Scaffold(
      appBar: AppBar(title: const Text('Health Detail')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _chart('Steps', steps),
          _chart('Active energy (kcal)', active),
          _chart('Basal energy (kcal)', basal),
          _chart('Sleep (min)', sleep),
          _chart('Resting HR (bpm)', rhr),
          _chart('Average HR (bpm)', avghr),
          _chart('HRV SDNN (ms)', hrv),
          _chart('VO₂max (ml/kg·min)', vo2),
          _chart('Stand minutes', stand),
        ],
      ),
    );
  }
}


