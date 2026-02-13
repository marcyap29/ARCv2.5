// lib/shared/ui/settings/advanced_settings_view.dart
// Analysis and memory settings - Voice & Transcription, Memory Configuration, Response Behavior

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/chat/voice/transcription/transcription_provider.dart';
import 'package:my_app/services/assemblyai_service.dart';
import 'package:my_app/arc/chat/services/lumara_reflection_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdvancedSettingsView extends StatefulWidget {
  const AdvancedSettingsView({super.key});

  @override
  State<AdvancedSettingsView> createState() => _AdvancedSettingsViewState();
}

class _AdvancedSettingsViewState extends State<AdvancedSettingsView> {
  bool _isLoading = true;

  // Voice & Transcription settings
  SttMode _sttMode = SttMode.auto;
  SttTier _userTier = SttTier.free;

  // Advanced memory settings
  int _lookbackYears = 2;
  double _similarityThreshold = 0.55;
  int _maxMatches = 5;
  bool _memorySettingsLoading = true;

  // Therapeutic settings (Response Behavior)
  int _therapeuticDepthLevel = 2;
  bool _therapeuticSettingsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
  }

  Future<void> _loadAllSettings() async {
    await Future.wait([
      _loadTranscriptionSettings(),
      _loadMemorySettings(),
      _loadTherapeuticSettings(),
    ]);
  }

  Future<void> _loadTranscriptionSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString('stt_mode');
      final sttMode = savedMode != null
          ? SttMode.values.firstWhere((m) => m.name == savedMode, orElse: () => SttMode.auto)
          : SttMode.auto;

      final assemblyAIService = AssemblyAIService();
      final userTier = await assemblyAIService.getUserTier();

      if (mounted) {
        setState(() {
          _sttMode = sttMode;
          _userTier = userTier;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading transcription settings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadMemorySettings() async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();

      final settings = await settingsService.loadAllSettings();
      if (mounted) {
        setState(() {
          _lookbackYears = settings['lookbackYears'] as int? ?? 2;
          _similarityThreshold = settings['similarityThreshold'] as double? ?? 0.55;
          _maxMatches = settings['maxMatches'] as int? ?? 5;
          _memorySettingsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading memory settings: $e');
      if (mounted) {
        setState(() {
          _memorySettingsLoading = false;
        });
      }
    }
  }

  Future<void> _loadTherapeuticSettings() async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();
      final settings = await settingsService.loadAllSettings();
      if (mounted) {
        setState(() {
          _therapeuticDepthLevel = settings['therapeuticDepthLevel'] as int? ?? 2;
          _therapeuticSettingsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading therapeutic settings: $e');
      if (mounted) {
        setState(() {
          _therapeuticSettingsLoading = false;
        });
      }
    }
  }

  // Memory settings handlers
  Future<void> _setLookbackYears(int years) async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.setLookbackYears(years);
      if (mounted) {
        setState(() {
          _lookbackYears = years;
        });
      }
    } catch (e) {
      debugPrint('Error setting lookback years: $e');
    }
  }

  Future<void> _setSimilarityThreshold(double threshold) async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.setSimilarityThreshold(threshold);
      if (mounted) {
        setState(() {
          _similarityThreshold = threshold;
        });
      }
    } catch (e) {
      debugPrint('Error setting similarity threshold: $e');
    }
  }

  Future<void> _setMaxMatches(int matches) async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.setMaxMatches(matches);
      if (mounted) {
        setState(() {
          _maxMatches = matches;
        });
      }
    } catch (e) {
      debugPrint('Error setting max matches: $e');
    }
  }

  // Response Behavior handlers
  Future<void> _setTherapeuticDepthLevel(int level) async {
    try {
      setState(() {
        _therapeuticDepthLevel = level;
      });
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.setTherapeuticDepthLevel(level);
    } catch (e) {
      debugPrint('Error setting therapeutic depth: $e');
    }
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
          'Analysis and memory',
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
                  // Voice & Transcription Section
                  _buildSection(
                    title: 'Voice & Transcription',
                    children: [
                      _buildTranscriptionModeTile(),
                    ],
                  ),
                  
                  const SizedBox(height: 32),

                  // Memory Configuration Section
                  _buildSection(
                    title: 'Memory Configuration',
                    children: [
                      // Lookback Years Slider
                      _buildSliderCard(
                        title: 'Memory Lookback',
                        subtitle: 'How far back LUMARA searches your history',
                        icon: Icons.history,
                        value: _lookbackYears.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        loading: _memorySettingsLoading,
                        onChanged: (value) => _setLookbackYears(value.round()),
                        displayValue: '$_lookbackYears ${_lookbackYears == 1 ? 'year' : 'years'}',
                      ),

                      // Similarity Threshold Slider
                      _buildSliderCard(
                        title: 'Matching Precision',
                        subtitle: 'How similar memories must be to include them',
                        icon: Icons.tune,
                        value: _similarityThreshold,
                        min: 0.3,
                        max: 0.9,
                        divisions: 12,
                        loading: _memorySettingsLoading,
                        onChanged: _setSimilarityThreshold,
                        displayValue: _similarityThreshold < 0.45 ? 'Loose' : _similarityThreshold > 0.7 ? 'Strict' : 'Balanced',
                      ),

                      // Max Matches Slider
                      _buildSliderCard(
                        title: 'Maximum Matches',
                        subtitle: 'Maximum number of past entries to include',
                        icon: Icons.format_list_numbered,
                        value: _maxMatches.toDouble(),
                        min: 1,
                        max: 20,
                        divisions: 19,
                        loading: _memorySettingsLoading,
                        onChanged: (value) => _setMaxMatches(value.round()),
                        displayValue: '$_maxMatches',
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Response Behavior Section (formerly Legacy Settings)
                  _buildSection(
                    title: 'Response Behavior',
                    children: [
                      // Therapeutic Depth
                      _buildTherapeuticDepthCard(),
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

  Widget _buildSliderCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required bool loading,
    required ValueChanged<double> onChanged,
    required String displayValue,
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
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
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
            onChanged: loading ? null : onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTherapeuticDepthCard() {
    final depthLabels = ['Light', 'Moderate', 'Deep'];
    final depthDescriptions = [
      'Supportive and encouraging',
      'Reflective and insight-oriented',
      'Exploratory and emotionally resonant',
    ];

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
                      'Therapeutic Depth',
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      depthDescriptions[_therapeuticDepthLevel - 1],
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
                  depthLabels[_therapeuticDepthLevel - 1],
                  style: bodyStyle(context).copyWith(
                    color: kcAccentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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
            inactiveColor: Colors.grey.withOpacity(0.3),
            onChanged: _therapeuticSettingsLoading
                ? null
                : (value) => _setTherapeuticDepthLevel(value.round()),
          ),
        ],
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
                'About Analysis and memory',
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'These settings control analysis features, memory retrieval, and LUMARA\'s response behavior. Most users can leave these at their defaults.',
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
