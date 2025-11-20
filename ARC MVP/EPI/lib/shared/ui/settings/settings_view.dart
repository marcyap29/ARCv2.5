import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/shared/ui/settings/sync_settings_section.dart';
import 'package:my_app/shared/ui/settings/music_control_section.dart';
import 'package:my_app/shared/ui/settings/first_responder_settings_section.dart';
import 'package:my_app/shared/ui/settings/coach_mode_settings_section.dart';
import 'package:my_app/shared/ui/settings/mcp_bundle_health_view.dart';
import 'package:my_app/shared/ui/settings/privacy_settings_view.dart';
import 'package:my_app/shared/ui/settings/memory_mode_settings_view.dart';
import 'package:my_app/shared/ui/settings/memory_snapshot_management_view.dart';
import 'package:my_app/shared/ui/settings/conflict_management_view.dart';
import 'package:my_app/shared/ui/settings/lumara_settings_view.dart';
import 'package:my_app/shared/ui/settings/arcx_settings_view.dart';
import 'package:my_app/shared/ui/settings/favorites_management_view.dart';
import 'package:my_app/shared/ui/settings/advanced_analytics_preference_service.dart';
import 'package:my_app/shared/ui/settings/voiceover_preference_service.dart';
import 'package:my_app/ui/screens/mcp_management_screen.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/chat/services/favorites_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  bool _advancedAnalyticsEnabled = false;
  bool _advancedAnalyticsLoading = true;
  bool _voiceoverEnabled = false;
  bool _voiceoverLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavoritesCount();
    _loadAdvancedAnalyticsPreference();
    _loadVoiceoverPreference();
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

  Future<void> _loadAdvancedAnalyticsPreference() async {
    try {
      final enabled = await AdvancedAnalyticsPreferenceService.instance.isAdvancedAnalyticsEnabled();
      if (mounted) {
        setState(() {
          _advancedAnalyticsEnabled = enabled;
          _advancedAnalyticsLoading = false;
        });
      }
    } catch (e) {
      print('Error loading advanced analytics preference: $e');
      if (mounted) {
        setState(() {
          _advancedAnalyticsLoading = false;
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

  Future<void> _toggleAdvancedAnalytics(bool value) async {
    try {
      await AdvancedAnalyticsPreferenceService.instance.setAdvancedAnalyticsEnabled(value);
      if (mounted) {
        setState(() {
          _advancedAnalyticsEnabled = value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Advanced Analytics enabled - Health and Analytics tabs are now visible'
                  : 'Advanced Analytics disabled - Health and Analytics tabs are now hidden',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: value ? Colors.green : Colors.lightBlue,
          ),
        );
        // Pop settings and return true to indicate preference changed
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling Advanced Analytics: $e'),
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
            // Advanced Analytics Section (Above Import & Export)
            _buildSection(
              context,
              title: 'Advanced Analytics',
              children: [
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
                      'Show Advanced Analytics',
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Show/hide Health and Analytics tabs in Insights',
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                      ),
                    ),
                    value: _advancedAnalyticsEnabled,
                    onChanged: _advancedAnalyticsLoading
                        ? null
                        : (value) => _toggleAdvancedAnalytics(value),
                    secondary: _advancedAnalyticsLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.analytics,
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
                  title: 'Bundle Health Check',
                  subtitle: 'Validate and repair backup files',
                  icon: Icons.health_and_safety,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const McpBundleHealthView()),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  title: 'Secure Archive Settings',
                  subtitle: 'Configure .arcx encryption and redaction',
                  icon: Icons.security,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ARCXSettingsView()),
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
                _buildSettingsTile(
                  context,
                  title: 'LUMARA Settings',
                  subtitle: 'Configure your AI reflection partner',
                  icon: Icons.auto_awesome,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LumaraSettingsView()),
                    );
                  },
                ),
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
                      'Voiceover Mode',
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Speak AI responses aloud',
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

            // Music Control Section
            const MusicControlSection(),

            const SizedBox(height: 32),

            // First Responder Settings Section
            const FirstResponderSettingsSection(),

            const SizedBox(height: 32),

            // Coach Mode Settings Section
            const CoachModeSettingsSection(),

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
}
