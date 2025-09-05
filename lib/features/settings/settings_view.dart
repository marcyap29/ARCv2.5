import 'package:flutter/material.dart';
import 'package:my_app/features/settings/privacy_view.dart';
import 'package:my_app/features/settings/data_view.dart';
import 'package:my_app/features/settings/personalization_view.dart';
import 'package:my_app/features/settings/about_view.dart';
import 'package:my_app/features/settings/widgets/settings_tile.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Privacy Section
          SettingsTile(
            title: 'Privacy',
            subtitle: 'Control your data and privacy settings',
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyView()),
              );
            },
          ),
          const Divider(color: Colors.grey),
          
          // Data Section
          SettingsTile(
            title: 'Data',
            subtitle: 'Export and manage your data',
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DataView()),
              );
            },
          ),
          const Divider(color: Colors.grey),
          
          // Personalization Section
          SettingsTile(
            title: 'Personalization',
            subtitle: 'Customize your experience',
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PersonalizationView()),
              );
            },
          ),
          const Divider(color: Colors.grey),
          
          // About Section
          SettingsTile(
            title: 'About',
            subtitle: 'App information and support',
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutView()),
              );
            },
          ),
        ],
      ),
    );
  }
}