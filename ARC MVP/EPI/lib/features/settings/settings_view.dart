import 'package:flutter/material.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import 'sync_settings_section.dart';
import 'music_control_section.dart';
import 'first_responder_settings_section.dart';
import 'coach_mode_settings_section.dart';
import 'data_view.dart';
import 'mcp_settings_view.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

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
            
            // Privacy Section
            _buildSection(
              context,
              title: 'Privacy & Data',
              children: [
                _buildSettingsTile(
                  context,
                  title: 'Data Export',
                  subtitle: 'Export your journal data as JSON',
                  icon: Icons.download,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DataView()),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  title: 'MCP Export',
                  subtitle: 'Export to MCP Memory Bundle format',
                  icon: Icons.cloud_upload,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const McpSettingsView()),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  title: 'MCP Import',
                  subtitle: 'Import from MCP Memory Bundle',
                  icon: Icons.cloud_download,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const McpSettingsView()),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  title: 'Erase All Data',
                  subtitle: 'Permanently delete all data',
                  icon: Icons.delete_forever,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DataView()),
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
