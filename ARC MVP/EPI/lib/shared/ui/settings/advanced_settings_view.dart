// lib/shared/ui/settings/advanced_settings_view.dart
// Advanced Settings View - contains Analysis and LUMARA Engine settings

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/chat/services/lumara_reflection_settings_service.dart';
import 'package:my_app/shared/ui/settings/combined_analysis_view.dart';
import 'package:my_app/arc/chat/voice/transcription/transcription_provider.dart';
import 'package:my_app/services/assemblyai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdvancedSettingsView extends StatefulWidget {
  const AdvancedSettingsView({super.key});

  @override
  State<AdvancedSettingsView> createState() => _AdvancedSettingsViewState();
}

class _AdvancedSettingsViewState extends State<AdvancedSettingsView> {
  // LUMARA Engine settings
  double _similarityThreshold = 0.55;
  int _lookbackYears = 5;
  int _maxMatches = 5;
  bool _crossModalEnabled = true;
  bool _therapeuticAutomaticMode = false;
  bool _isLoading = true;
  
  // Voice & Transcription settings
  SttMode _sttMode = SttMode.auto;
  SttTier _userTier = SttTier.free;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      final settings = await settingsService.loadAllSettings();
      
      // Load transcription settings
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString('stt_mode');
      final sttMode = savedMode != null
          ? SttMode.values.firstWhere((m) => m.name == savedMode, orElse: () => SttMode.auto)
          : SttMode.auto;
      
      // Get user tier
      final assemblyAIService = AssemblyAIService();
      final userTier = await assemblyAIService.getUserTier();
      
