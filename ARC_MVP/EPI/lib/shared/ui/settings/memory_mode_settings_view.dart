// lib/features/settings/memory_mode_settings_view.dart
// Memory mode settings UI for configuring how LUMARA uses memories

import 'package:flutter/material.dart';
import 'package:my_app/mira/memory/memory_mode_service.dart';
import 'package:my_app/mira/memory/enhanced_memory_schema.dart';
import 'package:my_app/mira/memory/lifecycle_management_service.dart';

/// Settings screen for memory retrieval modes
class MemoryModeSettingsView extends StatefulWidget {
  final MemoryModeService? memoryModeService;

  const MemoryModeSettingsView({
    super.key,
    this.memoryModeService,
  });

  @override
  State<MemoryModeSettingsView> createState() => _MemoryModeSettingsViewState();
}

class _MemoryModeSettingsViewState extends State<MemoryModeSettingsView> {
  late MemoryModeService _modeService;
  late LifecycleManagementService _lifecycleService;
  bool _loading = true;
  bool _showAdvanced = false;
  bool _showLifecycle = false;
  // Tracking variables for slider adjustment state
  // ignore: unused_field
  bool _isAdjustingDecay = false;
  // ignore: unused_field
  bool _isAdjustingReinforcement = false;

  @override
  void initState() {
    super.initState();
    _modeService = widget.memoryModeService ?? MemoryModeService();
    _lifecycleService = LifecycleManagementService();
    _initializeService();
  }

