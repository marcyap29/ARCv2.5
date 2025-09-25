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

      // Check if user has a phase (onboardingCurrentSeason)
      final hasPhase = userProfile?.onboardingCurrentSeason != null && 
                      userProfile!.onboardingCurrentSeason!.isNotEmpty;

      if (hasPhase) {
        print('DEBUG: User has a phase (${userProfile.onboardingCurrentSeason}), navigating to main menu');
        // User has a phase, go directly to main menu (Phase tab as starting screen)
        _navigateToHome();
      } else {
        print('DEBUG: User does not have a phase, navigating to phase quiz');
        // User doesn't have a phase, take them straight to phase quiz
        _navigateToPhaseQuiz();
      }
    } catch (e) {
      print('DEBUG: Error in _checkOnboardingStatus: $e');
      // If there's an error accessing the profile, go to phase quiz
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
