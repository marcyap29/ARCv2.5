// lib/shared/ui/onboarding/widgets/phase_reveal_screen.dart
// Phase Reveal Screen with dramatic reveal animation

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/ui/onboarding/arc_onboarding_cubit.dart';
import 'package:my_app/shared/ui/onboarding/arc_onboarding_state.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/ui/splash/animated_phase_shape.dart';
import 'package:my_app/shared/ui/onboarding/widgets/lumara_pulsing_symbol.dart';

class PhaseRevealScreen extends StatefulWidget {
  final PhaseAnalysis phaseAnalysis;

  const PhaseRevealScreen({
    super.key,
    required this.phaseAnalysis,
  });

  @override
  State<PhaseRevealScreen> createState() => _PhaseRevealScreenState();
}

class _PhaseRevealScreenState extends State<PhaseRevealScreen>
    with TickerProviderStateMixin {
  
  // Animation controller for the phase shape reveal
  late AnimationController _phaseShapeController;
  late Animation<double> _phaseShapeOpacity;
  
  // Animation controller for the content reveal
  late AnimationController _contentController;
  late Animation<double> _contentOpacity;

  @override
  void initState() {
    super.initState();
    
    // Phase shape reveal: 3 seconds fade in
    _phaseShapeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    
    _phaseShapeOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _phaseShapeController,
      curve: Curves.easeInOut,
    ));
    
    // Content reveal: 2 seconds fade in
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _contentOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeInOut,
    ));
    
    // When phase shape reveal completes, start content reveal
    _phaseShapeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _contentController.forward();
      }
    });
    
    // Start with a brief moment of darkness (500ms), then begin reveal
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _phaseShapeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _phaseShapeController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String _getPhaseName(PhaseLabel phase) {
    final phaseString = phase.toString().split('.').last;
    return phaseString[0].toUpperCase() + phaseString.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final phaseName = _getPhaseName(widget.phaseAnalysis.phase);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                kcPrimaryColor.withOpacity(0.2),
                Colors.black,
              ],
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // LUMARA symbol faded to background (20% opacity)
                      Opacity(
                        opacity: 0.2,
                        child: const LumaraPulsingSymbol(size: 120),
                      ),
                      const SizedBox(height: 48),

                      // Phase constellation - fades in from darkness over 5 seconds
                      AnimatedBuilder(
                        animation: _phaseShapeOpacity,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _phaseShapeOpacity.value,
                            child: AnimatedPhaseShape(
                              phase: phaseName,
                              size: 200,
                              rotationDuration: const Duration(seconds: 15),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 48),

                      // All content - fades in after phase shape is revealed
                      AnimatedBuilder(
                        animation: _contentOpacity,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _contentOpacity.value,
                            child: Column(
                              children: [
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
                                  widget.phaseAnalysis.recognitionStatement,
                                  style: bodyStyle(context).copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 16,
                                    height: 1.6,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),

                                // Phase evolution explanation
                                Text(
                                  "This is your starting assessment. As you journal, ARC refines your phase based on sustained patterns, not single entries.",
                                  style: bodyStyle(context).copyWith(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 15,
                                    height: 1.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),

                                Text(
                                  "Your phase constellation will fill with words and patterns as we talk. This is how ARC visualizes your narrative structure over time.",
                                  style: bodyStyle(context).copyWith(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 48),

                                // Tracking question
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: kcPrimaryColor.withOpacity(0.3),
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
                                        widget.phaseAnalysis.trackingQuestion,
                                        style: bodyStyle(context).copyWith(
                                          color: kcPrimaryColor,
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
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kcPrimaryColor,
                                      foregroundColor: Colors.white,
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
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              // Close button (X)
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
