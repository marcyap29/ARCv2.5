// lib/shared/ui/onboarding/arc_onboarding_sequence.dart
// ARC Onboarding Sequence - New conversational phase detection flow

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/ui/home/home_view.dart';
import 'arc_onboarding_cubit.dart';
import 'arc_onboarding_state.dart';
import 'widgets/lumara_pulsing_symbol.dart';
import 'widgets/phase_explanation_screen.dart';
// Old PhaseQuizScreen removed - replaced by PhaseQuizV2
// import 'widgets/phase_quiz_screen.dart'; // DEPRECATED
import 'widgets/phase_analysis_screen.dart';
import 'widgets/phase_reveal_screen.dart';
import 'phase_quiz_v2_screen.dart';

/// Main onboarding sequence widget
class ArcOnboardingSequence extends StatelessWidget {
  const ArcOnboardingSequence({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ArcOnboardingCubit(),
      child: const ArcOnboardingSequenceContent(),
    );
  }
}

class ArcOnboardingSequenceContent extends StatelessWidget {
  const ArcOnboardingSequenceContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ArcOnboardingCubit, ArcOnboardingState>(
      listener: (context, state) {
        if (state.currentScreen == OnboardingScreen.complete) {
          // Navigate to home when onboarding is complete
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const HomeView(),
            ),
            (route) => false,
          );
        }
      },
      child: BlocBuilder<ArcOnboardingCubit, ArcOnboardingState>(
        builder: (context, state) {
          // Screen routing based on state with layered fade transitions
          Widget currentScreen;
          String screenKey;
          switch (state.currentScreen) {
            case OnboardingScreen.logoReveal:
              // Skip logo reveal, go directly to LUMARA intro
              currentScreen = const _LumaraIntroScreen();
              screenKey = 'lumara_intro';
              break;
            case OnboardingScreen.lumaraIntro:
              currentScreen = const _LumaraIntroScreen();
              screenKey = 'lumara_intro';
              break;
            case OnboardingScreen.arcIntro:
              // Redundant screen removed; show LUMARA capabilities if state ever lands here
              currentScreen = const _LumaraCapabilitiesScreen();
              screenKey = 'lumara_capabilities';
              break;
            case OnboardingScreen.narrativeIntelligence:
              currentScreen = const _LumaraCapabilitiesScreen();
              screenKey = 'lumara_capabilities';
              break;
            case OnboardingScreen.sentinelIntro:
              // Screen removed; show phase explanation if state ever lands here
              currentScreen = const PhaseExplanationScreen();
              screenKey = 'phase_explanation';
              break;
            case OnboardingScreen.phaseExplanation:
              currentScreen = const PhaseExplanationScreen();
              screenKey = 'phase_explanation';
              break;
            case OnboardingScreen.phaseQuiz:
              // Use PhaseQuizV2 instead of old PhaseQuizScreen
              currentScreen = const PhaseQuizV2Screen();
              screenKey = 'phase_quiz_v2';
              break;
            case OnboardingScreen.phaseAnalysis:
              currentScreen = const PhaseAnalysisScreen();
              screenKey = 'phase_analysis';
              break;
            case OnboardingScreen.phaseReveal:
              currentScreen = PhaseRevealScreen(
                phaseAnalysis: state.phaseAnalysis!,
              );
              screenKey = 'phase_reveal';
              break;
            case OnboardingScreen.complete:
              // Navigation handled by listener
              currentScreen = const Center(child: CircularProgressIndicator());
              screenKey = 'complete';
              break;
          }
          
          // Use AnimatedSwitcher with custom layered fade transition for intro screens
          if (state.currentScreen == OnboardingScreen.lumaraIntro ||
              state.currentScreen == OnboardingScreen.arcIntro ||
              state.currentScreen == OnboardingScreen.narrativeIntelligence ||
              state.currentScreen == OnboardingScreen.sentinelIntro ||
              state.currentScreen == OnboardingScreen.phaseExplanation) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 1600),
              switchInCurve: const Cubic(0.25, 0.1, 0.25, 1.0), // Custom eased curve
              switchOutCurve: const Cubic(0.25, 0.1, 0.25, 1.0), // Custom eased curve
              transitionBuilder: (Widget child, Animation<double> animation) {
                return _LayeredFadeTransition(
                  animation: animation,
                  child: child,
                );
              },
              child: KeyedSubtree(
                key: ValueKey(screenKey),
                child: currentScreen,
              ),
            );
          }
          
          return currentScreen;
        },
      ),
    );
  }
}

/// Screen 1: LUMARA Introduction (first screen after splash)
class _LumaraIntroScreen extends StatelessWidget {
  const _LumaraIntroScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => context.read<ArcOnboardingCubit>().nextScreen(),
        child: SafeArea(
          child: _LayeredScreenContent(
            gradientColors: [
              kcPrimaryColor.withOpacity(0.3),
              Colors.black,
            ],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing LUMARA symbol (standardized size)
                const LumaraPulsingSymbol(size: 120),
                const SizedBox(height: 48),
                // Text
                Text(
                  "Hi, I'm LUMARA.",
                  style: heading1Style(context).copyWith(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  "Share what's on your mind. I build context from your entries over time — your patterns, your phases, the decisions you're working through. Over time, responses get more relevant to where you actually are. Not a fresh start every session. Intelligence that compounds.",
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Text(
                  'Tap to continue',
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen 2: LUMARA capabilities
class _LumaraCapabilitiesScreen extends StatelessWidget {
  const _LumaraCapabilitiesScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => context.read<ArcOnboardingCubit>().nextScreen(),
        child: SafeArea(
          child: _LayeredScreenContent(
            gradientColors: [
              kcPrimaryColor.withOpacity(0.2),
              Colors.black,
            ],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "What LUMARA does for you.",
                  style: heading1Style(context).copyWith(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  "I remember your story so we don't start from zero each time. I notice patterns in your entries over time — which phase you're in, what's shifting, what matters most. I match my tone and depth to where you actually are: calmer when you need rest, more direct when you're ready to move. That's how every conversation stays relevant.",
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Text(
                  'Tap to continue',
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget that provides layered content structure for smooth transitions
class _LayeredScreenContent extends StatelessWidget {
  final List<Color> gradientColors;
  final Widget child;

  const _LayeredScreenContent({
    required this.gradientColors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: child,
        ),
      ),
    );
  }
}

/// Custom layered fade transition for smoother screen transitions
/// Uses a gentler, longer fade with eased curves to avoid harsh transitions
class _LayeredFadeTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _LayeredFadeTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Create smooth fade with very gentle eased curves
    // Using a custom cubic curve for smoother, less abrupt transitions
    final fadeAnimation = CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.25, 0.1, 0.25, 1.0), // Gentle ease-in-out
    );
    
    // Apply the fade with a slight delay for smoother appearance
    // The curve ensures the fade starts slowly and ends slowly, avoiding harsh cuts
    return FadeTransition(
      opacity: fadeAnimation,
      child: child,
    );
  }
}