      if (mounted) {
        setState(() {
          _similarityThreshold = settings['similarityThreshold'] as double;
          _lookbackYears = settings['lookbackYears'] as int;
          _maxMatches = settings['maxMatches'] as int;
          _crossModalEnabled = settings['crossModalEnabled'] as bool;
          _therapeuticAutomaticMode = settings['therapeuticAutomaticMode'] as bool;
          _sttMode = sttMode;
          _userTier = userTier;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    final settingsService = LumaraReflectionSettingsService.instance;
    await settingsService.saveAllSettings(
      similarityThreshold: _similarityThreshold,
      lookbackYears: _lookbackYears,
      maxMatches: _maxMatches,
      crossModalEnabled: _crossModalEnabled,
      therapeuticAutomaticMode: _therapeuticAutomaticMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: const BackButton(color: kcPrimaryTextColor),
        title: Text(
          'Advanced Settings',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Analysis & Insights Section
                  _buildSection(
                    title: 'Analysis & Insights',
                    children: [
                      _buildNavigationTile(
                        title: 'Analysis',
                        subtitle: 'Phase detection, patterns, AURORA, VEIL, SENTINEL, Medical',
                        icon: Icons.analytics,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CombinedAnalysisView()),
                          );
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // LUMARA Engine Section
                  _buildSection(
                    title: 'LUMARA Engine',
                    children: [
                      _buildSliderTile(
                        title: 'Memory Lookback',
                        subtitle: 'How far back to search your history',
                        value: _lookbackYears.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        displayValue: '$_lookbackYears years',
                        icon: Icons.history,
                        onChanged: (value) {
                          setState(() {
                            _lookbackYears = value.round();
                          });
                          _saveSettings();
                        },
                      ),
                      _buildSliderTile(
                        title: 'Matching Precision',
                        subtitle: 'Higher = more relevant, fewer matches',
                        value: _similarityThreshold,
                        min: 0.1,
                        max: 1.0,
                        divisions: 18,
                        displayValue: '${(_similarityThreshold * 100).round()}%',
                        icon: Icons.tune,
                        onChanged: (value) {
                          setState(() {
                            _similarityThreshold = value;
                          });
                          _saveSettings();
                        },
                      ),
                      _buildSliderTile(
                        title: 'Max Similar Entries',
                        subtitle: 'Maximum entries to find per reflection',
                        value: _maxMatches.toDouble(),
                        min: 1,
                        max: 20,
                        divisions: 19,
                        displayValue: '$_maxMatches entries',
                        icon: Icons.format_list_numbered,
                        onChanged: (value) {
                          setState(() {
                            _maxMatches = value.round();
                          });
                          _saveSettings();
                        },
                      ),
                      _buildSwitchTile(
                        title: 'Include Media',
                        subtitle: 'Analyze photos, audio, video in reflections',
                        icon: Icons.perm_media,
                        value: _crossModalEnabled,
                        onChanged: (value) {
                          setState(() {
                            _crossModalEnabled = value;
                          });
                          _saveSettings();
                        },
                      ),
                      _buildSwitchTile(
                        title: 'Auto-Adapt Depth',
                        subtitle: 'Let system choose therapeutic depth automatically',
                        icon: Icons.auto_mode,
                        value: _therapeuticAutomaticMode,
                        onChanged: (value) {
                          setState(() {
                            _therapeuticAutomaticMode = value;
                          });
                          _saveSettings();
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Voice & Transcription Section
                  _buildSection(
                    title: 'Voice & Transcription',
                    children: [
                      _buildTranscriptionModeTile(),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // About Section
                  _buildInfoCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
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

  Widget _buildNavigationTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Icon(icon, color: kcAccentColor, size: 24),
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
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: kcSecondaryTextColor, size: 16),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required IconData icon,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
              Icon(icon, color: kcAccentColor, size: 24),
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
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kcAccentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  displayValue,
                  style: bodyStyle(context).copyWith(
                    color: kcAccentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
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
            inactiveColor: Colors.grey.withOpacity(0.3),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: kcAccentColor, size: 24),
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
            fontSize: 12,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: kcAccentColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildTranscriptionModeTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
              const Icon(Icons.mic, color: kcAccentColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transcription Mode',
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Choose how voice is transcribed to text',
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTranscriptionModeOption(
            mode: SttMode.auto,
            title: 'Auto (Recommended)',
            description: 'Uses cloud when available, falls back to on-device automatically',
            icon: Icons.auto_awesome,
          ),
          const SizedBox(height: 8),
          _buildTranscriptionModeOption(
            mode: SttMode.cloud,
            title: 'Cloud (AssemblyAI)',
            description: 'Higher accuracy, requires internet',
            icon: Icons.cloud,
            requiresPro: _userTier == SttTier.free,
          ),
          const SizedBox(height: 8),
          _buildTranscriptionModeOption(
            mode: SttMode.local,
            title: 'Local (On-Device)',
            description: 'Works offline, good for privacy',
            icon: Icons.smartphone,
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionModeOption({
    required SttMode mode,
    required String title,
    required String description,
    required IconData icon,
    bool requiresPro = false,
  }) {
    final isSelected = _sttMode == mode;
    final isDisabled = requiresPro;
    
    return GestureDetector(
      onTap: isDisabled
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cloud transcription requires BETA or PRO subscription'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          : () async {
              setState(() {
                _sttMode = mode;
              });
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('stt_mode', mode.name);
            },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? kcAccentColor.withOpacity(0.15)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? kcAccentColor
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDisabled
                      ? Colors.grey
                      : isSelected
                          ? kcAccentColor
                          : kcSecondaryTextColor,
                  width: 2,
                ),
                color: isSelected ? kcAccentColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Icon(
              icon,
              size: 20,
              color: isDisabled
                  ? Colors.grey
                  : isSelected
                      ? kcAccentColor
                      : kcSecondaryTextColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: bodyStyle(context).copyWith(
                          color: isDisabled
                              ? Colors.grey
                              : kcPrimaryTextColor,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      if (requiresPro) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    description,
                    style: bodyStyle(context).copyWith(
                      color: isDisabled
                          ? Colors.grey.withOpacity(0.7)
                          : kcSecondaryTextColor,
                      fontSize: 11,
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

  Widget _buildInfoCard() {
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
              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'About Advanced Settings',
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'These settings control how LUMARA analyzes your journal entries and generates insights. Most users don\'t need to change these defaults.',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

