// lib/shared/ui/onboarding/widgets/phase_analysis_screen.dart
// Phase Analysis Processing Screen (Screen 10)

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/ui/onboarding/arc_onboarding_cubit.dart';
import 'package:my_app/shared/ui/onboarding/widgets/lumara_pulsing_symbol.dart';

class PhaseAnalysisScreen extends StatelessWidget {
  const PhaseAnalysisScreen({super.key});

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
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // LUMARA symbol pulsing more intentionally (standardized size)
                    const LumaraPulsingSymbol(size: 120),
                    const SizedBox(height: 48),
                    Text(
                      "Let me see your pattern...",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
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
