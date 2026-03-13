// lib/shared/ui/onboarding/personality_reminder_screen.dart
// Standalone "How we'll work together" screen shown intermittently when user hasn't filled it (e.g. every 5–10 launches).

import 'package:flutter/material.dart';
import 'package:my_app/shared/ui/home/home_view.dart';
import 'package:my_app/shared/ui/onboarding/widgets/personality_setup_screen.dart';

/// Full-screen personality setup shown alone (no other onboarding). On complete or skip, replaces with [HomeView].
class PersonalityReminderScreen extends StatelessWidget {
  const PersonalityReminderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PersonalitySetupScreen(
      standaloneMode: true,
      onSaveAndComplete: () => _goToHome(context),
      onSkip: () => _goToHome(context),
    );
  }

  static void _goToHome(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const HomeView(),
      ),
    );
  }
}
