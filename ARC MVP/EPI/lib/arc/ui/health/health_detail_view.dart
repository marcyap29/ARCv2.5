import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_app/arc/health/apple_health_service.dart';
import 'package:my_app/ui/health/health_detail_screen.dart';
import 'package:path_provider/path_provider.dart';

class HealthDetailView extends StatelessWidget {
  final Map<String, dynamic> pointerJson;
  const HealthDetailView({super.key, required this.pointerJson});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Summary')),
      body: HealthSummaryBody(pointerJson: pointerJson),
    );
  }
}

/// Mixin to expose refresh capability
mixin RefreshableHealthSummary on State<HealthSummaryBody> {
  void refreshHealthData();
}

/// Reusable body content of the Health Summary screen so it can be embedded
/// inside other layouts (e.g., the Health tab's Summary subtab).
class HealthSummaryBody extends StatefulWidget {
  final Map<String, dynamic> pointerJson;
  const HealthSummaryBody({super.key, required this.pointerJson});

  @override
  State<HealthSummaryBody> createState() => _HealthSummaryBodyState();
}

class _HealthSummaryBodyState extends State<HealthSummaryBody> with WidgetsBindingObserver, RefreshableHealthSummary {
  Map<String, dynamic>? _importedSummary;
  bool _loadingSummary = true;

