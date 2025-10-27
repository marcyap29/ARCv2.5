/// ARCX Settings View
/// 
/// Configure .arcx export and migration settings.
library arcx_settings;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';

class ARCXSettingsView extends StatefulWidget {
  const ARCXSettingsView({super.key});

  @override
  State<ARCXSettingsView> createState() => _ARCXSettingsViewState();
}

class _ARCXSettingsViewState extends State<ARCXSettingsView> {
  bool _includePhotoLabels = false;
  bool _dateOnlyTimestamps = false;
  bool _secureDeleteOriginal = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _includePhotoLabels = prefs.getBool('arcx_include_photo_labels') ?? false;
      _dateOnlyTimestamps = prefs.getBool('arcx_date_only_timestamps') ?? false;
      _secureDeleteOriginal = prefs.getBool('arcx_secure_delete_original') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('arcx_include_photo_labels', _includePhotoLabels);
    await prefs.setBool('arcx_date_only_timestamps', _dateOnlyTimestamps);
    await prefs.setBool('arcx_secure_delete_original', _secureDeleteOriginal);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: kcBackgroundColor,
        appBar: AppBar(
          backgroundColor: kcBackgroundColor,
          elevation: 0,
          title: Text(
            'ARCX Settings',
            style: heading1Style(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: kcPrimaryTextColor),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: Text(
          'Secure Archive Settings',
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
            // Export Settings Section
            _buildSection(
              context,
              title: 'Export Settings',
              children: [
                _buildSwitchTile(
                  context,
                  title: 'Include Photo Labels',
                  subtitle: 'Include AI-generated labels in photo metadata (may contain sensitive information)',
                  value: _includePhotoLabels,
                  onChanged: (value) {
                    setState(() {
                      _includePhotoLabels = value;
                    });
                    _saveSettings();
                  },
                ),
                _buildSwitchTile(
                  context,
                  title: 'Date-Only Timestamps',
                  subtitle: 'Remove time information from timestamps (YYYY-MM-DD only)',
                  value: _dateOnlyTimestamps,
                  onChanged: (value) {
                    setState(() {
                      _dateOnlyTimestamps = value;
                    });
                    _saveSettings();
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Migration Settings Section
            _buildSection(
              context,
              title: 'Migration Settings',
              children: [
                _buildSwitchTile(
                  context,
                  title: 'Secure Delete Original',
                  subtitle: 'Automatically delete original .zip files after successful migration',
                  value: _secureDeleteOriginal,
                  onChanged: (value) {
                    setState(() {
                      _secureDeleteOriginal = value;
                    });
                    _saveSettings();
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // About ARCX Section
            _buildSection(
              context,
              title: 'About ARCX',
              children: [
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Secure Archive Format',
                          style: heading3Style(context).copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ARCX (.arcx) is a secure, encrypted archive format for your journal data. It uses:',
                          style: bodyStyle(context),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• AES-256-GCM encryption\n• Ed25519 digital signatures\n• iOS-native file protection\n• PII redaction by default',
                          style: bodyStyle(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Compatible with AirDrop, Files app, and secure sharing.',
                          style: bodyStyle(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: heading2Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        title: Text(title, style: bodyStyle(context)),
                  subtitle: Text(subtitle, style: captionStyle(context)),
        value: value,
        onChanged: onChanged,
        activeColor: kcPrimaryColor,
      ),
    );
  }
}

