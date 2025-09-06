import 'package:flutter/material.dart';
import 'package:my_app/features/home/home_view.dart';
import 'package:my_app/features/startup/welcome_view.dart';
import 'package:my_app/features/startup/phase_quiz_prompt_view.dart';
import 'package:hive/hive.dart';
import 'package:my_app/models/user_profile_model.dart';
import 'package:my_app/repositories/journal_repository.dart';
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

      if (userProfile != null && userProfile.onboardingCompleted) {
        print('DEBUG: User has completed onboarding, checking journal entries');
        // User has completed onboarding, but check if they have journal entries
        await _checkJournalEntriesAndNavigate();
      } else {
        print('DEBUG: User has not completed onboarding, navigating to welcome');
        _navigateToWelcome();
      }
    } catch (e) {
      print('DEBUG: Error in _checkOnboardingStatus: $e');
      // If there's an error accessing the profile, go to welcome
      _navigateToWelcome();
    }
  }

  Future<void> _checkJournalEntriesAndNavigate() async {
    try {
      final journalRepository = JournalRepository();
      final entryCount = await journalRepository.getEntryCount();
      
      print('DEBUG: Journal entry count: $entryCount');
      
      if (entryCount > 0) {
        print('DEBUG: $entryCount entries found, navigating to welcome screen (Continue Your Journey)');
        // User has entries, navigate to welcome screen with "Continue Your Journey"
        _navigateToWelcome();
      } else {
        print('DEBUG: No entries found, navigating to phase quiz (post-onboarding user)');
        // No journal entries exist, navigate to phase quiz for post-onboarding users
        _navigateToPhaseQuiz();
      }
    } catch (e) {
      print('DEBUG: Error checking journal entries: $e');
      // If there's an error checking entries, go to home as fallback
      _navigateToHome();
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

  void _navigateToWelcome() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeView()),
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
