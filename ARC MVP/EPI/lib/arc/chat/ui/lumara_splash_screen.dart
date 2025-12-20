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

/// Splash screen with ARC logo and animated phase shape
class LumaraSplashScreen extends StatefulWidget {
  const LumaraSplashScreen({super.key});

  @override
  State<LumaraSplashScreen> createState() => _LumaraSplashScreenState();
}

class _LumaraSplashScreenState extends State<LumaraSplashScreen> 
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  String _currentPhase = 'Discovery'; // Default phase
  bool _phaseLoaded = false;
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
    
    _loadCurrentPhase();
    _startTimer();
  }

  Future<void> _loadCurrentPhase() async {
    try {
      // Use PhaseRegimeService - the authoritative source for current phase
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      String phase = 'Discovery'; // Default
      
      // Check current regime first
      final currentRegime = phaseRegimeService.phaseIndex.currentRegime;
      if (currentRegime != null) {
        phase = currentRegime.label.toString().split('.').last;
        // Capitalize first letter
        phase = phase[0].toUpperCase() + phase.substring(1);
        print('DEBUG: Splash using current regime phase: $phase');
      } else {
        // Fall back to most recent regime
        final allRegimes = phaseRegimeService.phaseIndex.allRegimes;
        if (allRegimes.isNotEmpty) {
          final sortedRegimes = List.from(allRegimes)
            ..sort((a, b) => b.start.compareTo(a.start));
          final mostRecent = sortedRegimes.first;
          phase = mostRecent.label.toString().split('.').last;
          phase = phase[0].toUpperCase() + phase.substring(1);
          print('DEBUG: Splash using most recent regime phase: $phase');
        } else {
          print('DEBUG: Splash - no regimes found, using default Discovery');
        }
      }

      if (mounted) {
        setState(() {
          _currentPhase = phase;
          _phaseLoaded = true;
        });
        print('DEBUG: Splash loaded phase: $_currentPhase');
      }
    } catch (e) {
      print('DEBUG: Error loading phase for splash: $e');
      if (mounted) {
        setState(() => _phaseLoaded = true);
      }
    }
  }

  void _startTimer() {
    // Navigate after 8 seconds to admire the animated phase shape
    _timer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        _checkAuthAndNavigate();
      }
    });
  }

  void _checkAuthAndNavigate() {
    _timer?.cancel();

    // Check if user is authenticated
    final isSignedIn = FirebaseAuthService.instance.isSignedIn;

    if (isSignedIn) {
      // User is signed in, go to home
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeView(),
        ),
      );
    } else {
      // User is not signed in, go to sign-in screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const SignInScreen(),
        ),
      );
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
                      // ARC Logo
                      Image.asset(
                        'assets/images/ARC-Logo.png',
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.contain,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Animated Phase Shape
                      AnimatedPhaseShape(
                        phase: _currentPhase,
                        size: shapeSize,
                        rotationDuration: const Duration(seconds: 10),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Phase name label (subtle)
                      if (_phaseLoaded)
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

