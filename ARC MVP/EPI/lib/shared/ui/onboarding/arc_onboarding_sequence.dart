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
import 'widgets/phase_quiz_screen.dart';
import 'widgets/phase_analysis_screen.dart';
import 'widgets/phase_reveal_screen.dart';

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
              currentScreen = const _ArcIntroScreen();
              screenKey = 'arc_intro';
              break;
            case OnboardingScreen.narrativeIntelligence:
              currentScreen = const _NarrativeIntelligenceScreen();
              screenKey = 'narrative_intelligence';
              break;
            case OnboardingScreen.sentinelIntro:
              currentScreen = const _SentinelIntroScreen();
              screenKey = 'sentinel_intro';
              break;
            case OnboardingScreen.phaseExplanation:
              currentScreen = const PhaseExplanationScreen();
              screenKey = 'phase_explanation';
              break;
            case OnboardingScreen.phaseQuiz:
              currentScreen = const PhaseQuizScreen();
              screenKey = 'phase_quiz';
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
                  "Hi, I'm LUMARA, your personal intelligence.",
                  style: heading1Style(context).copyWith(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  "I'm here to understand your narrative arc. As we talk and reflect together, I learn the patterns in your journey—not just what happened, but what it means for where you're going.",
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "I'll help you see the story you're living.",
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

/// Screen 3: ARC Introduction
class _ArcIntroScreen extends StatelessWidget {
  const _ArcIntroScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => context.read<ArcOnboardingCubit>().nextScreen(),
        child: SafeArea(
          child: _LayeredScreenContent(
            gradientColors: [
              kcPrimaryColor.withOpacity(0.1),
              Colors.black,
            ],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LUMARA symbol (reduced opacity, standardized size)
                Opacity(
                  opacity: 0.3,
                  child: const LumaraPulsingSymbol(size: 120),
                ),
                const SizedBox(height: 48),
                Text(
                  "Welcome to ARC.",
                  style: heading1Style(context).copyWith(
                    color: Colors.white,
                    fontSize: 28,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  "This is where we have conversations. Share what matters. Your words stay on your device—private by design, powerful by architecture.",
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "ARC learns your patterns locally, then provides insights that understand your whole story.",
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

/// Screen 3: Narrative Intelligence Concept
class _NarrativeIntelligenceScreen extends StatelessWidget {
  const _NarrativeIntelligenceScreen();

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
                  "ARC and LUMARA are built on something new: Narrative Intelligence.",
                  style: heading1Style(context).copyWith(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  "Not just memory. Not just AI assistance.",
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "Intelligence that tracks *who you're becoming*, not just what you've done. That understands developmental trajectories, not disconnected moments.",
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "Your life has an arc. Let's follow it together.",
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
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

/// Screen 4: SENTINEL Introduction
class _SentinelIntroScreen extends StatelessWidget {
  const _SentinelIntroScreen();

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
                  "One more thing.",
                  style: heading1Style(context).copyWith(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  "I'm designed to notice patterns in your writing—including when things might be getting harder than usual.",
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "If I detect sustained distress, sudden intensity, or language suggesting crisis, I'll check in directly. Not to judge, but because staying silent wouldn't be right.",
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
