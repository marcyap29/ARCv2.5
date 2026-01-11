import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/shared/ui/settings/privacy_settings_view.dart';
import 'package:my_app/shared/ui/settings/memory_mode_settings_view.dart';
import 'package:my_app/shared/ui/settings/memory_snapshot_management_view.dart';
import 'package:my_app/shared/ui/settings/conflict_management_view.dart';
import 'package:my_app/shared/ui/settings/favorites_management_view.dart';
import 'package:my_app/shared/ui/settings/advanced_settings_view.dart';
import 'package:my_app/shared/ui/settings/voiceover_preference_service.dart';
import 'package:my_app/shared/ui/settings/throttle_settings_view.dart';
import 'package:my_app/ui/screens/mcp_management_screen.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/chat/services/favorites_service.dart';
import 'package:my_app/arc/chat/services/lumara_reflection_settings_service.dart';
import 'package:my_app/models/engagement_discipline.dart';
import 'package:my_app/models/memory_focus_preset.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/ui/subscription/subscription_management_view.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/shared/ui/settings/local_backup_settings_view.dart';
import 'package:my_app/shared/ui/settings/temporal_notification_settings_view.dart';
import 'package:my_app/arc/phase/share/phase_share_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:my_app/mira/store/mcp/import/mcp_pack_import_service.dart';
import 'package:my_app/mira/store/arcx/ui/arcx_import_progress_screen.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/utils/file_utils.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/shared/ui/home/home_view.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  int _favoritesCount = 0;
  int _savedChatsCount = 0;
  int _favoriteEntriesCount = 0;
  int _answersLimit = 25;
  int _chatsLimit = 25;
  int _entriesLimit = 25;
  bool _favoritesCountLoaded = false;
  bool _voiceoverEnabled = false;
  bool _voiceoverLoading = true;
  bool _shakeToReportEnabled = true;
  bool _shakeToReportLoading = true;
  
  // LUMARA Persona state
  LumaraPersona _selectedPersona = LumaraPersona.auto;
  bool _personaLoading = true;
  
  // Therapeutic depth state
  int _therapeuticDepthLevel = 2;
  bool _webAccessEnabled = false;
  bool _lumaraSettingsLoading = true;

  // Engagement settings state
  EngagementSettings _engagementSettings = const EngagementSettings();
  bool _engagementSettingsLoading = true;

  // Memory Focus preset state
  MemoryFocusPreset _memoryFocusPreset = MemoryFocusPreset.balanced;
  bool _memoryFocusLoading = true;
  
  // Custom Memory Focus settings state
  bool _showCustomMemorySettings = false;
  int _customTimeWindowDays = 90;
  double _customSimilarityThreshold = 0.55;
  int _customMaxEntries = 20;
  bool _customMemorySettingsLoading = true;
  
  // Other LUMARA settings state
  bool _crossModalEnabled = true;
  bool _crossModalLoading = true;
  
  // Phase share settings
  bool _phaseSharePromptsEnabled = true;
  bool _phaseShareSettingsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavoritesCount();
    _loadVoiceoverPreference();
    _loadShakeToReportPreference();
    _loadPersonaPreference();
    _loadLumaraSettings();
    _loadMemoryFocusPreset();
    _loadCrossModalSetting();
    _loadEngagementSettings();
    _loadPhaseShareSettings();
  }
  
  Future<void> _loadPhaseShareSettings() async {
    try {
      final shareService = PhaseShareService.instance;
      final enabled = await shareService.areSharePromptsEnabled();
      if (mounted) {
        setState(() {
          _phaseSharePromptsEnabled = enabled;
          _phaseShareSettingsLoading = false;
        });
      }
    } catch (e) {
      print('Error loading phase share settings: $e');
      if (mounted) {
        setState(() {
          _phaseShareSettingsLoading = false;
        });
      }
    }
  }
  
  Future<void> _togglePhaseSharePrompts(bool value) async {
    try {
      final shareService = PhaseShareService.instance;
      await shareService.setSharePromptsEnabled(value);
      if (mounted) {
        setState(() {
          _phaseSharePromptsEnabled = value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Phase share prompts enabled'
                  : 'Phase share prompts disabled',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: value ? Colors.green : Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating setting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Build phase share toggle
  Widget _buildPhaseShareToggle() {
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
          'Phase Share Prompts',
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Show prompts to share phase transitions',
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
            fontSize: 12,
          ),
        ),
        value: _phaseSharePromptsEnabled,
        onChanged: _phaseShareSettingsLoading
            ? null
            : (value) => _togglePhaseSharePrompts(value),
        secondary: _phaseShareSettingsLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                Icons.share,
                color: kcAccentColor,
                size: 24,
              ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }
  
  Future<void> _loadLumaraSettings() async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();
      final settings = await settingsService.loadAllSettings();
      if (mounted) {
        setState(() {
          _therapeuticDepthLevel = settings['therapeuticDepthLevel'] as int;
          _webAccessEnabled = settings['webAccessEnabled'] as bool;
          _lumaraSettingsLoading = false;
        });
      }
    } catch (e) {
      print('Error loading LUMARA settings: $e');
      if (mounted) {
        setState(() {
          _lumaraSettingsLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadMemoryFocusPreset() async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();
      final preset = await settingsService.getMemoryFocusPreset();
      
      // Load custom values if Custom preset is selected
      if (preset == MemoryFocusPreset.custom) {
        final settings = await settingsService.loadAllSettings();
        if (mounted) {
          setState(() {
            _memoryFocusPreset = preset;
            _showCustomMemorySettings = true;
            _customTimeWindowDays = settings['timeWindowDays'] as int? ?? settings['lookbackYears'] as int? ?? 90;
            _customSimilarityThreshold = settings['similarityThreshold'] as double? ?? 0.55;
            _customMaxEntries = settings['maxMatches'] as int? ?? 20;
            _memoryFocusLoading = false;
            _customMemorySettingsLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _memoryFocusPreset = preset;
            _showCustomMemorySettings = false;
            _memoryFocusLoading = false;
            _customMemorySettingsLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading memory focus preset: $e');
      if (mounted) {
        setState(() {
          _memoryFocusLoading = false;
          _customMemorySettingsLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadCrossModalSetting() async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();
      final enabled = await settingsService.isCrossModalEnabled();
      if (mounted) {
        setState(() {
          _crossModalEnabled = enabled;
          _crossModalLoading = false;
        });
      }
    } catch (e) {
      print('Error loading cross-modal setting: $e');
      if (mounted) {
        setState(() {
          _crossModalLoading = false;
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
  
  Future<void> _setTherapeuticDepthLevel(int level) async {
    setState(() {
      _therapeuticDepthLevel = level;
    });
    final settingsService = LumaraReflectionSettingsService.instance;
    await settingsService.setTherapeuticDepthLevel(level);
  }
  
  Future<void> _setWebAccessEnabled(bool enabled) async {
    setState(() {
      _webAccessEnabled = enabled;
    });
    final settingsService = LumaraReflectionSettingsService.instance;
    await settingsService.setWebAccessEnabled(enabled);
  }
  
  Future<void> _loadPersonaPreference() async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();
      final persona = await settingsService.getLumaraPersona();
      if (mounted) {
        setState(() {
          _selectedPersona = persona;
          _personaLoading = false;
        });
      }
    } catch (e) {
      print('Error loading persona preference: $e');
      if (mounted) {
        setState(() {
          _personaLoading = false;
        });
      }
    }
  }
  
  Future<void> _setPersona(LumaraPersona persona) async {
    setState(() {
      _personaLoading = true;
    });
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.setLumaraPersona(persona);
      if (mounted) {
        setState(() {
          _selectedPersona = persona;
          _personaLoading = false;
        });
      }
    } catch (e) {
      print('Error setting persona: $e');
      if (mounted) {
        setState(() {
          _personaLoading = false;
        });
      }
    }
  }

  Future<void> _loadFavoritesCount() async {
    try {
      await FavoritesService.instance.initialize();
      
      // Load subscription-based limits
      final answersLimit = await FavoritesService.instance.getCategoryLimit('answer');
      final chatsLimit = await FavoritesService.instance.getCategoryLimit('chat');
      final entriesLimit = await FavoritesService.instance.getCategoryLimit('journal_entry');
      
      final answersCount = await FavoritesService.instance.getCountByCategory('answer');
      final chatsCount = await FavoritesService.instance.getCountByCategory('chat');
      final entriesCount = await FavoritesService.instance.getCountByCategory('journal_entry');
      if (mounted) {
        setState(() {
          _answersLimit = answersLimit;
          _chatsLimit = chatsLimit;
          _entriesLimit = entriesLimit;
          _favoritesCount = answersCount;
          _savedChatsCount = chatsCount;
          _favoriteEntriesCount = entriesCount;
          _favoritesCountLoaded = true;
        });
      }
    } catch (e) {
      print('Error loading favorites count: $e');
      if (mounted) {
        setState(() {
          _favoritesCountLoaded = true;
        });
      }
    }
  }


  Future<void> _loadVoiceoverPreference() async {
    try {
      final enabled = await VoiceoverPreferenceService.instance.isVoiceoverEnabled();
      if (mounted) {
        setState(() {
          _voiceoverEnabled = enabled;
          _voiceoverLoading = false;
        });
      }
    } catch (e) {
      print('Error loading voiceover preference: $e');
      if (mounted) {
        setState(() {
          _voiceoverLoading = false;
        });
      }
    }
  }

  Future<void> _toggleVoiceover(bool value) async {
    try {
      await VoiceoverPreferenceService.instance.setVoiceoverEnabled(value);
      if (mounted) {
        setState(() {
          _voiceoverEnabled = value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Voiceover enabled - AI responses will be spoken aloud'
                  : 'Voiceover disabled - AI responses will be text only',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: value ? Colors.green : Colors.lightBlue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling Voiceover: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadShakeToReportPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('shake_to_report_enabled') ?? true;
      if (mounted) {
        setState(() {
          _shakeToReportEnabled = enabled;
          _shakeToReportLoading = false;
        });
      }
    } catch (e) {
      print('Error loading shake-to-report preference: $e');
      if (mounted) {
        setState(() {
          _shakeToReportLoading = false;
        });
      }
    }
  }

  Future<void> _toggleShakeToReport(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('shake_to_report_enabled', value);
      if (mounted) {
        setState(() {
          _shakeToReportEnabled = value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Shake to report enabled - shake your device to report bugs'
                  : 'Shake to report disabled',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: value ? Colors.green : Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling shake-to-report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          'Settings',
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

            // Import & Export Section (Top Priority)
            _buildSection(
              context,
              title: 'Import & Export',
              children: [
                _buildSettingsTile(
                  context,
                  title: 'Local Backup',
                  subtitle: 'Regular backups with incremental tracking and scheduling',
                  icon: Icons.folder,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocalBackupSettingsView(
                          journalRepo: context.read<JournalRepository>(),
                        ),
                      ),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  title: 'Import Data',
                  subtitle: 'Restore from .zip, .mcpkg, or .arcx backup files',
                  icon: Icons.cloud_download,
                  onTap: () {
                    _restoreDataFromSettings(context);
                  },
                ),
                _buildSettingsTile(
                  context,
                  title: 'Advanced Export',
                  subtitle: 'Custom exports with date filtering, multi-select, and sharing',
                  icon: Icons.tune,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => McpManagementScreen(
                          journalRepository: context.read<JournalRepository>(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Subscription & Account Section
            _buildSection(
              context,
              title: 'Subscription & Account',
              children: [
                _buildAccountTile(context),
                _buildSettingsTile(
                  context,
                  title: 'Subscription Management',
                  subtitle: 'Manage your subscription tier and billing',
                  icon: Icons.workspace_premium,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SubscriptionManagementView(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // LUMARA Section (between Import/Export and Privacy)
            _buildSection(
              context,
              title: 'LUMARA',
              children: [
                _buildSettingsTile(
                  context,
                  title: 'LUMARA Favorites',
                  subtitle: _favoritesCountLoaded
                      ? 'Answers ($_favoritesCount/$_answersLimit), Chats ($_savedChatsCount/$_chatsLimit), Entries ($_favoriteEntriesCount/$_entriesLimit)'
                      : 'Manage your favorites',
                  icon: Icons.star,
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FavoritesManagementView(),
                      ),
                    );
                    // Reload count when returning from favorites screen
                    if (result == true || mounted) {
                      _loadFavoritesCount();
                    }
                  },
                ),
                // LUMARA Persona Card
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.theater_comedy,
                              color: kcAccentColor,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'LUMARA Persona',
                                    style: heading3Style(context).copyWith(
                                      color: kcPrimaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Choose how LUMARA responds to you',
                                    style: bodyStyle(context).copyWith(
                                      color: kcSecondaryTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_personaLoading)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Colors.white12),
                      ...LumaraPersona.values.map((persona) => _buildPersonaOption(persona)),
                    ],
                  ),
                ),
                // Memory Focus Preset Card
                _buildMemoryFocusCard(),
                // Engagement Mode Card
                _buildEngagementModeCard(),
                // Cross-Domain Synthesis Toggle
                _buildCrossDomainSynthesisToggle(),
                // Therapeutic Language Toggle
                _buildTherapeuticLanguageToggle(),
                // Include Media Toggle
                _buildIncludeMediaToggle(),
                // Therapeutic Depth Slider
                _buildTherapeuticDepthCard(),
                // Web Search Toggle
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
                      'Web Search',
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Allow web lookups for external info',
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                      ),
                    ),
                    value: _webAccessEnabled,
                    onChanged: _lumaraSettingsLoading
                        ? null
                        : (value) => _setWebAccessEnabled(value),
                    secondary: Icon(
                      Icons.language,
                      color: kcAccentColor,
                      size: 24,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
                // Voice Responses Toggle
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
                      'Voice Responses',
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Speak LUMARA\'s responses aloud',
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                      ),
                    ),
                    value: _voiceoverEnabled,
                    onChanged: _voiceoverLoading
                        ? null
                        : (value) => _toggleVoiceover(value),
                    secondary: _voiceoverLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.volume_up,
                            color: kcAccentColor,
                            size: 24,
                          ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
                // Shake to Report Toggle
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
                      'Shake to Report',
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Shake device to report bugs',
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                      ),
                    ),
                    value: _shakeToReportEnabled,
                    onChanged: _shakeToReportLoading
                        ? null
                        : (value) => _toggleShakeToReport(value),
                    secondary: _shakeToReportLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.vibration,
                            color: kcAccentColor,
                            size: 24,
                          ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
                // Advanced Settings
                _buildSettingsTile(
                  context,
                  title: 'Advanced Settings',
                  subtitle: 'Analysis, memory lookback, matching precision',
                  icon: Icons.settings_applications,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdvancedSettingsView()),
                    );
                  },
                ),
                // Phase Share Settings
                _buildPhaseShareToggle(),
                // Temporal Notifications
                _buildSettingsTile(
                  context,
                  title: 'Temporal Notifications',
                  subtitle: 'Daily prompts, monthly reviews, arc views, and summaries',
                  icon: Icons.notifications_active,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TemporalNotificationSettingsView(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Privacy & Security Section
            _buildSection(
              context,
              title: 'Privacy & Security',
              children: [
                _buildSettingsTile(
                  context,
                  title: 'Throttle',
                  subtitle: 'Manage rate limiting settings',
                  icon: Icons.speed,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ThrottleSettingsView()),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  title: 'Privacy Protection',
                  subtitle: 'Configure PII detection and masking settings',
                  icon: Icons.security,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PrivacySettingsView()),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  title: 'Memory Modes',
                  subtitle: 'Control how LUMARA uses your memories',
                  icon: Icons.memory,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MemoryModeSettingsView()),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  title: 'Memory Snapshots',
                  subtitle: 'Backup and restore your memories',
                  icon: Icons.backup,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MemorySnapshotManagementView()),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  title: 'Memory Conflicts',
                  subtitle: 'Resolve memory contradictions',
                  icon: Icons.psychology,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ConflictManagementView()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // About Section
            _buildSection(
              context,
              title: 'About',
              children: [
                _buildSettingsTile(
                  context,
                  title: 'Version',
                  subtitle: '1.0.5',
                  icon: Icons.info,
                  onTap: null,
                ),
                _buildSettingsTile(
                  context,
                  title: 'Privacy Policy',
                  subtitle: 'Read our privacy policy',
                  icon: Icons.privacy_tip,
                  onTap: () {
                    // TODO: Implement privacy policy
                  },
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
  
  /// Build therapeutic depth card with slider
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
                  color: kcAccentColor.withValues(alpha: 0.2),
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
            inactiveColor: Colors.grey.withValues(alpha: 0.3),
            onChanged: _lumaraSettingsLoading
                ? null
                : (value) => _setTherapeuticDepthLevel(value.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: depthLabels.asMap().entries.map((entry) {
              final index = entry.key;
              final label = entry.value;
              final isSelected = _therapeuticDepthLevel == index + 1;
              return GestureDetector(
                onTap: _lumaraSettingsLoading
                    ? null
                    : () => _setTherapeuticDepthLevel(index + 1),
                child: Text(
                  label,
                  style: bodyStyle(context).copyWith(
                    color: isSelected ? kcAccentColor : kcSecondaryTextColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 11,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Build Engagement Mode card
  Widget _buildEngagementModeCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.tune, color: kcAccentColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Engagement Mode',
                        style: heading3Style(context).copyWith(
                          color: kcPrimaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'How deeply LUMARA engages with your reflections',
                        style: bodyStyle(context).copyWith(
                          color: kcSecondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_engagementSettingsLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          ...EngagementMode.values.map((mode) => _buildEngagementModeOption(mode)),
        ],
      ),
    );
  }

  Widget _buildEngagementModeOption(EngagementMode mode) {
    final isSelected = _engagementSettings.defaultMode == mode;
    return InkWell(
      onTap: _engagementSettingsLoading ? null : () => _setEngagementMode(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? kcAccentColor : Colors.white38,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kcAccentColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.displayName,
                    style: bodyStyle(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? kcAccentColor : kcPrimaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.description,
                    style: bodyStyle(context).copyWith(
                      fontSize: 11,
                      color: kcSecondaryTextColor,
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

  Future<void> _setEngagementMode(EngagementMode mode) async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      final updated = _engagementSettings.copyWith(defaultMode: mode);
      await settingsService.saveAllSettingsWithEngagement(
        engagementSettings: updated,
      );
      if (mounted) {
        setState(() {
          _engagementSettings = updated;
        });
      }
    } catch (e) {
      print('Error setting engagement mode: $e');
    }
  }

  /// Build Cross-Domain Synthesis toggle
  Widget _buildCrossDomainSynthesisToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: SwitchListTile(
        title: Text(
          'Cross-Domain Connections',
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Allow LUMARA to connect themes across different life areas',
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
          ),
        ),
        value: _engagementSettings.synthesisPreferences.allowCrossDomainSynthesis,
        onChanged: _engagementSettingsLoading
            ? null
            : (value) => _setCrossDomainSynthesis(value),
        secondary: Icon(
          Icons.hub,
          color: kcAccentColor,
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

  /// Build Therapeutic Language toggle
  Widget _buildTherapeuticLanguageToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: SwitchListTile(
        title: Text(
          'Therapeutic Language',
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Allow therapy-style phrasing and direct advice',
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
          ),
        ),
        value: _engagementSettings.responseDiscipline.allowTherapeuticLanguage,
        onChanged: _engagementSettingsLoading
            ? null
            : (value) => _setTherapeuticLanguage(value),
        secondary: Icon(
          Icons.healing,
          color: kcAccentColor,
          size: 24,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
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


  /// Build a persona option radio tile
  Widget _buildPersonaOption(LumaraPersona persona) {
    final isSelected = _selectedPersona == persona;
    return InkWell(
      onTap: _personaLoading ? null : () => _setPersona(persona),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? kcAccentColor : Colors.white38,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kcAccentColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              persona.icon,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    persona.displayName,
                    style: heading3Style(context).copyWith(
                      color: isSelected ? kcAccentColor : kcPrimaryTextColor,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    persona.description,
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

  /// Build account tile showing sign in/out status
  Widget _buildAccountTile(BuildContext context) {
    final authService = FirebaseAuthService.instance;
    final isSignedIn = authService.isSignedIn;
    final isAnonymous = authService.isAnonymous;
    final userEmail = authService.userEmail;
    final displayName = authService.userDisplayName;

    // Determine what to show
    String title;
    String subtitle;
    IconData icon;
    
    if (!isSignedIn || isAnonymous) {
      title = 'Sign In';
      subtitle = 'Sign in to sync your data across devices';
      icon = Icons.login;
    } else {
      title = displayName ?? userEmail ?? 'Signed In';
      subtitle = userEmail ?? 'Manage your account';
      icon = Icons.account_circle;
    }

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
        leading: CircleAvatar(
          backgroundColor: kcAccentColor.withValues(alpha: 0.2),
          backgroundImage: authService.userPhotoURL != null 
              ? NetworkImage(authService.userPhotoURL!) 
              : null,
          child: authService.userPhotoURL == null 
              ? Icon(icon, color: kcAccentColor, size: 24)
              : null,
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: (!isSignedIn || isAnonymous)
            ? const Icon(
                Icons.arrow_forward_ios,
                color: kcSecondaryTextColor,
                size: 16,
              )
            : IconButton(
                icon: const Icon(Icons.logout, color: kcSecondaryTextColor),
                onPressed: () => _showSignOutDialog(context),
                tooltip: 'Sign Out',
              ),
        onTap: (!isSignedIn || isAnonymous)
            ? () => Navigator.of(context).pushNamed('/sign-in')
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }

  /// Show sign out confirmation dialog
  Future<void> _showSignOutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out', style: heading2Style(context)),
        content: Text(
          'Are you sure you want to sign out? Your local data will remain on this device.',
          style: bodyStyle(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: kcSecondaryTextColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kcDangerColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await FirebaseAuthService.instance.signOut();
        if (mounted) {
          // Navigate to sign-in screen and clear all navigation stack
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/sign-in',
            (route) => false, // Remove all previous routes
          );

          // Show success message on the sign-in screen
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Signed out successfully'),
                  backgroundColor: kcSuccessColor,
                ),
              );
            }
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign out failed: $e'),
              backgroundColor: kcDangerColor,
            ),
          );
        }
      }
    }
  }
  
  /// Restore data - directly open file picker and import
  Future<void> _restoreDataFromSettings(BuildContext context) async {
    try {
      // Open file picker directly
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'mcpkg', 'arcx'],
        allowMultiple: true, // Allow multiple files for separated packages
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final files = result.files.where((f) => f.path != null).map((f) => f.path!).toList();
      
      if (files.isEmpty) {
        return;
      }

      // Check file type and import accordingly
      final hasArcx = files.any((p) => p.endsWith('.arcx'));
      final hasZip = files.any((p) => p.endsWith('.zip') || p.endsWith('.mcpkg') || FileUtils.isMcpPackage(p));

      if (hasArcx) {
        // ARCX file(s) - navigate to ARCX import progress screen
        if (files.length == 1) {
          // Single ARCX file
          final arcxFile = File(files.first);
          if (!await arcxFile.exists()) {
            _showImportError(context, 'File not found');
            return;
          }

          // Find manifest file (sibling to .arcx)
          final manifestPath = files.first.replaceAll('.arcx', '.manifest.json');
          final manifestFile = File(manifestPath);
          String? actualManifestPath;
          
          if (await manifestFile.exists()) {
            actualManifestPath = manifestPath;
          }

          // Navigate to ARCX import progress screen
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ARCXImportProgressScreen(
                arcxPath: files.first,
                manifestPath: actualManifestPath,
                parentContext: context,
              ),
            ),
          ).then((result) {
            // Refresh timeline after ARCX import completes
            if (context.mounted && result != null) {
              try {
                context.read<TimelineCubit>().reloadAllEntries();
                print('✅ Timeline refreshed after ARCX import');
                
                // Navigate to timeline (Journal tab in HomeView)
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const HomeView(initialTab: 0), // Journal tab
                      ),
                      (route) => false, // Remove all previous routes
                    );
                  }
                });
              } catch (e) {
                print('⚠️ Could not refresh timeline: $e');
              }
            }
          });
        } else {
          // Multiple ARCX files - show error for now (separated packages need more complex handling)
          _showImportError(context, 'Multiple ARCX files selected. Please select one file at a time.');
        }
      } else if (hasZip) {
        // ZIP file(s) - use MCP pack import service
        if (files.length == 1) {
          // Single ZIP file
          final zipFile = File(files.first);
          if (!await zipFile.exists()) {
            _showImportError(context, 'File not found');
            return;
          }

          // Show loading indicator
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );

          try {
            // Initialize PhaseRegimeService for extended data import
            PhaseRegimeService? phaseRegimeService;
            try {
              final analyticsService = AnalyticsService();
              final rivetSweepService = RivetSweepService(analyticsService);
              phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
              await phaseRegimeService.initialize();
            } catch (e) {
              print('Warning: Could not initialize PhaseRegimeService: $e');
            }

            // Initialize ChatRepo for chat import
            final chatRepo = ChatRepoImpl.instance;
            await chatRepo.initialize();
            
            final journalRepo = context.read<JournalRepository>();
            final importService = McpPackImportService(
              journalRepo: journalRepo,
              phaseRegimeService: phaseRegimeService,
              chatRepo: chatRepo,
            );

            final importResult = await importService.importFromPath(files.first);

            if (!context.mounted) return;
            Navigator.pop(context); // Close loading dialog

            if (importResult.success) {
              // Refresh timeline before showing success dialog
              try {
                context.read<TimelineCubit>().reloadAllEntries();
                print('✅ Timeline refreshed after import');
              } catch (e) {
                print('⚠️ Could not refresh timeline: $e');
              }
              
              // Show success dialog briefly, then navigate to timeline
              _showImportSuccess(
                context,
                'Import Complete',
                'Imported ${importResult.totalEntries} entries and ${importResult.totalPhotos} media items.',
              );
              
              // Navigate to timeline after a short delay (allows dialog to show)
              Future.delayed(const Duration(milliseconds: 500), () {
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const HomeView(initialTab: 0), // Journal tab
                    ),
                    (route) => false, // Remove all previous routes
                  );
                }
              });
            } else {
              _showImportError(context, importResult.error ?? 'Import failed');
            }
          } catch (e) {
            if (!context.mounted) return;
            Navigator.pop(context); // Close loading dialog
            _showImportError(context, 'Import failed: $e');
          }
        } else {
          _showImportError(context, 'Multiple ZIP files selected. Please select one file at a time.');
        }
      } else {
        _showImportError(context, 'Unsupported file format');
      }
    } catch (e) {
      _showImportError(context, 'Failed to select file: $e');
    }
  }
  
  /// Show import error dialog
  void _showImportError(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcBackgroundColor,
        title: const Text('Error', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  /// Show import success dialog
  void _showImportSuccess(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcBackgroundColor,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  /// Build Memory Focus preset card
  Widget _buildMemoryFocusCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.memory, color: kcAccentColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Memory Focus',
                        style: heading3Style(context).copyWith(
                          color: kcPrimaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'How much context LUMARA uses from your history',
                        style: bodyStyle(context).copyWith(
                          color: kcSecondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_memoryFocusLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          ...MemoryFocusPreset.values.map((preset) => _buildMemoryFocusOption(preset)),
          // Show custom sliders when Custom is selected
          if (_showCustomMemorySettings) ..._buildCustomMemorySettings(),
        ],
      ),
    );
  }
  
  List<Widget> _buildCustomMemorySettings() {
    return [
      const Divider(height: 1, color: Colors.white12),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          'Custom Settings',
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
      _buildCustomSliderCard(
        title: 'Time Window',
        subtitle: 'How far back LUMARA searches your history',
        icon: Icons.history,
        value: _customTimeWindowDays.toDouble(),
        min: 1,
        max: 365,
        divisions: 36, // Every 10 days
        loading: _customMemorySettingsLoading,
        onChanged: (value) => _setCustomTimeWindowDays(value.round()),
        labels: const ['1 day', '30 days', '90 days', '180 days', '365 days'],
      ),
      _buildCustomSliderCard(
        title: 'Matching Precision',
        subtitle: 'How similar memories must be to include them',
        icon: Icons.tune,
        value: _customSimilarityThreshold,
        min: 0.3,
        max: 0.9,
        divisions: 12,
        loading: _customMemorySettingsLoading,
        onChanged: _setCustomSimilarityThreshold,
        labels: const ['Loose', 'Balanced', 'Strict'],
      ),
      _buildCustomSliderCard(
        title: 'Maximum Entries',
        subtitle: 'Maximum number of past entries to include',
        icon: Icons.format_list_numbered,
        value: _customMaxEntries.toDouble(),
        min: 1,
        max: 50,
        divisions: 49,
        loading: _customMemorySettingsLoading,
        onChanged: (value) => _setCustomMaxEntries(value.round()),
        labels: const ['1', '10', '20', '30', '50'],
      ),
    ];
  }
  
  Widget _buildCustomSliderCard({
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
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
              Icon(icon, color: kcAccentColor, size: 20),
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
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
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
            onChanged: loading ? null : onChanged,
          ),
          if (labels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: labels.map((label) => Text(
                  label,
                  style: bodyStyle(context).copyWith(
                    color: kcSecondaryTextColor,
                    fontSize: 9,
                  ),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildMemoryFocusOption(MemoryFocusPreset preset) {
    final isSelected = _memoryFocusPreset == preset;
    return InkWell(
      onTap: _memoryFocusLoading ? null : () => _setMemoryFocusPreset(preset),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? kcAccentColor : Colors.white38,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kcAccentColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.displayName,
                    style: bodyStyle(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? kcAccentColor : kcPrimaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preset.description,
                    style: bodyStyle(context).copyWith(
                      fontSize: 11,
                      color: kcSecondaryTextColor,
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
  
  Future<void> _setMemoryFocusPreset(MemoryFocusPreset preset) async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.setMemoryFocusPreset(preset);
      if (mounted) {
        setState(() {
          _memoryFocusPreset = preset;
          _showCustomMemorySettings = preset == MemoryFocusPreset.custom;
          
          // Load custom values if switching to Custom
          if (preset == MemoryFocusPreset.custom) {
            _loadCustomMemorySettings();
          }
        });
      }
    } catch (e) {
      print('Error setting memory focus preset: $e');
    }
  }
  
  Future<void> _loadCustomMemorySettings() async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();
      final settings = await settingsService.loadAllSettings();
      if (mounted) {
        setState(() {
          _customTimeWindowDays = settings['timeWindowDays'] as int? ?? (settings['lookbackYears'] as int? ?? 5) * 365;
          _customSimilarityThreshold = settings['similarityThreshold'] as double? ?? 0.55;
          _customMaxEntries = settings['maxMatches'] as int? ?? 20;
          _customMemorySettingsLoading = false;
        });
      }
    } catch (e) {
      print('Error loading custom memory settings: $e');
      if (mounted) {
        setState(() {
          _customMemorySettingsLoading = false;
        });
      }
    }
  }
  
  Future<void> _setCustomTimeWindowDays(int days) async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.setTimeWindowDays(days);
      if (mounted) {
        setState(() {
          _customTimeWindowDays = days;
        });
      }
    } catch (e) {
      print('Error setting custom time window days: $e');
    }
  }
  
  Future<void> _setCustomSimilarityThreshold(double threshold) async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.setSimilarityThreshold(threshold);
      if (mounted) {
        setState(() {
          _customSimilarityThreshold = threshold;
        });
      }
    } catch (e) {
      print('Error setting custom similarity threshold: $e');
    }
  }
  
  Future<void> _setCustomMaxEntries(int entries) async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.setMaxMatches(entries);
      if (mounted) {
        setState(() {
          _customMaxEntries = entries;
        });
      }
    } catch (e) {
      print('Error setting custom max entries: $e');
    }
  }
  
  /// Build Include Media toggle
  Widget _buildIncludeMediaToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: SwitchListTile(
        title: Text(
          'Include Media',
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Analyze photos, audio, and video in reflections',
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
          ),
        ),
        value: _crossModalEnabled,
        onChanged: _crossModalLoading
            ? null
            : (value) => _setCrossModalEnabled(value),
        secondary: Icon(
          Icons.perm_media,
          color: kcAccentColor,
          size: 24,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
  
  Future<void> _setCrossModalEnabled(bool value) async {
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.setCrossModalEnabled(value);
      if (mounted) {
        setState(() {
          _crossModalEnabled = value;
        });
      }
    } catch (e) {
      print('Error setting cross-modal enabled: $e');
    }
  }
}
