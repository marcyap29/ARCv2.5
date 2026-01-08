/// Simplified Advanced Settings View
/// Houses complex LUMARA options that were removed from main settings
///
/// MOVED HERE:
/// - Memory lookback years
/// - Debug classification info
/// - Manual persona override (for debugging)
/// - Detailed matching precision settings
/// - Development/testing features

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/chat/services/lumara_reflection_settings_service.dart';
import 'package:my_app/models/engagement_discipline.dart';

class SimplifiedAdvancedSettingsView extends StatefulWidget {
  const SimplifiedAdvancedSettingsView({super.key});

  @override
  State<SimplifiedAdvancedSettingsView> createState() => _SimplifiedAdvancedSettingsViewState();
}

class _SimplifiedAdvancedSettingsViewState extends State<SimplifiedAdvancedSettingsView> {
  // Advanced memory settings
  int _lookbackYears = 2;
  double _similarityThreshold = 0.55;
  int _maxMatches = 5;
  bool _memorySettingsLoading = true;

  // Debug settings
  bool _showClassificationDebug = false;
  bool _debugSettingsLoading = true;

  // Engagement settings (moved from main settings)
  EngagementSettings _engagementSettings = const EngagementSettings();
  bool _engagementSettingsLoading = true;

  // Advanced therapeutic settings (moved from main)
  int _therapeuticDepthLevel = 2;
  bool _therapeuticSettingsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemorySettings();
    _loadDebugSettings();
    _loadEngagementSettings();
    _loadTherapeuticSettings();
  }

  Future<void> _loadMemorySettings() async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();

      // Load memory-related settings
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
      print('Error loading memory settings: $e');
      if (mounted) {
        setState(() {
          _memorySettingsLoading = false;
        });
      }
    }
  }

  Future<void> _loadDebugSettings() async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();

      final settings = await settingsService.loadAllSettings();
      if (mounted) {
        setState(() {
          _showClassificationDebug = settings['showClassificationDebug'] as bool? ?? false;
          _debugSettingsLoading = false;
        });
      }
    } catch (e) {
      print('Error loading debug settings: $e');
      if (mounted) {
        setState(() {
          _debugSettingsLoading = false;
        });
      }
    }
  }

  Future<void> _loadEngagementSettings() async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();
      final engagement = await settingsService.getEngagementSettings();
      if (mounted) {
        setState(() {
          _engagementSettings = engagement;
          _engagementSettingsLoading = false;
        });
      }
    } catch (e) {
      print('Error loading engagement settings: $e');
      if (mounted) {
        setState(() {
          _engagementSettingsLoading = false;
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
      print('Error loading therapeutic settings: $e');
      if (mounted) {
        setState(() {
          _therapeuticSettingsLoading = false;
        });
      }
    }
  }

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
      print('Error setting lookback years: $e');
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
      print('Error setting similarity threshold: $e');
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
      print('Error setting max matches: $e');
    }
  }

  Future<void> _setShowClassificationDebug(bool show) async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.setShowClassificationDebug(show);
      if (mounted) {
        setState(() {
          _showClassificationDebug = show;
        });
      }
    } catch (e) {
      print('Error setting classification debug: $e');
    }
  }

  Future<void> _setTherapeuticDepthLevel(int level) async {
    try {
      setState(() {
        _therapeuticDepthLevel = level;
      });
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.setTherapeuticDepthLevel(level);
    } catch (e) {
      print('Error setting therapeutic depth: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: Text(
          'Advanced Settings',
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
            // Warning card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'These settings can significantly impact LUMARA\'s behavior. The Companion-first system handles most optimizations automatically.',
                      style: bodyStyle(context).copyWith(
                        color: Colors.orange,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Memory Configuration Section
            _buildSection(
              context,
              title: 'Memory Configuration',
              children: [
                // Lookback Years Slider
                _buildSliderCard(
                  context,
                  title: 'Memory Lookback',
                  subtitle: 'How far back LUMARA searches your history',
                  icon: Icons.history,
                  value: _lookbackYears.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  loading: _memorySettingsLoading,
                  onChanged: (value) => _setLookbackYears(value.round()),
                  labels: const ['1 year', '2 years', '3 years', '4 years', '5 years', '6 years', '7 years', '8 years', '9 years', '10 years'],
                ),

                // Similarity Threshold Slider
                _buildSliderCard(
                  context,
                  title: 'Matching Precision',
                  subtitle: 'How similar memories must be to include them',
                  icon: Icons.tune,
                  value: _similarityThreshold,
                  min: 0.3,
                  max: 0.9,
                  divisions: 12,
                  loading: _memorySettingsLoading,
                  onChanged: _setSimilarityThreshold,
                  labels: const ['Loose', 'Balanced', 'Strict'],
                ),

                // Max Matches Slider
                _buildSliderCard(
                  context,
                  title: 'Maximum Matches',
                  subtitle: 'Maximum number of past entries to include',
                  icon: Icons.format_list_numbered,
                  value: _maxMatches.toDouble(),
                  min: 1,
                  max: 20,
                  divisions: 19,
                  loading: _memorySettingsLoading,
                  onChanged: (value) => _setMaxMatches(value.round()),
                  labels: const ['1', '5', '10', '15', '20'],
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Debug & Development Section
            _buildSection(
              context,
              title: 'Debug & Development',
              children: [
                // Classification Debug Toggle
                Container(
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
                      'Show Classification Debug',
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Show how entries are classified (factual, reflective, etc.)',
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                      ),
                    ),
                    value: _showClassificationDebug,
                    onChanged: _debugSettingsLoading
                        ? null
                        : (value) => _setShowClassificationDebug(value),
                    secondary: Icon(
                      Icons.bug_report,
                      color: kcAccentColor,
                      size: 24,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Legacy Engagement Settings (moved from main)
            _buildSection(
              context,
              title: 'Legacy Settings (Deprecated)',
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.grey, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Legacy Features',
                              style: heading3Style(context).copyWith(
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'These settings are from the previous system and will be removed in a future update. The new Companion-first system handles these optimizations automatically.',
                        style: bodyStyle(context).copyWith(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Therapeutic Depth (legacy)
                _buildLegacyTherapeuticDepthCard(),

                // Cross-Domain Synthesis Toggle (legacy)
                _buildLegacyToggle(
                  title: 'Cross-Domain Connections',
                  subtitle: '(Legacy) Allow connections across life areas',
                  icon: Icons.hub,
                  value: _engagementSettings.synthesisPreferences.allowCrossDomainSynthesis,
                  onChanged: _setCrossDomainSynthesis,
                ),

                // Therapeutic Language Toggle (legacy)
                _buildLegacyToggle(
                  title: 'Therapeutic Language',
                  subtitle: '(Legacy) Allow therapy-style phrasing',
                  icon: Icons.healing,
                  value: _engagementSettings.responseDiscipline.allowTherapeuticLanguage,
                  onChanged: _setTherapeuticLanguage,
                ),
              ],
            ),
          ],
        ),
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

  Widget _buildSliderCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required bool loading,
    required Function(double) onChanged,
    required List<String> labels,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                ),
            ],
          ),
          const SizedBox(height: 16),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: kcAccentColor,
            inactiveColor: Colors.grey.withValues(alpha: 0.3),
            onChanged: loading ? null : onChanged,
          ),
          if (labels.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: labels.map((label) => Text(
                label,
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontSize: 10,
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildLegacyTherapeuticDepthCard() {
    final depthLabels = ['Light', 'Moderate', 'Deep'];
    final depthDescriptions = [
      '(Legacy) Supportive and encouraging',
      '(Legacy) Reflective and insight-oriented',
      '(Legacy) Exploratory and emotionally resonant',
    ];

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
                Icons.psychology,
                color: Colors.grey,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Therapeutic Depth (Legacy)',
                      style: heading3Style(context).copyWith(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      depthDescriptions[_therapeuticDepthLevel - 1],
                      style: bodyStyle(context).copyWith(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  depthLabels[_therapeuticDepthLevel - 1],
                  style: bodyStyle(context).copyWith(
                    color: Colors.grey,
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
            activeColor: Colors.grey,
            inactiveColor: Colors.grey.withValues(alpha: 0.3),
            onChanged: _therapeuticSettingsLoading
                ? null
                : (value) => _setTherapeuticDepthLevel(value.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: heading3Style(context).copyWith(
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: bodyStyle(context).copyWith(
            color: Colors.grey,
          ),
        ),
        value: value,
        onChanged: _engagementSettingsLoading ? null : onChanged,
        secondary: Icon(
          icon,
          color: Colors.grey,
          size: 24,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Future<void> _setCrossDomainSynthesis(bool value) async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      final updated = _engagementSettings.copyWith(
        synthesisPreferences: _engagementSettings.synthesisPreferences.copyWith(
          allowCrossDomainSynthesis: value,
        ),
      );
      await settingsService.saveAllSettingsWithEngagement(
        engagementSettings: updated,
      );
      if (mounted) {
        setState(() {
          _engagementSettings = updated;
        });
      }
    } catch (e) {
      print('Error setting cross-domain synthesis: $e');
    }
  }

  Future<void> _setTherapeuticLanguage(bool value) async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      final updated = _engagementSettings.copyWith(
        responseDiscipline: _engagementSettings.responseDiscipline.copyWith(
          allowTherapeuticLanguage: value,
        ),
      );
      await settingsService.saveAllSettingsWithEngagement(
        engagementSettings: updated,
      );
      if (mounted) {
        setState(() {
          _engagementSettings = updated;
        });
      }
    } catch (e) {
      print('Error setting therapeutic language: $e');
    }
  }
}