// lib/arc/chat/ui/lumara_splash_screen.dart
// LUMARA splash screen shown on app launch

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:my_app/models/user_profile_model.dart';
import 'package:my_app/shared/ui/home/home_view.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/ui/auth/sign_in_screen.dart';
import 'package:my_app/ui/splash/animated_phase_shape.dart';
import 'package:my_app/shared/ui/onboarding/arc_onboarding_sequence.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/prism/atlas/rivet/rivet_provider.dart';

/// Splash screen with LUMARA logo and animated phase shape
class LumaraSplashScreen extends StatefulWidget {
  const LumaraSplashScreen({super.key});

  @override
  State<LumaraSplashScreen> createState() => _LumaraSplashScreenState();
}

class _LumaraSplashScreenState extends State<LumaraSplashScreen> 
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  /// Safeguard: if phase load hangs, still navigate after this delay so app never sticks on splash/white.
  Timer? _safeguardTimer;
  String _currentPhase = 'Discovery';
  bool _phaseLoaded = false;
  /// True only when the user has at least one phase regime (current or past).
  /// When false, we show only the LUMARA logo—no phase shape or label.
  bool _userHasPhase = false;
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
    try {
      // SOP: 1a RIVET (gate open + regime), else 1b quiz result, else Discovery
      var profilePhase = await UserPhaseService.getCurrentPhase();
      print('DEBUG: _loadCurrentPhase - getCurrentPhase returned: "$profilePhase"');
      
      // MIGRATION: If UserProfile has no phase, try to backfill from entries
      if (profilePhase.isEmpty) {
        print('DEBUG: Profile phase is empty, attempting backfill from entries...');
        final entryPhase = await _getPhaseFromEntries();
        print('DEBUG: _getPhaseFromEntries returned: "$entryPhase"');
        if (entryPhase != null && entryPhase.isNotEmpty) {
          print('DEBUG: Backfilling UserProfile phase from entry: $entryPhase');
          final success = await UserPhaseService.forceUpdatePhase(entryPhase);
          print('DEBUG: forceUpdatePhase returned: $success');
          profilePhase = entryPhase;
        }
      }
      
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      bool rivetGateOpen = false;
      try {
        final rivetProvider = RivetProvider();
        if (!rivetProvider.isAvailable) {
          await rivetProvider.initialize('default_user');
        }
        rivetGateOpen = rivetProvider.service?.wouldGateOpen() ?? false;
      } catch (_) {}

      String? regimePhase;
      final currentRegime = phaseRegimeService.phaseIndex.currentRegime;
      final allRegimes = phaseRegimeService.phaseIndex.allRegimes;
      if (currentRegime != null) {
        regimePhase = currentRegime.label.toString().split('.').last;
      } else if (allRegimes.isNotEmpty) {
        final sortedRegimes = List.from(allRegimes)
          ..sort((a, b) => b.start.compareTo(a.start));
        regimePhase = sortedRegimes.first.label.toString().split('.').last;
      }

      final displayPhase = UserPhaseService.getDisplayPhase(
        regimePhase: regimePhase,
        rivetGateOpen: rivetGateOpen,
        profilePhase: profilePhase,
      );
      
      // Brand new users with no phase see NO phase shape (empty displayPhase)
      // Only show phase shape when we have an actual phase from regime or profile
      final hasPhase = displayPhase.isNotEmpty;
      final phase = hasPhase
          ? displayPhase[0].toUpperCase() + displayPhase.substring(1).toLowerCase()
          : ''; // No default - brand new users see LUMARA logo only

      if (mounted) {
        setState(() {
          _userHasPhase = hasPhase;
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
  
  /// Get phase from existing journal entries (for migration/backfill)
  Future<String?> _getPhaseFromEntries() async {
    try {
      final journalRepo = JournalRepository();
      final entries = await journalRepo.getAllJournalEntries();
      print('DEBUG: _getPhaseFromEntries - found ${entries.length} entries');
      if (entries.isEmpty) return null;
      
      // Sort by most recent first
      final sortedEntries = List.of(entries)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Find the first entry with a valid phase
      for (final entry in sortedEntries) {
        print('DEBUG: Checking entry ${entry.id}: autoPhase=${entry.autoPhase}, computedPhase=${entry.computedPhase}, phase=${entry.phase}');
        // Use computedPhase (priority: userPhaseOverride > autoPhase > legacyPhaseTag)
        final computed = entry.computedPhase;
        if (computed != null && computed.isNotEmpty) {
          // Capitalize properly
          final result = computed[0].toUpperCase() + computed.substring(1).toLowerCase();
          print('DEBUG: Found phase from computedPhase: $result');
          return result;
        }
        // Fallback to phase field
        if (entry.phase != null && entry.phase!.isNotEmpty) {
          final phase = entry.phase!;
          final result = phase[0].toUpperCase() + phase.substring(1).toLowerCase();
          print('DEBUG: Found phase from phase field: $result');
          return result;
        }
      }
      print('DEBUG: No entries with valid phase found');
      return null;
    } catch (e) {
      print('DEBUG: Error getting phase from entries: $e');
      return null;
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
              builder: (context) => HomeView(),
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
                      // LUMARA logo (always shown)
                      Image.asset(
                        'assets/icon/LUMARA_Sigil.png',
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

