// lib/shared/ui/onboarding/arc_onboarding_sequence.dart
// ARC Onboarding Sequence - Personality onboarding (phases are internal model use only, not shown to user)

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
import 'widgets/personality_setup_screen.dart';
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
            case OnboardingScreen.personalitySetup:
              currentScreen = const PersonalitySetupScreen();
              screenKey = 'personality_setup';
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
              state.currentScreen == OnboardingScreen.phaseExplanation ||
              state.currentScreen == OnboardingScreen.personalitySetup) {
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

/// Screen 1: LUMARA Intro — capability + trust, first impression
class _LumaraIntroScreen extends StatelessWidget {
  const _LumaraIntroScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _LayeredScreenContent(
          gradientColors: [
            kcPrimaryColor.withOpacity(0.3),
            Colors.black,
          ],
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'LUMARA',
                  style: heading1Style(context).copyWith(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 10,
                  ),
                ),
                const SizedBox(height: 20),
                const LumaraPulsingSymbol(size: 100),
                const SizedBox(height: 32),
                Text(
                  'Frontier AI that actually knows you — and keeps it that way.',
                  style: heading1Style(context).copyWith(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Powered by the same models behind the best AI on the market. Your data stays on your device, encrypted, never used to train anything. Context activates only when you ask for it.',
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 15,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _SupportLine(icon: Icons.lock_outline, text: 'Your data lives on your device. Always.'),
                const SizedBox(height: 10),
                _SupportLine(icon: Icons.flash_on_outlined, text: 'Frontier model capability — no compromises.'),
                const SizedBox(height: 10),
                _SupportLine(icon: Icons.psychology_outlined, text: 'Full context when you want it. Nothing shared without your say.'),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.read<ArcOnboardingCubit>().nextScreen(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Get started'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No account required to explore. Context features unlock after your first journal entry.',
                  style: captionStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SupportLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: kcPrimaryColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: bodyStyle(context).copyWith(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// Screen 2: What Makes LUMARA Different — concrete value pillars
class _LumaraCapabilitiesScreen extends StatelessWidget {
  const _LumaraCapabilitiesScreen();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ArcOnboardingCubit>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _LayeredScreenContent(
          gradientColors: [
            kcPrimaryColor.withOpacity(0.2),
            Colors.black,
          ],
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Most AI forgets you the moment you close the app.',
                  style: heading1Style(context).copyWith(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'LUMARA remembers — but only when you want it to. Your journal, your patterns, your history. Available on demand. Private by design.',
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 15,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                _PillarCard(
                  title: 'Full context, on your terms.',
                  body: 'Bring your journal and history into any conversation with one tap. Or don\'t. LUMARA waits for you — it never assumes.',
                ),
                const SizedBox(height: 14),
                _PillarCard(
                  title: 'Your data never leaves without you.',
                  body: 'Everything stays on your device. When LUMARA needs to think, sensitive details are scrubbed before anything reaches the cloud. Encrypted at rest. Yours completely.',
                ),
                const SizedBox(height: 14),
                _PillarCard(
                  title: 'Frontier capability, no compromises.',
                  body: 'LUMARA runs on the same models powering the best AI available. Privacy architecture doesn\'t mean settling for less. It means you get both.',
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => cubit.startPersonalitySetup(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Set how we\'ll work together'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => cubit.startPersonalitySetup(),
                  child: Text(
                    'Jump in →',
                    style: bodyStyle(context).copyWith(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 15,
                    ),
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

class _PillarCard extends StatelessWidget {
  final String title;
  final String body;

  const _PillarCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: bodyStyle(context).copyWith(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: bodyStyle(context).copyWith(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
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
