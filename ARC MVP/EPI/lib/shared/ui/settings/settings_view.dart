import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/shared/ui/settings/sync_settings_section.dart';
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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/ui/subscription/subscription_management_view.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/shared/ui/settings/google_drive_backup_settings_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  int _favoritesCount = 0;
  int _savedChatsCount = 0;
  int _favoriteEntriesCount = 0;
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

  @override
  void initState() {
    super.initState();
    _loadFavoritesCount();
    _loadVoiceoverPreference();
    _loadShakeToReportPreference();
    _loadPersonaPreference();
    _loadLumaraSettings();
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
      final answersCount = await FavoritesService.instance.getCountByCategory('answer');
      final chatsCount = await FavoritesService.instance.getCountByCategory('chat');
      final entriesCount = await FavoritesService.instance.getCountByCategory('journal_entry');
      if (mounted) {
        setState(() {
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
                  title: 'Import/Export Data',
                  subtitle: 'Export, import, and organize your journal data',
                  icon: Icons.dashboard,
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
                _buildSettingsTile(
                  context,
                  title: 'Google Drive Backup',
                  subtitle: 'Automatically backup to Google Drive',
                  icon: Icons.cloud_upload,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GoogleDriveBackupSettingsView(
                          journalRepo: context.read<JournalRepository>(),
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
                      ? 'Answers ($_favoritesCount/25), Chats ($_savedChatsCount/20), Entries ($_favoriteEntriesCount/20)'
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

            // Sync Settings Section
            const SyncSettingsSection(),

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
          setState(() {}); // Refresh the UI
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signed out successfully'),
              backgroundColor: kcSuccessColor,
            ),
          );
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
}
