// lib/shared/ui/settings/advanced_settings_view.dart
// Consolidated Advanced Settings View - combines Analysis, Memory, Debug, and Response Behavior settings

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/shared/ui/settings/combined_analysis_view.dart';
import 'package:my_app/shared/ui/settings/health_readiness_view.dart';
import 'package:my_app/arc/ui/health/health_view.dart';
import 'package:my_app/arc/chat/voice/transcription/transcription_provider.dart';
import 'package:my_app/arc/chat/voice/models/voice_input_mode.dart';
import 'package:my_app/services/assemblyai_service.dart';
import 'package:my_app/arc/chat/services/lumara_reflection_settings_service.dart';
import 'package:my_app/models/engagement_discipline.dart';
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
  VoiceInputMode _voiceInputMode = VoiceInputMode.pushToTalk;

  // Advanced memory settings
  int _lookbackYears = 2;
  double _similarityThreshold = 0.55;
  int _maxMatches = 5;
  bool _memorySettingsLoading = true;

  // Debug settings
  bool _showClassificationDebug = false;
  bool _debugSettingsLoading = true;

  // Engagement settings (Response Behavior)
  EngagementSettings _engagementSettings = const EngagementSettings();
  bool _engagementSettingsLoading = true;

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
      _loadDebugSettings(),
      _loadEngagementSettings(),
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
      
      // Load voice input mode
      final savedVoiceInputMode = prefs.getString('voice_input_mode');
      final voiceInputMode = savedVoiceInputMode != null
          ? VoiceInputMode.values.firstWhere(
              (m) => m.name == savedVoiceInputMode, 
              orElse: () => VoiceInputMode.pushToTalk
            )
          : VoiceInputMode.pushToTalk;
      
      final assemblyAIService = AssemblyAIService();
      final userTier = await assemblyAIService.getUserTier();
      
      if (mounted) {
        setState(() {
          _sttMode = sttMode;
          _userTier = userTier;
          _voiceInputMode = voiceInputMode;
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
  
  Future<void> _setVoiceInputMode(VoiceInputMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('voice_input_mode', mode.name);
      if (mounted) {
        setState(() {
          _voiceInputMode = mode;
        });
      }
    } catch (e) {
      debugPrint('Error setting voice input mode: $e');
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

  Future<void> _loadDebugSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final showDebug = prefs.getBool('show_classification_debug') ?? false;
      if (mounted) {
        setState(() {
          _showClassificationDebug = showDebug;
          _debugSettingsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading debug settings: $e');
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
      debugPrint('Error loading engagement settings: $e');
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

  // Debug settings handlers
  Future<void> _setShowClassificationDebug(bool show) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('show_classification_debug', show);
      if (mounted) {
        setState(() {
          _showClassificationDebug = show;
        });
      }
    } catch (e) {
      debugPrint('Error setting classification debug: $e');
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
      debugPrint('Error setting cross-domain synthesis: $e');
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
      debugPrint('Error setting therapeutic language: $e');
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
                        subtitle: 'Phase detection, patterns, AURORA, VEIL, SENTINEL',
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

                  // Health & Readiness Section
                  _buildSection(
                    title: 'Health & Readiness',
                    children: [
                      _buildNavigationTile(
                        title: 'Health & Readiness',
                        subtitle: 'Operational readiness and phase ratings',
                        icon: Icons.assessment,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const HealthReadinessView()),
                          );
                        },
                      ),
                      _buildNavigationTile(
                        title: 'Medical',
                        subtitle: 'Health data tracking and summary',
                        icon: Icons.medical_services,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const HealthView()),
                          );
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
                      const SizedBox(height: 8),
                      _buildVoiceInputModeTile(),
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

                      // Cross-Domain Synthesis Toggle
                      _buildSwitchTile(
                        title: 'Cross-Domain Connections',
                        subtitle: 'Allow LUMARA to make connections across different life areas',
                        icon: Icons.hub,
                        value: _engagementSettings.synthesisPreferences.allowCrossDomainSynthesis,
                        onChanged: _engagementSettingsLoading ? null : _setCrossDomainSynthesis,
                      ),

                      // Therapeutic Language Toggle
                      _buildSwitchTile(
                        title: 'Therapeutic Language',
                        subtitle: 'Allow supportive, therapy-style phrasing in responses',
                        icon: Icons.healing,
                        value: _engagementSettings.responseDiscipline.allowTherapeuticLanguage,
                        onChanged: _engagementSettingsLoading ? null : _setTherapeuticLanguage,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Debug & Development Section
                  _buildSection(
                    title: 'Debug & Development',
                    children: [
                      _buildSwitchTile(
                        title: 'Show Classification Debug',
                        subtitle: 'Show how entries are classified (factual, reflective, etc.)',
                        icon: Icons.bug_report,
                        value: _showClassificationDebug,
                        onChanged: _debugSettingsLoading ? null : _setShowClassificationDebug,
                      ),
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

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool>? onChanged,
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

  Widget _buildVoiceInputModeTile() {
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
              const Icon(Icons.touch_app, color: kcAccentColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice Input Mode',
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'How you interact with voice mode',
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
          _buildVoiceInputModeOption(
            mode: VoiceInputMode.pushToTalk,
            title: 'Push to Talk (Recommended)',
            description: 'Hold to speak, release to send. Clear control over recording.',
            icon: Icons.touch_app,
          ),
          const SizedBox(height: 8),
          _buildVoiceInputModeOption(
            mode: VoiceInputMode.handsFree,
            title: 'Hands-Free Mode',
            description: 'Auto-detects when you finish speaking. Good for accessibility.',
            icon: Icons.accessibility_new,
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceInputModeOption({
    required VoiceInputMode mode,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _voiceInputMode == mode;
    
    return GestureDetector(
      onTap: () => _setVoiceInputMode(mode),
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
                  color: isSelected ? kcAccentColor : kcSecondaryTextColor,
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
              color: isSelected ? kcAccentColor : kcSecondaryTextColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: bodyStyle(context).copyWith(
                      color: kcPrimaryTextColor,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  Text(
                    description,
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
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
            'These settings control analysis features, memory retrieval, voice transcription, and LUMARA\'s response behavior. Most users can leave these at their defaults.',
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
