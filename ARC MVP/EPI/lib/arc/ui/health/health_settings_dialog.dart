import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_app/prism/services/health_service.dart';
import 'package:my_app/mira/store/mcp/mcp_fs.dart';
import 'package:health/health.dart';

class HealthSettingsDialog extends StatefulWidget {
  const HealthSettingsDialog({super.key});

  @override
  State<HealthSettingsDialog> createState() => _HealthSettingsDialogState();
}

class _HealthSettingsDialogState extends State<HealthSettingsDialog> {
  bool _importing = false;
  String? _importStatus;

  Future<void> _importHealth({required int daysBack}) async {
    setState(() {
      _importing = true;
      _importStatus = 'Importing $daysBack days of health data...';
    });

    try {
      final health = Health();

      // Check if HealthKit is available on this platform
      debugPrint('🔍 Health Import Debug - Checking HealthKit availability...');
      // Note: HealthKit is always available on iOS, unlike Android Health Connect
      final isIOS = Platform.isIOS;
      debugPrint('🔍 Health Import Debug - Platform is iOS: $isIOS');

      final granted = await health.requestAuthorization([
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED,
        HealthDataType.EXERCISE_TIME,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.HEART_RATE,
        HealthDataType.HEART_RATE_VARIABILITY_SDNN,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.WEIGHT,
        HealthDataType.WORKOUT,
      ]);

      if (!granted) {
        setState(() {
          _importStatus = 'HealthKit permission denied';
          _importing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('HealthKit permission denied')),
          );
        }
        return;
      }

      final ingest = HealthIngest(health);
      final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';

      // Debug: Log import attempt details
      debugPrint('🔍 Health Import Debug - Starting import for $daysBack days');
      debugPrint('🔍 Health Import Debug - UID: $uid');
      debugPrint('🔍 Health Import Debug - Platform: ${Platform.operatingSystem}');
      debugPrint('🔍 Health Import Debug - Environment: ${Platform.environment}');

      final lines = await ingest.importDays(daysBack: daysBack, uid: uid);

      // Debug: Log import results
      debugPrint('🔍 Health Import Debug - Import completed. Lines returned: ${lines.length}');
      if (lines.isEmpty) {
        debugPrint('❌ Health Import Debug - NO DATA RETURNED from HealthIngest.importDays()');
        debugPrint('❌ This means either:');
        debugPrint('❌ 1. HealthKit returned 0 data points');
        debugPrint('❌ 2. Running on iOS Simulator (HealthKit not supported)');
        debugPrint('❌ 3. Apple Health app has no data for requested types');
        debugPrint('❌ 4. Date range has no data');
      }

      if (lines.isNotEmpty) {
        final first = (lines.first['timeslice'] as Map)['start'] as String;
        final monthKey = first.substring(0, 7);
        final file = await McpFs.healthMonth(monthKey);
        debugPrint('Writing health data to: ${file.path}');
        final sink = file.openWrite(mode: FileMode.append);
        for (final m in lines) {
          sink.writeln(jsonEncode(m));
        }
        await sink.close();
        debugPrint('Wrote ${lines.length} health data lines to ${file.path}');
      }

      setState(() {
        if (lines.isEmpty) {
          _importStatus = 'Import completed - No health data found';
        } else {
          _importStatus = 'Successfully imported ${lines.length} days';
        }
        _importing = false;
      });

      if (mounted) {
        if (lines.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Import completed - No health data found. Check debug logs for details.'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully imported ${lines.length} days of health data')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _importStatus = 'Error: $e';
        _importing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Health Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Import Health Data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Import and aggregate health metrics from Apple Health for analysis. Select how many days of data to import.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ImportButton(
                    days: 30,
                    label: '30 Days',
                    description: 'Last month',
                    onPressed: _importing ? null : () => _importHealth(daysBack: 30),
                    importing: _importing,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ImportButton(
                    days: 60,
                    label: '60 Days',
                    description: 'Last 2 months',
                    onPressed: _importing ? null : () => _importHealth(daysBack: 60),
                    importing: _importing,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ImportButton(
                    days: 90,
                    label: '90 Days',
                    description: 'Last 3 months',
                    onPressed: _importing ? null : () => _importHealth(daysBack: 90),
                    importing: _importing,
                  ),
                ),
              ],
            ),
            if (_importing || _importStatus != null) ...[
              const SizedBox(height: 20),
              if (_importing) const LinearProgressIndicator(),
              if (_importStatus != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _importStatus!.startsWith('Error')
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _importStatus!.startsWith('Error')
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                          color: _importStatus!.startsWith('Error')
                              ? Colors.red
                              : Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _importStatus!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImportButton extends StatelessWidget {
  final int days;
  final String label;
  final String description;
  final VoidCallback? onPressed;
  final bool importing;

  const _ImportButton({
    required this.days,
    required this.label,
    required this.description,
    this.onPressed,
    required this.importing,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        side: BorderSide(
          color: onPressed == null
              ? Colors.grey.withOpacity(0.3)
              : Theme.of(context).primaryColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }
}

