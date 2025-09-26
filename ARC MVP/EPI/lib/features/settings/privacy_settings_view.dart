// lib/features/settings/privacy_settings_view.dart
// Privacy Settings UI for user-configurable PII protection

import 'package:flutter/material.dart';
import '../../services/privacy/privacy_settings_service.dart';
import '../../services/privacy/pii_detection_service.dart';
import '../privacy/privacy_demo_screen.dart';

class PrivacySettingsView extends StatefulWidget {
  const PrivacySettingsView({super.key});

  @override
  State<PrivacySettingsView> createState() => _PrivacySettingsViewState();
}

class _PrivacySettingsViewState extends State<PrivacySettingsView> {
  final PrivacySettingsService _settingsService = PrivacySettingsService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settingsService.initialize();
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.science),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacyDemoScreen(),
                ),
              );
            },
            tooltip: 'Test Privacy Protection',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildPrivacyLevelSection(),
            const SizedBox(height: 16),
            _buildDetectionSettings(),
            const SizedBox(height: 16),
            _buildMaskingSettings(),
            const SizedBox(height: 16),
            _buildSecuritySettings(),
            const SizedBox(height: 16),
            _buildPerformanceSettings(),
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Privacy Protection',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Control how your personal information is protected when using AI features. '
              'Higher protection levels provide better privacy but may affect text readability.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _settingsService.getPrivacyImpactDescription(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildPrivacyLevelSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Level',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...PrivacyLevel.values.map((level) {
              return RadioListTile<PrivacyLevel>(
                title: Text(level.displayName),
                subtitle: Text(level.description),
                value: level,
                groupValue: _settingsService.currentLevel,
                onChanged: (PrivacyLevel? value) async {
                  if (value != null) {
                    await _settingsService.setPrivacyLevel(value);
                    setState(() {});
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionSettings() {
    if (_settingsService.currentLevel != PrivacyLevel.custom) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detection Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // Sensitivity Level
            ListTile(
              title: const Text('Detection Sensitivity'),
              subtitle: Text(_getSensitivityDescription()),
              trailing: DropdownButton<SensitivityLevel>(
                value: _settingsService.currentSettings.detectionSensitivity,
                onChanged: (SensitivityLevel? value) async {
                  if (value != null) {
                    final newSettings = _settingsService.currentSettings.copyWith(
                      detectionSensitivity: value,
                    );
                    await _settingsService.updateSettings(newSettings);
                    setState(() {});
                  }
                },
                items: SensitivityLevel.values.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level.toString().split('.').last.toUpperCase()),
                  );
                }).toList(),
              ),
            ),

            const Divider(),

            // PII Types
            Text(
              'Protected Information Types',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),

            ...PIIType.values.map((type) {
              final isEnabled = _settingsService.currentSettings.enabledPIITypes.contains(type);
              return CheckboxListTile(
                title: Text(_getPIITypeDisplayName(type)),
                subtitle: Text(_getPIITypeDescription(type)),
                value: isEnabled,
                onChanged: (bool? value) async {
                  final enabledTypes = Set<PIIType>.from(_settingsService.currentSettings.enabledPIITypes);
                  if (value == true) {
                    enabledTypes.add(type);
                  } else {
                    enabledTypes.remove(type);
                  }

                  final newSettings = _settingsService.currentSettings.copyWith(
                    enabledPIITypes: enabledTypes,
                  );
                  await _settingsService.updateSettings(newSettings);
                  setState(() {});
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMaskingSettings() {
    if (_settingsService.currentLevel != PrivacyLevel.custom) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masking Options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Preserve Text Structure'),
              subtitle: const Text('Maintain formatting and readability'),
              value: _settingsService.currentSettings.preserveStructure,
              onChanged: (bool value) async {
                final newSettings = _settingsService.currentSettings.copyWith(
                  preserveStructure: value,
                );
                await _settingsService.updateSettings(newSettings);
                setState(() {});
              },
            ),

            SwitchListTile(
              title: const Text('Consistent Mapping'),
              subtitle: const Text('Same person always gets same token'),
              value: _settingsService.currentSettings.consistentMapping,
              onChanged: (bool value) async {
                final newSettings = _settingsService.currentSettings.copyWith(
                  consistentMapping: value,
                );
                await _settingsService.updateSettings(newSettings);
                setState(() {});
              },
            ),

            SwitchListTile(
              title: const Text('Hash Email Addresses'),
              subtitle: const Text('Generate SHA256 hashes for emails'),
              value: _settingsService.currentSettings.hashEmails,
              onChanged: (bool value) async {
                final newSettings = _settingsService.currentSettings.copyWith(
                  hashEmails: value,
                );
                await _settingsService.updateSettings(newSettings);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySettings() {
    if (_settingsService.currentLevel != PrivacyLevel.custom) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security & Compliance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('API Guardrail Protection'),
              subtitle: const Text('Block requests with unmasked PII'),
              value: _settingsService.currentSettings.enableInterceptor,
              onChanged: (bool value) async {
                final newSettings = _settingsService.currentSettings.copyWith(
                  enableInterceptor: value,
                );
                await _settingsService.updateSettings(newSettings);
                setState(() {});
              },
            ),

            SwitchListTile(
              title: const Text('Strict Blocking'),
              subtitle: const Text('Block on any privacy violation'),
              value: _settingsService.currentSettings.blockOnViolation,
              onChanged: (bool value) async {
                final newSettings = _settingsService.currentSettings.copyWith(
                  blockOnViolation: value,
                );
                await _settingsService.updateSettings(newSettings);
                setState(() {});
              },
            ),

            SwitchListTile(
              title: const Text('Audit Logging'),
              subtitle: const Text('Log privacy violations for review'),
              value: _settingsService.currentSettings.auditLogging,
              onChanged: (bool value) async {
                final newSettings = _settingsService.currentSettings.copyWith(
                  auditLogging: value,
                );
                await _settingsService.updateSettings(newSettings);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Expected impact: ${_settingsService.getPerformanceImpact()}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            if (_settingsService.currentLevel == PrivacyLevel.custom) ...[
              SwitchListTile(
                title: const Text('Real-time Scanning'),
                subtitle: const Text('Scan text as you type'),
                value: _settingsService.currentSettings.enableRealTimeScanning,
                onChanged: (bool value) async {
                  final newSettings = _settingsService.currentSettings.copyWith(
                    enableRealTimeScanning: value,
                  );
                  await _settingsService.updateSettings(newSettings);
                  setState(() {});
                },
              ),

              ListTile(
                title: const Text('Processing Timeout'),
                subtitle: Text('${_settingsService.currentSettings.maxProcessingTime}ms'),
                trailing: SizedBox(
                  width: 200,
                  child: Slider(
                    value: _settingsService.currentSettings.maxProcessingTime.toDouble(),
                    min: 100,
                    max: 5000,
                    divisions: 49,
                    label: '${_settingsService.currentSettings.maxProcessingTime}ms',
                    onChanged: (double value) async {
                      final newSettings = _settingsService.currentSettings.copyWith(
                        maxProcessingTime: value.round(),
                      );
                      await _settingsService.updateSettings(newSettings);
                      setState(() {});
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyDemoScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.science),
              label: const Text('Test Privacy Protection'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Reset to Defaults'),
                    content: const Text('This will reset all privacy settings to recommended defaults.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await _settingsService.resetToDefaults();
                  setState(() {});

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Privacy settings reset to defaults')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset to Defaults'),
            ),
          ],
        ),
      ),
    );
  }

  String _getSensitivityDescription() {
    switch (_settingsService.currentSettings.detectionSensitivity) {
      case SensitivityLevel.strict:
        return 'Aggressive detection, may have false positives';
      case SensitivityLevel.normal:
        return 'Balanced detection for general use';
      case SensitivityLevel.relaxed:
        return 'Conservative detection, fewer false positives';
    }
  }

  String _getPIITypeDisplayName(PIIType type) {
    switch (type) {
      case PIIType.name:
        return 'Names';
      case PIIType.email:
        return 'Email Addresses';
      case PIIType.phone:
        return 'Phone Numbers';
      case PIIType.address:
        return 'Physical Addresses';
      case PIIType.ssn:
        return 'Social Security Numbers';
      case PIIType.creditCard:
        return 'Credit Card Numbers';
      case PIIType.ipAddress:
        return 'IP Addresses';
      case PIIType.url:
        return 'URLs';
      case PIIType.dateOfBirth:
        return 'Dates of Birth';
      case PIIType.other:
        return 'Other Sensitive Data';
    }
  }

  String _getPIITypeDescription(PIIType type) {
    switch (type) {
      case PIIType.name:
        return 'Personal names and titles';
      case PIIType.email:
        return 'Email addresses and contact info';
      case PIIType.phone:
        return 'Phone and fax numbers';
      case PIIType.address:
        return 'Street addresses and locations';
      case PIIType.ssn:
        return 'Government identification numbers';
      case PIIType.creditCard:
        return 'Payment card information';
      case PIIType.ipAddress:
        return 'Network identifiers';
      case PIIType.url:
        return 'Web addresses and links';
      case PIIType.dateOfBirth:
        return 'Birth dates and ages';
      case PIIType.other:
        return 'Other potentially sensitive information';
    }
  }
}