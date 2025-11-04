// lib/lumara/ui/lumara_onboarding_screen.dart
// LUMARA onboarding screen for first-time setup

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lumara_settings_screen.dart';
import 'widgets/lumara_icon.dart';
import 'package:my_app/shared/ui/home/home_view.dart';

/// LUMARA onboarding screen shown when no AI provider is configured
class LumaraOnboardingScreen extends StatelessWidget {
  const LumaraOnboardingScreen({super.key});

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
            return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                    // Add space to push symbol lower
                    const SizedBox(height: 120),
                    
                    // Logo/Icon - positioned lower, medium size
                    Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculate icon size based on screen width (use 40% of screen width, min 200px)
                          final iconSize = (constraints.maxWidth * 0.4).clamp(200.0, 600.0);
                          return LumaraIcon(
                            size: iconSize,
                color: theme.colorScheme.primary,
                            strokeWidth: (iconSize / 100).clamp(2.0, 6.0),
                          );
                        },
                      ),
                    ),

                    // Reduced gap between symbol and card
              const SizedBox(height: 16),

                    // LUMARA Settings Card - positioned closer to symbol
              _buildSettingsCard(
                context: context,
                theme: theme,
              ),
                    
                    // Ensure card doesn't scroll past bottom
                    const SizedBox(height: 40),
            ],
          ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required BuildContext context,
    required ThemeData theme,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _navigateToSettings(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.settings,
                      color: theme.colorScheme.primary,
                      size: 32,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'SETUP',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'LUMARA Settings',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Configure AI provider, model settings, and preferences',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Open Settings',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToSettings(BuildContext context) async {
    // Navigate to LUMARA Settings and wait for return
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LumaraSettingsScreen(),
      ),
    );

    // If settings were saved and configuration is complete, navigate to HomeView
    if (context.mounted && result == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('lumara_onboarding_completed', true);
      await prefs.setBool('lumara_welcome_shown', true); // Mark welcome as shown
      
      // Navigate to HomeView, replacing the onboarding screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeView(),
        ),
      );
    }
  }
}
