// lib/arc/chat/ui/lumara_splash_screen.dart
// LUMARA splash screen shown on app launch

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:my_app/models/user_profile_model.dart';
import 'package:my_app/shared/ui/home/home_view.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/ui/auth/sign_in_screen.dart';
import 'package:my_app/shared/ui/onboarding/arc_onboarding_sequence.dart';
import 'package:my_app/arc/core/journal_repository.dart';

/// Splash screen with LUMARA logo (phase shape removed for reposition)
class LumaraSplashScreen extends StatefulWidget {
  const LumaraSplashScreen({super.key});

  @override
  State<LumaraSplashScreen> createState() => _LumaraSplashScreenState();
}

class _LumaraSplashScreenState extends State<LumaraSplashScreen> 
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  /// Safeguard: if init hangs, still navigate after this delay so app never sticks on splash/white.
  Timer? _safeguardTimer;
  bool _hasNavigated = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Fade in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
    
    _loadCurrentPhase(); // starts timer with correct duration when done

    // Ensure we never stick on splash (e.g. if _loadCurrentPhase or phase init hangs)
    _safeguardTimer = Timer(const Duration(seconds: 14), () {
      if (mounted && !_hasNavigated) {
        _checkAuthAndNavigate();
      }
    });
  }

  Future<void> _loadCurrentPhase() async {
    // Phase display removed for reposition; minimal init then start timer
    if (mounted) _startTimer();
  }

  void _startTimer() {
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _checkAuthAndNavigate();
      }
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    if (_hasNavigated) return;
    _timer?.cancel();
    _safeguardTimer?.cancel();

    // Check if user is authenticated
    final isSignedIn = FirebaseAuthService.instance.isSignedIn;

    if (isSignedIn) {
      // Prefer UserProfile.onboardingCompleted so quiz/inaugural entry is not treated as "no entries"
      final onboardingCompleted = await _getOnboardingCompleted();
      final hasAnyJournalEntry = await _hasAnyJournalEntry();

      if (onboardingCompleted || hasAnyJournalEntry) {
        // Completed onboarding (profile flag) or has at least one entry (e.g. inaugural from phase quiz) → home
        if (mounted && !_hasNavigated) {
          _hasNavigated = true;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const HomeView(),
            ),
          );
        }
      } else {
        // First-time user - show onboarding
        if (mounted && !_hasNavigated) {
          _hasNavigated = true;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const ArcOnboardingSequence(),
            ),
          );
        }
      }
    } else {
      // User is not signed in, go to sign-in screen
      if (mounted && !_hasNavigated) {
        _hasNavigated = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const SignInScreen(),
          ),
        );
      }
    }
  }

  /// True if UserProfile has onboardingCompleted set (quiz or skip path completed).
  Future<bool> _getOnboardingCompleted() async {
    try {
      Box<UserProfile> userBox;
      if (Hive.isBoxOpen('user_profile')) {
        userBox = Hive.box<UserProfile>('user_profile');
      } else {
        userBox = await Hive.openBox<UserProfile>('user_profile');
      }
      final profile = userBox.get('profile');
      return profile?.onboardingCompleted == true;
    } catch (e) {
      return false;
    }
  }

  /// True if user has at least one journal entry (including onboarding-tagged, e.g. inaugural from phase quiz).
  Future<bool> _hasAnyJournalEntry() async {
    try {
      final journalRepo = JournalRepository();
      final entries = await journalRepo.getAllJournalEntries();
      return entries.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  void _navigateToMainMenu() {
    // Allow user to tap anywhere to skip the splash screen timer
    _checkAuthAndNavigate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _safeguardTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Black background for white logo
      body: GestureDetector(
        onTap: _navigateToMainMenu, // Tap anywhere to skip
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final logoSize = (constraints.maxWidth * 0.5).clamp(150.0, 300.0);
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'LUMARA',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 12,
                        ) ?? const TextStyle(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 12,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Image.asset(
                        'assets/icon/LUMARA_Sigil.png',
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

