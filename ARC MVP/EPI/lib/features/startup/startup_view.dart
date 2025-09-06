import 'package:flutter/material.dart';
import 'package:my_app/features/home/home_view.dart';
import 'package:my_app/features/startup/welcome_view.dart';
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
    _checkOnboardingStatus();
  }

  void _checkOnboardingStatus() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    try {
      final userBox = await Hive.openBox<UserProfile>('user_profile');
      final userProfile = userBox.get('profile');

      if (userProfile != null && userProfile.onboardingCompleted) {
        // User has completed onboarding, but check if they have journal entries
        await _checkJournalEntriesAndNavigate();
      } else {
        _navigateToWelcome();
      }
    } catch (e) {
      // If there's an error accessing the profile, go to welcome
      _navigateToWelcome();
    }
  }

  Future<void> _checkJournalEntriesAndNavigate() async {
    try {
      final journalRepository = JournalRepository();
      final entryCount = await journalRepository.getEntryCount();
      
      if (entryCount == 0) {
        // No journal entries exist, navigate to welcome screen
        // This will show "Continue Your Journey" for post-onboarding users
        _navigateToWelcome();
      } else {
        // User has entries, navigate to normal home view
        _navigateToHome();
      }
    } catch (e) {
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
