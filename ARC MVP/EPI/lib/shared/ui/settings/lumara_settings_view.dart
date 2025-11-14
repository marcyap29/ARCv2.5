import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/telemetry/analytics.dart';
import 'package:my_app/arc/chat/services/lumara_reflection_settings_service.dart';

class LumaraSettingsView extends StatefulWidget {
  const LumaraSettingsView({super.key});

  @override
  State<LumaraSettingsView> createState() => _LumaraSettingsViewState();
}

class _LumaraSettingsViewState extends State<LumaraSettingsView> {
  final _analytics = Analytics();
  
  // Settings state
  double _similarityThreshold = 0.55;
  int _lookbackYears = 5;
  int _maxMatches = 5;
  bool _crossModalEnabled = true;
  
  // Therapeutic Presence settings
  bool _therapeuticPresenceEnabled = true;
  int _therapeuticDepthLevel = 2; // 1=Light, 2=Moderate, 3=Deep

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settingsService = LumaraReflectionSettingsService.instance;
    final settings = await settingsService.loadAllSettings();
    
    if (mounted) {
      setState(() {
        _similarityThreshold = settings['similarityThreshold'] as double;
        _lookbackYears = settings['lookbackYears'] as int;
        _maxMatches = settings['maxMatches'] as int;
        _crossModalEnabled = settings['crossModalEnabled'] as bool;
        _therapeuticPresenceEnabled = settings['therapeuticPresenceEnabled'] as bool;
        _therapeuticDepthLevel = settings['therapeuticDepthLevel'] as int;
      });
    }
  }

  Future<void> _saveSettings() async {
    final settingsService = LumaraReflectionSettingsService.instance;
    await settingsService.saveAllSettings(
      similarityThreshold: _similarityThreshold,
      lookbackYears: _lookbackYears,
      maxMatches: _maxMatches,
      crossModalEnabled: _crossModalEnabled,
      therapeuticPresenceEnabled: _therapeuticPresenceEnabled,
      therapeuticDepthLevel: _therapeuticDepthLevel,
    );
    
    _analytics.logLumaraEvent('settings_updated', data: {
      'similarityThreshold': _similarityThreshold,
      'lookbackYears': _lookbackYears,
      'maxMatches': _maxMatches,
      'crossModalEnabled': _crossModalEnabled,
      'therapeuticPresenceEnabled': _therapeuticPresenceEnabled,
      'therapeuticDepthLevel': _therapeuticDepthLevel,
    });
  }
  
  Widget _buildDepthSliderTile(BuildContext context) {
    final depthLabels = ['Light', 'Moderate', 'Deep'];
    final depthDescriptions = [
      'Supportive and encouraging',
      'Reflective and insight-oriented',
      'Exploratory and emotionally resonant',
    ];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8, top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology,
                color: kcAccentColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Depth Level',
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      depthDescriptions[_therapeuticDepthLevel - 1],
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kcAccentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  depthLabels[_therapeuticDepthLevel - 1],
                  style: bodyStyle(context).copyWith(
                    color: kcAccentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: _therapeuticDepthLevel.toDouble(),
            min: 1,
            max: 3,
            divisions: 2,
            activeColor: kcAccentColor,
            inactiveColor: Colors.grey.withValues(alpha: 0.3),
            label: depthLabels[_therapeuticDepthLevel - 1],
            onChanged: (value) {
              setState(() {
                _therapeuticDepthLevel = value.round();
              });
              _saveSettings();
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: depthLabels.asMap().entries.map((entry) {
              final index = entry.key;
              final label = entry.value;
              final isSelected = _therapeuticDepthLevel == index + 1;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _therapeuticDepthLevel = index + 1;
                  });
                  _saveSettings();
                },
                child: Text(
                  label,
                  style: bodyStyle(context).copyWith(
                    color: isSelected ? kcAccentColor : kcSecondaryTextColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: Text(
          'LUMARA Settings',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reflection Settings Section
            _buildSection(
              context,
              title: 'Reflection Settings',
              children: [
                _buildSliderTile(
                  context,
                  title: 'Similarity Threshold',
                  subtitle: 'Minimum similarity score for matching entries (${_similarityThreshold.toStringAsFixed(2)})',
                  value: _similarityThreshold,
                  min: 0.1,
                  max: 1.0,
                  divisions: 18,
                  onChanged: (value) {
                    setState(() {
                      _similarityThreshold = value;
                    });
                    _saveSettings();
                  },
                ),
                _buildSliderTile(
                  context,
                  title: 'Lookback Period',
                  subtitle: 'Years of history to search ($_lookbackYears years)',
                  value: _lookbackYears.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: (value) {
                    setState(() {
                      _lookbackYears = value.round();
                    });
                    _saveSettings();
                  },
                ),
                _buildSliderTile(
                  context,
                  title: 'Max Matches',
                  subtitle: 'Maximum number of similar entries to find ($_maxMatches)',
                  value: _maxMatches.toDouble(),
                  min: 1,
                  max: 20,
                  divisions: 19,
                  onChanged: (value) {
                    setState(() {
                      _maxMatches = value.round();
                    });
                    _saveSettings();
                  },
                ),
                _buildSwitchTile(
                  context,
                  title: 'Cross-Modal Awareness',
                  subtitle: 'Include photos, audio, and video in reflection analysis',
                  value: _crossModalEnabled,
                  onChanged: (value) {
                    setState(() {
                      _crossModalEnabled = value;
                    });
                    _saveSettings();
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Therapeutic Presence Settings Section
            _buildSection(
              context,
              title: 'Therapeutic Presence',
              children: [
                _buildSwitchTile(
                  context,
                  title: 'Enable Therapeutic Presence',
                  subtitle: 'Warm, reflective support for journaling and emotional processing',
                  value: _therapeuticPresenceEnabled,
                  onChanged: (value) {
                    setState(() {
                      _therapeuticPresenceEnabled = value;
                    });
                    _saveSettings();
                  },
                ),
                if (_therapeuticPresenceEnabled) ...[
                  _buildDepthSliderTile(context),
                ],
              ],
            ),

            const SizedBox(height: 32),

            // About LUMARA Section
            _buildSection(
              context,
              title: 'About LUMARA',
              children: [
                _buildInfoCard(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Colors.blue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'LUMARA v2.0',
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'LUMARA is your multimodal reflective partner that connects your current thoughts to historical insights across text, photos, audio, and video.',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Features:',
            style: bodyStyle(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '• Semantic similarity matching\n• Phase-aware reflection prompts\n• Cross-modal pattern detection\n• 3-5 year historical lookback',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: heading2Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: kcAccentColor,
          size: 24,
        ),
        title: Text(
          title,
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
          ),
        ),
        trailing: onTap != null
            ? const Icon(
                Icons.arrow_forward_ios,
                color: kcSecondaryTextColor,
                size: 16,
              )
            : null,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: enabled 
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled 
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: enabled ? kcAccentColor : Colors.grey,
          size: 24,
        ),
        title: Text(
          title,
          style: heading3Style(context).copyWith(
            color: enabled ? kcPrimaryTextColor : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: bodyStyle(context).copyWith(
            color: enabled ? kcSecondaryTextColor : Colors.grey,
          ),
        ),
        trailing: enabled
            ? const Icon(
                Icons.arrow_forward_ios,
                color: kcSecondaryTextColor,
                size: 16,
              )
            : null,
        onTap: enabled ? onTap : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }

  Widget _buildSliderTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune,
                color: kcAccentColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: kcAccentColor,
            inactiveColor: Colors.grey.withValues(alpha: 0.3),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: kcAccentColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }
}