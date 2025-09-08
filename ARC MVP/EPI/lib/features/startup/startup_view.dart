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

  /// Ensures Hive is ready and critical boxes are available
  Future<void> _ensureHiveReady() async {
    print('DEBUG: Ensuring Hive is ready for StartupView');
    
    // Wait for Hive to be initialized with exponential backoff
    int attempts = 0;
    const maxAttempts = 15; // Increased from 10
    
    while (attempts < maxAttempts) {
      try {
        // First check if Hive itself is initialized
        if (!Hive.isBoxOpen('settings')) {
          print('DEBUG: Settings box not open, attempting to open... (attempt ${attempts + 1})');
          
          // Try to open the settings box
          try {
            await Hive.openBox('settings');
            print('DEBUG: Successfully opened settings box');
          } catch (openError) {
            print('DEBUG: Failed to open settings box: $openError');
            
            // If opening fails, wait longer and try again
            final waitTime = Duration(milliseconds: 200 * (attempts + 1)); // Exponential backoff
            await Future.delayed(waitTime);
            attempts++;
            continue;
          }
        }
        
        // Test if Hive is actually working
        final settingsBox = Hive.box('settings');
        final testKey = '_startup_health_check_${DateTime.now().millisecondsSinceEpoch}';
        
        await settingsBox.put(testKey, DateTime.now().millisecondsSinceEpoch);
        final testValue = settingsBox.get(testKey);
        await settingsBox.delete(testKey);
        
        if (testValue == null) {
          throw Exception('Hive read/write test failed - value not persisted');
        }
        
        print('DEBUG: Hive is ready for StartupView (attempt ${attempts + 1})');
        
        // Also ensure user_profile box is available
        if (!Hive.isBoxOpen('user_profile')) {
          try {
            await Hive.openBox<UserProfile>('user_profile');
            print('DEBUG: Successfully opened user_profile box');
          } catch (profileError) {
            print('DEBUG: Failed to open user_profile box: $profileError');
            // Try opening as generic box
            await Hive.openBox('user_profile');
            print('DEBUG: Opened user_profile as generic box');
          }
        }
        
        return; // Success!
        
      } catch (e) {
        print('DEBUG: Hive health check failed (attempt ${attempts + 1}): $e');
        
        // Progressive backoff: wait longer each time
        final waitTime = Duration(milliseconds: 300 * (attempts + 1));
        await Future.delayed(waitTime);
        attempts++;
        
        // On later attempts, try more aggressive recovery
        if (attempts > 5) {
          print('DEBUG: Attempting aggressive Hive recovery (attempt $attempts)');
          try {
            // Close all boxes and try to reinitialize
            await Hive.close();
            await Future.delayed(const Duration(milliseconds: 200));
            
            // Don't reinit Hive here as that's done in bootstrap
            // Just try to reopen the critical boxes
            if (!Hive.isBoxOpen('settings')) {
              await Hive.openBox('settings');
            }
          } catch (recoveryError) {
            print('DEBUG: Aggressive recovery failed: $recoveryError');
          }
        }
      }
    }
    
    // If we get here, we've exhausted all attempts
    print('DEBUG: WARNING - Could not ensure Hive is ready after $maxAttempts attempts');
    print('DEBUG: Proceeding anyway - errors will be handled downstream');
  }

  void _checkOnboardingStatus() async {
    print('DEBUG: _checkOnboardingStatus called');
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    try {
      // Ensure Hive is properly initialized before accessing boxes
      await _ensureHiveReady();
      if (!mounted) return;
      
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
