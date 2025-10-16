import 'package:flutter/material.dart';
import 'package:my_app/features/home/home_view.dart';
import 'package:my_app/features/startup/phase_quiz_prompt_view.dart';
import 'package:hive/hive.dart';
import 'package:my_app/models/user_profile_model.dart';
import 'package:my_app/shared/app_colors.dart';

class StartupView extends StatefulWidget {
  const StartupView({super.key});

  @override
  State<StartupView> createState() => _StartupViewState();
}

class _StartupViewState extends State<StartupView> {
  @override
  void initState() {
    super.initState();
    print('DEBUG: StartupView initState called');
    _checkOnboardingStatus();
  }

  void _checkOnboardingStatus() async {
    print('DEBUG: _checkOnboardingStatus called');
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    try {
      // Check if box is already open (from bootstrap)
      Box<UserProfile> userBox;
      if (Hive.isBoxOpen('user_profile')) {
        userBox = Hive.box<UserProfile>('user_profile');
        print('DEBUG: Using existing user_profile box');
      } else {
        userBox = await Hive.openBox<UserProfile>('user_profile');
        print('DEBUG: Opened new user_profile box');
      }
      
      final userProfile = userBox.get('profile');
      
      print('DEBUG: User profile found: ${userProfile != null}');
      print('DEBUG: Onboarding completed: ${userProfile?.onboardingCompleted}');
      print('DEBUG: Current season: ${userProfile?.onboardingCurrentSeason}');

      // NEW RULES: Only show quiz to completely new users (no profile exists at all)
      // This ensures the quiz only appears on fresh installs, not when users delete all entries
      final isNewUser = userProfile == null;
      
      if (isNewUser) {
        print('DEBUG: New user detected (no profile), showing phase quiz');
        _navigateToPhaseQuiz();
      } else {
        print('DEBUG: Existing user, navigating to main menu');
        // Existing user - go directly to main menu
        _navigateToHome();
      }
    } catch (e) {
      print('DEBUG: Error in _checkOnboardingStatus: $e');
      // If there's an error accessing the profile, treat as new user
      _navigateToPhaseQuiz();
    }
  }


  void _navigateToHome() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeView()),
      );
    }
  }


  void _navigateToPhaseQuiz() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PhaseQuizPromptView()),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0C0F14),
              Color(0xFF121621),
            ],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kcPrimaryColor),
          ),
        ),
      ),
    );
  }
}
