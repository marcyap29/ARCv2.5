import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:my_app/arc/health/apple_health_service.dart';
import 'package:my_app/mira/store/mcp/mcp_fs.dart';

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
      // Use local time for user-facing date calculations
      final nowLocal = DateTime.now();
      final startLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day)
          .subtract(const Duration(days: 6)); // Last 7 days
      
      // Convert to UTC for comparing with stored health data (which uses UTC)
      final nowUtc = nowLocal.toUtc();
      final startUtc = startLocal.toUtc();
      
      // Health data files are organized by UTC month (from ISO date strings)
      // Check months based on both local and UTC to handle timezone edge cases
      final monthsToCheck = <String>{};
      
      // Add months based on UTC dates (how files are actually organized)
      final startUtcMonthKey = '${startUtc.year.toString().padLeft(4, '0')}-${startUtc.month.toString().padLeft(2, '0')}';
      final nowUtcMonthKey = '${nowUtc.year.toString().padLeft(4, '0')}-${nowUtc.month.toString().padLeft(2, '0')}';
      monthsToCheck.add(startUtcMonthKey);
      monthsToCheck.add(nowUtcMonthKey);
      
      // Also check adjacent months for timezone edge cases
      // (e.g., if it's late at night PST, it might be next day UTC)
      final prevMonthUtc = DateTime.utc(startUtc.year, startUtc.month - 1 <= 0 ? 12 : startUtc.month - 1);
      if (startUtc.month == 1) {
        monthsToCheck.add('${startUtc.year - 1}-12'); // Previous year December
      } else {
        monthsToCheck.add('${prevMonthUtc.year.toString().padLeft(4, '0')}-${prevMonthUtc.month.toString().padLeft(2, '0')}');
      }
      
      final nextMonthUtc = DateTime.utc(nowUtc.year, nowUtc.month + 1 > 12 ? 1 : nowUtc.month + 1);
      if (nowUtc.month == 12) {
        monthsToCheck.add('${nowUtc.year + 1}-01'); // Next year January
      } else {
        monthsToCheck.add('${nextMonthUtc.year.toString().padLeft(4, '0')}-${nextMonthUtc.month.toString().padLeft(2, '0')}');
      }

      debugPrint('🔍 Health Detail Debug - User local time: $nowLocal (PST/PST-8)');
      debugPrint('🔍 Health Detail Debug - UTC time: $nowUtc');
      debugPrint('🔍 Health Detail Debug - Checking months (UTC-based): $monthsToCheck');
      debugPrint('🔍 Health Detail Debug - Date range (local): ${startLocal.toIso8601String()} to ${nowLocal.toIso8601String()}');
      debugPrint('🔍 Health Detail Debug - Date range (UTC): ${startUtc.toIso8601String()}Z to ${nowUtc.toIso8601String()}Z');

      final days = <Map<String, dynamic>>[];
      
      for (final monthKey in monthsToCheck) {
        final file = await McpFs.healthMonth(monthKey);
        debugPrint('🔍 Health Detail Debug - Looking for file: ${file.path}');

        if (!await file.exists()) {
          debugPrint('⚠️ Health Detail Debug - File does not exist for month: $monthKey');
          continue;
        }

        debugPrint('✅ Health Detail Debug - MCP file exists for month: $monthKey');
        final lines = await file.readAsLines();
        debugPrint('🔍 Health Detail Debug - Read ${lines.length} lines from $monthKey.jsonl');

        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          try {
            final obj = jsonDecode(line) as Map<String, dynamic>;
            if (obj['type'] == 'health.timeslice.daily') {
              // Filter by date range (compare in UTC for consistency with stored data)
              final startIso = (obj['timeslice']?['start'] as String?) ?? '';
              if (startIso.isNotEmpty) {
                try {
                  final day = DateTime.parse(startIso).toUtc();
                  // Include days that fall within the last 7 days (based on local time)
                  if (day.isAfter(startUtc.subtract(const Duration(seconds: 1))) && 
                      day.isBefore(nowUtc.add(const Duration(days: 1)))) {
                    days.add(obj);
                  }
                } catch (e) {
                  debugPrint('⚠️ Health Detail Debug - Failed to parse date: $e');
                }
              }
            }
          } catch (e) {
            debugPrint('❌ Health Detail Debug - Failed to parse line: $e');
          }
        }
      }

      debugPrint('🔍 Health Detail Debug - Found ${days.length} valid health day objects');

      if (days.isEmpty) {
        debugPrint('❌ Health Detail Debug - NO valid health days in MCP stream; trying Apple Health fallback.');
        // Fallback: build summary from Apple Health when MCP stream has no data
        try {
          final appleData = await AppleHealthService.instance.fetchBasicSummary();
          if (appleData.isNotEmpty && mounted) {
            final steps = appleData['steps7d']?.round() ?? 0;
            final avgHr = appleData['avgHR']?.toDouble();
            setState(() {
              _importedSummary = {
                'days_count': 7,
                'total_steps': steps,
                'avg_active_energy': null,
                'avg_basal_energy': null,
                'total_exercise_min': null,
                'avg_sleep_min': null,
                'workout_count': 0,
                'avg_resting_hr': avgHr,
                'avg_hr': avgHr,
                'avg_hrv': null,
                '_source': 'apple_health',
              };
              _loadingSummary = false;
            });
            return;
          }
        } catch (e) {
          debugPrint('Apple Health fallback failed: $e');
        }
        if (mounted) {
          setState(() {
            _importedSummary = null;
            _loadingSummary = false;
          });
        }
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
      int rhrCount = 0; // Count days with resting HR data
      int hrCount = 0;  // Count days with avg HR data
      int hrvCount = 0; // Count days with HRV data

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
        if (rhr != null) {
          avgRestingHr = (avgRestingHr ?? 0) + rhr;
          rhrCount++;
          debugPrint('🔍 Health Detail Debug - Found resting_hr: $rhr (count: $rhrCount)');
        }
        
        final hr = _getMetricValue(m, 'avg_hr');
        if (hr != null) {
          avgHr = (avgHr ?? 0) + hr;
          hrCount++;
          debugPrint('🔍 Health Detail Debug - Found avg_hr: $hr (count: $hrCount)');
        }
        
        final hrv = _getMetricValue(m, 'hrv_sdnn');
        if (hrv != null) {
          avgHrv = (avgHrv ?? 0) + hrv;
          hrvCount++;
          debugPrint('🔍 Health Detail Debug - Found hrv_sdnn: $hrv (count: $hrvCount)');
        }
      }

      final dayCount = recentDays.length;

      debugPrint('🔍 Health Detail Debug - Final aggregated totals:');
      debugPrint('🔍 Health Detail Debug - Days: $dayCount, Steps: $totalSteps, Active: $totalActiveEnergy, Basal: $totalBasalEnergy');
      debugPrint('🔍 Health Detail Debug - HR metrics counts: RHR=$rhrCount, AvgHR=$hrCount, HRV=$hrvCount');

      setState(() {
        _importedSummary = {
          'days_count': dayCount,
          'total_steps': totalSteps,
          'avg_active_energy': totalActiveEnergy / dayCount,
          'avg_basal_energy': totalBasalEnergy / dayCount,
          'total_exercise_min': totalExerciseMin,
          'avg_sleep_min': totalSleepMin / dayCount,
          'workout_count': workoutCount,
          // Only calculate average if we have at least one day with data, divide by actual count
          'avg_resting_hr': avgRestingHr != null && rhrCount > 0 ? avgRestingHr / rhrCount : null,
          'avg_hr': avgHr != null && hrCount > 0 ? avgHr / hrCount : null,
          'avg_hrv': avgHrv != null && hrvCount > 0 ? avgHrv / hrvCount : null,
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
    
    // Debug logging
    debugPrint('🔍 _getMetricValue Debug - Looking for key: $key, found: ${m.runtimeType}, value: $m');
    
    if (m == null) {
      debugPrint('❌ _getMetricValue Debug - Key $key not found in metrics');
      return null;
    }
    
    // Try Map with 'value' key (standard format: {"value": X, "unit": "..."})
    if (m is Map) {
      final value = m['value'];
      // If value is null, that's valid - return null (metric not available for this day)
      if (value == null) {
        debugPrint('ℹ️ _getMetricValue Debug - Map has null value for $key (metric not available)');
        return null;
      }
      // If value exists and is numeric, return it
      if (value is num) {
        debugPrint('✅ _getMetricValue Debug - Extracted from Map: $value');
        return value;
      }
      debugPrint('⚠️ _getMetricValue Debug - Map has value but it\'s not numeric: ${value.runtimeType}');
    }
    
    // Try direct num value
    if (m is num) {
      debugPrint('✅ _getMetricValue Debug - Direct num value: $m');
      return m;
    }
    
    // Try to parse if it's a string representation
    if (m is String) {
      try {
        final parsed = num.parse(m);
        debugPrint('✅ _getMetricValue Debug - Parsed from string: $parsed');
        return parsed;
      } catch (e) {
        debugPrint('❌ _getMetricValue Debug - Failed to parse string: $e');
      }
    }
    
    debugPrint('❌ _getMetricValue Debug - Unknown format for key $key: ${m.runtimeType}');
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
                          // Navigate to Details tab - this is handled by the parent HealthView
                          // We can't directly control tabs from here, so we'll just show a message
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Switch to the Details tab to view charts'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        tooltip: 'View detailed charts (Details tab)',
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