  String _currentMonthKeyUtc() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadImportedSummary();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadImportedSummary();
    }
  }


  void refresh() {
    _loadImportedSummary();
  }

  @override
  void refreshHealthData() {
    _loadImportedSummary();
  }

  Future<void> _loadImportedSummary() async {
    setState(() => _loadingSummary = true);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final monthKey = _currentMonthKeyUtc();
      final file = File('${appDir.path}/mcp/streams/health/$monthKey.jsonl');

      // Debug: Log file path and existence
      debugPrint('🔍 Health Detail Debug - Looking for file: ${file.path}');
      debugPrint('🔍 Health Detail Debug - Month key: $monthKey');

      if (!await file.exists()) {
        debugPrint('❌ Health Detail Debug - MCP file does NOT exist!');
        setState(() {
          _importedSummary = null;
          _loadingSummary = false;
        });
        return;
      }

      debugPrint('✅ Health Detail Debug - MCP file exists!');

      final lines = await file.readAsLines();
      debugPrint('🔍 Health Detail Debug - Read ${lines.length} lines from MCP file');

      final days = <Map<String, dynamic>>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final obj = jsonDecode(line) as Map<String, dynamic>;
          debugPrint('🔍 Health Detail Debug - Parsed object type: ${obj['type']}');
          if (obj['type'] == 'health.timeslice.daily') {
            days.add(obj);
            debugPrint('✅ Health Detail Debug - Added valid health day object');
          }
        } catch (e) {
          debugPrint('❌ Health Detail Debug - Failed to parse line: $e');
        }
      }

      debugPrint('🔍 Health Detail Debug - Found ${days.length} valid health day objects');

      if (days.isEmpty) {
        debugPrint('❌ Health Detail Debug - NO valid health days found after filtering!');
        setState(() {
          _importedSummary = null;
          _loadingSummary = false;
        });
        return;
      }

      // Aggregate last 7 days
      final recentDays = days.length > 7 ? days.sublist(days.length - 7) : days;
      
      // Calculate totals and averages
      int totalSteps = 0;
      double totalActiveEnergy = 0;
      double totalBasalEnergy = 0;
      int totalExerciseMin = 0;
      int totalSleepMin = 0;
      int workoutCount = 0;
      double? avgRestingHr;
      double? avgHr;
      double? avgHrv;

      for (final day in recentDays) {
        final m = day['metrics'] as Map<String, dynamic>;
        debugPrint('🔍 Health Detail Debug - Processing day metrics: ${m.keys.toList()}');

        final steps = _getMetricValue(m, 'steps') ?? 0;
        final activeEnergy = _getMetricValue(m, 'active_energy') ?? 0;
        final basalEnergy = _getMetricValue(m, 'resting_energy') ?? 0;

        debugPrint('🔍 Health Detail Debug - Extracted values: steps=$steps, active=$activeEnergy, basal=$basalEnergy');

        totalSteps += steps.toInt();
        totalActiveEnergy += activeEnergy;
        totalBasalEnergy += basalEnergy;
        totalExerciseMin += (_getMetricValue(m, 'exercise_minutes') ?? 0).toInt();
        totalSleepMin += ((_getMetricValue(m, 'sleep_total_minutes') ?? (m['sleep_total_minutes'] as num?)) ?? 0).toInt();
        workoutCount += ((m['workouts'] as List?)?.length ?? 0);
        
        final rhr = _getMetricValue(m, 'resting_hr');
        if (rhr != null) avgRestingHr = (avgRestingHr ?? 0) + rhr;
        
        final hr = _getMetricValue(m, 'avg_hr');
        if (hr != null) avgHr = (avgHr ?? 0) + hr;
        
        final hrv = _getMetricValue(m, 'hrv_sdnn');
        if (hrv != null) avgHrv = (avgHrv ?? 0) + hrv;
      }

      final dayCount = recentDays.length;

      debugPrint('🔍 Health Detail Debug - Final aggregated totals:');
      debugPrint('🔍 Health Detail Debug - Days: $dayCount, Steps: $totalSteps, Active: $totalActiveEnergy, Basal: $totalBasalEnergy');

      setState(() {
        _importedSummary = {
          'days_count': dayCount,
          'total_steps': totalSteps,
          'avg_active_energy': totalActiveEnergy / dayCount,
          'avg_basal_energy': totalBasalEnergy / dayCount,
          'total_exercise_min': totalExerciseMin,
          'avg_sleep_min': totalSleepMin / dayCount,
          'workout_count': workoutCount,
          'avg_resting_hr': avgRestingHr != null ? avgRestingHr / dayCount : null,
          'avg_hr': avgHr != null ? avgHr / dayCount : null,
          'avg_hrv': avgHrv != null ? avgHrv / dayCount : null,
        };
        _loadingSummary = false;
      });
    } catch (e) {
      setState(() {
        _importedSummary = null;
        _loadingSummary = false;
      });
    }
  }

  num? _getMetricValue(Map<String, dynamic> metrics, String key) {
    final m = metrics[key];
    if (m is Map && m['value'] != null) return m['value'] as num;
    if (m is num) return m;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Apple Health 7-day summary (existing)
        FutureBuilder<Map<String, num>>(
            future: AppleHealthService.instance.fetchBasicSummary(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              final data = snapshot.data!;
              return Container(
              padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Apple Health (last 7 days)', style: Theme.of(context).textTheme.titleMedium),
                      IconButton(
                        icon: const Icon(Icons.show_chart),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HealthDetailScreen(monthKey: _currentMonthKeyUtc()),
                            ),
                          );
                        },
                        tooltip: 'View detailed charts',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                    Text('Steps: ${data['steps7d']?.round() ?? 0}  •  Avg HR: ${data['avgHR']?.toStringAsFixed(0) ?? '—'} bpm'),
                  ],
                ),
              );
            },
        ),
        const SizedBox(height: 12),

        // Clear "View Detailed Charts" button
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HealthDetailScreen(monthKey: _currentMonthKeyUtc()),
              ),
            );
          },
          icon: const Icon(Icons.show_chart),
          label: const Text('View Detailed Charts'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 16),

        // Health Summary Card (aggregated from imported data)
        _buildSummaryCard(context),
        const SizedBox(height: 12),

        // Detailed Info Card (last 7 days breakdown)
        _buildDetailedInfoCard(context),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Health Summary', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_loadingSummary)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_importedSummary == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No imported data yet. Go to Settings to import health data.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryRow('Days', '${_importedSummary!['days_count']} days'),
                const SizedBox(height: 8),
                _buildSummaryRow('Total Steps', '${_importedSummary!['total_steps']?.toStringAsFixed(0) ?? '—'}'),
                _buildSummaryRow('Avg Active Energy', '${(_importedSummary!['avg_active_energy'] as num?)?.toStringAsFixed(0) ?? '—'} kcal'),
                _buildSummaryRow('Avg Basal Energy', '${(_importedSummary!['avg_basal_energy'] as num?)?.toStringAsFixed(0) ?? '—'} kcal'),
                _buildSummaryRow('Exercise Time', '${(_importedSummary!['total_exercise_min'] as num?)?.round() ?? '—'} min'),
                _buildSummaryRow('Avg Sleep', '${(_importedSummary!['avg_sleep_min'] as num?)?.round() ?? '—'} min'),
                if (_importedSummary!['workout_count'] > 0)
                  _buildSummaryRow('Workouts', '${_importedSummary!['workout_count']}'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetailedInfoCard(BuildContext context) {
        return Container(
      padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text('Detailed Metrics', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_loadingSummary)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_importedSummary == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Import health data to see detailed metrics including heart rate, HRV, and more.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_importedSummary!['avg_resting_hr'] != null)
                  _buildDetailRow('Avg Resting HR', '${(_importedSummary!['avg_resting_hr'] as num).toStringAsFixed(0)} bpm'),
                if (_importedSummary!['avg_hr'] != null)
                  _buildDetailRow('Avg Heart Rate', '${(_importedSummary!['avg_hr'] as num).toStringAsFixed(0)} bpm'),
                if (_importedSummary!['avg_hrv'] != null)
                  _buildDetailRow('Avg HRV (SDNN)', '${(_importedSummary!['avg_hrv'] as num).toStringAsFixed(1)} ms'),
                if (_importedSummary!['avg_resting_hr'] == null && _importedSummary!['avg_hr'] == null && _importedSummary!['avg_hrv'] == null)
                  Text(
                    'Heart rate data will appear here after import.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}


