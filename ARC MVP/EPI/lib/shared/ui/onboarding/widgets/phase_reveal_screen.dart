// lib/shared/ui/onboarding/widgets/phase_reveal_screen.dart
// Phase Reveal Screen (Screen 11)

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/shared/ui/onboarding/arc_onboarding_cubit.dart';
import 'package:my_app/shared/ui/onboarding/arc_onboarding_state.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/ui/splash/animated_phase_shape.dart';
import 'package:my_app/shared/ui/onboarding/widgets/lumara_pulsing_symbol.dart';

class PhaseRevealScreen extends StatelessWidget {
  final PhaseAnalysis phaseAnalysis;

  const PhaseRevealScreen({
    super.key,
    required this.phaseAnalysis,
  });

  String _getPhaseName(PhaseLabel phase) {
    // Convert enum to string using toString and extract the name part
    final phaseString = phase.toString().split('.').last;
    return phaseString[0].toUpperCase() + phaseString.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final phaseName = _getPhaseName(phaseAnalysis.phase);

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
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  // LUMARA symbol faded to background (20% opacity, standardized size)
                  Opacity(
                    opacity: 0.2,
                    child: const LumaraPulsingSymbol(size: 120),
                  ),
                  const SizedBox(height: 48),

                  // Phase constellation (empty, wireframe)
                  AnimatedPhaseShape(
                    phase: phaseName,
                    size: 200,
                    rotationDuration: const Duration(seconds: 15),
                  ),
                  const SizedBox(height: 48),

                  // Phase name
                  Text(
                    "You're in $phaseName.",
                    style: heading1Style(context).copyWith(
                      color: Colors.white,
                      fontSize: 28,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Recognition statement
                  Text(
                    phaseAnalysis.recognitionStatement,
                    style: bodyStyle(context).copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  Text(
                    "Your phase constellation will fill with words and patterns as you journal. This is how ARC visualizes your narrative structure over time.",
                    style: bodyStyle(context).copyWith(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Tracking question (smaller, bottom)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "The question you're living:",
                          style: bodyStyle(context).copyWith(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          phaseAnalysis.trackingQuestion,
                          style: bodyStyle(context).copyWith(
                            color: const Color(0xFFD4AF37),
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Enter ARC button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        context.read<ArcOnboardingCubit>().completeOnboarding();
                        // Navigation handled by BlocListener in parent
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
                        'Enter ARC',
                        style: buttonStyle(context).copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
              // Close button (X) in upper left corner
              Positioned(
                top: 16,
                left: 16,
                child: IconButton(
                  onPressed: () {
                    context.read<ArcOnboardingCubit>().skipToMainPage();
                  },
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                  tooltip: 'Close quiz',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
