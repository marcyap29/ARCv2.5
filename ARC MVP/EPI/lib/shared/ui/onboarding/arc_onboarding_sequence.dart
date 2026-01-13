// lib/shared/ui/onboarding/arc_onboarding_sequence.dart
// ARC Onboarding Sequence - New conversational phase detection flow

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/shared/ui/home/home_view.dart';
import 'arc_onboarding_cubit.dart';
import 'arc_onboarding_state.dart';
import 'widgets/lumara_pulsing_symbol.dart';
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
          // Screen routing based on state
          switch (state.currentScreen) {
            case OnboardingScreen.logoReveal:
              return const _LogoRevealScreen();
            case OnboardingScreen.lumaraIntro:
              return const _LumaraIntroScreen();
            case OnboardingScreen.arcIntro:
              return const _ArcIntroScreen();
            case OnboardingScreen.narrativeIntelligence:
              return const _NarrativeIntelligenceScreen();
            case OnboardingScreen.phaseQuiz:
              return const PhaseQuizScreen();
            case OnboardingScreen.phaseAnalysis:
              return const PhaseAnalysisScreen();
            case OnboardingScreen.phaseReveal:
              return PhaseRevealScreen(
                phaseAnalysis: state.phaseAnalysis!,
              );
            case OnboardingScreen.complete:
              // Navigation handled by listener
              return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

/// Screen 1: Logo Reveal (updated splash screen)
class _LogoRevealScreen extends StatefulWidget {
  const _LogoRevealScreen();

  @override
  State<_LogoRevealScreen> createState() => _LogoRevealScreenState();
}

class _LogoRevealScreenState extends State<_LogoRevealScreen> {
  String _currentPhase = 'Discovery';
  bool _phaseLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentPhase();
    // Auto-advance after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        context.read<ArcOnboardingCubit>().nextScreen();
      }
    });
  }

  Future<void> _loadCurrentPhase() async {
    try {
      final phase = await UserPhaseService.getCurrentPhase();
      if (mounted) {
        setState(() {
          _currentPhase = phase;
          _phaseLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _phaseLoaded = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => context.read<ArcOnboardingCubit>().nextScreen(),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ARC Logo
                Image.asset(
                  'assets/images/ARC-Logo.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                // Phase indicator (rotating)
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
        ),
      ),
    );
  }
}

/// Screen 2: LUMARA Introduction
class _LumaraIntroScreen extends StatelessWidget {
  const _LumaraIntroScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => context.read<ArcOnboardingCubit>().nextScreen(),
        child: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFD4AF37).withOpacity(0.3),
                  Colors.black,
                ],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pulsing LUMARA symbol
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
                      "I'm here to understand your narrative arc. As you journal and reflect, I learn the patterns in your journey—not just what happened, but what it means for where you're going.",
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
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFD4AF37).withOpacity(0.1),
                  Colors.black,
                ],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // LUMARA symbol (reduced opacity)
                    Opacity(
                      opacity: 0.3,
                      child: const LumaraPulsingSymbol(size: 80),
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
                      "This is where you journal, reflect, and talk with me. Write what matters. Your words stay on your device—private by design, powerful by architecture.",
                      style: bodyStyle(context).copyWith(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "ARC learns your patterns locally, then helps me give you insights that understand your whole story.",
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
        ),
      ),
    );
  }
}

/// Screen 4: Narrative Intelligence Concept
class _NarrativeIntelligenceScreen extends StatelessWidget {
  const _NarrativeIntelligenceScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFD4AF37).withOpacity(0.2),
                Colors.black,
              ],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Abstract visualization placeholder (interwoven arcs)
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: CustomPaint(
                      painter: _InterwovenArcsPainter(),
                    ),
                  ),
                  const SizedBox(height: 48),
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
                  ElevatedButton(
                    onPressed: () {
                      context.read<ArcOnboardingCubit>().startPhaseQuiz();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Begin Phase Detection',
                      style: buttonStyle(context).copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Painter for interwoven arcs visualization
class _InterwovenArcsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4AF37).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Draw interwoven arcs
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90) * (3.14159 / 180);
      final startAngle = angle;
      final sweepAngle = 180 * (3.14159 / 180);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
