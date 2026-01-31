// lib/lumara/ui/lumara_splash_screen.dart
// ARC splash screen shown on app launch

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/shared/ui/home/home_view.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/ui/auth/sign_in_screen.dart';
import 'package:my_app/ui/splash/animated_phase_shape.dart';
import 'package:my_app/shared/ui/onboarding/arc_onboarding_sequence.dart';
import 'package:my_app/arc/core/journal_repository.dart';

/// Splash screen with ARC logo and animated phase shape
class LumaraSplashScreen extends StatefulWidget {
  const LumaraSplashScreen({super.key});

  @override
  State<LumaraSplashScreen> createState() => _LumaraSplashScreenState();
}

class _LumaraSplashScreenState extends State<LumaraSplashScreen> 
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  String _currentPhase = 'Discovery';
  bool _phaseLoaded = false;
  /// True only when the user has at least one phase regime (current or past).
  /// When false, we show only the ARC logo—no phase shape or label.
  bool _userHasPhase = false;
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
  }

  Future<void> _loadCurrentPhase() async {
    try {
      // Use PhaseRegimeService - the authoritative source for current phase
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      final currentRegime = phaseRegimeService.phaseIndex.currentRegime;
      final allRegimes = phaseRegimeService.phaseIndex.allRegimes;
      final hasAnyRegime = currentRegime != null || allRegimes.isNotEmpty;

      String phase = 'Discovery';
      if (currentRegime != null) {
        phase = currentRegime.label.toString().split('.').last;
        phase = phase[0].toUpperCase() + phase.substring(1);
      } else if (allRegimes.isNotEmpty) {
        final sortedRegimes = List.from(allRegimes)
          ..sort((a, b) => b.start.compareTo(a.start));
        final mostRecent = sortedRegimes.first;
        phase = mostRecent.label.toString().split('.').last;
        phase = phase[0].toUpperCase() + phase.substring(1);
      }

      if (mounted) {
        setState(() {
          _userHasPhase = hasAnyRegime;
          _currentPhase = phase;
          _phaseLoaded = true;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userHasPhase = false;
          _phaseLoaded = true;
        });
        _startTimer();
      }
    }
  }

  void _startTimer() {
    // Logo-only: 3s. With phase shape: 8s to admire the animation.
    final duration = _userHasPhase
        ? const Duration(seconds: 8)
        : const Duration(seconds: 3);
    _timer = Timer(duration, () {
      if (mounted) {
        _checkAuthAndNavigate();
      }
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    _timer?.cancel();

    // Check if user is authenticated
    final isSignedIn = FirebaseAuthService.instance.isSignedIn;

    if (isSignedIn) {
      // Check if this is a first-time user (no journal entries)
      final userEntryCount = await _getUserEntryCount();
      
      if (userEntryCount == 0) {
        // First-time user - show onboarding
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const ArcOnboardingSequence(),
            ),
          );
        }
      } else {
        // Returning user - go to home
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeView(),
            ),
          );
        }
      }
    } else {
      // User is not signed in, go to sign-in screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const SignInScreen(),
          ),
        );
      }
    }
  }

  Future<int> _getUserEntryCount() async {
    try {
      final journalRepo = JournalRepository();
      final entries = await journalRepo.getAllJournalEntries();
      // Filter out onboarding entries (they have 'onboarding' tag)
      final nonOnboardingEntries = entries.where((e) => 
        !e.tags.contains('onboarding')
      ).toList();
      return nonOnboardingEntries.length;
    } catch (e) {
      print('Error getting user entry count: $e');
      return 0; // Default to showing onboarding on error
    }
  }

  void _navigateToMainMenu() {
    // Allow user to tap anywhere to skip the splash screen timer
    _checkAuthAndNavigate();
  }

  @override
  void dispose() {
    _timer?.cancel();
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
              // Calculate logo size based on screen width (use 50% of screen width, min 150px, max 300px)
              final logoSize = (constraints.maxWidth * 0.5).clamp(150.0, 300.0);
              // Phase shape size (slightly smaller than logo)
              final shapeSize = logoSize * 0.8;
              
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ARC Logo (always shown)
                      Image.asset(
                        'assets/images/ARC-Logo.png',
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.contain,
                      ),
                      // Phase shape and label only when user has a phase (not first-time / no regime)
                      if (_phaseLoaded && _userHasPhase) ...[
                        const SizedBox(height: 24),
                        AnimatedPhaseShape(
                          phase: _currentPhase,
                          size: shapeSize,
                          rotationDuration: const Duration(seconds: 10),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _currentPhase,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
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

