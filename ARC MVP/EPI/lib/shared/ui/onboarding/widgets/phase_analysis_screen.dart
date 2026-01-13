// lib/shared/ui/onboarding/widgets/phase_analysis_screen.dart
// Phase Analysis Processing Screen (Screen 10)

import 'package:flutter/material.dart';
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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LUMARA symbol pulsing more intentionally
                const LumaraPulsingSymbol(size: 150),
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
        ),
      ),
    );
  }
}