  Future<void> _initializeService() async {
    setState(() => _loading = true);
    try {
      await _modeService.initialize();
    } catch (e) {
      debugPrint('Error initializing memory mode service: $e');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Modes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
            tooltip: 'Help',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildIntroCard(),
                const SizedBox(height: 24),
                _buildGlobalModeSection(),
                const SizedBox(height: 24),
                _buildDomainModesSection(),
                const SizedBox(height: 24),
                _buildAdvancedSection(),
                const SizedBox(height: 24),
                _buildLifecycleSection(),
                const SizedBox(height: 24),
                _buildModeDescriptions(),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildIntroCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.memory,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Control Your Memory',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Choose how LUMARA uses your memories. You can set a default mode for all memories, or customize by domain (work, health, etc.).',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalModeSection() {
    final currentMode = _modeService.config.globalMode;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Global Memory Mode',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Default for all memory domains',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildModeChip(MemoryMode.alwaysOn, currentMode),
                _buildModeChip(MemoryMode.suggestive, currentMode),
                _buildModeChip(MemoryMode.askFirst, currentMode),
                _buildModeChip(MemoryMode.highConfidenceOnly, currentMode),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _getModeIcon(currentMode),
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      MemoryModeService.getModeDescription(
                        currentMode,
                        threshold: _modeService.config.highConfidenceThreshold,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(MemoryMode mode, MemoryMode currentMode) {
    final isSelected = mode == currentMode;

    return FilterChip(
      label: Text(MemoryModeService.getModeDisplayName(mode)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _setGlobalMode(mode);
        }
      },
      avatar: Icon(
        _getModeIcon(mode),
        size: 16,
        color: isSelected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildDomainModesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Domain-Specific Modes',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Customize for specific areas (optional)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...MemoryDomain.values.where((d) => d != MemoryDomain.meta).map(
              (domain) => _buildDomainModeRow(domain),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDomainModeRow(MemoryDomain domain) {
    final domainMode = _modeService.config.domainModes[domain];
    final effectiveMode = domainMode ?? _modeService.config.globalMode;
    final hasOverride = domainMode != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getDomainDisplayName(domain),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (hasOverride)
                  Text(
                    'Override active',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: DropdownButton<MemoryMode?>(
                    value: domainMode,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem<MemoryMode?>(
                        value: null,
                        child: Text(
                          'Use Global (${MemoryModeService.getModeDisplayName(effectiveMode)})',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      ...MemoryMode.values.map((mode) => DropdownMenuItem(
                        value: mode,
                        child: Row(
                          children: [
                            Icon(_getModeIcon(mode), size: 16),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                MemoryModeService.getModeDisplayName(mode),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                    onChanged: (mode) {
                      if (mode == null) {
                        _clearDomainMode(domain);
                      } else {
                        _setDomainMode(domain, mode);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _showAdvanced = !_showAdvanced),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Advanced Settings',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    _showAdvanced ? Icons.expand_less : Icons.expand_more,
                  ),
                ],
              ),
            ),
            if (_showAdvanced) ...[
              const SizedBox(height: 16),
              _buildConfidenceThresholdSlider(),
              const SizedBox(height: 16),
              _buildSuggestionsToggle(),
              const SizedBox(height: 16),
              _buildResetButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceThresholdSlider() {
    final threshold = _modeService.config.highConfidenceThreshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'High Confidence Threshold',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              '${(threshold * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Only use memories above this confidence level when in "High Confidence Only" mode',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Slider(
          value: threshold,
          min: 0.5,
          max: 0.95,
          divisions: 9,
          label: '${(threshold * 100).toInt()}%',
          onChanged: (value) {
            setState(() {
              _modeService.setHighConfidenceThreshold(value);
            });
          },
        ),
      ],
    );
  }

  Widget _buildSuggestionsToggle() {
    final showSuggestions = _modeService.config.showSuggestions;

    return SwitchListTile(
      title: Text(
        'Show Memory Suggestions',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(
        'Display suggestion details in prompts',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      value: showSuggestions,
      onChanged: (value) {
        setState(() {
          _modeService.setShowSuggestions(value);
        });
      },
    );
  }

  Widget _buildResetButton() {
    return OutlinedButton.icon(
      onPressed: _resetToDefaults,
      icon: const Icon(Icons.restore),
      label: const Text('Reset to Defaults'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  Widget _buildLifecycleSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _showLifecycle = !_showLifecycle),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.timeline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Memory Lifecycle',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _showLifecycle ? Icons.expand_less : Icons.expand_more,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Control how memories decay and get reinforced over time',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (_showLifecycle) ...[
              const SizedBox(height: 16),
              _buildDecaySettings(),
              const SizedBox(height: 16),
              _buildReinforcementSettings(),
              const SizedBox(height: 16),
              _buildLifecycleStats(),
              const SizedBox(height: 16),
              _buildLifecycleResetButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDecaySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Decay Settings',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Memories naturally decay over time. You can adjust the decay rates for different domains.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...MemoryDomain.values.where((d) => d != MemoryDomain.meta).map(
          (domain) => _buildDomainDecayRow(domain),
        ),
      ],
    );
  }

  Widget _buildDomainDecayRow(MemoryDomain domain) {
    // Get the decay strategy for this domain
    final strategy = _lifecycleService.getDecayStrategy(domain);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getDomainDisplayName(domain),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${(strategy.baseDecayRate * 100).toStringAsFixed(1)}%/month',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _getDecayIcon(strategy.decayFunction),
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: strategy.baseDecayRate,
            min: 0.001, // 0.1% per month
            max: 0.1,   // 10% per month
            divisions: 99,
            label: '${(strategy.baseDecayRate * 100).toStringAsFixed(1)}%/month',
            onChangeStart: (value) {
              // Start tracking that we're adjusting
              _isAdjustingDecay = true;
            },
            onChanged: (value) {
              // Update the value silently while adjusting
              _lifecycleService.updateDecayRate(domain, value);
              setState(() {});
            },
            onChangeEnd: (value) {
              // Show popup only when finished adjusting
              _isAdjustingDecay = false;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${_getDomainDisplayName(domain)} decay rate updated to ${(value * 100).toStringAsFixed(1)}%/month'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReinforcementSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reinforcement Settings',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Memories get stronger when you interact with them. Reinforcement sensitivity varies by domain.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...MemoryDomain.values.where((d) => d != MemoryDomain.meta).map(
          (domain) => _buildDomainReinforcementRow(domain),
        ),
      ],
    );
  }

  Widget _buildDomainReinforcementRow(MemoryDomain domain) {
    final strategy = _lifecycleService.getDecayStrategy(domain);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getDomainDisplayName(domain),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${(strategy.reinforcementSensitivity * 100).toInt()}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.trending_up,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: strategy.reinforcementSensitivity,
            min: 0.1,  // 10%
            max: 1.0,  // 100%
            divisions: 90,
            label: '${(strategy.reinforcementSensitivity * 100).toInt()}%',
            onChangeStart: (value) {
              // Start tracking that we're adjusting
              _isAdjustingReinforcement = true;
            },
            onChanged: (value) {
              // Update the value silently while adjusting
              _lifecycleService.updateReinforcementSensitivity(domain, value);
              setState(() {});
            },
            onChangeEnd: (value) {
              // Show popup only when finished adjusting
              _isAdjustingReinforcement = false;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${_getDomainDisplayName(domain)} reinforcement sensitivity updated to ${(value * 100).toInt()}%'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLifecycleStats() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getLifecycleStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Text(
            'Error loading stats: ${snapshot.error}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          );
        }
        
        final stats = snapshot.data ?? {};
        final avgDecay = stats['avg_decay_score'] as double? ?? 0.0;
        final avgReinforcement = stats['avg_reinforcement'] as double? ?? 0.0;
        
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Memory Health',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Avg Decay',
                    '${(avgDecay * 100).toInt()}%',
                    Icons.trending_down,
                    avgDecay > 0.7 ? Colors.green : avgDecay > 0.4 ? Colors.orange : Colors.red,
                  ),
                  _buildStatItem(
                    'Avg Reinforcement',
                    '${avgReinforcement.toStringAsFixed(1)}/5',
                    Icons.trending_up,
                    avgReinforcement > 2.0 ? Colors.green : avgReinforcement > 1.0 ? Colors.orange : Colors.red,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  IconData _getDecayIcon(DecayFunction function) {
    switch (function) {
      case DecayFunction.linear:
        return Icons.trending_down;
      case DecayFunction.exponential:
        return Icons.trending_down;
      case DecayFunction.logarithmic:
        return Icons.trending_down;
      case DecayFunction.spaced_repetition:
        return Icons.schedule;
      case DecayFunction.step_wise:
        return Icons.stairs;
    }
  }

  Future<Map<String, dynamic>> _getLifecycleStats() async {
    // For now, return mock data since we don't have access to actual memory nodes
    // In a real implementation, you'd get this from the memory service
    return {
      'avg_decay_score': 0.75,
      'avg_reinforcement': 2.3,
      'total_memories': 0,
      'scheduled_for_decay': 0,
    };
  }


  Widget _buildLifecycleResetButton() {
    return OutlinedButton.icon(
      onPressed: _resetLifecycleToDefaults,
      icon: const Icon(Icons.restore),
      label: const Text('Reset Lifecycle to Defaults'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  Future<void> _resetLifecycleToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Lifecycle Settings?'),
        content: const Text(
          'This will reset all decay rates and reinforcement sensitivity to their default values. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Reinitialize the lifecycle service to reset to defaults
      _lifecycleService = LifecycleManagementService();
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lifecycle settings reset to defaults'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildModeDescriptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mode Guide',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildModeGuideItem(
              MemoryMode.alwaysOn,
              'Best for: Active journaling sessions',
            ),
            _buildModeGuideItem(
              MemoryMode.suggestive,
              'Best for: Balanced control (Recommended)',
            ),
            _buildModeGuideItem(
              MemoryMode.askFirst,
              'Best for: Maximum privacy control',
            ),
            _buildModeGuideItem(
              MemoryMode.highConfidenceOnly,
              'Best for: High-stakes decisions',
            ),
            _buildModeGuideItem(
              MemoryMode.soft,
              'Best for: Gentle guidance',
            ),
            _buildModeGuideItem(
              MemoryMode.hard,
              'Best for: Factual recall',
            ),
            _buildModeGuideItem(
              MemoryMode.disabled,
              'Best for: Fresh start',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeGuideItem(MemoryMode mode, String useCase) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _getModeIcon(mode),
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MemoryModeService.getModeDisplayName(mode),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  MemoryModeService.getModeDescription(
                    mode,
                    threshold: _modeService.config.highConfidenceThreshold,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  useCase,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getModeIcon(MemoryMode mode) {
    switch (mode) {
      case MemoryMode.alwaysOn:
        return Icons.auto_mode;
      case MemoryMode.suggestive:
        return Icons.lightbulb_outline;
      case MemoryMode.askFirst:
        return Icons.question_answer;
      case MemoryMode.highConfidenceOnly:
        return Icons.verified;
      case MemoryMode.soft:
        return Icons.cloud_outlined;
      case MemoryMode.hard:
        return Icons.lock;
      case MemoryMode.disabled:
        return Icons.block;
    }
  }

  String _getDomainDisplayName(MemoryDomain domain) {
    final name = domain.name;
    return name[0].toUpperCase() + name.substring(1);
  }

  Future<void> _setGlobalMode(MemoryMode mode) async {
    await _modeService.setGlobalMode(mode);
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Global mode set to ${MemoryModeService.getModeDisplayName(mode)}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _setDomainMode(MemoryDomain domain, MemoryMode mode) async {
    await _modeService.setDomainMode(domain, mode);
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_getDomainDisplayName(domain)} set to ${MemoryModeService.getModeDisplayName(mode)}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearDomainMode(MemoryDomain domain) async {
    await _modeService.clearDomainMode(domain);
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_getDomainDisplayName(domain)} reset to global mode'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults?'),
        content: const Text(
          'This will reset all memory mode settings to their default values. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _modeService.resetToDefaults();
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings reset to defaults'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Memory Modes Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Memory modes control how LUMARA uses your journal entries and memories in conversations.',
              ),
              const SizedBox(height: 16),
              Text(
                'Quick Guide:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              const Text('• Suggestive: Recommended for most users\n'
                  '• Ask First: Maximum control and privacy\n'
                  '• Always On: Seamless memory integration\n'
                  '• High Confidence: Critical decisions only'),
              const SizedBox(height: 16),
              Text(
                'Domain Overrides:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'You can set different modes for different areas. For example:\n'
                '• Health: Ask First (privacy)\n'
                '• Creative: Always On (inspiration)\n'
                '• Work: High Confidence (accuracy)',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}