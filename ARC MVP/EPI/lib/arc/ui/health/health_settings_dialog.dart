import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_app/prism/services/health_service.dart';
import 'package:my_app/mira/store/mcp/mcp_fs.dart';
import 'package:my_app/services/health_data_service.dart';
import 'package:health/health.dart';

class HealthSettingsDialog extends StatefulWidget {
  const HealthSettingsDialog({super.key});

  @override
  State<HealthSettingsDialog> createState() => _HealthSettingsDialogState();
}

class _HealthSettingsDialogState extends State<HealthSettingsDialog> {
  bool _importing = false;
  String? _importStatus;
  
  // LUMARA health signals
  double _sleepQuality = 0.7;
  double _energyLevel = 0.7;
  bool _loadingHealthData = true;
  bool _savingHealthData = false;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    try {
      final healthData = await HealthDataService.instance.getHealthData();
      if (mounted) {
        setState(() {
          _sleepQuality = healthData.sleepQuality;
          _energyLevel = healthData.energyLevel;
          _loadingHealthData = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading health data: $e');
      if (mounted) {
        setState(() => _loadingHealthData = false);
      }
    }
  }

  Future<void> _saveHealthData() async {
    setState(() => _savingHealthData = true);
    try {
      await HealthDataService.instance.updateHealthData(
        sleepQuality: _sleepQuality,
        energyLevel: _energyLevel,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health data saved - LUMARA will adapt to your current state'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving health data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingHealthData = false);
      }
    }
  }

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
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
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
              
              // LUMARA Health Signals Section
              _buildLumaraHealthSection(context),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
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
      ),
    );
  }

  /// Build LUMARA Health Signals section
  Widget _buildLumaraHealthSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.psychology, color: Colors.purple, size: 20),
            const SizedBox(width: 8),
            Text(
              'LUMARA Health Signals',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'These values influence how LUMARA responds to you. Low sleep or energy will make LUMARA more supportive and gentle.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        
        if (_loadingHealthData)
          const Center(child: CircularProgressIndicator())
        else ...[
          // Sleep Quality Slider
          _buildHealthSlider(
            context: context,
            label: 'Sleep Quality',
            icon: Icons.bedtime,
            value: _sleepQuality,
            onChanged: (v) => setState(() => _sleepQuality = v),
            lowLabel: 'Poor',
            highLabel: 'Great',
          ),
          
          const SizedBox(height: 16),
          
          // Energy Level Slider
          _buildHealthSlider(
            context: context,
            label: 'Energy Level',
            icon: Icons.bolt,
            value: _energyLevel,
            onChanged: (v) => setState(() => _energyLevel = v),
            lowLabel: 'Low',
            highLabel: 'High',
          ),
          
          const SizedBox(height: 20),
          
          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savingHealthData ? null : _saveHealthData,
              icon: _savingHealthData 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_savingHealthData ? 'Saving...' : 'Save Health Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Effect preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getHealthEffectDescription(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.purple,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHealthSlider({
    required BuildContext context,
    required String label,
    required IconData icon,
    required double value,
    required ValueChanged<double> onChanged,
    required String lowLabel,
    required String highLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(
              '${(value * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _getValueColor(value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _getValueColor(value),
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
            thumbColor: _getValueColor(value),
            overlayColor: _getValueColor(value).withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(lowLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            Text(highLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Color _getValueColor(double value) {
    if (value < 0.4) return Colors.red;
    if (value < 0.6) return Colors.orange;
    return Colors.green;
  }

  String _getHealthEffectDescription() {
    if (_sleepQuality < 0.4 || _energyLevel < 0.4) {
      return 'LUMARA will be extra gentle and supportive today.';
    } else if (_sleepQuality < 0.6 || _energyLevel < 0.6) {
      return 'LUMARA will maintain a warm, balanced tone.';
    } else if (_sleepQuality > 0.7 && _energyLevel > 0.7) {
      return 'LUMARA may offer more direct insights and challenges.';
    }
    return 'LUMARA will adapt to your current state.';
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

