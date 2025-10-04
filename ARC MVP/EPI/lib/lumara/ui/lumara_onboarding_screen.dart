// lib/lumara/ui/lumara_onboarding_screen.dart
// LUMARA onboarding screen for first-time setup

import 'package:flutter/material.dart';
import 'lumara_settings_screen.dart';

/// LUMARA onboarding screen shown when no AI provider is configured
class LumaraOnboardingScreen extends StatelessWidget {
  const LumaraOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo/Icon
              Icon(
                Icons.psychology,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Welcome to LUMARA',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Subtitle
              Text(
                'Your AI-powered journaling companion',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Setup message
              Text(
                'Choose how you\'d like LUMARA to provide insights:',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Option A: Internal Models
              _buildOptionCard(
                context: context,
                theme: theme,
                icon: Icons.security,
                title: 'Download Internal Models',
                subtitle: 'Privacy-first AI that runs entirely on your device',
                badge: 'RECOMMENDED',
                badgeColor: theme.colorScheme.primary,
                onTap: () => _navigateToSettings(context, showInternalModels: true),
              ),
              const SizedBox(height: 16),

              // Option B: Cloud API
              _buildOptionCard(
                context: context,
                theme: theme,
                icon: Icons.cloud,
                title: 'Use Cloud API',
                subtitle: 'Connect to Gemini, OpenAI, or Anthropic',
                badge: 'REQUIRES API KEY',
                badgeColor: theme.colorScheme.secondary,
                onTap: () => _navigateToSettings(context, showInternalModels: false),
              ),
              const SizedBox(height: 32),

              // Info text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You can change your choice anytime in Settings',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
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
                      color: badgeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: badgeColor,
                      size: 32,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: badgeColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      badge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Set up',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    color: badgeColor,
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

  void _navigateToSettings(BuildContext context, {required bool showInternalModels}) async {
    // Navigate to LUMARA Settings and wait for return
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LumaraSettingsScreen(),
      ),
    );

    // If settings were saved and configuration is complete, go back to LUMARA
    // The assistant screen will check configuration and show main UI if ready
    if (context.mounted && result == true) {
      Navigator.pop(context);
    }
  }
}
