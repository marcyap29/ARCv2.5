// lib/lumara/ui/lumara_settings_welcome_screen.dart
// LUMARA settings welcome splash screen shown once when first opening LUMARA tab

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/lumara_icon.dart';
import 'lumara_settings_screen.dart';

/// Welcome splash screen for LUMARA settings - shown only once
class LumaraSettingsWelcomeScreen extends StatelessWidget {
  const LumaraSettingsWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: theme.colorScheme.onSurface,
            size: 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to Main Menu',
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate icon size based on screen width (use 40% of screen width, min 200px)
            final iconSize = (constraints.maxWidth * 0.4).clamp(200.0, 600.0);
            
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Large LUMARA symbol (responsive - 40% of screen width, min 200px)
                  LumaraIcon(
                    size: iconSize,
                    color: theme.colorScheme.primary,
                  ),
              
              const SizedBox(height: 48),
              
              // Welcome text
              Text(
                'Welcome to LUMARA',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Your AI-powered journaling companion',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 64),
              
              // Continue button
              ElevatedButton(
                onPressed: () => _navigateToSettings(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Continue'),
              ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _navigateToSettings(BuildContext context) async {
    // Mark welcome as shown
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lumara_settings_welcome_shown', true);
    
    // Navigate to settings screen
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LumaraSettingsScreen(),
        ),
      );
    }
  }
}

/// Helper function to check if welcome screen should be shown
Future<bool> shouldShowLumaraSettingsWelcome() async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool('lumara_settings_welcome_shown') ?? false);
}

