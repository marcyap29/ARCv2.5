import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_app/prism/services/health_service.dart';
import 'package:my_app/mira/store/mcp/mcp_fs.dart';
import 'package:my_app/services/health_data_service.dart';
import 'package:my_app/services/health_data_refresh_service.dart';
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
  
  // Hybrid mode state
  bool _isAutoMode = false;
  bool _refreshingHealth = false;
  String? _healthDataSource;
  DateTime? _healthDataLastUpdated;
  
  // Refresh settings state
  DateTime? _lastRefreshTime;
  bool _autoRefreshEnabled = true;
  String _refreshTime = "08:00";
  bool _refreshingNow = false;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
    _loadRefreshSettings();
  }
  
  Future<void> _loadRefreshSettings() async {
    try {
      final refreshService = HealthDataRefreshService.instance;
      await refreshService.initialize();
      
      final lastRefresh = await refreshService.getLastRefreshTime();
      final autoRefreshEnabled = await refreshService.isAutoRefreshEnabled();
      final refreshTime = await refreshService.getRefreshTime();
      
      if (mounted) {
        setState(() {
          _lastRefreshTime = lastRefresh;
          _autoRefreshEnabled = autoRefreshEnabled;
          _refreshTime = refreshTime;
        });
      }
    } catch (e) {
      debugPrint('Error loading refresh settings: $e');
    }
  }

  Future<void> _loadHealthData() async {
    try {
      // Check if auto-detected health data is available
      final autoHealthData = await HealthDataService.instance.getAutoDetectedHealthData();
      final manualHealthData = await HealthDataService.instance.getHealthData();
      
      // Determine mode: Auto if auto data is not stale/default, else Manual
      final hasAutoData = !autoHealthData.isStale && 
                         (autoHealthData.sleepQuality != 0.7 || autoHealthData.energyLevel != 0.7);
      
      if (mounted) {
        setState(() {
          _isAutoMode = hasAutoData;
          if (_isAutoMode) {
            _sleepQuality = autoHealthData.sleepQuality;
            _energyLevel = autoHealthData.energyLevel;
            _healthDataSource = 'Apple Health';
            _healthDataLastUpdated = autoHealthData.lastUpdated ?? DateTime.now();
          } else {
            _sleepQuality = manualHealthData.sleepQuality;
            _energyLevel = manualHealthData.energyLevel;
            _healthDataSource = null;
            _healthDataLastUpdated = manualHealthData.lastUpdated;
          }
          _loadingHealthData = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading health data: $e');
      if (mounted) {
        setState(() {
          _isAutoMode = false;
          _loadingHealthData = false;
        });
      }
    }
  }
  
  Future<void> _refreshFromHealth() async {
    setState(() => _refreshingHealth = true);
    try {
      final autoHealthData = await HealthDataService.instance.getAutoDetectedHealthData();
      
      if (mounted) {
        setState(() {
          _sleepQuality = autoHealthData.sleepQuality;
          _energyLevel = autoHealthData.energyLevel;
          _healthDataLastUpdated = DateTime.now();
          _refreshingHealth = false;
        });
        
        // Save the refreshed data
        await HealthDataService.instance.updateHealthData(
          sleepQuality: _sleepQuality,
          energyLevel: _energyLevel,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health data refreshed from Apple Health'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _refreshingHealth = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  void _switchToManualMode() {
    setState(() {
      _isAutoMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Switched to manual mode'),
        duration: Duration(seconds: 1),
      ),
    );
  }
  
  void _switchToAutoMode() async {
    setState(() => _isAutoMode = true);
    await _refreshFromHealth();
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
    if (!mounted) return;
    
    setState(() {
      _importing = true;
      _importStatus = 'Importing $daysBack days of health data...';
    });

    try {
      debugPrint('🔍 Health Import Debug - Starting process...');
      
      // Check platform first
      if (!Platform.isIOS) {
        throw Exception('Health data import is only available on iOS');
      }
      
      debugPrint('🔍 Health Import Debug - Creating Health instance...');
      final health = Health();

      debugPrint('🔍 Health Import Debug - Requesting authorization...');
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
      ]).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('❌ Health Import Debug - Authorization timeout');
          return false;
        },
      );

      debugPrint('🔍 Health Import Debug - Authorization result: $granted');

      if (!granted) {
        if (!mounted) return;
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

      debugPrint('🔍 Health Import Debug - Creating HealthIngest...');
      final ingest = HealthIngest(health);
      final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';

      debugPrint('🔍 Health Import Debug - Starting import for $daysBack days');
      debugPrint('🔍 Health Import Debug - UID: $uid');

      final lines = await ingest.importDays(daysBack: daysBack, uid: uid).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('❌ Health Import Debug - Import timeout');
          return <Map<String, dynamic>>[];
        },
      );

      debugPrint('🔍 Health Import Debug - Import completed. Lines returned: ${lines.length}');
      
      if (lines.isEmpty) {
        debugPrint('❌ Health Import Debug - NO DATA RETURNED');
        debugPrint('❌ Possible reasons:');
        debugPrint('❌ 1. No health data in Apple Health for this date range');
        debugPrint('❌ 2. Running on iOS Simulator (HealthKit not supported)');
        debugPrint('❌ 3. Health data types not available');
      }

      if (lines.isNotEmpty) {
        debugPrint('🔍 Health Import Debug - Writing ${lines.length} entries to file...');
        try {
          final first = (lines.first['timeslice'] as Map)['start'] as String;
          final monthKey = first.substring(0, 7);
          final file = await McpFs.healthMonth(monthKey);
          debugPrint('🔍 Health Import Debug - File path: ${file.path}');
          
          final sink = file.openWrite(mode: FileMode.append);
          for (final m in lines) {
            sink.writeln(jsonEncode(m));
          }
          await sink.close();
          debugPrint('✅ Health Import Debug - Successfully wrote ${lines.length} entries');
        } catch (fileError) {
          debugPrint('❌ Health Import Debug - File write error: $fileError');
          throw Exception('Failed to save health data: $fileError');
        }
      }

      if (!mounted) return;
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
              content: Text('Import completed - No health data found in Apple Health'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported ${lines.length} days of health data'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Health Import Debug - CRASH: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      
      if (!mounted) return;
      setState(() {
        _importStatus = 'Error: ${e.toString().split('\n').first}';
        _importing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: ${e.toString().split('\n').first}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Import Error Details'),
                    content: SingleChildScrollView(
                      child: Text('$e\n\nStack trace:\n$stackTrace'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
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
          _isAutoMode
              ? 'Health data is automatically detected from Apple Health. You can override to set manually.'
              : 'Tell LUMARA how you\'re feeling right now. This helps LUMARA adapt its tone and depth to match your current state.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        
        // Mode Toggle
        _buildModeToggle(context),
        
        const SizedBox(height: 16),
        
        // Refresh Settings Section
        _buildRefreshSettingsSection(context),
        
        const SizedBox(height: 16),
        // Explanatory cards
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bedtime, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Sleep Quality',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'How rested do you feel? Low = tired/groggy, High = refreshed/alert',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Energy Level',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'How much mental/physical energy do you have? Low = drained/overwhelmed, High = energized/focused',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        if (_loadingHealthData)
          const Center(child: CircularProgressIndicator())
        else ...[
          // Show auto mode or manual mode UI
          if (_isAutoMode) ...[
            _buildAutoModeDisplay(context),
          ] else ...[
            // Manual Mode - Sliders
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
            
            _buildHealthSlider(
              context: context,
              label: 'Energy Level',
              icon: Icons.bolt,
              value: _energyLevel,
              onChanged: (v) => setState(() => _energyLevel = v),
              lowLabel: 'Low',
              highLabel: 'High',
            ),
            
            // Reset to Auto button (if health data available)
            if (_healthDataSource != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _switchToAutoMode,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset to Auto'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple,
                  side: const BorderSide(color: Colors.purple),
                ),
              ),
            ],
          ],
          
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
  
  Widget _buildModeToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isAutoMode = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: !_isAutoMode ? Colors.purple.withOpacity(0.3) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    'Manual',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: !_isAutoMode ? Colors.white : Colors.grey,
                      fontWeight: !_isAutoMode ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_healthDataSource != null) {
                  _switchToAutoMode();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No health data available. Please import health data first.'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: _isAutoMode ? Colors.purple.withOpacity(0.3) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    'Auto (Health)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _isAutoMode ? Colors.white : Colors.grey,
                      fontWeight: _isAutoMode ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAutoModeDisplay(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sleep Quality Card
        _buildAutoModeCard(
          context: context,
          label: 'Sleep Quality',
          icon: Icons.bedtime,
          value: _sleepQuality,
          source: _healthDataSource,
          lastUpdated: _healthDataLastUpdated,
          onRefresh: _refreshFromHealth,
          refreshing: _refreshingHealth,
          onOverride: _switchToManualMode,
        ),
        
        const SizedBox(height: 16),
        
        // Energy Level Card
        _buildAutoModeCard(
          context: context,
          label: 'Energy Level',
          icon: Icons.bolt,
          value: _energyLevel,
          source: _healthDataSource,
          lastUpdated: _healthDataLastUpdated,
          onRefresh: _refreshFromHealth,
          refreshing: _refreshingHealth,
          onOverride: _switchToManualMode,
        ),
      ],
    );
  }
  
  Widget _buildAutoModeCard({
    required BuildContext context,
    required String label,
    required IconData icon,
    required double value,
    required String? source,
    required DateTime? lastUpdated,
    required VoidCallback onRefresh,
    required bool refreshing,
    required VoidCallback onOverride,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
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
          const SizedBox(height: 12),
          
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: Colors.grey.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(_getValueColor(value)),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Source Info
          if (source != null) ...[
            Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.purple),
                const SizedBox(width: 6),
                Text(
                  'From $source',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.purple,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (lastUpdated != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last updated: ${_formatLastUpdated(lastUpdated)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 12),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: refreshing ? null : onRefresh,
                    icon: refreshing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: const BorderSide(color: Colors.purple),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: onOverride,
                    child: const Text('Override'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  String _formatLastUpdated(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
  
  Widget _buildRefreshSettingsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Auto-Refresh Settings',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Last refresh time
          if (_lastRefreshTime != null) ...[
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Last refreshed: ${_formatRefreshTime(_lastRefreshTime!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Never refreshed',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          
          // Auto-refresh toggle
          SwitchListTile(
            title: const Text('Auto-refresh health data'),
            subtitle: const Text('Automatically refresh from Apple Health'),
            value: _autoRefreshEnabled,
            onChanged: (value) async {
              setState(() => _autoRefreshEnabled = value);
              await HealthDataRefreshService.instance.setAutoRefreshEnabled(value);
              if (value) {
                await HealthDataRefreshService.instance.startScheduledRefresh();
              }
            },
            contentPadding: EdgeInsets.zero,
          ),
          
          // Refresh time picker
          if (_autoRefreshEnabled) ...[
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.alarm, size: 20),
              title: const Text('Refresh time'),
              subtitle: Text(_formatRefreshTimeString(_refreshTime)),
              trailing: const Icon(Icons.chevron_right),
              contentPadding: EdgeInsets.zero,
              onTap: () => _showTimePicker(context),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Refresh Now button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _refreshingNow ? null : _refreshNow,
              icon: _refreshingNow
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: Text(_refreshingNow ? 'Refreshing...' : 'Refresh Now'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatRefreshTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final refreshDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (refreshDate == today) {
      // Today - show time
      final hour = dateTime.hour;
      final minute = dateTime.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return 'Today at ${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } else if (refreshDate == today.subtract(const Duration(days: 1))) {
      // Yesterday
      final hour = dateTime.hour;
      final minute = dateTime.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return 'Yesterday at ${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } else {
      // Older
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
  
  String _formatRefreshTimeString(String timeString) {
    final parts = timeString.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
  
  Future<void> _showTimePicker(BuildContext context) async {
    final parts = _refreshTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    
    if (picked != null && mounted) {
      final newTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() => _refreshTime = newTime);
      await HealthDataRefreshService.instance.setRefreshTime(newTime);
    }
  }
  
  Future<void> _refreshNow() async {
    setState(() => _refreshingNow = true);
    try {
      await HealthDataRefreshService.instance.forceRefresh();
      
      // Reload health data and refresh settings
      await _loadHealthData();
      await _loadRefreshSettings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health data refreshed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _refreshingNow = false);
      }
    }
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

